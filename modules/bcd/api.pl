use strict;
use warnings;
use Data::Dumper;
use Graph::Directed;
use JSON;
use lib qw(lib);
use List::Util qw(reduce);
use Mojolicious::Lite;
use Mojo::Redis2;
use ddag_sample::bcd;
use Mojo::Pg;

app->config(hypnotoad => {listen => ['http://*:80']});

my $pg = Mojo::Pg->new('postgresql://ddag:nlprocks@localhost/pipelines');

my $modulename = "bcd";
helper redis => sub {
    state $r = Mojo::Redis2->new(url => "redis://redis:6379");
};

$pg->migrations->name('nlp')->from_string(<<EOF)->migrate;
-- 1 up
create unlogged table jobs (jobid text, module text, data text);
-- 1 down
drop table jobs;
EOF

my $bool = $pg->auto_migrate;
$pg      = $pg->auto_migrate($bool);

# If input is only from one module, put it in 'data',
# other wise remove the identifiers and ship 'em ;-)
sub process {
    my $hash = $_[0];
    my %newhash;
    if (keys %{$hash} == 1) {
        %newhash = (data => (%{$hash})[1]);
    } else {
        @newhash{ map { s/_[^_]*$//r } keys %{$hash} } = values %{$hash};
    }
    return ddag_sample::bcd::process(%newhash);
}

sub genError {
    my $c = shift;
    my $error = shift;
    $c->render(json => to_json({Error => $error}), status => 400);
}

sub genDAGGraph {
    my %edges = %{$_[0]};
    my $g = Graph::Directed->new();
    foreach my $from (keys %edges) {
        foreach my $to (@{$edges{$from}}) {
            $g->add_edge($from, $to);
        }
    }
    return $g;
}

post '/pipeline' => sub {
    my $c = shift;
    my $ilmt_json = decode_json($c->req->body);
    my $ilmt_modid = $ilmt_json->{modid} || genError($c, "No ModuleID Specified!") && return;
    my $ilmt_jobid = $ilmt_json->{jobid} || genError($c, "No JobID Specified!") && return;
    my $ilmt_data = $ilmt_json->{data} || genError($c, "No Data Specified!") && return;
    my $ilmt_dag = genDAGGraph($ilmt_json->{edges});
    genError($c, "Edges not specified!") && return if (!$ilmt_dag);
    my $ilmt_module = $modulename . '_' . $ilmt_modid;
    my @ilmt_inputs = map {@$_[0]} $ilmt_dag->edges_to($ilmt_module);
    my $db = $pg->db;
    foreach (@ilmt_inputs) {
	$db->query('insert into jobs (jobid, module, data) values (?, ?, ?)', $ilmt_jobid, $_, $ilmt_data->{$_}) if $ilmt_data->{$_};
    }
    my %content;
    my $results = $db->query('select * from jobs where jobid = (?)', $ilmt_jobid);
    while (my $next = $results->hash) {
        $content{$next->{module}} = $next->{data};
    }
    if (@ilmt_inputs == keys %content) {
        $c->render(json => "{Response: 'Processing...'}", status => 202);
        my $ilmt_output = process(\%content);
        $ilmt_data->{$ilmt_module} = $ilmt_output;
	%{$ilmt_data} = (%{$ilmt_data}, %content);
        my @tmp = $ilmt_dag->edges_from($ilmt_module);
        my @ilmt_next = map {@$_[1]} $ilmt_dag->edges_from($ilmt_module);
        if (@ilmt_next) {
            foreach (@ilmt_next) {
                my @module_info = split(/_([^_]+)$/, $_);
                my $next_module = $module_info[0];
                $ilmt_json->{modid} = $module_info[1];
                $c->ua->post("http://$next_module/pipeline" => json
                    => from_json(encode_json($ilmt_json), {utf8 => 1}) => sub {
                        my ($ua, $tx) = @_;
                        my $msg = $tx->error ? $tx->error->{message} : $tx->res->body;
                        $c->app->log->debug("[$ilmt_jobid]: $msg\n");
                    });
            }
        } else {
            $c->redis->publish($ilmt_jobid => encode_json($ilmt_json));
        }
    } else {
        $c->render(json => "{Response: 'Waiting for more inputs...'}", status => 202);
    }
};

app->start;

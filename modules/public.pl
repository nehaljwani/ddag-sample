use strict;
use warnings;
use Data::Dumper;
use Graph::Directed;
use JSON;
use List::Util qw(reduce);
use Mojolicious::Lite;
use Mojo::Redis2;
use Set::Scalar;
use String::Random;

app->config(hypnotoad => {listen => ['http://*:80']});

my $redis = Mojo::Redis2->new(url => "redis://redis:6379");
my %redis_handlers = ();
$redis->on(message => sub {
        my ($self, $msg, $channel) = @_;
        $redis_handlers{$channel}->($msg) if ($redis_handlers{$channel});
    });


my $randid = String::Random->new;

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

post '/' => sub {
    my $c = shift;
    my $ilmt_json = decode_json($c->req->body);
    my $ilmt_data = $ilmt_json->{data} || genError($c, "No Data Specified!") && return;
    my $ilmt_dag = genDAGGraph($ilmt_json->{edges});
    genError($c, "Edges not specified!") && return if (!$ilmt_dag);
    $ilmt_json->{jobid} = $randid->randpattern("ssssssss");
    $redis->subscribe([$ilmt_json->{jobid}]);
    my %res_data = ();
    $redis_handlers{$ilmt_json->{jobid}} = sub {
        my ($msg) = @_;
        %res_data = (%res_data, %{from_json($msg, { utf8  => 1 })->{data}});
        if ($ilmt_dag->vertices == keys %res_data) {
            $c->render(json => \%res_data);
            $redis->unsubscribe([$ilmt_json->{jobid}]);
        }
    };
    my @beginning_modules = $ilmt_dag->source_vertices();
    my $ilmt_next_modules = Set::Scalar->new;
    foreach (@beginning_modules) {
        $ilmt_next_modules->insert(map {@$_[1]} $ilmt_dag->edges_from($_));
    }
    foreach ($ilmt_next_modules->members) {
        my @module_info = split(/_([^_]+)$/, $_);
        my $next_module = $module_info[0];
        $ilmt_json->{modid} = $module_info[1];
        $c->ua->post("http://${next_module}/pipeline" => json
            => from_json(encode_json($ilmt_json), {utf8 => 1}) => sub {
                my ($ua, $tx) = @_;
                my $jobid = $ilmt_json->{jobid};
                my $msg = $tx->error ? $tx->error->{message} : $tx->res->body;
                $c->app->log->debug("[$jobid]: $msg\n");
            });
    }
};

app->start;

use strict;
use warnings;
use Data::Dumper;
package ddag_sample::efg;

#I just capitalize stuff
sub process {
    my %args = @_;
    foreach (keys %args) {
        $args{$_} =~ s/(\w+)/\u$1/g;
    }
    return join ':', values %args
}

1;

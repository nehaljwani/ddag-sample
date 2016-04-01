use strict;
use warnings;
use Data::Dumper;
package ddag_sample::abc;

#I just concatenate stuff
sub process {
    my %args = @_;
    return join '', values %args;
}

1;

use strict;
use warnings;
use Data::Dumper;
package ddag_sample::def;

#I just reverse concatenate stuff
sub process {
    my %args = @_;
    return reverse join ':', values %args;
}

1;

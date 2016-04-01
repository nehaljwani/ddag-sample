use strict;
use warnings;
use Data::Dumper;
package ddag_sample::bcd;

#I just lower case stuff
sub process {
    my %args = @_;
    return lc($args{'data'});
}

1;

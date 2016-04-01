use strict;
use warnings;
use Data::Dumper;
package ddag_sample::cde;

#I just do upper case
sub process {
    my %args = @_;
    return uc($args{'data'});
}

1;

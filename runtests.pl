#!/usr/bin/perl
use Data::Dumper;
use strict;

for (my $i= 0; $i < 100; $i++) {
    system("/Users/robertshane/Documents/qualpro/qp-perl/PerlExpectProj/expectSandbox.pl");
}
print "DONE";

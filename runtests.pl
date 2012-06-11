#!/usr/bin/perl
use Data::Dumper;
use strict;

our $fhdebug;
open($fhdebug, ">>debug.txt");
my $a = 'X';
my $b = 207;
for (my $i= 0; $i < 20; $i++) {
        print($fhdebug "@{[$a x $b]}\n");
    system("/Users/robertshane/Documents/qualpro/qp-perl/PerlExpectProj/expectSandbox.pl");
}
print "DONE";

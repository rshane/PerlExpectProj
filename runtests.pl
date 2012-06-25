#!/usr/bin/perl
use Data::Dumper;
use strict;

our ($fhdebug, $myoutput);
open($fhdebug, ">>debug.txt");
open($myoutput, ">>output.txt");

my $a = 'X';
my $b = 207;

for (my $i= 0; $i < 20; $i++) {
    print($fhdebug "@{[$a x $b]}\n");
    print($myoutput "@{[$a x $b]}\n");
    system("/Users/robertshane/Documents/qualpro/qp-perl/PerlExpectProj/expectParser.pl");
}
print "DONE";

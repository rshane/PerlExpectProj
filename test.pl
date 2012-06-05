#!/usr/bin/perl
use Expect;
use Data::Dumper;
#use warnings;
use constant DEBUG => 1;
use constant INMASS_SERVER_UNC =>   '\\inmass.ecm.qual-pro.com';
use constant INMASS_SERVER_UNC_DEBUG =>  'C:\opt\qp\inmass\200411\bindata';
use constant FILE_SERVER_UNC_PRODUCTION  => '\\file.corp.qual-pro.com';
use constant FILE_SERVER_UNC_DEBUG  =>  '\\file.corp.qual-pro.com\Users\rjshane\inmass\reports';
use constant FILE_SERVER_UNC => DEBUG() ? FILE_SERVER_UNC_DEBUG() : FILE_SERVER_UNC_PRODUCTION();
use constant LOG => "/tmp/edumplog.log";
use constant MOUNT_M_PRODUCTION => "NET USE M:@{[FILE_SERVER_UNC()]} /user:<<USER>> " .  '"<<PASSWORD>>"';
use constant MOUNT_M_DEBUG => 'SUBST M: C:\opt\qp\inmass\200411\bindata';
use constant MOUNT_M => DEBUG() ? MOUNT_M_DEBUG() : MOUNT_M_PRODUCTION();
use constant CNUM => '99';
use constant IPADDRESS => '10.2.0.101';
use constant PASS => 'EXPICSTK';
use constant PATH => '/Users/robertshane/Documents/qualpro/qp-perl/';
use constant SCRIPT => 'leadtime.template';
use constant HOST => DEBUG() ? 'Bobby' : die('NEED HOST NAME');; #if in debug need host to be 'Bobby' 
use constant HPASS => DEBUG() ? 'windows' : die('NEED HOST PASSWORD'); #if in debug need host to be 'windows'
use constant UPATH => 'expectPath.txt';
use constant USER => DEBUG() ? 'rjshane' : die('NEED USER NAME');
use constant UPASS => DEBUG() ? 'RJShane--' : die('NEED USER PASSWORD');
use constant REGEX_DEBUG => ;
use constant REGEX_PRODUCTION => ;
use constant REGEX => DEBUG() ? REGEX_DEBUG : REGEX_PRODUCTION; 
use constant INIT_INMASS_SESSION => <<END_STRING;
@{[ MOUNT_M ]}
NET USE N: @{[ FILE_SERVER_UNC ]} /user:<<USER>> "<<PASSWORD>>"
NET USE V: \\file.corp.qual-pro.com
SUBST O: C:\\TEMP
M:
INMASS
END_STRING

#---------
sub hcprint  {
#---------
    my $str   = shift;
    my @chars = split //, $str;
    my ($h, $char);
    foreach my $c (@chars)
    {
	$char = ord $c;
	$h = sprintf("%x", $char);
	if ($c =~ /[[:cntrl:]]/)  {
	    print(". | $h\n");
	} else {

	    printf ("%c | $h\n", $char);
	}
    }
    print "\n";
}

sub file_to_string {
#the parameter is a path to a file inclusive of file
#returns a string representation of the file
    my ($fh0, $file, $filestring, $filesize);
    $file = shift;
    open($fh0, $file) or die ("Can't open $file file: $!\n");
    $filesize = -s $file;
    read($fh0, $filestring, $filesize);
    close($fh0);    
    $filestring
}

	
my %thash0 = ('<<COMPANYNUMBER>>' => CNUM(), '<<PASSWORD>>' => PASS() );
my $regex,
my @tarray1 = ({re => $regex, '<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 8}, {re => $regex, '<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 9});

my $tpath = "@{[PATH()]}@{[SCRIPT()]}";
my ($sfile, $tmpl0, $tmpl1, $tmpl2);
$sfile = file_to_string($tpath);
$sfile =~ /<<ITEMID>>.c.8.<<VALUE>>../;
$tmpl0 = substr($sfile, 0, $-[0]);
$tmpl1 = substr($sfile, $-[$#-] ,$+[$#-] - $-[$#-] ); 
$tmpl2 = substr($sfile, $+[$#+]);

#einmass_run($expectobj, $cmd, $patt_value_hash, $regex_check); 


#Using Expect to access inmass
my $timeout = 5;
my $e = new Expect;
my $log = "edumplog.txt";

$e -> raw_pty(0);
$e->log_file($log, "w");
$e->spawn("telnet -l Bobby 10.2.0.101")
    or die "Cannot spawn telnet: $!\n";


$e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("windows\r\n");}]);
sleep(1);




#Log into Bobby Shanes Windows VM, make appropriate drives for inmass, and access inmass
$e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("windows\r\n");}]);
$e->expect($timeout, [ qr/Bobby>/i => sub {$e->send("cd ..\r\n");}]);
$e->expect($timeout, [ qr/Settings>$/i => sub {$e->send("test.bat\r\n");}]);
$e->expect($timeout, [ qr/Done/i => sub {$e->send("m:\r\n");}]);
$e->expect($timeout, [ qr/M/i => sub {$e->send("inmass\r");}]);
einmass_enter($tmpl0, $e, %thash0);
$e->expect($timeout, [ qr/Inventory File Maintenance/i => sub {$e->send("ZBAGr");}]);


sub einmass_enter {
    my $template = shift;
    my $e = shift;
    my %args = @_;


    foreach my $key (keys %args) {
	my $val = $args{$key};
	$template =~ s/$key/$val/g;
    }

    
    my $cnum = $args{'<<COMPANYNUMBER>>'};
    my $pass = $args{'<<PASSWORD>>'};
    my @atemplate = split //, $template;
#Using inmass via expect object $e passed in as a parameter

    for(my $i =0; $i <= scalar(@atemplate); $i++) {
	    $e->clear_accum();
	    $e->send($atemplate[$i]);
	    sleep(1);
    } 
}


$e->soft_close();

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
    

our $debug = 1;

#---------
sub bprint  {
#---------
    my $str   = shift;
    my @chars = split //, $str;

    foreach my $c (@chars)
    {
	printf "%x", ord $c;
    }
    print "\n";
}

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

sub check_success { 
#checks to see if a command was successful
#Parameters: (log_file, an_expect_statement, a_name_for_the_command, the_actual_command)
#returns an error if a command was not successful

    my $e = shift;
    my $success = shift;
    my $scommand = shift;
    my $command = shift;
    my $log = $e->log_file();

    if ($success == 1) {
	print $log "Successfully sent $scommand: $command\n";
	
    }
    else {
	print $log "ERROR occured with sending $scommand: $command\n";
	die("ERROR occured with sending $scommand: $command\n");
    }
}


#----------------
sub einmass_init {
#telnets into host computer and logs in
#Parameters: (host_name, host_password, ipaddress_of_host_computer, *log)
#The log parameter is optional if not set will default to "edumplog.txt"
#returns expect object

    my $host = shift;
    my $hpass = shift;
    my $ipadd = shift;
    my $logfile = shift;
    my $timeout = 5;
    my $e = new Expect;
    

    $e -> raw_pty(1);
    $e->debug(3);
    $e->exp_internal( 1 );
    $logfile = $logfile ? $logfile : LOG();
    $e->log_file("$logfile", "w");
    $e->spawn("telnet -l $host $ipadd")
	or die "Cannot spawn telnet: $!\n";
    $e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("$hpass\r\n");}]);
#    check_success($e, $successful, 'password');
#   if ($successful == 1) {
#	print $log "Successfully sent password\n";
	
#    }
#    else {
#	print $log "ERROR occured with sending password\n";
#	die("ERROR occured with sending password\n");
#    }
#    my $successful =  $e->expect($timeout, qr/Welcome to Microsoft Telnet Server/i );

    $e;
}

#----------------
sub einmass_run {
#For a generic command, uses a pattern=>value hash, to create a specific command from the generic one
#Sends command to host computer and checks whether command was successful or not, if not returns an error
#Parameters: (expect_obj, command, pattern_value_hash, regex_check, *log)
#The log parameter is optional if not set will default to "edumplog.txt"
#returns expect object
    
    my $e = shift;
    my $cmd = shift;
    my $patt_value_hash = shift;
    my $check; #tells expect what to check for after command ran to see if successful or not
    my $log = shift;

    my $timeout = 5;
    open($log, "<<$log");
    foreach my $key (sort keys %$patt_value_hash) {
	my $val = $patt_value_hash ->{$key};
	$cmd =~ s/$key/$val/g;
    }
    my $successful = $e->expect($timeout, [ qr/"$check"/i => sub {$e->send("$cmd");}]);
    if ($successful == 1) {
	print $log "Successfully sent command: $cmd\n";
    }
    else {
	die("ERROR occured with sending command $cmd to host computer\n");
    }
    
    $e;
    
=comment
    my $init_inmass_sess = shift;
    my $ipadd = shift;
    my %userprofile = @_;
    
    my $user = $userprofile{'<<USER>>'};
    my $userpass = $userprofile{'<<PASSWORD>>'};

    foreach my $key (sort keys %userprofile) {
	my $val = $userprofile{$key};
	$init_inmass_sess =~ s/$key/$val/g;
    }

    if(DEBUG()) {
	print "IN DEBUG MODE \n";
	$user = USER();
	$userpass = UPASS();
    }

    my @ainit_inmass_sess = split /\n/, $init_inmass_sess;
#     print Dumper(@ainit_inmass_sess);

#    my $length = scalar(@ainit_inmass_sess);
#    print "Length $length\n";
#    my $i = 0;
#    foreach my $val (@ainit_inmass_sess) {
#	print " i: $i,\n $val\n";
#	$i = $i + 1;
#    }    



#Using Expect to access inmass
    my $timeout = 5;
    my $e = new Expect;

    $e -> raw_pty(1);
    $e->log_file("edumplog.txt", "w");
    $e->spawn("telnet -l $user $ipadd")
	or die "Cannot spawn telnet: $!\n";
   
    $e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("$userpass\r\n");}]);
    sleep(1);



    for(my $i =0; $i <= scalar(@ainit_inmass_sess); $i++) {
	$e->expect($timeout, [ qr/Bobby>/i => sub {$e->send("cd ..\r\n");}]);
    } 


    $e;




#get to path on the telnetted machine



#Log into Bobby Shanes Windows VM, make appropriate drives for inmass, and access inmass
    $e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("windows\r\n");}]);
    $e->expect($timeout, [ qr/Bobby>/i => sub {$e->send("cd ..\r\n");}]);
    $e->expect($timeout, [ qr/Settings>$/i => sub {$e->send("test.bat\r\n");}]);
    $e->expect($timeout, [ qr/Done/i => sub {$e->send("m:\r\n");}]);
    $e->expect($timeout, [ qr/M/i => sub {$e->send("inmass\r");}]);
    sleep(1);
=cut 

}


#----------------
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
    for(my $i =0; $i <= scalar($atemplate); $i++) {
	    $e->clear_accum();
	    $e->send($atemplate[$i]);
	    sleep(1);
    } 
}


#----------------
sub einmass_iterator {
    my $origtemplate = shift;
    my $e = shift;
    my @hargs = @_;
    
#    print "einmass_iterator: hargs: " . Dumper(\@hargs);
    foreach my $args (@hargs) { 
 	my $template = $origtemplate;
#	print "  args: " . Dumper($args);
	foreach my $key (sort keys %$args) {
	    my $val = $args->{$key};
	    next if $key eq 're';
#	    print("KEY: $key VAL: $val\n");
	    $template =~ s/$key/$val/g;
	}
	
	my $cnum = $args->{'<<ITEMID>>'};
	my $pass = $args->{'<<VALUE>>'};
	my @atemplate = split //, $template;

#Using inmass via expect object $e passed in as a parameter
	for(my $i =0; $i <= scalar($atemplate); $i++) {
	    $e->clear_accum();
	    $e->send($atemplate[$i]);
	    sleep(1);
	}

    }   
}

#----------------
sub einmass_exit {
#exiting out of inmass
    my $template = shift;
    my $e = shift;
    my @atemplate = split //, $template;
    for(my $i =0; $i <= scalar($atemplate); $i++) {
	    $e->clear_accum();
	    $e->send($atemplate[$i]);
	    sleep(1);
    } 
    $e->soft_close();

}

	
my %thash0 = ('<<COMPANYNUMBER>>' => CNUM(), '<<PASSWORD>>' => PASS() );
my $regex;
my @tarray1 = ({re => $regex, '<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 8}, {re => $regex, '<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 9});

my $tpath = "@{[PATH()]}@{[SCRIPT()]}";
my ($sfile, $tmpl0, $tmpl1, $tmpl2);
$sfile = file_to_string($tpath);
$sfile =~ /<<ITEMID>>.c.8.<<VALUE>>../;
$tmpl0 = substr($sfile, 0, $-[0]);
$tmpl1 = substr($sfile, $-[$#-] ,$+[$#-] - $-[$#-] ); 
$tmpl2 = substr($sfile, $+[$#+]);

my ($host, $hpass, $init_inmass_sess, $ipadd, $path, $spath, $user, $userpass);
$host = HOST();
$hpass = HPASS();
$ipadd = IPADDRESS();

$user = USER();
$userpass = UPASS();

$init_inmass_sess = INIT_INMASS_SESSION();
my %userprofile = ('<<USER>>' => $user, '<<PASSWORD>>' => $userpass);

my $expectobj = einmass_init($host, $hpass, $ipadd); 
#einmass_run($expectobj, $cmd, $patt_value_hash, $regex_check); 
#einmass_enter($tmpl0, $expectobj, %thash0);
#einmass_iterator($tmpl1, $expectobj, @tarray1);
#einmass_exit($tmpl2, $expectobj);
$expectobj->soft_close();

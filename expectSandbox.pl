#!/usr/bin/perl
use Expect;
use Data::Dumper;
#use warnings;
use constant DEBUG => 1;
use constant INMASS_SERVER_UNC =>   '\\inmass.ecm.qual-pro.com';
use constant INMASS_SERVER_UNC_DEBUG =>  'C:\opt\qp\inmass\200411\bindata';
use constant FILE_SERVER_UNC_PRODUCTION  => '\\\\file.corp.qual-pro.com';
use constant FILE_SERVER_UNC_DEBUG  =>  '\\\\file.corp.qual-pro.com\Users\rjshane\inmass\reports';
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
use constant REGEX_DEBUG => '/[11;22H<<VALUE>>/';
use constant REGEX_PRODUCTION => ;
use constant REGEX => DEBUG() ? REGEX_DEBUG : REGEX_PRODUCTION; 
use constant INIT_INMASS_SESSION => <<END_STRING;
@{[ MOUNT_M ]}
NET USE N: @{[ FILE_SERVER_UNC ]} /user:<<USER>> "<<PASSWORD>>"
NET USE V: \\\\inmass.ecm.qual-pro.com\\var /user:<<USER>> "<<PASSWORD>>"
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
    my $log = shift;

    if ($success == 1) {
	print $log "\nSuccessfully sent $scommand: $command\n";

    }
    else {

	die("\nERROR occured with sending $scommand: $command\n");
    }
}


#----------------
sub einmass_init {
#telnets into host computer and logs into inmass
#Parameters: (host_name, host_password, ipaddress_of_host_computer, commands_needed_to_get_into_inmass, hash_of_userprofile, *log)
#The log parameter is optional if not set will default to "edumplog.txt"
#returns expect object

    my $host = shift;
    my $hpass = shift;
    my $ipadd = shift;
    my $userprofile = shift;
    my $logfile = shift;
    my $init_inmass_sess = INIT_INMASS_SESSION();
    my $timeout = 5;
    my $e = new Expect;
    my $success;

    $e -> raw_pty(0);
    $logfile = $logfile ? $logfile : LOG();
    $e->log_file("$logfile", "w");
    $e->spawn("telnet -l $host $ipadd")
	or die "Cannot spawn telnet: $!\n";
    $e->expect($timeout, [ qr/password:\s*\r?$/i => sub {$e->send("$hpass\r\n");}]);
    sleep(1);


    my $user = $userprofile->{'<<USER>>'};
    my $userpass = $userprofile->{'<<PASSWORD>>'};

    foreach my $key (sort keys %$userprofile) {
	my $val = $userprofile->{$key};
	$init_inmass_sess =~ s/$key/$val/g;
    }
    my @ainit_inmass_sess = split /\n/, $init_inmass_sess;
  
    foreach my $val (@ainit_inmass_sess) {
	$e->send("$val\r");
	sleep(1);
    }


    $e;
}


# Parameters( e_object pattern ) 
# Expect a given pattern as a response or error out
# returns expect object
#--------------
sub einmass_run  {
#--------------
    my $e       = shift;
    my $pattern = shift;
    my $timeout = 5;
    my $success = $e->expect($timeout, re =>$pattern);


    if ($success != 1) {
	die("Did not find pattern: $pattern in inmass to check that change happened");
    }

    $e;
}


#----------------
sub einmass_enter {
#Goes to correct path in inmass, enters in company number, password, then goes to desired choice
#Parameters: (action_template, expect_obj, hash_containing_company_number_and_company_value)
#returns expect object

    
    my $template = shift;
    my $e = shift;
    my %args = @_;
    

    foreach my $key (keys %args) {
	my $val = $args{$key};
	$template =~ s/$key/$val/g;
    }
    
    $e->send($template);
    $e 
}


#----------------
sub einmass_iterator {
#Iterates through each item and enters desired information according to action_template
#Parameters: (a hash contatin template, expect_obj, pattern, array_of_hashes_of_items)
#returns expect object
    
    my %args = @_;
    my $origtemplate = $args{'template'};
    my $e = $args{'expect_object'};
    my $pattern = $args{'pattern'};
    my $hargs = $args{'items_array'};

    
#    print "einmass_iterator: hargs: " . Dumper(\@hargs);
    my $i = 0;
    foreach my $args (@$hargs) { 
 	my $template = $origtemplate;
	my $itemid = $args->{'<<ITEMID>>'};
	my $value = $args->{'<<VALUE>>'};
#	my $pattern = $args->{'pattern'};
	$template =~ s/<<ITEMID>>/$itemid/;
	$template =~ s/<<VALUE>>/$value/;
	$pattern =~ s/<<VALUE>>/$value/;
	
	$e->clear_accum();
	$e->send($template);
	print ("THE PATTERN IN ITERATE IS: $pattern \n");
	$i++;
	einmass_run($e, $pattern);
	

    }

	
	
     
    $e;  
}

#----------------
sub einmass_exit {
#exiting out of inmass
    my $template = shift;
    my $e = shift;

    $e->send($template);
    $e->soft_close();

}

	
my %thash0 = ('<<COMPANYNUMBER>>' => CNUM(), '<<PASSWORD>>' => PASS() );
my $pattern = REGEX();
my @tarray1 = ({'<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 8}, {'<<ITEMID>>' => 'ZBAG', '<<VALUE>>' => 9});

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


my $expectobj = einmass_init($host, $hpass, $ipadd, \%userprofile); 
my %iterator_hash = ('template' => $tmpl1, 'expect_object' => $expectobj, 'pattern' => $pattern, 'items_array' => \@tarray1);

print "\nTHE PATTERN IS $iterator_hash->{'pattern'}\n";
einmass_enter($tmpl0, $expectobj, %thash0);
einmass_iterator(%iterator_hash);
einmass_exit($tmpl2, $expectobj);
$expectobj->soft_close();

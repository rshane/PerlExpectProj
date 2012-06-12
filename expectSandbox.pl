#!/usr/bin/perl
use Expect;
use Data::Dumper;
use strict;
#use warnings;
use constant DEBUG => 1;
use constant ITEM_VALUE_A =>int(rand(1000));
use constant ITEM_VALUE_B =>int(rand(1000));
use constant ITEM_VALUE_C => int(rand(1000));
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
use constant REGEX_DEBUG =>  '(\e\[11;22H(\e\[(1|37|44)m)*<<VALUE>>)|(\e\[11;23H(\e\[(1|37|44)m)*<<VALUE2>>)|(\e\[11;24H(\e\[(1|37|44)m)*<<VALUE1>>)|(Lead\s+Time\s+<<VALUE>>)|(RECORD\s+CHANGED)';
use constant REGEX_PRODUCTION => 'FILL IN!!!!!!!!!!!' ;
use constant REGEX => DEBUG() ? REGEX_DEBUG : REGEX_PRODUCTION; 
use constant INIT_INMASS_SESSION => <<END_STRING;
@{[ MOUNT_M ]}
NET USE N: @{[ FILE_SERVER_UNC ]} /user:<<USER>> "<<PASSWORD>>"
NET USE V: \\\\inmass.ecm.qual-pro.com\\var /user:<<USER>> "Qual-ProPassword4Inmass"
SUBST O: C:\\Temp
M:
INMASS
END_STRING
    

our ($fhdebug, $myoutput);
open($fhdebug, ">>debug.txt");
open($myoutput, ">>output.txt");

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
    my $timeout = 3;
    my $e = new Expect;
    my $success;

    $e -> raw_pty(0);
    $logfile = $logfile ? $logfile : LOG();
    $e->log_file("$logfile", "w");
  #  $e->debug(3);
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
    my $itemid  = shift; 
    my $timeout = 3;
#    my $success = $e->expect($timeout,  $pattern);
    my @exp_stat = $e->expect($timeout, '-re',  $pattern);


    print($fhdebug Dumper(\@exp_stat));
#    print($fhdebug @exp_stat[0]);
    print($fhdebug "\n\nPattern: $pattern \n\n");
    print($fhdebug "\n\nItemID: $itemid \n\n");
    print($myoutput "\nBefore: @{[$e->before()]} \n\n");
    print($myoutput "\nMatched: @{[@exp_stat[2]]} \n\n");
    print($myoutput "\nAfter: @{[$e->after()]} \n\n");
    print($myoutput "\n\nPattern: $pattern \n\n");

    if (@exp_stat[0] == 1) {

	print($fhdebug "\n\nSuccess: @{[@exp_stat[0]]} \n\n");
	print($myoutput "\n\nSuccess: @{[@exp_stat[0]]} \n\n");

    }
    else {
	print($fhdebug "\n\nSuccess: 0 \n\n");
	print($myoutput "\n\nSuccess: 0 \n\n");
	die("Did not find pattern: $pattern in inmass, desired change in inmass may not have happened");

    }
#MAKE SURE TO DIEEEEEEE IF NOT PASS TEST
#    my $nosuccess = !defined($success);
#    if ($success != 1) {
	
#	die("\nPatterns: $pattern\n Success: $success\n ");

#    }

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
    
    my %args  = @_;
    my $templ = $args{'template'};
    my $e     = $args{'expect_object'};
    my $patt  = $args{'pattern'};
    my $params = $args{'items_array'};
  
    my ($fh1, $fh2);

#    $e->notransfer(1);
#    $e->exp_internal(1);
    my $i = 0;
    foreach my $hash_item ( @$params )
    {
	
	my $tscrpt = $templ;
	my $pscrpt = $patt;
	my $itemid = $hash_item->{'<<ITEMID>>'};
	my $value = $hash_item->{'<<VALUE>>'};

	my @digitval = split //, $value;
	my $key_item  = '<<ITEMID>>';
	my $key_value = '<<VALUE>>';
	my $key2      = '<<VALUE2>>';
	my $key1      = '<<VALUE1>>';
		
	$tscrpt =~ s/$key_item/$itemid/ig;
	$tscrpt =~ s/$key_value/$value/ig;
	
	if (scalar(@digitval) == 3) {
	    my $val2 = "$digitval[1]($digitval[2])?";
	    my $val1 = $digitval[2]; #1's digit
	    $pscrpt =~ s/$key2/$val2/ig;
	    $pscrpt =~ s/$key1/$val1/ig;
	}

	if (scalar(@digitval) == 2) {
	    my $val2 = $digitval[1];
	    $pscrpt =~ s/$key2/$val2/ig;
	}

	my $key = "<<VALUE>>";
	my $val = "$digitval[0]($digitval[1]($digitval[2])?)?";
	$pscrpt =~ s/$key/$val/ig;

	
	$e->clear_accum();
	$e->send( $tscrpt );
	einmass_run( $e, $pscrpt, $itemid);
	
	
    }
    
    close($fhdebug);
#    $e;
}



#----------------
sub einmass_exit {
#exiting out of inmass
    my $template = shift;
    my $e = shift;
    my $timeout = 1;

    $e->send($template);
    $e->do_soft_close();
#    $e->expect($timeout, 'eof');
    return  1;

}

	
my %thash0 = ('<<COMPANYNUMBER>>' => CNUM(), '<<PASSWORD>>' => PASS() );
my $pattern = REGEX();
my @tarray1 = ( { '<<ITEMID>>' => '00023389-501', '<<VALUE>>' => ITEM_VALUE_A()  },
		{ '<<ITEMID>>' => '00023469-501', '<<VALUE>>' => ITEM_VALUE_B()  },
		{ '<<ITEMID>>' => '00022788-503', '<<VALUE>>' => ITEM_VALUE_C()  },
		{ '<<ITEMID>>' => '00022481-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00022788-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00021668-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00018716-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00018609-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00017959-501', '<<VALUE>>' => int(rand(1000)) },
		{ '<<ITEMID>>' => '00016126-501', '<<VALUE>>' => int(rand(1000)) }, );

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


my $e = einmass_init($host, $hpass, $ipadd, \%userprofile); 
my %iterator_hash = ( template      => $tmpl1, 
		      expect_object => $e, 
		      pattern       => $pattern, 
		      items_array   => \@tarray1);

einmass_enter($tmpl0, $e, %thash0);
einmass_iterator(%iterator_hash);
einmass_exit($tmpl2, $e);

1;



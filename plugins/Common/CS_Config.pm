##
##  Module to send messages to volunteers/organizers
##
package Common::CS_Config;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( getConfigInfo saveConfig);

use warnings;
use strict;


use open qw(:std :utf8);
use utf8;
use utf8::all;

sub saveConfig(%);

my $HOME = $ENV{'HOME'};
my $adminName;
my $adminEmail;
my $adminPhone;
my $adminTextNumber;
my $adminLogin;
my $adminPassword;
my $directoryAccessURL;
my $directoryAdminName;
my $directoryAdminEmail;
my $directoryAdminPhone;
my $directoryAdminTextNumber;
my $directoryAutoWelcome;
my $directoryEmailSender;
my $emailSender;
my $email_pwd;
my $email_uid;
my $email_smtp;
my $email_port;
my $TwilioAccount;
my $TwilioAuth;
my $TwilioPhone;
my $TwilioGender;
my $TwilioIntro;
my $phoneTreeEmailSender;
my $TwilioAlways;
my $logging;
my $maxRetries;
my $delayBetweenRetries;
my $callerIDNumber;
my $uid;
my $pwd;
our $ConfigName = ".churchsuite.cfg";
my $lastConfigLoad = 0;


#------------------------------------------------------------------------------
#  sub hidden()
#------------------------------------------------------------------------------
sub hidden($)
{
 my $text = $_[0];
 $text =~ tr/0-9A-Z!_a-z\-@/a-z\-@A-Z!_0-9/;
 return( $text);
}

#------------------------------------------------------------------------------
#  sub unhidden($)
#------------------------------------------------------------------------------
sub unhidden($)
{
 my $text = $_[0];
 $text =~ tr/a-z\-@A-Z!_0-9/0-9A-Z!_a-z\-@/;
 return( $text);
}

#------------------------------------------------------------------------------
#  sub loadConfig()
#		Load predefined config info for sending emails, etc.
#------------------------------------------------------------------------------
sub loadConfig()
{
	if ( -e $ConfigName)
	{
		##
		##  Check the last time the config file was changed
		##
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat( $ConfigName);

		
		##
		##  Is it after the last time we loaded the config?
		##
		if ( $mtime > $lastConfigLoad)
		{
			##
			##  If so, load the changed config
			##
			$lastConfigLoad = time();
			open( CFG, $ConfigName) || die "Couldn't open $ConfigName! $!\n";
			while( <CFG>)
			{
				chomp;
				if ( m/^EmailServer=(.*)/)
				{
					$email_smtp = $1;
					next;
				}
				if ( m/^EmailPort=(.*)/)
				{
					$email_port=int($1);
					next;
				}
				if ( m/^EmailUID=(.*)/)
				{
					$email_uid=$1;
					next;
				}
				if ( m/^EmailPWD=(.*)/)
				{
					$email_pwd = unhidden($1);
					next;
				}
				if ( m/^TwilioAcct=(.*)/)
				{
					$TwilioAccount=$1;
					next;
				}
				if ( m/^TwilioAuth=(.*)/)
				{
					$TwilioAuth = unhidden($1);
					next;
				}
				if ( m/^TwilioPhone=(.*)/)
				{
					$TwilioPhone=$1;
					next;
				}

				##  PhoneTree specific entries
				if ( m/^PhoneTreeEmailSender=(.*)/)
				{
					$phoneTreeEmailSender=$1;
					next;
				}

				if ( m/TwilioGender=(.*)/)
				{
					$TwilioGender=$1;
					next;
				}
				if ( m/TwilioIntro=(.*)/)
				{
					$TwilioIntro=$1;
					next;
				}
				if ( m/TwilioAlways=(.*)/)
				{
					$TwilioAlways=$1;
					next;
				}
				if ( m/Logging=(.*)/)
				{
					$logging = $1;
					next;
				}
				if ( m/MaxRetries=(.*)/)
				{
					$maxRetries = $1;
					next;
				}
				if ( m/DelayBetweenRetries=(.*)/)
				{
					$delayBetweenRetries = $1;
					next;
				}
				if (m/CallerIDNumber=(.*)/i)
				{
					$callerIDNumber = $1;
					next;
				}

				## Scheduler specific entries
				if ( m/^EmailSender=(.*)/)
				{
					$emailSender=$1;
					next;
				}
				if ( m/^AdminName=(.*)/)
				{
					$adminName = $1;
					next;
				}
				if ( m/^AdminEmail=(.*)/)
				{
					$adminEmail = $1;
					next;
				}
				if ( m/^AdminPhone=(.*)/)
				{
					$adminPhone = $1;
					next;
				}
				if ( m/^AdminText=(.*)/)
				{
					$adminTextNumber = $1;
					next;
				}
				if ( m/^AdminLogin=(.*)/)
				{
					$adminLogin = $1;
					next;
				}
				if ( m/^AdminPWD=(.*)/)
				{
					$adminPassword = unhidden($1);
					next;
				}

				#Directory specific entries
				if ( m/^DirectoryAccessURL=(.*)/)
				{
					$directoryAccessURL = $1;
					next;
				}
				if ( m/^DirectoryAdminName=(.*)/)
				{
					$directoryAdminName = $1;
					next;
				}
				if ( m/^DirectoryAdminEmail=(.*)/)
				{
					$directoryAdminEmail = $1;
					next;
				}
				if ( m/^DirectoryAdminPhone=(.*)/)
				{
					$directoryAdminPhone = $1;
					next;
				}
				if ( m/^DirectoryAdminText=(.*)/)
				{
					$directoryAdminTextNumber = $1;
					next;
				}
				if ( m/^DirectoryAutoWelcome=(.*)/)
				{
					$directoryAutoWelcome = int ($1 =~ /^yes/i);
					next;
				}
				if ( m/^DirectoryEmailSender=(.*)/)
				{
					$directoryEmailSender=$1;
					next;
				}

				die "No match found for $_!\n";
			}
			close CFG;
		}
	}
	else
	{
		die "There's no Config file!\n";
	}
}

#------------------------------------------------------------------------------
#  sub saveConfig( %config)
#  		This routine writes the provided config values to file and updates the
#  		current configuration values in memory
#------------------------------------------------------------------------------
sub saveConfig(%)
{
	my %config = @_;

	loadConfig();

	##
	##  Update info in memory
	##
	if ( defined( $config{"EmailServer"}))
	{
		$email_smtp = $config{"EmailServer"};
	}
	if ( defined( $config{"EmailPort"}))
	{
		$email_port = $config{"EmailPort"};
	}
	if ( defined( $config{"EmailUID"}))
	{
		$email_uid = $config{"EmailUID"};
	}
	if ( defined( $config{"EmailPWD"}))
	{
		$email_pwd = $config{"EmailPWD"};
	}
	if ( defined( $config{"TwilioAcct"}))
	{
		$TwilioAccount = $config{"TwilioAcct"};
	}
	if ( defined( $config{"TwilioAuth"}))
	{
		$TwilioAuth = $config{"TwilioAuth"};
	}
	if ( defined( $config{"TwilioPhone"}))
	{
		$TwilioPhone = $config{"TwilioPhone"};
	}

	##	PhoneTree specific
	if ( defined( $config{"TwilioGender"}))
	{
		$TwilioGender = $config{"TwilioGender"};
	}
	if ( defined( $config{"TwilioIntro"}))
	{
		$TwilioIntro = $config{"TwilioIntro"};
	}
	if ( defined( $config{"TwilioAlways"}))
	{
		$TwilioAlways = $config{"TwilioAlways"};
	}
	if ( defined( $config{"DirectoryEmailSender"}))
	{
		$directoryEmailSender = $config{"DirectoryEmailSender"};
	}
	if ( defined( $config{"Logging"}))
	{
		$logging  = $config{"Logging"};
	}
	if ( defined( $config{"MaxRetries"}))
	{
		$maxRetries  = $config{"MaxRetries"};
	}
	if ( defined( $config{"DelayBetweenRetries"}))
	{
		$delayBetweenRetries  = $config{"DelayBetweenRetries"};
	}
	if (defined( $config{"CallerIDNumber"}))
	{
		$callerIDNumber = $config{"CallerIDNumber"};
	}

	##	Scheduler specific
	if ( defined( $config{"EmailSender"}))
	{
		$emailSender = $config{"EmailSender"};
	}
	if ( defined( $config{"AdminName"}))
	{
		$adminName = $config{"AdminName"};
	}
	if ( defined( $config{"AdminEmail"}))
	{
		$adminEmail = $config{"AdminEmail"};
	}
	if ( defined( $config{"AdminPhone"}))
	{
		$adminPhone = $config{"AdminPhone"};
	}
	if ( defined( $config{"AdminText"}))
	{
		$adminTextNumber = $config{"AdminText"};
	}
	if ( defined( $config{"AdminLogin"}))
	{
		$adminLogin = $config{"AdminLogin"};
	}
	if ( defined( $config{"AdminPWD"}))
	{
		$adminPassword = $config{"AdminPWD"};
	}

	##	Directory specific
	if ( defined( $config{"DirectoryAdminName"}))
	{
		$directoryAdminName = $config{"DirectoryAdminName"};
	}
	if ( defined( $config{"DirectoryAdminEmail"}))
	{
		$directoryAdminEmail = $config{"DirectoryAdminEmail"};
	}
	if ( defined( $config{"DirectoryAdminPhone"}))
	{
		$directoryAdminPhone = $config{"DirectoryAdminPhone"};
	}
	if ( defined( $config{"DirectoryAdminText"}))
	{
		$directoryAdminTextNumber = $config{"DirectoryAdminText"};
	}
	if ( defined( $config{"DirectoryAccessURL"}))
	{
		$directoryAccessURL = $config{"DirectoryAccessURL"};
	}
	if ( defined( $config{"DirectoryAutoWelcome"}))
	{
		$directoryAutoWelcome = $config{"DirectoryAutoWelcome"};
	}
	if ( defined( $config{"DirectoryEmailSender"}))
	{
		$directoryEmailSender = $config{"DirectoryEmailSender"};
	}


	##
	##  Write to config file
	##

	open( CFG, ">", $ConfigName);

	print CFG "EmailServer=" . $email_smtp ."\n";
	print CFG "EmailPort=" . $email_port . "\n";
	print CFG "EmailUID=" . $email_uid . "\n";
	print CFG "EmailPWD=" . hidden( $email_pwd) . "\n";
	print CFG "TwilioAcct=" . $TwilioAccount . "\n";
	print CFG "TwilioAuth=" . hidden( $TwilioAuth) . "\n";
	print CFG "TwilioPhone=" . $TwilioPhone . "\n";

	##	Phone Tree specific
	print CFG "TwilioGender=" . $TwilioGender . "\n";
	print CFG "TwilioIntro=" . $TwilioIntro . "\n";
	print CFG "TwilioAlways=" . $TwilioAlways . "\n";
	print CFG "PhoneTreeEmailSender=" . $phoneTreeEmailSender . "\n";
	print CFG "Logging=" . $logging . "\n";
	print CFG "MaxRetries=" . $maxRetries . "\n";
	print CFG "DelayBetweenRetries=" . $delayBetweenRetries . "\n";
	print CFG "CallerIDNumber=" . $callerIDNumber . "\n";

	##	Scheduler specific
	print CFG "EmailSender=" . $emailSender . "\n";
	print CFG "AdminName=" . $adminName . "\n";
	print CFG "AdminEmail=" . $adminEmail . "\n";
	print CFG "AdminPhone=" . $adminPhone . "\n";
	print CFG "AdminText=" . $adminTextNumber . "\n";
	print CFG "AdminLogin=" . $adminLogin . "\n";
	print CFG "AdminPWD=" . hidden( $adminPassword) . "\n";

	##	Directory specific
	print CFG "DirectoryAdminName=" . $directoryAdminName . "\n";
	print CFG "DirectoryAdminEmail=" . $directoryAdminEmail . "\n";
	print CFG "DirectoryAdminPhone=" . $directoryAdminPhone . "\n";
	print CFG "DirectoryAdminText=" . $directoryAdminTextNumber . "\n";
	print CFG "DirectoryAccessURL=" . $directoryAccessURL . "\n";
	print CFG "DirectoryAutoWelcome=" . (($directoryAutoWelcome) ? 'yes' : 'no') . "\n";
	print CFG "DirectoryEmailSender=" . $directoryEmailSender . "\n";
	
	close CFG;
}
#------------------------------------------------------------------------------
#  sub getConfigInfo()
#  		This function returns the current data from the Config file
#------------------------------------------------------------------------------
sub getConfigInfo()
{
	loadConfig();

	my %configInfo = (
						'EmailServer' => $email_smtp , 
						'EmailPort' => $email_port, 
						'EmailUID' => $email_uid, 
						'EmailPWD' => $email_pwd , 
						'TwilioAcct' => $TwilioAccount, 
						'TwilioAuth' => $TwilioAuth , 
						'TwilioPhone' => $TwilioPhone, 

						# Scheduler specific
						'EmailSender' => $emailSender, 
						'AdminName' => $adminName , 
						'AdminEmail' => $adminEmail , 
						'AdminPhone' => $adminPhone , 
						'AdminText' => $adminTextNumber , 
						'AdminLogin' => $adminLogin , 
						'AdminPWD' => $adminPassword , 

						# Phone Tree specific
						'TwilioGender' => $TwilioGender,
						'TwilioIntro' => $TwilioIntro,
						'TwilioAlways' => $TwilioAlways,
						'PhoneTreeEmailSender' => $phoneTreeEmailSender,
						'Logging' => $logging,
						'MaxRetries' => $maxRetries,
						'DelayBetweenRetries' => $delayBetweenRetries,
						'CallerIDNumber' => $callerIDNumber,

						#  Directory specific
						'DirectoryAdminName' => $directoryAdminName,
						'DirectoryAdminEmail' => $directoryAdminEmail,
						'DirectoryAdminPhone' => $directoryAdminPhone,
						'DirectoryAdminText' => $directoryAdminTextNumber,
						'DirectoryAccessURL' => $directoryAccessURL,
						'DirectoryAutoWelcome' => $directoryAutoWelcome,
						'DirectoryEmailSender' => $directoryEmailSender,
					 );

	return %configInfo;
}

1;

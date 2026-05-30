##
##  Module to send messages to volunteers/organizers
##
package Common::CS_Config;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( getConfigInfo saveConfig configDiffers extractConfigDataFromTar updateConfigInfo restoreBackupData restoreCommonSettings releaseBackupData);

use warnings;
use strict;


use open qw(:std :utf8);
use utf8;
use utf8::all;
use Crypt::OpenPGP;
use JSON;
use File::Temp qw(tempfile);
use Data::Dumper;

sub saveConfig(%);
sub compareConfigInfo($$);
sub updateConfigInfo($@);

my $HOME = $ENV{'HOME'};
my $adminName;
my $adminEmail;
my $adminPhone;
my $adminTextNumber;
my $adminLogin;
my $adminPassword;
my $phoneTreeAdminLogin;
my $phoneTreeAdminPassword;
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

my %keyNames = ( Common => [ 'EmailServer', 'EmailPort', 'EmailUID', 'EmailPWD', 'TwilioAcct', 'TwilioAuth', 'TwilioPhone'],	
				 Scheduler => [ 'EmailSender', 'AdminName', 'AdminEmail', 'AdminPhone', 'AdminText', 'AdminLogin', 'AdminPWD'],
				 PhoneTree => [ 'TwilioGender', 'TwilioIntro', 'TwilioAlways', 'PhoneTreeEmailSender', 'Logging', 'MaxRetries', 'DelayBetweenRetries', 'CallerIDNumber', 'PhoneTreeAdminLogin', 'PhoneTreeAdminPWD'],
				 Directory => [ 'DirectoryAdminName', 'DirectoryAdminEmail', 'DirectoryAdminPhone', 'DirectoryAdminText', 'DirectoryAccessURL', 'DirectoryAutoWelcome']
			   );

my %hiddenKeys = (
					EmailPWD=> 1,
					TwilioAuth => 1,
					AdminPWD => 1,
					PhoneTreeAdminPWD => 1,
				 );

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

				#PhoneTree specific entries
				if ( m/^PhoneTreeAdminLogin=(.*)/)
				{
					$phoneTreeAdminLogin = $1;
					next;
				}
				if ( m/^PhoneTreeAdminPWD=(.*)/)
				{
					$phoneTreeAdminPassword = unhidden($1);
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
	if ( defined( $config{"PhoneTreeAdminLogin"}))
	{
		$phoneTreeAdminLogin = $config{"PhoneTreeAdminLogin"};
		print "PhoneTreeAdminLogin = $phoneTreeAdminLogin\n";
	}
	if ( defined( $config{"PhoneTreeAdminPWD"}))
	{
		$phoneTreeAdminPassword = $config{"PhoneTreeAdminPWD"};
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
		$directoryAutoWelcome = ( $config{"DirectoryAutoWelcome"} =~/1|yes/);
	}
	if ( defined( $config{"DirectoryEmailSender"}))
	{
		$directoryEmailSender = $config{"DirectoryEmailSender"};
	}


	##
	##  Write to config file
	##

	open( CFG, ">", $ConfigName);

	##  Common
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
	print CFG "PhoneTreeAdminLogin=" . $phoneTreeAdminLogin . "\n";
	print CFG "PhoneTreeAdminPWD=" . hidden( $phoneTreeAdminPassword) . "\n";

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
						# Common
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
						'PhoneTreeAdminLogin' => $phoneTreeAdminLogin , 
						'PhoneTreeAdminPWD' => $phoneTreeAdminPassword , 

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

#------------------------------------------------------------------------------
#  sub configDiffers( \%compareTo[, $project])
#  		This method compares the information provided in the hash reference
#  		"compareTo" to see if the configuration options for the given "project"
#  		are identical.  If no "project" is specified, all options are compared.
#  		The valid option names are "Common", "Scheduler", "Directory", and
#  		"PhoneTree".  A value of zero is returned if the options provided
#  		match what is in the current config file.
#------------------------------------------------------------------------------
sub configDiffers($$)
{
	my ( $compareTo, $project) = @_;
	my $rc = 0;
	my %configInfo = getConfigInfo();

	my @keys;

	if ( defined( $project))
	{
		@keys = @{$keyNames{$project}};
	}
	else
	{
		@keys = keys( %{$compareTo});
	}

	foreach my $key ( @keys)
	{
		if ( $configInfo{$key} ne $compareTo->{$key})
		{
			print "Configs differ for $key\n";
			$rc = 1;
		}
	}

	return $rc;
}


#------------------------------------------------------------------------------
#  sub updateConfigInfo( \%updateWith[, @projects])
#  		This method updates the config file info with the information provided
#  		in the hash reference "updateWith" for the given projects. If no
#  		projects are specified, all options are updated. The valid option names
#  		are "Common", "Scheduler", "Directory", and "PhoneTree". 
#------------------------------------------------------------------------------
sub updateConfigInfo($@)
{
	my ( $updateWith, @projects) = @_;

	my $rc = 0;
	my %newConfig;
	my @keys;
	print "Config data provided = " . Dumper( %{$updateWith}) ."\n";

	if ( int( @projects))
	{
		foreach my $project (@projects)
		{
			push( @keys, @{$keyNames{$project}});
		}
	}
	else
	{
		@keys = keys( %{$updateWith});
	}

	print "Key list is:\n\t" . join( "\n\t", @keys) . "\n";

	foreach my $key ( @keys)
	{
		if ( defined( $updateWith->{$key}))
		{
			print "Setting $key to " . $updateWith->{$key}. "\n";
			$newConfig{$key} = $updateWith->{$key};
		}
	}

	saveConfig( %newConfig);
}

#------------------------------------------------------------------------------
#  sub extractConfigDataFromTar($tar)
#  		This method extracts the configuration data stored in the backup tar
#  		and returns it as a hash.
#------------------------------------------------------------------------------
sub extractConfigDataFromTar($)
{
	my $tar = shift( @_);
	
	my %backupConfig;
	my @contents = split( /[\n\r]+/, $tar->get_content( ($ConfigName)));
	foreach my $entry (@contents)
	{
		my ($key, $value) = split( /\s*=\s*/, $entry);
		if ( defined( $hiddenKeys{$key}))
		{
			$backupConfig{$key} = unhidden( $value);
		}
		else
		{
			$backupConfig{$key} = $value;
		}
	}

	return %backupConfig;
}

#------------------------------------------------------------------------------
#  sub restoreBackupData( $backupData, $passphrase, $restoreFor, @dataFiles)
#		This routine restores files from the provided backupData for the
#		indicated service (Scheduler, Directory, PhoneTree). The routine will
#		restore the named data files from the backup, and if successful, it
#		will then unload the configuration data to a temporary file and check
#		to see if the configuration data will make changes to the existing
#		"Common" configuration (email and twilio account info).
#		
#		If the configuration data does not change the existing settings, the
#		configuration data will be used to update the existing configuration,
#		and the temporary file will be deleted.
#
#		If the configuration data differes in the Common section, the routine
#		will return the name of the configuration data temporary file to the
#		caller to let the user decide if the settings should be applied or not.
#
#		The routine returns two values. The first contains the status of
#		restoring the data files ('Success' or error message).  The second is
#		either undefined or the name of the file where configuration
#		information is buffered. 
#------------------------------------------------------------------------------
sub restoreBackupData($$$@)
{
	my ($backupData, $passphrase, $restoreFor, @dataFiles) = @_;
	my $restoreCompleted = "Success";
	my $backupName;

	unlink( "dataBackup.tar");

	##
	##  Decrypt the file data
	##
	my $pgp = Crypt::OpenPGP->new;
	my $decodedBackupData = $pgp->decrypt( Data => $backupData, Passphrase => $passphrase);

	if ( defined ( $decodedBackupData))
	{
		open( my $TAR, '>', "dataBackup.tar");
		binmode( $TAR);
		syswrite( $TAR, $decodedBackupData);
		close( $TAR);

		my $tar = Archive::Tar->new();
		$Archive::Tar::INSECURE_EXTRACT_MODE = 1;
		if ( $tar->read( 'dataBackup.tar'))
		{
			my $tarSucceeded;

			##
			##  Were we given specific data file names to extract?
			##
			if ( !@dataFiles)
			{
				##
				##  If not, get a list of all files in the tar,
				##  except for the config file.
				##
				@dataFiles = $tar->list_files();
				@dataFiles = map { (m/$ConfigName/)? () : $_} @dataFiles;
			}

			##
			##  Get the project specific data
			##
			$tarSucceeded = $tar->extract( @dataFiles);

			if ( $tarSucceeded)
			{
				##
				##  Get the contents of the config file from the tar
				##
				my %backupConfig = extractConfigDataFromTar( $tar);

				##
				##  See if the 'Common' config data differs
				##
				if ( configDiffers( \%backupConfig, 'Common'))
				{
					print "Setting aside config data...\n";

					##
					##  If so, store the config info temporarily
					##
					my $configJSON = encode_json( \%backupConfig);

					##
					##  Encrypt the file data
					##
					my $pgp = Crypt::OpenPGP->new;
					my $encodedJSON = $pgp->encrypt( Data => $configJSON, Passphrase => $passphrase);

					##
					##  Write the data to a tempfile
					##
					my $fh;
					( $fh, $backupName) = tempfile( 'BackupXXXXXXX', DIR => '.', SUFFIX=>'.pbj');
					binmode( $fh);
					syswrite( $fh, $encodedJSON);
					close( $fh);
				}

				##
				##  Restore all the configuration settings specific to this project
				##
				updateConfigInfo( \%backupConfig, $restoreFor);
				print "\n\n\n\nRestored!!!\n\n\n";
			}
			else
			{
				$restoreCompleted =  "Unable to read backup file contents!";
				print "\n\n\n\nRead error!!!\n\n\n";
			}
		}
		else
		{
			$restoreCompleted =  "Unable to read backup file!";
			print "\n\n\n\nTar read error!!!\n\n\n";
		}

		unlink( 'dataBackup.tar');
	}


	return ($restoreCompleted, $backupName);
}

#------------------------------------------------------------------------------
#  sub restoreCommonSettings($filename, $passphrase)
#  		This function reads the indicated temporary configuration settings
#  		backup file and uses its contents to update the Common configuration
#  		settings.  When it finishes, the backup file is removed.
#------------------------------------------------------------------------------
sub restoreCommonSettings($$)
{
	my ($filename, $passphrase) = @_;
	if (( -e $filename) && ($filename =~ /Backup.{7}\.pbj/))
	{

		open( my $fh, '<', $filename);
		binmode( $fh);
		sysread( $fh, my $backupData, 999999);
		close( $fh);
		print "Restoring common data.\n";

		##
		##  Encrypt the file data
		##
		my $pgp = Crypt::OpenPGP->new;
		my $encodedJSON = $pgp->decrypt( Data => $backupData, Passphrase => $passphrase);

		##
		##  If so, store the config info temporarily
		##
		my $configData = decode_json( $encodedJSON);

		##
		##  Restore all the configuration settings specific to this project
		##
		updateConfigInfo( $configData, 'Common');

		releaseBackupData( $filename);
	}
}

#------------------------------------------------------------------------------
#  sub releaseBackupData($)
#  		This function unlinks the named backup file
#------------------------------------------------------------------------------
sub releaseBackupData($)
{
	my $filename = shift(@_);
	if (( -e $filename) && ($filename =~ /Backup.{7}\.pbj/))
	{
		unlink( $filename);
	}
}

1;

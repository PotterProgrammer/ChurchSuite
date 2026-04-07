##
##  Module to save/restore scheduling information
##
package PhoneTree::BackupRestore;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( backupData restoreBackup);

use warnings;
use strict;

use lib "./plugins";

use Common::CS_Config;

use open qw(:std :utf8);
use utf8;
use utf8::all;

use Archive::Tar;
use Crypt::OpenPGP;
use PhoneTree::Members;

our $baseBackupFilename = 'phoneTreeBackup.pbt';

#------------------------------------------------------------------------------
#  sub backupData( $passphrase)
#  		This function backs up the current DB and config info into a file and
#  		returns the filename.
#------------------------------------------------------------------------------
sub backupData($)
{
	my $passphrase = shift( @_);
	my $tar = Archive::Tar->new;
	
	##
	##  Remove old files
	##
	unlink( "public/$baseBackupFilename");

##-->	print "Making a backup!\n";
##-->	print "Adding $PhoneTree::Members::DBFilename and  $Common::CS_Config::ConfigName\n";

	$tar->add_files( $PhoneTree::Members::DBFilename, $Common::CS_Config::ConfigName);
	my $tarData = $tar->write();

	my $pgp = Crypt::OpenPGP->new( Compat => 'GnuPG');
	my $encrypted = $pgp->encrypt( Data => $tarData, Passphrase => $passphrase );
	open( my $PBT, '>', "public/$baseBackupFilename");
	binmode( $PBT);
	syswrite( $PBT, $encrypted);
	close( $PBT);

	return( $baseBackupFilename);
}

#------------------------------------------------------------------------------
#  sub restoreBackup( $filename, $passphrase)
#		This function restores a backup from the filedata provided by $filename.
#		It returns a hash containing the title, text, and displayTime for the 
#		status of the restore.
#------------------------------------------------------------------------------
sub restoreBackup($$)
{
	my ($filename, $passphrase) = @_;
	my $size = $filename->size;
	my $name = $filename->filename;
	my %response;
	unlink( "phoneTreeBackup.tar");

	##
	##  Decrypt the file data
	##
	my $pgp = Crypt::OpenPGP->new;
	my $backupData = $filename->asset->slurp;

	my ($restoreResult, $backupFilename) = restoreBackupData( $backupData, $passphrase, 'PhoneTree', ());

	if ( $restoreResult eq 'Success')
	{
		%response = ( textMessage => "Restore completed!", backupFile=> $backupFilename, title=>'Success', showFor=>5000);
	}
	else
	{
		%response = ( textMessage => $restoreResult, backupFile=> $backupFilename, title=>'Warning!', showFor=>5000);
	}

	return %response;
}

1;


#
##  Module to save/restore scheduling information
##
package Directory::BackupRestore;

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

our $DBFilename = "./members.db";


#------------------------------------------------------------------------------
#  sub backupData()
#  		This function backs up the current DB and config info into a file and
#  		returns the filename.
#------------------------------------------------------------------------------
sub backupData()
{
		my $tar = Archive::Tar->new;
		
		##
		##  Remove old files
		##
		unlink( 'public/directoryBackup.pbt');

		print "Making a backup!\n";
		$tar->add_files( $DBFilename, $CS_Config::ConfigName, glob( "./public/directory/Photos/*"));
		my $tarData = $tar->write();

		my $pgp = Crypt::OpenPGP->new( Compat => 'GnuPG');
		my $encrypted = $pgp->encrypt( Data => $tarData, Passphrase => 'EnjoyTheView');
		open( my $PBT, '>', 'public/directoryBackup.pbt');
		binmode( $PBT);
		syswrite( $PBT, $encrypted);
		close( $PBT);

		return( 'directoryBackup.pbt');
}

#------------------------------------------------------------------------------
#  sub restoreBackup( $filename)
#		This function restores a backup from the filedata provided by $filename.
#		It returns a hash containing the title, text, and displayTime for the 
#		status of the restore.
#------------------------------------------------------------------------------
sub restoreBackup($)
{
	my $filename = shift(@_);
	my $size = $filename->size;
	my $name = $filename->filename;
	my %response;
	unlink( "directoryBackup.tar");

	##
	##  Decrypt the file data
	##
	my $pgp = Crypt::OpenPGP->new;
	my $encrypted = $filename->asset->slurp;
	my $backupData = $pgp->decrypt( Data => $encrypted, Passphrase => 'EnjoyTheView');

	if ( defined ( $backupData))
	{
		open( my $TAR, '>', "directoryBackup.tar");
		binmode( $TAR);
		syswrite( $TAR, $backupData);
		close( $TAR);

		my $tar = Archive::Tar->new();
		$Archive::Tar::INSECURE_EXTRACT_MODE = 1;
		if ( $tar->read( 'directoryBackup.tar'))
		{
			if ($tar->extract())
			{
				%response = ( textMessage => "Restore completed!", title=>'Success', showFor=>5000);
				print "\n\n\n\nRestored!!!\n\n\n";
			}
			else
			{
				%response = ( textMessage => "Unable to read backup file contents!", title=>'Warning!', showFor=>5000);
				print "\n\n\n\nRead error!!!\n\n\n";
			}
		}
		else
		{
			%response = ( textMessage => "Unable to read backup file!", title=>'Warning!', showFor=>5000);
			print "\n\n\n\nTar read error!!!\n\n\n";
		}

		unlink( 'directoryBackup.tar');
	}
	else
	{
		%response = ( textMessage => "Unable to read provided backup file!", title=>'Warning!', showFor=>5000);
		print "\n\n\n\nDecryption read error dude!!!\n\n\n";
	}

	return %response;
}

1;

##
##  Module to send messages to volunteers/organizers
##
package Directory::Messaging;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( sendEmailToMember sendPasswordResetAlert);

use warnings;
use strict;

use lib "./plugins";

use Data::Dumper;

use Common::CS_Config;
use Common::CS_Contact;

use DBI;
use POSIX;
use Email::Send::SMTP::Gmail;


use WWW::Twilio::API;
use WWW::Twilio::TwiML;
use URI::Escape;

use open qw(:std :utf8);
use utf8;
use utf8::all;

sub sendMemberAlert($);
sub sendSchedules($$$);

my $HOME = $ENV{'HOME'};
my $uid;
my $pwd;

#------------------------------------------------------------------------------
#  sub sendEmailToMember( $memberRef, $emailType)
#  		This function sends an email to a member to let them know
#  		how to access the system and set their password.  The argument received
#  		is a reference to a hash containing the user info.  If $emailType='New',
#  		then a "new member" message is sent.  If it is 'Reset', a "your password
#  		has been reset" message is sent
#------------------------------------------------------------------------------
sub sendEmailToMember($$)
{
	$SIG{CHLD} = "IGNORE";
	my $pid = fork();
	my %emailTypes = ( New => {email => "email/directory/newMember.htm", message => "Welcome to the new online directory!"},
					   Reset => {email => "email/directory/resetPassword.htm", message => "Your online directory password has been reset."});

	die "Fork failed!!\n" if (! defined( $pid));

	if ( !$pid)
	{
		my ($member, $emailType) = @_;
		my $emailTemplate;
		my $textTemplate;

		my %config = getConfigInfo();

		my $dialableAdminPhone = $config{DirectoryAdminPhone};
		my $textableAdminNumber = $config{DirectoryAdminText};

		$dialableAdminPhone =~ s/[^0-9]//g;
		$textableAdminNumber =~ s/[^0-9]//g;

		my $name = "$member->{firstName} $member->{lastName}";
		my $firstName = $member->{firstName};
		my $accessURL = $config{DirectoryAccessURL};
		$accessURL =~ s/\/\s*$//;		## Remove trailing slash, if any...

		my $activateURL = $accessURL . "?user=" . $member->{loginId} . "&UID=" . $member->{UID};
	
		##
		##  Read in the templates
		##
		if ( defined( $emailTypes{$emailType}))
		{
			open( my $TEMPLATE, '<', $emailTypes{$emailType}{email}) || die "Couldn't read email template!\n";
			read( $TEMPLATE, $emailTemplate, 999999);
			close $TEMPLATE;
		}
		else
		{
			print STDERR "Unrecognized mail type $emailType!\n";
			return;
		}
		
		if ( defined( $member->{email}) && ( $member->{email} =~ /@/))
		{
			my $email  = $emailTemplate;

			$email =~ s/__FIRST_NAME__/$firstName/smg;
			$email =~ s/__NAME__/$name/smg;
			$email =~ s/__LOGIN_ID__/$member->{loginId}/smg;
			$email =~ s/__ACTIVATE_URL__/$activateURL/smg;
			$email =~ s/__ACCESS_URL__/$accessURL/smg;
			$email =~ s/__DIRECTORY_ADMIN__/$config{DirectoryAdminName}/smg;
			$email =~ s/__DIRECTORY_ADMIN_EMAIL__/$config{DirectoryAdminEmail}/smg;
			$email =~ s/__DIRECTORY_ADMIN_PHONE__/$config{DirectoryAdminPhone}/smg;
			$email =~ s/__DIRECTORY_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
			$email =~ s/__DIRECTORY_ADMIN_TEXT_NUMBER__/$config{DirectoryAdminText}/smg;
			$email =~ s/__DIRECTORY_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;

			##
			##  Send the reminder email
			##
			print "Emailing $name a \"$emailTypes{$emailType}{message}\" message...\n";
			sendEmail( $member->{email}, $config{DirectoryEmailSender}, $emailTypes{$emailType}{message}, $email, 'email/directory/directoryLogo.png');
			print "Sent\n";
		}
		else
		{
			print STDERR "No email address for $name!\n";
		}

		exit;
	}
	else
	{
		print "Spawned $pid\n";
	}
}

1;

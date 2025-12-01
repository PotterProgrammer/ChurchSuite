##
##  Module to send messages to directory members
##
package Directory::Messaging;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( sendNoticeToMember sendPasswordResetAlert);

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
#  sub sendNoticeToMember( $memberRef, $msgType)
#  		This function sends an email or SMS to a member to let them know
#  		how to access the system and set their password.  The argument received
#  		is a reference to a hash containing the user info.  If $msgType='New',
#  		then a "new member" message is sent.  If it is 'Reset', a "your password
#  		has been reset" message is sent
#------------------------------------------------------------------------------
sub sendNoticeToMember($$)
{
	$SIG{CHLD} = "IGNORE";
	my $pid = fork();
	my %msgTypes = ( New   => {	email => "email/directory/newMember.htm", message => "Welcome to the new online directory!",
								sms => "sms/directory/newMember.txt", message => "Welcome to the new online directory!"
							  },
					 Reset => {	email => "email/directory/resetPassword.htm", message => "Your online directory password has been reset.",
				     			sms => "sms/directory/resetPassword.txt", message => "Your online directory password has been reset."
							  });

	die "Fork failed!!\n" if (! defined( $pid));

	if ( !$pid)
	{
		my ($member, $msgType) = @_;
		my $email;
		my $sms;

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
		if ( defined( $msgTypes{$msgType}))
		{
			open( my $TEMPLATE, '<', $msgTypes{$msgType}{email}) || die "Couldn't read email template \"$msgTypes{$msgType}{email}\"!\n";
			read( $TEMPLATE, $email, 999999);
			close $TEMPLATE;
			open( $TEMPLATE, '<', $msgTypes{$msgType}{sms}) || die "Couldn't read SMS template \"$msgTypes{$msgType}{sms}\"!\n";
			read( $TEMPLATE, $sms, 999999);
			close $TEMPLATE;
		}
		else
		{
			print STDERR "Unrecognized mail type $msgType!\n";
			return;
		}
		
		foreach  my $msg ($email, $sms)
		{
			$msg =~ s/__FIRST_NAME__/$firstName/smg;
			$msg =~ s/__NAME__/$name/smg;
			$msg =~ s/__LOGIN_ID__/$member->{loginId}/smg;
			$msg =~ s/__ACTIVATE_URL__/$activateURL/smg;
			$msg =~ s/__ACCESS_URL__/$accessURL/smg;
			$msg =~ s/__DIRECTORY_ADMIN__/$config{DirectoryAdminName}/smg;
			$msg =~ s/__DIRECTORY_ADMIN_EMAIL__/$config{DirectoryAdminEmail}/smg;
			$msg =~ s/__DIRECTORY_ADMIN_PHONE__/$config{DirectoryAdminPhone}/smg;
			$msg =~ s/__DIRECTORY_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
			$msg =~ s/__DIRECTORY_ADMIN_TEXT_NUMBER__/$config{DirectoryAdminText}/smg;
			$msg =~ s/__DIRECTORY_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;
		}

		if ( defined( $member->{email}) && ( $member->{email} =~ /@/))
		{
			##
			##  Send the email
			##
			print "Emailing $name a \"$msgTypes{$msgType}{message}\" message...\n";
			sendEmail( $member->{email}, $config{DirectoryEmailSender}, $msgTypes{$msgType}{message}, $email, 'email/directory/directoryLogo.png');
			print "Sent\n";
		}
		elsif ( defined( $member->{cell}) && ( $member->{cell} =~ m/^[0-9-\(\) ]+/))
		{
			##
			##  Send a text
			##
			my $phone = $member->{cell};
			$phone =~ s/[^0-9\+]//g;

			##
			##  Send the reminder text
			##
			print "Sending a \"$msgTypes{$msgType}{message}\" text to $phone\n";
			sendSMSTwilio( $phone, $sms);
##-->			while( $sms =~ m/(.{1,155})/smg)
##-->			{
##-->				sendSMSTwilio( $phone, $1);
##-->			}
			print "Sent\n";
		}
		else
		{
			##
			##  No active contact info for $name.  Send email
			##  to admin with login info for $name.  
			##
			print STDERR "No email address or phone for $name!\n";

			##
			##  Add notification at the top of the email,
			##  explaining that this is being sent to the admin
			##  because there was no email or cell phone
			##  provided for $name, and that the admin will
			##  need to provide this information to $name.
			##
			$email =~ s/<body>/<body>\n$config{DirectoryAdminName}, please note: <b>$name<\/b> does not have an email or cell phone number entered in the directory, so the following message could not be sent automatically.<p>Please provide the following information to $name so that $name can access the directory.<\/p><hr>\n/;
			$email =~ s/(<a href="([^"]*)">)click here/goto $1$2<\/a> in your browser/;

			##
			##  Send the email
			##
			print "Emailing $config{DirectoryAdminName} a \"$msgTypes{$msgType}{message}\" message for $name...\n";
			sendEmail( $config{DirectoryAdminEmail}, $config{DirectoryEmailSender}, "An online directory update for $name was made.", $email, 'email/directory/directoryLogo.png');
			print "Sent\n";
		}

		exit;
	}
	else
	{
		print "Spawned $pid\n";
	}
}


1;

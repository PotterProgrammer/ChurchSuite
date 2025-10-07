##
##  Module to send messages to volunteers/organizers
##
package Common::CS_Contact;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( sendEmail sendSMSTwilio);

use warnings;
use strict;

use lib "./plugins";


use Common::CS_Config;
use Email::Send::SMTP::Gmail;


use WWW::Twilio::API;
use WWW::Twilio::TwiML;
use URI::Escape;

use open qw(:std :utf8);
use utf8;
use utf8::all;

sub saveConfig(%);

my $HOME = $ENV{'HOME'};


#------------------------------------------------------------------------------
#  sendEmail( $to, $from, $sub, $message[, @attachments])
#		This function uses the default email settings to send an email message.
#		The function returns a non-zero value if an error occurred.
#------------------------------------------------------------------------------
sub sendEmail(@)
{
	my ( $to, $from, $subj, $message, @attachments) = @_;

	my %config = getConfigInfo();

  
	my ($mailer, $error) = Email::Send::SMTP::Gmail->new( -smtp=> $config{EmailServer},
														  -login=>$config{EmailUID},
														  -pass=>$config{EmailPWD}
													    );

	print STDERR "Can't get mail connection!! $error" if ( defined( $error) && length( $error));

	
	if ( @attachments)
	{
		my $filenames = join( ',', @attachments);

		$mailer->send( -to => $to,
					   -subject => $subj,
					   -from => $from, 
					   -contenttype => "text/html",
					   -body => $message,
					   -attachments => $filenames,
					   -disposition => "inline",
					 );
	}
	else
	{
		$mailer->send( -to => $to,
					   -subject => $subj,
					   -from => $from,
					   -contenttype => "text/html",
					   -body => $message,
					 );
	}
	$mailer->bye;
}

#------------------------------------------------------------------------------
#  sub sendSMSTwilio($$$)
#		Send an SMS message using Twilio to transmit. This function returns a
#		non-zero value on error.
#------------------------------------------------------------------------------
sub sendSMSTwilio($$)
{
	my ( $to, $message) = @_;
	my $rc = 0;
	my @pieces;

	push( @pieces, $message);

	my %config = getConfigInfo();

	my $twilio = WWW::Twilio::API->new(AccountSid  => $config{TwilioAcct},
									AuthToken   => $config{TwilioAuth},
									API_VERSION => '2010-04-01' );



	foreach $message ( @pieces)
	{
		print "Message = '$message'\n";
		chomp $message;
		
		##
		##  Send message via Twilio
		##
		print "Sending to $to\n";
		my $response = $twilio->POST(	'Messages',
									To   => $to,
									From => $config{TwilioPhone},
									Body => $message,
									);

		my $sid;
		my $status;
		if ($response->{content} =~ m/<Sid>([^<]*)<\/Sid>/i)
		{
			$sid = $1;
		}
		
		if ( $response->{content} =~ m/.*<Status>(.*?)<\/Status>/i)
		{
			$status = $1;
		}
		
		if ( !defined( $status))
		{
			print "*** ERROR ***   Unable to send TXT message!", "Twilio said: " . $response->{message} . "\n" . $response->{content} . "\n";

			sendEmail( $config{AdminEmail}, 'Scheduler Program Alert', 'Scheduler Program Alert!', "Trying to send a message to $to returned the following error: " .  $response->{content});
			$rc = 1;
		}
		else
		{
			print "Status=$status\n";
			while( $status =~ /queued|sending/)
			{
				##
				##  Get the response
				##
				$response = $twilio->GET( "Messages/$sid", AccountSid=> $config{TwilioAcct}, Sid=>$sid);
				$response->{content} =~ m/<Status>(.*?)<\/Status>/i;
				$status = $1;
				sleep 1;
		  	}

			print "Final status=$status\n";
			$rc |= ( $status =~ m/fail/);
		}
	}
	print "The rc was $rc\n";

	return( $rc);
}

1;

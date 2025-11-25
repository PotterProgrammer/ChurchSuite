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

			sendEmail( $config{AdminEmail}, 'Church Suite Program Alert', 'Church Suite Program Alert!', "Trying to send a message to $to returned the following error: " .  $response->{content});
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

#------------------------------------------------------------------------------
#  sub makeTwilioAutoCall( $phoneNumber, $message)
#  		This function calls the indicated phone number and reads the message
#  		provided.
#------------------------------------------------------------------------------
sub makeTwilioAutoCall($$)
{
 my ( $phoneNumber, $message) = @_;
 my $rc = 0;
 my %config = getConfigInfo();
 my $gender = ($config{TwilioGender} =~ /m/i) ? 'man' : 'woman';
 my $intro = $config{TwilioIntro};
 my $tw = WWW::Twilio::TwiML->new();
 my $twr = $tw->Response;
 my $callingFrom = (defined( $config{callerIDNumber})) ? $config{callerIDNumber} : $config{TwilioPhone};

 if ( defined( $intro) && length( $intro))
	{
	 $twr->Say( {voice => "$gender"},  $intro);
	 $twr->Pause();
 	}

 $twr->Say( {voice => "$gender"}, $message);
 $twr->Pause();
 $twr->Say( {voice => "$gender"}, "If you would like to hear this message again, please press 9 now.");
 $twr->Gather( {numDigits => 1, timeout => 3, finishOnKey=>'#'});
 $twr->Say( {voice => "$gender"}, "Good-bye...");

 my $msg = uri_escape( $tw->to_string);
 my $twilio = WWW::Twilio::API->new(AccountSid  => $config{TwilioAccount},
									AuthToken   => $config{TwilioAuth},
									API_VERSION => '2010-04-01' );

 my $response = $twilio->POST(	'Calls',
								To   => $phoneNumber,
								From => $callingFrom,
##-->  Changed by Twilio								IfMachine => 'Continue',
								MachineDetection => 'DetectMessageEnd',
								Url  => 'http://twimlets.com/echo?Twiml='.$msg
##-->								Url  => 'http://twimlets.com/message?Message%5B0%5D='.$msg
							 );

 print "Response is: $response->{content}\n\n$response->{message}\n";
 if ( $response->{code} != 201)
 	{
	 logCall( "Call not placed!",  "Twilio said: " . $response->{code} . ':' .$response->{message}. "\n" . $response->{content});
	 return 1;
	}
 $response->{content} =~ m/<Sid>(.*?)<\/Sid>.*<Status>(.*?)<\/Status>/i;
 my ($sid, $status) = ($1, $2);

 while( $status =~ /ringing|in-progress|queued/)
	{
	 $response = $twilio->GET( 'Calls', Sid=>$sid);
	 $response->{content} =~ m/<Status>(.*?)<\/Status>/i;
	 $status = $1;
##-->	 print "STATUS=$status\n";
	 sleep 1;
   }

 $rc = ( $status !~ m/completed/i);
 return( $rc);
}

1;

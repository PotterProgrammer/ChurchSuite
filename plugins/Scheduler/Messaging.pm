##
##  Module to send messages to volunteers/organizers
##
package Scheduler::Messaging;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( makeCalendarFor sendReminders sendSchedules sendUpdateRequest isAdmin);

use warnings;
use strict;

##-->@EXPORT = qw( makeCalendarFor getConfigInfo saveConfig sendEmail sendReminders sendSchedules sendUpdateRequest loadConfig isAdmin);

use lib "./plugins";

use Common::CS_Config qw( getConfigInfo saveConfig);
use Common::CS_Contact;

use Data::ICal;
use Data::ICal::Entry::Event;
use DateTime;
use DateTime::Format::ICal;
use DBI;
use Email::Send::SMTP::Gmail;
use POSIX;
use Scheduler::SaveRestore;
use Time::HiRes;


use WWW::Twilio::API;
use WWW::Twilio::TwiML;
use URI::Escape;

use open qw(:std :utf8);
use utf8;
use utf8::all;

sub makeCalendarFor($$$);
sub saveConfig(%);
sub sendReminders($);
sub sendSchedules($$$);

my $HOME = $ENV{'HOME'};
my $uid;
my $pwd;



#------------------------------------------------------------------------------
#  sub sendReminders( $numberOfDays)
#  		This function sends reminders to everyone who is scheduled to volunteer
#  		in the next number of days
#------------------------------------------------------------------------------
sub sendReminders($)
{
	$SIG{CHLD} = "IGNORE";
	my $pid = fork();

	die "Fork failed!!\n" if (! defined( $pid));

	if ( !$pid)
	{
		my ($number) = @_;
		my $emailTemplate;
		my $textTemplate;

		my %config = getConfigInfo();

		my $dialableAdminPhone = $config{AdminPhone};
		my $textableAdminNumber = $config{AdminText};

		$dialableAdminPhone =~ s/[^0-9]//g;
		$textableAdminNumber =~ s/[^0-9]//g;

		##
		##  Get a list of people volunteering on the given date
		##
		my @volunteers = readReminderList( $number);

		##
		##  Read in the templates
		##
		open( my $TEMPLATE, '<', "email/scheduler/reminder.htm") || die "Couldn't read email template!\n";
		read( $TEMPLATE, $emailTemplate, 999999);
		close $TEMPLATE;
		
		open( $TEMPLATE, '<', "sms/scheduler/reminder.txt") || die "Couldn't read text template!\n";
		read( $TEMPLATE, $textTemplate, 999999);
		close $TEMPLATE;


		##
		##  Loop through the list, sending reminders
		##
		foreach  my $scheduledVolunteer ( @volunteers)
		{
			##
			##  Get the info for this slot
			##
			my $name = $scheduledVolunteer->{name};
			my $firstName = ($name =~ m/^([^\s]*)/) ? $1 : $name;
			my $date = $scheduledVolunteer->{date};
			my $time = $scheduledVolunteer->{time};
			my $position = $scheduledVolunteer->{title};
			$date =~ s/(\d+)-(.*)/$2-$1/;

			print "Sending a reminder to $name for $position on $date\n";

			##
			##  Get info for this person
			##
			my @info = readVolunteers( $name);
			my $volunteerEmail = $info[0]->{email};
			my $volunteerPhone = $info[0]->{phone};
			my $contactMode = $info[0]->{contact};

			$volunteerPhone =~ s/[- \(\)]//g;

			##
			##  Should we email the person?
			##
			if ( $contactMode =~ /email|both/)
			{
				my $email  = $emailTemplate;

				$email =~ s/__FIRST_NAME__/$firstName/smg;
				$email =~ s/__NAME__/$name/smg;
				$email =~ s/__DATE__/$date/smg;
				$email =~ s/__TIME__/$time/smg;
				$email =~ s/__POSITION__/$position/smg;
				$email =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
				$email =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
				$email =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
				$email =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
				$email =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
				$email =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;

				##
				##  Send the reminder email
				##
				if ( defined( $volunteerEmail) && $volunteerEmail =~ m/\S\@\S/)
				{
					sendEmail( $volunteerEmail, $config{EmailSender}, 'Service reminder', $email, 'email/scheduler/reminder.png');
					print "Sent\n";
				}
				else
				{
					print STDERR "No email address for $name!\n";
				}
			}

			##
			##  Should we send a text?
			##
			if ( $contactMode =~ /text|both/)
			{
				my $text  = $textTemplate;

				$text =~ s/__FIRST_NAME__/$firstName/smg;
				$text =~ s/__NAME__/$name/smg;
				$text =~ s/__DATE__/$date/smg;
				$text =~ s/__TIME__/$time/smg;
				$text =~ s/__POSITION__/$position/smg;
				$text =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
				$text =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
				$text =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
				$text =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
				$text =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
				$text =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;

				##
				##  Send the reminder text
				##
				if ( defined( $volunteerPhone) && $volunteerPhone =~ m/^[0-9-]+$/)
				{
					print "Sending a text reminder to $volunteerPhone\n";
					sendSMSTwilio( $volunteerPhone, $text);
					print "Sent\n";
				}
				else
				{
					print STDERR "No phone number for $name!\n";
				}
				
			}
			
			##
			##  Note that this person was notified
			##
			updateScheduleReminded( $scheduledVolunteer);
		}
		exit;
	}
}

#------------------------------------------------------------------------------
#  sub sendSchedules( $firstDate, $lastDate, $calendarURL)
#  		This function sends out email copies of the personal volunteer schedule
#  		to each person who is scheduled to serve sometime from the first date
#  		through the last date.
#------------------------------------------------------------------------------
sub sendSchedules($$$)
{
	$SIG{CHLD} = "IGNORE";
	my $pid = fork();

	die "Fork failed!!\n" if (! defined( $pid));

	if ( !$pid)
	{
		my ( $firstDate, $lastDate, $calendarURL) = @_;
		my $template;
		my $textTemplate;
		my $dash = "\x{2014}";
		my $enDash = "\x{2013}";

		my %config = getConfigInfo();

		my $dialableAdminPhone = $config{AdminPhone};
		my $textableAdminNumber = $config{AdminText};
		$dialableAdminPhone =~ s/[^0-9]//g;
		$textableAdminNumber =~ s/[^0-9]//g;


		my $printableStart = $firstDate;
		my $printableEnd = $lastDate;
		$printableStart =~ s/(\d\d\d\d)-(.*)/$2-$1/;
		$printableEnd =~ s/(\d\d\d\d)-(.*)/$2-$1/;

		##
		##  First, get a list of people volunteering
		##
		my @volunteers = readVolunteers();

		##
		##  Read in the scheduler template
		##
		open( my $TEMPLATE, '<', "email/scheduler/personalSchedule.htm") || die "Couldn't read email template!\n";
		read( $TEMPLATE, $template, 999999);
		close $TEMPLATE;

		open( $TEMPLATE, '<', "sms/scheduler/personalSchedule.txt") || die "Couldn't read text template!\n";
		read( $TEMPLATE, $textTemplate, 999999);
		close $TEMPLATE;
		

		##
		##  Loop through the list to find schedules (if any) for the given dates
		##
		foreach my $volunteer (@volunteers)
		{
			my $name = $volunteer->{name};
			my $firstName = ( $name=~/(\S+)/) ? $1 : $name;
			my $volunteerEmail = $volunteer->{email};
			my $volunteerPhone = $volunteer->{phone};
			my $contactMode = $volunteer->{contact};

			##
			##  See if this person is scheduled for the dates given
			##
			my @schedules = readScheduleFor( $name, $firstDate, $lastDate);

			##
			##	Was the person scheduled?
			##
			if ( @schedules)
			{
				##
				##  Should we email the person?
				##
				if ( $contactMode =~ /email|both/)
				{
					my $scheduledDates = '';

					##
					##  Build the schedule list
					##
					foreach my $schedule ( @schedules)
					{
						my $printableDate = $schedule->{date};
						$printableDate =~ s/(\d+)-(.*)/$2-$1/;
						$scheduledDates .= '<li><span class="scheduledDate">' . $printableDate . '</span>';
						$scheduledDates .= '<span class="scheduledSeparator">' . $dash . '</span>';
						$scheduledDates .= '<span class="scheduledRole">' . $schedule->{title}. '</span>';
						$scheduledDates .= 'at <span class="scheduledTime">' . $schedule->{time}. '</span>';
						$scheduledDates .= '</li>';
					}

					my $email  = $template;

					$email =~ s/__FIRST_NAME__/$firstName/smg;
					$email =~ s/__NAME__/$name/smg;
					$email =~ s/__SCHEDULE__/$scheduledDates/smg;
					$email =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
					$email =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
					$email =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
					$email =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
					$email =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
					$email =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;
					$email =~ s/__CALENDAR_FILE__/$calendarURL\/$name?start=$firstDate\&end=$lastDate/smg;
							
					##
					##  Send the reminder email
					##
					if ( defined( $volunteerEmail) && $volunteerEmail =~ m/\S\@\S/)
					{
						sendEmail( $volunteerEmail, $config{EmailSender}, "New Schedule for $printableStart $enDash $printableEnd", $email, 'email/scheduler/scheduling.png');
						print "Sent\n";
					}
					else
					{
						print STDERR "No email address for $name!\n";
					}
				}

				##
				##  Should we send a text?
				##
				if ( $contactMode =~ /text|both/)
				{
					my $scheduledDates = '';

					##
					##  Build the schedule list
					##
					foreach my $schedule ( @schedules)
					{
						my $printableDate = $schedule->{date};
						$printableDate =~ s/(\d+)-(.*)/$2-$1/;
						$scheduledDates .= " * $printableDate:  $schedule->{title}  $schedule->{time}\n";
					}

					my $text  = $textTemplate;

					$text =~ s/__FIRST_NAME__/$firstName/smg;
					$text =~ s/__NAME__/$firstName/smg;
					$text =~ s/__SCHEDULE__/$scheduledDates/smg;
					$text =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
					$text =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
					$text =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
					$text =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
					$text =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
					$text =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;
							
					##
					##  Send the reminder text
					##
					if ( defined( $volunteerPhone) && $volunteerPhone =~ m/^[0-9-]+$/)
					{
						print "Sending a text of the schedule to $volunteerPhone\n";
						sendSMSTwilio( $volunteerPhone, $text);
						print "Sent\n";
					}
					else
					{
						print STDERR "No phone number for $name!\n";
					}
				}
			}
		}
		exit;
	}
}

#------------------------------------------------------------------------------
#  sub makeCalendarFor( $$$)
#  		This routine returns a string in .ics format that contains the
#  		scheduled dates that the named individual is to volunteer between the
#  		provided start and end dates.
#------------------------------------------------------------------------------
sub makeCalendarFor( $$$)
{
	my ($name, $firstDate, $lastDate) = @_;
	my $ics;
	
	##
	##  See if this person is scheduled for the dates given
	##
	my @schedules = readScheduleFor( $name, $firstDate, $lastDate);

	##
	##	Was the person scheduled?
	##
	if ( @schedules)
	{
		my $timezoneOffset =  strftime( "%z", localtime());
		my $calendar = Data::ICal->new();
		my $timeNow = DateTime->now();

		##
		##  Build a calendar entry for each scheduled date
		##
		foreach my $schedule ( @schedules)
		{
			my $event = Data::ICal::Entry::Event->new();
			$schedule->{time} =~ m/(\d+):(\d+)/;
			my ( $hour, $minute) = ($1, $2);
			$schedule->{date} =~ m/(\d+)-(\d+)-(\d+)/;
			my ( $year, $month, $day) = ( $1, $2, $3);

			my $start = DateTime->new( year=>$year, month=>$month, day=>$day, hour=>$hour, minute=>$minute, time_zone=>$timezoneOffset);
			my $end = DateTime->new( year=>$year, month=>$month, day=>$day, hour=>$hour + 1, minute=>$minute, time_zone=>$timezoneOffset);

			$event->add_properties(
									summary => 'Volunteering',
									description => "Serving in the position: $schedule->{title}.",
									dtstamp => DateTime::Format::ICal->format_datetime( $timeNow),
									dtstart => DateTime::Format::ICal->format_datetime( $start),
									dtend => DateTime::Format::ICal->format_datetime( $end),
									status => 'CONFIRMED',
									uid => Time::HiRes::time()
								  );

			$calendar->add_entry( $event);
		}
	
		##
		##  Generate ICS 
		##
		$ics = $calendar->as_string;
	}

	return $ics;
}

#------------------------------------------------------------------------------
#  sub sendUpdateRequest( $baseURL)
#  		This function sends a request to all volunteers to update their
#  		information before the next scheduling.
#------------------------------------------------------------------------------
sub sendUpdateRequest($)
{
	$SIG{CHLD} = "IGNORE";
	my $pid = fork();

	die "Fork failed!!\n" if (! defined( $pid));

	if ( !$pid)
	{
		my ($baseURL) = @_;
		my $template;
		my $textTemplate;

		my %config = getConfigInfo();

		my $dialableAdminPhone = $config{AdminPhone};
		my $textableAdminNumber = $config{AdminText};
		$dialableAdminPhone =~ s/[^0-9]//g;
		$textableAdminNumber =~ s/[^0-9]//g;

		##
		##  Get a list of people volunteering on the given date
		##
		my @volunteers = readVolunteers();

		##
		##  Read in the templates
		##
		open( my $TEMPLATE, '<', "email/scheduler/prescheduling.htm") || die "Couldn't read email template!\n";
		read( $TEMPLATE, $template, 999999);
		close $TEMPLATE;

		open( $TEMPLATE, '<', "sms/scheduler/prescheduling.txt") || die "Couldn't read text template!\n";
		read( $TEMPLATE, $textTemplate, 999999);
		close $TEMPLATE;

		##
		##  Loop through the list, sending a request to update information
		##
		foreach  my $volunteer ( @volunteers)
		{
			##
			##  Get the info for this slot
			##
			my $name = $volunteer->{name};
			my $firstName = ($name =~ m/^([^\s]*)/) ? $1 : $name;
			my $positions = $volunteer->{desiredRoles};
			my $volunteerEmail = $volunteer->{email};
			my $volunteerPhone = $volunteer->{phone};
			my $contactMode = $volunteer->{contact};
			my $url = "$baseURL\/?user=$name\&UID=" . $volunteer->{UID};
			$url =~ s/ /%20/g;


			##
			##  Should we email the person?
			##
			if ( $contactMode =~ /email|both/)
			{
				my $email  = $template;

				my $emailPositions = $positions;
				$emailPositions =~ s/([^,]+),?/<li>$1<\/li>\n/g;

				$email =~ s/__FIRST_NAME__/$firstName/smg;
				$email =~ s/__POSITIONS__/$emailPositions/smg;
				$email =~ s/__UPDATE_URL__/$url/smg;
				$email =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
				$email =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
				$email =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
				$email =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
				$email =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
				$email =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;

				##
				##  Send the reminder email
				##
				if ( defined( $volunteerEmail) && $volunteerEmail =~ m/\S\@\S/)
				{
					sendEmail( $volunteerEmail, $config{EmailSender}, 'Any Information updates for volunteering?', $email, 'email/scheduler/scheduling.png');
					print "Sent\n";
				}
				else
				{
					print STDERR "No email address for $name!\n";
				}
			}

			if ( $contactMode =~ /text|both/)
			{
				my $text  = $textTemplate;
				
				my $textPositions = $positions;
				$textPositions =~ s/([^,]+),?/ *  $1\n/g;

				$text =~ s/__FIRST_NAME__/$firstName/smg;
				$text =~ s/__POSITIONS__/$textPositions/smg;
				$text =~ s/__UPDATE_URL__/$url/smg;
				$text =~ s/__SCHEDULE_ADMIN__/$config{AdminName}/smg;
				$text =~ s/__SCHEDULE_ADMIN_EMAIL__/$config{AdminEmail}/smg;
				$text =~ s/__SCHEDULE_ADMIN_PHONE__/$config{AdminPhone}/smg;
				$text =~ s/__SCHEDULE_ADMIN_DIALABLE_PHONE__/$dialableAdminPhone/smg;
				$text =~ s/__SCHEDULE_ADMIN_TEXT_NUMBER__/$config{AdminText}/smg;
				$text =~ s/__SCHEDULE_ADMIN_TEXTABLE_NUMBER__/$textableAdminNumber/smg;

				##
				##  Send the reminder text
				##
				if ( defined( $volunteerPhone) && $volunteerPhone =~ m/^[0-9-]+$/)
				{
					print "Sending a text reminder to $volunteerPhone\n";
					sendSMSTwilio( $volunteerPhone, $text);
					print "Sent\n";
				}
				else
				{
					print STDERR "No phone number for $name!\n";
				}
				
			}
		}
		exit;
	}
}


#------------------------------------------------------------------------------
#	sub isAdmin( $user, $password)
#		This subroutine returns true if the provided user and password match
#		the admin user name and password.
#------------------------------------------------------------------------------
sub isAdmin( $$)
{
	my ($user, $pwd) = @_;

	my %config = getConfigInfo();

	return( ($user eq $config{AdminLogin}) && ( $pwd eq $config{AdminPWD}));
}
1;

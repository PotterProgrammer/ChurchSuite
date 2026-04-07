##
##  Module to handle saving/restoring Member information
##
package PhoneTree::Messages;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( storeMessage pendingMessages messagesArePending setMessageStatus resetToPending purgeSentMessages bumpRetryCount);

use warnings;
use strict;


use DBI;
use open qw(:std :utf8);
use utf8;
use utf8::all;

use Data::Dumper;
use PhoneTree::Members;


my $dbh;

#------------------------------------------------------------------------------
#  sub initDB()
#  		This routine loads the DB and makes sure it is properly set up.
#------------------------------------------------------------------------------
sub initDB()
{
	openDB();
	
	$dbh->do( 'CREATE TABLE if not exists Messages
				(
					sendTo	integer,
					fromWho	text,
					subject	text,
					message	text,
					sendOn  text,
					status	text,
					retryCount integer not null default 0
				)'
			);

	closeDB();
}

#------------------------------------------------------------------------------
#  sub openDB()
#  		This routine opens the DB
#------------------------------------------------------------------------------
sub openDB()
{
	if ( !defined( $dbh))
	{
		$dbh = DBI->connect( "dbi:SQLite:${PhoneTree::Members::DBFilename}", "", "", {AutoCommit =>1}) or die "Sorry, couldn't open PhoneTree database!\n";
		$dbh->{sqlite_unicode} = 1;
	}
}

#------------------------------------------------------------------------------
#  sub closeDB()
#  		This routine closes the DB.
#------------------------------------------------------------------------------
sub closeDB()
{
	if ( defined( $dbh))
	{
		$dbh->disconnect();
		undef $dbh;
	}
}

#------------------------------------------------------------------------------
#  sub storeMessage( $to, $from, $subject, $message,[ $sendOn])
#  		This function stores a message to a member for later transmission.  If
#  		the "sendOn" date is not provided (as an ISO Datetime string), the
#  		current datetime is used. Note that $to is the member ID number, not a
#  		name.
#------------------------------------------------------------------------------
sub storeMessage(@)
{
	my ( $to, $from, $subject, $message, $sendOn) = @_;
	my $rc = 1;
	if ( !defined( $sendOn))
	{
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$sendOn = sprintf( "%04d-%02d-%02d %02d:%02d:%02d.000", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
	}

	openDB();

	my $sth = $dbh->prepare( "insert into Messages ( sendTo, fromWho, subject, message, sendOn, status, retryCount) values (?,?,?,?,?, 'Pending', 0)");

	$sth->bind_param( 1, $to);
	$sth->bind_param( 2, $from);
	$sth->bind_param( 3, $subject);
	$sth->bind_param( 4, $message);
	$sth->bind_param( 5, $sendOn);

	$sth->execute();

	if( $sth->err)
	{
		$rc = 0;
		print STDERR "DB ERROR!  $sth->err:  $sth->errstr\n";
		last;
	}

	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  sub pendingMessages()
#		This routine returns an arrayref to a list of all messages that are in the
#		'Pending' state.
#------------------------------------------------------------------------------
sub pendingMessages()
{
	openDB();

	my $memberList = $dbh->selectall_arrayref( "select rowid, * from Messages where status = 'Pending' and sendOn <= datetime('now', 'localtime')", {Slice => {}});

	closeDB();
	return $memberList;
}

#------------------------------------------------------------------------------
#  sub messagesArePending()
#  		This routine returns zero if there are no messages pending and a
#  		non-zero value otherwise.
#------------------------------------------------------------------------------
sub messagesArePending()
{
	openDB();

	my $countList = $dbh->selectall_arrayref( "select count(*) from Messages where sendOn <= datetime('now', 'localtime') and (status = 'Pending' or status = 'Sending')");

	closeDB();
	return $countList->[0]->[0];
}



#------------------------------------------------------------------------------
#  sub setMessageStatus(  $rowId, $status)
#  		This function updates the message status for the indicated record.
#  		The function returns the number of rows updated. (Status is expected to
#  		be either "Pending", "Sending", "Sent", or "Failed".
#------------------------------------------------------------------------------
sub setMessageStatus($$)
{
	my ( $id, $status) = @_;

	if ( $status !~/^(Pending|Sent|Sending|Failed)$/)
	{
		die "Invalid status: $status!\n";
	}

	openDB();

	my $rc = $dbh->do( "update Messages set status=? where rowid=?", undef, $status, $id);

	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  sub resetToPending()
#  		This function resets the message status for each message that currently
#  		has a status of "Sending" to "Pending".  (To try to resolve messages
#  		that were in a "Sending" state when a shutdown occurred.)
#------------------------------------------------------------------------------
sub resetToPending()
{
	openDB();

	my $rc = $dbh->do( "update Messages set status='Pending' where status='Sending'");

	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  sub bumpRetryCount( $id)
#  		This function increments the retryCount for the message with the
#  		provided rowid.  The function returns the number of rows updated.
#------------------------------------------------------------------------------
sub bumpRetryCount($)
{
	my ( $id) = @_;

	openDB();

	my $rc = $dbh->do( "update Messages set retryCount = retryCount + 1 where rowid=?", undef, $id);

	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  sub purgeSentMessages()
#  		This routine clears all entries from the Messages table that have a
#  		status of "Sent". It returns the number of rows cleared.
#------------------------------------------------------------------------------
sub purgeSentMessages()
{
	openDB();

	my $rc = $dbh->do( "delete from Messages where status='Sent'");

	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  BEGIN
#  		Make sure that we have a DB with appropriate tables ready to go
#------------------------------------------------------------------------------
BEGIN
{
	initDB();
}

#------------------------------------------------------------------------------
#  END
#  		Make sure DB is disconnected at shutdown
#------------------------------------------------------------------------------
END
{
	closeDB();
}

1;
 

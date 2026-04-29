##
##  Module to handle saving/restoring Member information
##
package PhoneTree::Messages;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( 
			 allMessages
			 allPendingMessages
			 bumpRetryCount
			 deleteSelectedMessages
			 getMessageRecipients
			 getQueuedMessage
			 messagesArePending
			 messagesVary
			 pendingMessages
			 purgeSentMessages
			 resetToPending
			 setMessageStatus
			 storeMessage
			 openDB
			 closeDB
			 startTransaction
			 commitTransaction
			 rollbackTransaction
			);

use warnings;
use strict;


use DBI;
use open qw(:std :utf8);
use utf8;
use utf8::all;

use Data::Dumper;
use PhoneTree::Members;


my $dbh;
my $inTransaction = 0;

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

	return if ($inTransaction);

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
	return if ($inTransaction);

	if ( defined( $dbh))
	{
		$dbh->disconnect();
		undef $dbh;
	}
}

#------------------------------------------------------------------------------
#  sub startTransaction()
#  		This routine starts a transaction on an already open DB.  The
#  		transaction remains open until either commitTransaction() or
#  		rollbackTransaction() is called.  While the transaction is open, all
#  		calls to openDB() and closeDB() are disabled.
#------------------------------------------------------------------------------
sub startTransaction()
{
	$inTransaction = 1;
	$dbh->begin_work;
}

#------------------------------------------------------------------------------
#  sub commitTransaction()
#  		This routine commits all requests since the call to startTransaction()
#  		and then ends the transaction.
#------------------------------------------------------------------------------
sub commitTransaction()
{
	$dbh->commit;
	$inTransaction = 1;
}

#------------------------------------------------------------------------------
#  sub rollbackTransaction()
#  		This routine rolls back all requests since the call to
#  		startTransaction() and then ends the transaction.
#------------------------------------------------------------------------------
sub rollbackTransaction()
{
	$dbh->rollback;
	$inTransaction = 0;
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
#  sub allMessages()
#		This routine returns an arrayref to a list of all messages that are in the
#		queue.
#------------------------------------------------------------------------------
sub allMessages()
{
	openDB();

	print "Getting a list of all messages\n";
	my $messageList = $dbh->selectall_arrayref( "select rowid, * from Messages", {Slice => {}});

	closeDB();
	return $messageList;
}

#------------------------------------------------------------------------------
#  sub getQueuedMessage($)
#  		This routine gets the message with the indicated rowId.  It returns
#  		a hashref to the message data.  The hashref will be undefined if an 
#  		error occurs.
#------------------------------------------------------------------------------
sub getQueuedMessage($)
{
	my ($rowid) = @_;

	openDB();

	my $messageInfo = $dbh->selectrow_hashref( "select * from Messages where rowid=?", undef, $rowid);
	closeDB();
	return $messageInfo;
}

#------------------------------------------------------------------------------
#  sub getMessageRecipients( $messageIdList)
#  		This routine returns an array of all of the user Ids of the messages in 
#  		the provided list of message Ids.
#------------------------------------------------------------------------------
sub getMessageRecipients($)
{
	my ($messageIdList) = @_;
	my @recipients;

	if ( @{$messageIdList})
	{
		my $rowIds =  '[' . join( ',', @{$messageIdList}) . ']';
		openDB();
		my $messages = $dbh->selectall_arrayref( "select sendTo from Messages where rowid in ( select value from json_each(?))", undef, $rowIds);
		@recipients = map { $_->[0]}  @${messages};
		closeDB();
	}
	return @recipients;
}

#------------------------------------------------------------------------------
#  sub messagesVary( $messageIdList)
#  		This routine returns a non-zero value if the message fields in the
#  		messages in the Messages table identified by the provided row IDs have
#  		differing text.  For example, if the the message for row 3 was "Unique"
#  		and the text for the message in row 4 was "Varied", a non-zero value
#  		would be returned.  However, if both message texts were "Common", zero
#  		would be returned.
#------------------------------------------------------------------------------
sub messagesVary( $)
{
	my ($messageIdList) = @_;
	my $rc = 0;

	if ( @{$messageIdList})
	{
		my $rowIds =  '[' . join( ',', @{$messageIdList}) . ']';
		openDB();
		my $messages = $dbh->selectrow_arrayref( "select count( distinct message) from Messages where rowid in ( select value from json_each(?))", undef, $rowIds);
		$rc = int($messages->[0] != 1);
	}

	return $rc;
}

##-->#------------------------------------------------------------------------------
##-->#  sub getMessageRecipients( $messageIdList)
##-->#  		This routine returns an array of all of the user Ids of the messages in 
##-->#  		the provided list of message Ids.
##-->#------------------------------------------------------------------------------
##-->sub getMessageRecipients($)
##-->{
##-->	my ($messageIdList) = @_;
##-->	my @recipients;
##-->
##-->	if ( @{$messageIdList})
##-->	{
##-->		my $rowIds =  '[' . join( ',', @{$messageIdList}) . ']';
##-->		print "Row IDS: $rowIds\n";
##-->		openDB();
##-->		my $messages = $dbh->selectall_arrayref( "select sendTo from Messages where rowid in ( select value from json_each(?))", undef, $rowIds);
##-->		print Dumper( $messages) . "\n";;
##-->		@recipients = map { $_->[0]}  @${messages};
##-->		print "Recipients are:\n\t" . join( "\n\t", @recipients) . "\n\n";
##-->		closeDB();
##-->	}
##-->	return @recipients;
##-->}

#------------------------------------------------------------------------------
#  sub pendingMessages()
#		This routine returns an arrayref to a list of all messages that are in the
#		'Pending' state and have a send date earlier than now.
#------------------------------------------------------------------------------
sub pendingMessages()
{
	openDB();
	print "Getting a list of pending messages\n";

	my $memberList = $dbh->selectall_arrayref( "select rowid, * from Messages where status = 'Pending' and sendOn <= datetime('now', 'localtime')", {Slice => {}});

	closeDB();
	return $memberList;
}

#------------------------------------------------------------------------------
#  sub allPendingMessages()
#		This routine returns an arrayref to a list of all Pending messages that
#		are in the queue.
#------------------------------------------------------------------------------
sub allPendingMessages()
{
	openDB();

	print "Getting a list of all messages\n";
	my $query = << "ESQL";
select m.rowid,m.status,m.sendOn,c.firstname,c.lastname,m.message
from Messages as m inner join Contacts as c 
on m.sendTo = c.rowid 
where m.status = 'Pending'
ESQL
	
	#
	my $messageList = $dbh->selectall_arrayref( $query, {Slice => {}});
	print "Got back " . Dumper( $messageList) . "\n";

	closeDB();
	return $messageList;
}

#------------------------------------------------------------------------------
#  sub deleteSelectedMessages( $messageList)
#  		This method deletes all indicated messages from the message queue.  
#  		@{$messageList} contains the rowId of each message to be deleted.
#  		A value of true is returned if the delete was successful.
#------------------------------------------------------------------------------
sub deleteSelectedMessages($)
{
	my $messageList = shift( @_);
	my $rc = 1;

	openDB();

	my $sth = $dbh->prepare( "delete from messages where rowid in ( Select value from json_each( ?))");
	my $rows =  '[' . join( ',', @{$messageList}) . ']';
	$sth->bind_param( 1, $rows);
	$sth->execute();

	if( $sth->err)
	{
		$rc = 0;
		print STDERR "DB ERROR!  $sth->err:  $sth->errstr\n";
	}

	closeDB();
	return $rc;
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
	print "$countList->[0]->[0] messages are pending...\n";
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
 

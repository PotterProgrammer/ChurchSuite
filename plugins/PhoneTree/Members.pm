##
##  Module to handle saving/restoring Member information
##
package PhoneTree::Members;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( readMembers addMember deleteMember writeContactInfo readContacts readContactInfo);

use warnings;
use strict;


use DBI;
use open qw(:std :utf8);
use utf8;
use utf8::all;

use Data::Dumper;


my $DBFilename;
my $dbh;

#------------------------------------------------------------------------------
#  sub initDB()
#  		This routine loads the DB and makes sure it is properly set up.
#------------------------------------------------------------------------------
sub initDB()
{
	openDB();
	
	$dbh->do( "create table if not exists Contacts
					(
						lastname varchar(100),
						firstname varchar(100),
						email varchar(255),
						homephone varchar(10),
						cell varchar(10),
						callAll int,
						tryFirst varchar(6),
						trySecond varchar(6),
						tryThird varchar(6)
					)"
			);

	$dbh->do( 'CREATE TABLE if not exists Groups
					(
						name varchar(255), 
						members varchar(6000)
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
		$dbh = DBI->connect( "dbi:SQLite:$DBFilename", "", "", {AutoCommit =>1}) or die "Sorry, couldn't open PhoneTree database!\n";
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
#  sub	readContacts()
#  		This function returns an arrayref of all contacts.  Each row in the
#  		array is a hashref.
#------------------------------------------------------------------------------
sub	readContacts()
{
	openDB();

	my $memberList = $dbh->selectall_arrayref( "select rowid, * from Contacts order by lastname, firstname asc", {Slice => {}});

	closeDB();
	return $memberList;
}

#------------------------------------------------------------------------------
#  sub	readContactInfo( $id)
#  		This function returns a hashref of info for the specified contact ID.
#------------------------------------------------------------------------------
sub	readContactInfo($)
{
	my $id = shift(@_);
	openDB();

	my $memberInfo = $dbh->selectrow_hashref( "select rowid, * from Contacts where rowid=?",undef,$id);

	closeDB();
	return $memberInfo;
}



#------------------------------------------------------------------------------
#  sub writeContactInfo( $contactInfo)
#  		This function writes the info in the hashref $contactInfo to the
#  		Contacts table.
#------------------------------------------------------------------------------
sub writeContactInfo($)
{
	my $contactInfo = shift( @_);

	openDB();

	my $sth = $dbh->prepare( "insert or replace into Contacts  (
									lastname,
									firstname,
									email,
									homephone,
									cell,
									callAll,
									tryFirst,
									trySecond,
									tryThird,
									rowid
								) values (?,?,?,?,?,?,?,?,?,?)");

##-->	foreach  my $id ( keys( %{$contactInfo}))
	{
		$sth->bind_param( 1, $contactInfo->{lastname});
		$sth->bind_param( 2, $contactInfo->{firstname});
		$sth->bind_param( 3, $contactInfo->{email});
		$sth->bind_param( 4, $contactInfo->{homephone});
		$sth->bind_param( 5, $contactInfo->{cell});
		$sth->bind_param( 6, $contactInfo->{callAll});
		$sth->bind_param( 7, $contactInfo->{tryFirst});
		$sth->bind_param( 8, $contactInfo->{trySecond});
		$sth->bind_param( 9, $contactInfo->{tryThird});
		$sth->bind_param( 10, ($contactInfo->{rowid} eq "new") ? undef : $contactInfo->{rowid});

		$sth->execute();
	}

	closeDB();
}

#------------------------------------------------------------------------------
#  sub deleteMember( $rowid)
#  		This method removes the row indicated by the rowid from the Contacts
#  		table.  It returns the number of rows deleted.
#------------------------------------------------------------------------------
sub deleteMember($)
{
	my $rowid = shift( @_);

	openDB();
	
	my $rowsDeleted = $dbh->do( 'Delete from Contacts where rowid=?', undef, $rowid);
	closeDB();

	return( $rowsDeleted);
}

#------------------------------------------------------------------------------
#  BEGIN
#  		Make sure that we have a DB with appropriate tables ready to go
#------------------------------------------------------------------------------
BEGIN
{
	$DBFilename = "./phonetree.db";
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
 

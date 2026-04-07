##
##  Module to handle saving/restoring Member information
##
package PhoneTree::Members;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( deleteMember writeContactInfo readContacts readContactInfo readGroups getGroupMembers saveGroup removeGroup);

use warnings;
use strict;


use DBI;
use open qw(:std :utf8);
use utf8;
use utf8::all;

use Data::Dumper;


our $DBFilename = "./phonetree.db";

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
						lastname text,
						firstname text,
						email text,
						homephone text,
						cell text,
						callAll int,
						tryFirst text,
						trySecond text,
						tryThird text
					)"
			);

	$dbh->do( 'CREATE TABLE if not exists Groups
					(
						name text,
						memberName text,
						memberId integer,
						isGroup integer not null default 0
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
#  sub	readGroups()
#  		This function returns an arrayref of the arrayrefs of the names of all
#  		groups. ($r->[0]->[0] = 'name1')
#------------------------------------------------------------------------------
sub	readGroups()
{
	openDB();

	my $groupList = $dbh->selectall_arrayref( "select distinct name from Groups order by name asc");

	closeDB();
	return $groupList;
}


#------------------------------------------------------------------------------
#  sub	getGroupMembers( $groupName)
#  		This function returns an arrayref of the hashrefs of all
#  		members of the named group. ($r->[0]->{members: 'memberName', isGroup = 1})
#------------------------------------------------------------------------------
sub	getGroupMembers($)
{
	my $groupName = shift( @_);

	openDB();

	print "Looking for members of $groupName\n";

	my $groupList = $dbh->selectall_arrayref( "select memberName, id, isGroup from Groups where name=?", {Slice =>{}}, $groupName);

	closeDB();
	return $groupList;
}

#------------------------------------------------------------------------------
#  sub saveGroup($groupName, $memberNameList)
#		This method first deletes any entries for the named group.  It then
#		adds each member included in the array reference, member list, to the
#		groups table as a member of the named group.  If successful, it returns
#		true. If unsuccessful, the delete is rolled back and false is returned.
#------------------------------------------------------------------------------
sub saveGroup($$)
{
	my ( $groupName, $memberNameList) = @_;
	my $rc = 1;  ## Hope for the best

	openDB();

	##
	##  First, begin a transaction
	##
	$dbh->begin_work;

	##
	##  Delete all entries for the named group
	##
	$dbh->do( "delete from groups where name=?", undef, $groupName);

	my $sth = $dbh->prepare( "insert into Groups ( name, membername, id, isGroup) values (?,?,?,?)");

	foreach my $member ( @{$memberNameList})
	{
		my $memberName = $member->{name};
		my $id = $member->{id};
		my $isGroup = $member->{isGroup};

		$sth->bind_param( 1, $groupName);
		$sth->bind_param( 2, $memberName);
		$sth->bind_param( 3, $id);
		$sth->bind_param( 4, $isGroup);
		$sth->execute();
		if( $sth->err)
		{
			$rc = 0;
			print STDERR "DB ERROR!  $sth->err:  $sth->errstr\n";
			last;
		}
		
	}

	if ( $rc)
	{
		$dbh->commit();
	}
	else
	{
		$dbh->rollback();
	}
	closeDB();
	return $rc;
}

#------------------------------------------------------------------------------
#  sub removeGroup( $groupName)
#  		This method removes the group indicated by the groupName from the
#  		Groups table.  It returns the number of rows deleted.
#------------------------------------------------------------------------------
sub removeGroup($)
{
	my $groupName = shift( @_);

	openDB();
	
	my $rowsDeleted = $dbh->do( 'Delete from Groups where name=?', undef, $groupName);
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
 

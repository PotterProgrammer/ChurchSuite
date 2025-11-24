##
##  Module to save/restore scheduling information
##
package Directory::Members;

require Exporter;
@ISA = qw( Exporter);
@EXPORT = qw( readDirectoryMembers saveDirectoryMembers writeMemberInfo removeMember UIDExists generateUID lookupUser getUserInfo resetMemberPassword toggleAdmin isAdminUID getLoginIdForUID );

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

	##
	##  Create Schedule table
	##
	$dbh->do( "create table if not exists members
				   ( loginId text,
					 firstName text,
					 lastName text,
					 address text,
					 city text,
					 zip text,
					 email text,
					 phone text,
					 cell text,
					 photo text,
					 UID text unique,
					 password text,
					 admin boolean,
					 primary key( 'loginId')
				   )");

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
		$dbh = DBI->connect( "dbi:SQLite:$DBFilename", "", "", {AutoCommit =>1}) or die "Sorry, couldn't open schedule database!\n";
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
#  sub	readDirectoryMembers()
#------------------------------------------------------------------------------
sub	readDirectoryMembers()
{
	openDB();

	my $memberList = $dbh->selectall_hashref( "select * from members", "loginId");

	closeDB();
	return $memberList;
}

#------------------------------------------------------------------------------
#  sub saveDirectoryMembers($)
#------------------------------------------------------------------------------
sub saveDirectoryMembers($)
{
	my $memberList = shift( @_);

	openDB();

	my $sth = $dbh->prepare( "insert or replace into members  (
		           	 loginId,
			         firstName,
					 lastName,
					 children,
					 address,
					 city,
					 zip,
				     email,
				     email2,
					 phone,
				     cell,
				     cell2,
					 photo,
					 UID,
					 password,
					 admin
		) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

	foreach  my $loginId ( keys( %{$memberList}))
	{
		$sth->bind_param( 1, $loginId);
		$sth->bind_param( 2, $memberList->{$loginId}->{firstName});
		$sth->bind_param( 3, $memberList->{$loginId}->{lastName});
		$sth->bind_param( 4, $memberList->{$loginId}->{children});
		$sth->bind_param( 5, $memberList->{$loginId}->{address});
		$sth->bind_param( 6, $memberList->{$loginId}->{city});
		$sth->bind_param( 7, $memberList->{$loginId}->{zip});
		$sth->bind_param( 8, $memberList->{$loginId}->{email});
		$sth->bind_param( 9, $memberList->{$loginId}->{email2});
		$sth->bind_param( 10, $memberList->{$loginId}->{phone});
		$sth->bind_param( 11, $memberList->{$loginId}->{cell});
		$sth->bind_param( 12, $memberList->{$loginId}->{cell2});
		$sth->bind_param( 13, $memberList->{$loginId}->{photo});
		$sth->bind_param( 14, $memberList->{$loginId}->{UID});
		$sth->bind_param( 15, $memberList->{$loginId}->{password});
		$sth->bind_param( 16, $memberList->{$loginId}->{admin});

		$sth->execute();
	}

	closeDB();
}

#------------------------------------------------------------------------------
#  sub writeMemberInfo($memberInfo)
#  		This function writes the info in the hashref $memberInfo to the members
#  		table.
#------------------------------------------------------------------------------
sub writeMemberInfo($)
{
	my $memberInfo = shift( @_);

	openDB();

	my $sth = $dbh->prepare( "insert or replace into members  (
		           	 loginId,
			         firstName,
					 lastName,
					 children,
					 address,
					 city,
					 zip,
				     email,
				     email2,
					 phone,
				     cell,
				     cell2,
					 photo,
					 UID,
					 password,
					 admin
		) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

	$sth->bind_param( 1, $memberInfo->{loginId});
	$sth->bind_param( 2, $memberInfo->{firstName});
	$sth->bind_param( 3, $memberInfo->{lastName});
	$sth->bind_param( 4, $memberInfo->{children});
	$sth->bind_param( 5, $memberInfo->{address});
	$sth->bind_param( 6, $memberInfo->{city});
	$sth->bind_param( 7, $memberInfo->{zip});
	$sth->bind_param( 8, $memberInfo->{email});
	$sth->bind_param( 9, $memberInfo->{email2});
	$sth->bind_param( 10, $memberInfo->{phone});
	$sth->bind_param( 11, $memberInfo->{cell});
	$sth->bind_param( 12, $memberInfo->{cell2});
	$sth->bind_param( 13, $memberInfo->{photo});
	$sth->bind_param( 14, $memberInfo->{UID});
	$sth->bind_param( 15, $memberInfo->{password});
	$sth->bind_param( 16, $memberInfo->{admin});

	$sth->execute();

	closeDB();
}

#------------------------------------------------------------------------------
#  sub removeMember( $loginID)
#  		This function removes the member identified by loginId from the
#  		database.
#------------------------------------------------------------------------------
sub removeMember($)
{
	my $loginId = shift( @_);
	openDB();

	$dbh->do( "DELETE from members where loginId=?", undef, $loginId);

	closeDB();
}

#------------------------------------------------------------------------------
#  sub getMemberUID($$)
#------------------------------------------------------------------------------
sub getMemberUID($$)
{
	my ( $loginId, $password) = @_;
	my $uid;

	openDB();

	my $sth = $dbh->prepare( "Select UID from members where loginId=? and password=?");
	$sth->bind_param( 1, $loginId);
	$sth->bind_param( 2, $password);
	$sth->execute();

	my @row = $sth->fetchrow_array();
	if ( @row)
	{
		$uid = $row[0];
	}
	closeDB();
}

#------------------------------------------------------------------------------
#  sub UIDExists($)
#------------------------------------------------------------------------------
sub UIDExists($)
{
	my ($id) = (@_);
	my $memberInfo;
	

	openDB();

	my $matches = $dbh->selectall_arrayref( "select *from members where UID=?", undef, $id);

	closeDB();

	return( int(@{$matches}));
}

#------------------------------------------------------------------------------
#	sub generateUID()
#		This routine generates a random 10 character alpha-numeric string
#------------------------------------------------------------------------------
sub generateUID()
{
	my @chars = ( 'a'..'z', '0'..'9', 'A'..'Z');
	my $id;
	do 
	{
		$id = '';
		for( 1..10)
		{
			$id .= $chars[ int rand( @chars)];
		}
	} while( UIDExists( $id));

	return $id;
}

#------------------------------------------------------------------------------
#  sub lookupUser($userId, $password)
#------------------------------------------------------------------------------
sub lookupUser($$)
{
	my ( $name, $pwd) = (@_);
	my $memberInfo;

	openDB();

	my $row;
	if ( defined( $pwd) && length( $pwd))
	{
		$row = $dbh->selectall_hashref( "select * from members where loginId=? and password=?", 'loginId', undef, $name, $pwd);
	}
	else
	{
		$row = $dbh->selectall_hashref( "select * from members where loginId=? and password is null", 'loginId', undef, $name);
	}
	if ( defined($row))
	{
		$memberInfo = $row->{$name};
	}

	closeDB();
	return $memberInfo;
}

#------------------------------------------------------------------------------
#	sub getUserInfo( $username, $id) 
#		This routines checks the members table to see if there is an entry
#		for $username, and if so, if the stored UID matches the value provided
#		in $id.  If so, a reference to the user info is returned.  If not,
#		undef is returned.
#------------------------------------------------------------------------------
sub getUserInfo($$)
{
	my ($name, $id) = (@_);
	my $memberInfo;
	
	openDB();

	my $matches = $dbh->selectall_hashref( "select * from members where loginId = ? and UID=?", 'loginId', undef, $name, $id);

	print "Looking for name=$name and ID=$id\n";
	closeDB();
	
	if ( defined( $matches))
	{
		$memberInfo = $matches->{$name};
##-->	print "Got a match!\n";
##-->	print Dumper( $memberInfo);
	}

	return $memberInfo;
}

#------------------------------------------------------------------------------
#  sub resetMemberPassword($loginId)
#		This method resets the login password for the specified login Id.
#------------------------------------------------------------------------------
sub resetMemberPassword($)
{
	my ($loginId) = @_;

	openDB();

	$dbh->do( "update members set password=null where loginId=?", undef, $loginId);

	closeDB();
}

#------------------------------------------------------------------------------
#  sub toggleAdmin( $loginId)
#------------------------------------------------------------------------------
sub toggleAdmin( $)
{
	my ($loginId) = @_;

	openDB();

	$dbh->do( "update members set admin = CASE WHEN admin is null THEN 1 ELSE (1-admin) END where loginID=?", undef, $loginId);

	closeDB();
}

#------------------------------------------------------------------------------
#	sub isAdminUID( $id) 
#------------------------------------------------------------------------------
sub isAdminUID( $)
{
	my $id = shift( @_);
	my $isAdmin = 0;

	openDB();

	my $matches = $dbh->selectall_hashref( "select UID, admin from members where UID=?", 'UID', undef, $id);

	closeDB();
	
	if ( defined( $matches))
	{
		$isAdmin = $matches->{$id}->{admin} // 0;
		print "User $id is " . ( ($isAdmin) ? "" : "not ") . "an admin.\n";
	}
	print "Returning $isAdmin...\n";

	return( $isAdmin);
}

#------------------------------------------------------------------------------
#	sub getLoginIdForUID( $)
#		This function returns the loginId associated with the provided UID or
#		undef if none exists.
#------------------------------------------------------------------------------
sub getLoginIdForUID( $)
{
	my $id = shift( @_);
	my $loginId;

	openDB();

	my $matches = $dbh->selectall_hashref( "select UID, loginId from members where UID=?", 'UID', undef, $id);

	closeDB();
	
	if ( defined( $matches))
	{
		$loginId = $matches->{$id}->{loginId} // 0;
	}
	print "Returning $loginId...\n";

	return( $loginId);
}


#------------------------------------------------------------------------------
#  BEGIN
#  		Make sure that we have a DB with appropriate tables ready to go
#------------------------------------------------------------------------------
BEGIN
{
	$DBFilename = "./directory.db";
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

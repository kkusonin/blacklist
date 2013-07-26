use strict;
use warnings;
package Vicidial::Hopper;
use base qw(Vicidial);

sub clean {
	my ($class, $user) = shift;
	
	my $dbh = $class->db_connect;
	my $sth = $dbh->prepare_cached(
"DELETE FROM vicidial_hopper where status IN('QUEUE','INCALL','DONE') and user = ?"
	);
	$sth->execute($user);
	$sth->finish;
	
	return $sth->rows;
}


1;

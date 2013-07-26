#!/usr/bin/perl
package Vicidial::List;
use strict;
use warnings;
use base qw(Vicidial::LogObject);

sub table {'vicidial_list'};
sub log_id {'lead_id'};

sub mark_eri {
	my ($self, $user) = @_;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached(
"UPDATE vicidial_list set status = 'ERI', user = '' where status IN('QUEUE','INCALL') and user = ?"
        );
    $sth->execute($user);
    $sth->finish;

    return $sth->rows;
}

1;

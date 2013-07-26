#!/usr/bin/perl
package Vicidial::LiveAgent;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_live_agents'};
sub keys {['user']};


sub get_status {
	my $self = shift;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached(
"SELECT status FROM vicidial_live_agents WHERE user = ? AND server_ip =?"
		);
	$sth->execute($self->{user}, $self->{server_ip});
	$sth->bind_columns(\$self->{status});
	$sth->fetch;
	$sth->finish;
	
	return $self->{status};
}

my $query = {
		READY	=>
"UPDATE vicidial_live_agents set status = 'READY', lead_id = 0 where user = ? and server_ip= ?",
		PAUSED	=>
"UPDATE vicidial_live_agents set status = 'PAUSED', ring_callerid='' where user = ? and server_ip= ?",
	};

sub set_status {
	my ($self,$status) = @_;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached($query->{$status});
	$sth->execute($self->{user}, $self->{server_ip});
	$sth->finish;
	
	return 1;
}

1;

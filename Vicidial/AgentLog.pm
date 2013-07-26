#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::AgentLog;
use base qw(Vicidial::LogObject);

sub table {'vicidial_agent_log'}

sub log_id {'agent_log_id'}

sub pause_epoch {
	my ($self) = @_;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached(
"SELECT pause_epoch FROM vicidial_agent_log where agent_log_id= ?"
		);
	$sth->execute($self->{agent_log_id});
	$sth->bind_columns(\$self->{pause_epoch});
	$sth->fetch;
	
	return $self->{pause_epoch};
}

1;

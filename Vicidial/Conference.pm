#!/usr/bin/perl
package Vicidial::Conference;
use strict;
use warnings;
use base qw(Vicidial);

sub new {
	my ($class,$args) = @_;
	my $self = bless {}, $class;
	
	$self->{server_ip} = $args->{server_ip};
	$self->{extension} = $args->{extension};
	
	return $self;
}

sub allocate {
	my ($class, $args) = @_;
	
	my $self = bless {}, $class;
	my $dbh = $self->db_connect;
	$self->{server_ip} = $args->{server_ip};
	$self->{extension} = $args->{extension};
	
	if (!defined $self->get_conf_exten) {
		my $sth = $dbh->prepare_cached(
"UPDATE vicidial_conferences set extension= ?, leave_3way='0' where server_ip= ? and ((extension = '') or (extension is null)) limit 1"
			);
		$sth->execute($self->{extension}, $self->{server_ip});
		$sth->finish;
	}
	
	return $self;
}

sub get_conf_exten {
	my $self = shift;
	my $dbh = $self->db_connect;
	
	my $sth = $dbh->prepare_cached(
"SELECT conf_exten from vicidial_conferences where extension = ? and server_ip = ?"
	);
	$sth->execute($self->{extension}, $self->{server_ip});
	$sth->bind_columns(\$self->{conf_exten});
	$sth->fetch;
	$sth->finish;
	
	return $self->{conf_exten};
}

sub free {
	my $self = shift;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached(
"UPDATE vicidial_conferences set extension='' where conf_exten = ? and server_ip = ?"
		);
	$sth->execute($self->{conf_exten}, $self->{server_ip});
	$sth->finish;
	
	return $sth->rows;
}

1;

#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::Phone;
use base qw(Vicidial::DataObject);
use Carp;

sub table {'phones'}
sub keys {['extension', 'server_ip']}

sub q_auth_select {
	my ($self, $args) = @_;
	
	my $data = (scalar @$args) ? join(', ', @$args) : '* ';
	
	return 'SELECT ' . $data . ' FROM ' . $self->table . " WHERE login = ? and pass = ? and active = 'Y'";
}

sub authload {
	my ($class, $args) = @_;
	my $self = bless {}, $class;
	
	$self->{login} = $args->{login};
	$self->{pass} = $args->{pass};
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached($self->q_auth_select(@$args{columns}));
	$sth->execute($self->{login}, $self->{pass});
	$sth->bind_columns(\@$self{@{$sth->{NAME_lc}}});
	$sth->fetch;
	$sth->finish;
	if (!$sth->rows) {
		croak "ERROR: Invalid username or password";
	}
	
	return $self;
}

1; 

#!/usr/bin/perl
package Vicidial::User;
use strict;
use warnings;
use base qw(Vicidial::DataObject);
use Carp;

sub table { 'vicidial_users' };
sub keys { [ 'user' ] };

sub q_auth_select {
	my ($self, $args) = @_;
	
	my $data = (scalar @$args) ? join(', ', @$args) : '* ';
	
	return 'SELECT ' . $data . ' FROM ' . $self->table . " WHERE user = ? and pass = ?";
}

sub authload {
	my ($class, $args) = @_;
	my $self = bless {}, $class;
	
	$self->{user} = $args->{user};
	$self->{pass} = $args->{pass};
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached($self->q_auth_select(@$args{columns}));
	$sth->execute($self->{user}, $self->{pass});
	$sth->bind_columns(\@$self{@{$sth->{NAME_lc}}});
	$sth->fetch;
	$sth->finish;
	if (!$sth->rows) {
		croak "ERROR: Invalid username or password";
	}
	
	return $self;
}

1;

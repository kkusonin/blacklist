#!/usr/bin/perl'
package Vicidial::LogObject;
use strict;
use warnings;
use base qw(Vicidial);

sub table { '' };
sub log_id { '' };

sub query_maker{
    my $argref = shift;

    my $qt = {
        SELECT  => sub { 'SELECT ' . join(', ', @{$argref->{columns}}) . ' FROM ' . $argref->{table} . ' WHERE ' . join(' AND  ', map {$_ . ' = ?'} @{$argref->{where}}) },
        UPDATE  => sub { 'UPDATE ' . $argref->{table} . ' SET ' . join(', ', map {$_ . '= ?'} @{$argref->{columns}}) . ' WHERE ' . join(' AND  ', map {$_ . ' = ?'} @{$argref->{where}}) },
        INSERT  => sub { 'INSERT INTO ' . $argref->{table} .  ' (' . join(', ', @{$argref->{columns}}) . ') VALUES (' . join(', ', map {'?'} @{$argref->{columns}}) . ')' },
        DELETE  => sub { 'DELETE FROM ' . $argref->{table} . ' WHERE ' . join(' AND ', map {$_ . ' = ?'} @{$argref->{where}}) },
        'SELECT COUNT'  => sub { 'SELECT COUNT(*) FROM ' . $argref->{table} . ' WHERE ' . join(' AND ', map {$_ . ' = ?'} @{$argref->{where}}) },
    };
  
    return $qt->{ $argref->{type} }->();
}

sub q_insert {
	my $self = shift;
	
	my $keys = join(', ', keys %$self);
	my $values = (scalar(keys %$self) > 1) ? '?, ' x (scalar(keys %$self) - 1) . '?' : '?';
	
	return 'INSERT INTO ' . $self->table . ' (' . $keys . ') VALUES (' . $values . ')';
}

sub q_select {
	my ($self, $args) = @_;
	
	my $data = (defined $args) ? join(', ', @$args) : '* ';
	
	return 'SELECT ' . $data . ' FROM ' . $self->table . ' WHERE ' . $self->log_id . ' = ?';
}

sub q_update {
	my ($self, $args) = @_;
	
	my $settings = '';
	foreach (@$args) {
		$settings .= ($settings eq '') ? $_ . ' = ?' : ', ' . $_ . ' = ?';
	}
	
	return 'UPDATE ' . $self->table . ' SET ' . $settings . ' WHERE '  . $self->log_id . ' = ?';
}

sub new {
	my ($class, $args) = @_;
	
	return bless $args, $class;
}

sub add {
	my ($class, $args) = @_;
	my $self = bless $args, $class;
	
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached($self->q_insert($args));
	$sth->execute(values %$args);
	$sth->finish;
	
	$self->{$self->log_id} = $dbh->last_insert_id(undef,undef,$self->table,undef);
	
	return $self;
}

sub load {
	my ($class, $args) = @_;
	my $self = bless {}, $class;
	
	$self->{$self->log_id} = $args->{$self->log_id};
	my $dbh = $self->db_connect;
	my $sth = $dbh->prepare_cached($self->q_select($args->{columns}));
	$sth->execute($self->{$self->log_id});
	$sth->bind_columns(\@$self{@{$sth->{NAME_lc}}});
	$sth->fetch;
	$sth->finish;

	return $self;
}

sub update {
	my ($self, $args) = @_;
	my $dbh = $self->db_connect;
    
    my $sth = $dbh->prepare_cached($self->q_update([keys %$args]));
    $sth->execute((values %$args),$self->{$self->log_id});
    $sth->finish;

    return $sth->rows;
}

###########################################################################
# Проверяет наличие данного объекта в базе
sub exists : method {
###########################################################################
    my ($self, $opts) = @_;
    my $rslt;
    
    my $keys = $opts->{keys} || $self->keys;
    
    my $dbh = $self->db_connect;
    my $stmt = query_maker({
            type    => uc $opts->{statement} || 'SELECT COUNT',
            table   => $self->table,
            where   => $keys,
        });
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@$self{@$keys});
    $sth->bind_columns(\$rslt);
    $sth->fetch;
    $sth->finish;
    
    return $rslt;
}

1;

#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::Manager;
use base qw(Vicidial::DataObject);

sub table {'vicidial_manager'}
sub log_id {'man_id'}
sub keys : method { [ 'callerid', 'server_ip'] }

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


sub command {
    my ($class, $args, $opts) = @_;
    
    my $self = bless $args, $class;
    
    delete $self->{configfile};
    delete $self->{config};
    
    my $statement  = uc $opts->{statement} || 'INSERT';
    my $exception  = $opts->{exception} || 0;
    
    my $stmt = query_maker({
        type    => $statement,
        table   => $self->table,
        columns => [ (keys %$self) ],
        });
    my $dbh = $self->db_connect;
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(values %$self);
    if (defined $self->log_id) {
        $self->{$self->log_id} = $dbh->last_insert_id(undef,undef,$self->table,undef);
    }
    $sth->finish;
    
    return $self;
	
}

1;

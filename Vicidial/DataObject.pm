#!/usr/bin/perl
package Vicidial::DataObject;
use strict;
use warnings;
use base qw(Vicidial);
use Carp;
use Data::Dumper;

sub table { '' }
sub keys : method { [] }

sub query_maker{
    my $argref = shift;

    my $qt = {
        SELECT  => sub { 'SELECT ' . join(', ', @{$argref->{columns}}) . ' FROM ' . $argref->{table} . ' WHERE ' . join(' AND  ', map {$_ . ' = ?'} @{$argref->{where}}) . ' ' . $argref->{order} },
        UPDATE  => sub { 'UPDATE ' . $argref->{table} . ' SET ' . join(', ', map {$_ . '= ?'} @{$argref->{columns}}) . ' WHERE ' . join(' AND  ', map {$_ . ' = ?'} @{$argref->{where}}) },
        INSERT  => sub { 'INSERT INTO ' . $argref->{table} .  ' (' . join(', ', @{$argref->{columns}}) . ') VALUES (' . join(', ', map {'?'} @{$argref->{columns}}) . ')' },
        DELETE  => sub { 'DELETE FROM ' . $argref->{table} . ' WHERE ' . join(' AND ', map {$_ . ' = ?'} @{$argref->{where}}) },
        'SELECT COUNT'  => sub { 'SELECT COUNT(*) FROM ' . $argref->{table} . ' WHERE ' . join(' AND ', map {$_ . ' = ?'} @{$argref->{where}}) },
    };
  
    return $qt->{ $argref->{type} }->();
}

sub read_args {
    my $args = shift;
    return map { $_, $args->{$_} } grep { $_ ne 'columns' } (keys %$args);
}

###########################################################################
# Создаёт новый объект без связи с базой данных
sub new {
###########################################################################
    my ($class, $args) = @_;

    return bless $args, $class;
}

###########################################################################
# Читает атрибуты объекта из базы
sub sync {
###########################################################################
    my ($self, $args, $opts) = @_;
    
    my $statement  = $opts->{statement} || 'SELECT';
    my $keys       = $opts->{keys} || $self->keys;
    my $order      = $opts->{order} || '';
    my $exception  = $opts->{exception} || 0;
    
    my $dbh = $self->db_connect;
    my $stmt = query_maker({
            type    => $statement,
            table   => $self->table,
            columns => $args->{columns} || ['*'],
            where   => $keys,
            order   => $order,
        });
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@$self{@$keys});
    $sth->bind_columns(\@$self{@{$sth->{NAME_lc}}});
    $sth->fetch;
    $sth->finish;
    
    if ($exception && !$sth->rows) {
        croak "Non existent object";
    }

    return $sth->rows;
}

###########################################################################
# загружает новый объект из базы
sub load {
###########################################################################
    my ($class, $args, $opts) = @_;
    my $self = bless {}, $class;
    
    %$self = read_args($args);
    
    $self->sync({ columns => $args->{columns}}, $opts);

    return $self;
} 

###########################################################################
# Устанавливает значения атрибутов без обновления базы
sub set {
###########################################################################
    my ($self, $args) = @_;
    foreach (keys %$args) {
        $self->{$_} = $args->{$_};
    }
    
    return;
}
###########################################################################
# Обновляет данные в базе
sub update {
###########################################################################
    my ($self, $args, $opts) = @_;
    
    my $statement  = uc $opts->{statement} || 'UPDATE';
    my $keys       = $opts->{keys} || $self->keys;
    my $order      = $opts->{order} || '';
    my $exception  = $opts->{exception} || 0;
    
    %$self = (%$self, (read_args($args)));
    
    my $dbh = $self->db_connect;
    my $stmt = query_maker({
            type    => $statement,
            table   => $self->table,
            columns => [ keys %$args ],
            where   => $keys, 
        });
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute((values %$args),@$self{@$keys});
    $sth->finish;
    
    if ($exception && !$sth->rows) {
        croak "Non existent object";
    }
    
    return $sth->rows;
}

###########################################################################
# Удаляет объект из базы
sub delete {
###########################################################################
    my ($self, $opts) = @_;
    
    my $statement  = uc $opts->{statement} || 'DELETE';
    my $keys       = $opts->{keys} || $self->keys;
    my $order      = $opts->{order} || '';
    my $exception  = $opts->{exception} || 0;
    
    my $dbh = $self->db_connect;
    my $stmt = query_maker({
            type    => $statement,
            table   => $self->table,
            where   => $keys,
        });
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@$self{@$keys});
    $sth->finish;
    
    if ($exception && !$sth->rows) {
        croak "Non existent object";
    }
    
    return $sth->rows;
}

###########################################################################
# добавляет новый объект в базу
sub add {
###########################################################################
    my $tmp = shift;
    my ($self, $args, $opts);
    
    if (ref $tmp) {
        $self = $tmp;
	print join(';', @_),"\n";
        $opts = shift;
    } else {
        ($args, $opts) = @_;
        $self = bless $args, $tmp;
    }
    delete $self->{configfile};
    delete $self->{config};
    
    my $statement  = uc $opts->{statement} || 'INSERT';
    my $exception  = $opts->{exception} || 0;
    
    my $stmt = query_maker({
        type    => $statement,
        table   => $self->table,
        columns => [ keys %$self ],
        });
    my $dbh = $self->db_connect;
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(values %$self);
    $sth->finish;
    
    if ($self->can('log_id')) {
        $self->{$self->log_id} = $dbh->last_insert_id(undef,undef,$self->table,undef);
    }    

    if (ref $tmp) {
        return $self;
    } else {
        return $sth->rows;
    }
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

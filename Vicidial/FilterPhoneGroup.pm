#!user/bin/perl
package Vicidial::FilterPhoneGroup;
use strict;
use base qw(Vicidial::DataObject);

sub table {'vicidial_filter_phone_groups'};
sub keys  {['filter_phone_group_id']};

sub add_number {
    my ($self, $number) = @_;
    my $dbh = $self->db_connect;    

    my $stmt = 
"INSERT INTO vicidial_filter_phone_numbers (filter_phone_group_id, phone_number) VALUES (?, ?)";
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute($self->{'filter_phone_group_id'}, $number);
    $sth->finish;
    return $sth->rows;
}

sub del_number {
    my ($self, $number) = @_;
    my $dbh = $self->db_connect; 

    my $stmt =
"DELETE FROM  vicidial_filter_phone_numbers WHERE filter_phone_group_id = ? and phone_number = ?";
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute($self->{'filter_phone_group_id'}, $number);
    $sth->finish;
    return $sth->rows;
}

sub del_numbers {
    my $self = shift;
    my $dbh = $self->db_connect; 

    my $stmt =
"DELETE FROM vicidial_filter_phone_numbers WHERE filter_phone_group_id = ?";
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute($self->{'filter_phone_group_id'});
    $sth->finish;
    return $sth->rows;
}

sub get_numbers {
    my $self = shift;
    my $number;
    my @numbers;

    my $dbh = $self->db_connect;
    my $stmt =
"SELECT phone_number FROM vicidial_filter_phone_numbers WHERE filter_phone_group_id = ? ORDER BY phone_number";
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute($self->{'filter_phone_group_id'});
    $sth->bind_columns(\$number);
    while ($sth->fetch) {
        push @numbers, $number;
    }    
    return \@numbers;
}

1;

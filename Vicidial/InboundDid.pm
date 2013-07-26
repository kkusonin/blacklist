#!/usr/bin/perl
package Vicidial::InboundDid;
use strict;
use Vicidial::FilterPhoneGroup;
use base qw(Vicidial::DataObject);
use Carp;

sub table {'vicidial_inbound_dids'};
sub keys  {[qw(did_id)]};

sub find_by_did_pattern {
    my ($class, $did_pattern) = @_;
    my $did = $class->load(
        {did_pattern => $did_pattern},
        { keys => ['did_pattern'] },
        );

    if (!defined $did->{did_id}) {
        croak "Non-existent number!";
    }
    
    return $did;
}

sub get_filter_group {
    my $self = shift; 
    my $filter_group_id = $self->{filter_group_id};

    if (!defined $filter_group_id || $filter_group_id eq '---NONE---') {
        return undef;
    }

    return Vicidial::FilterPhoneGroup->load({ filter_phone_group_id => $filter_group_id});
}

sub set_filter_group_id {
    my ($self, $filter_group_id) = @_;
    $self->update({
        filter_group_id => $filter_group_id
    });

    return $self;
}

1;

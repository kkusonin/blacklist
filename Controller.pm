#!/usr/bin/perl
package Blacklist::Controller;
use Carp;
use Vicidial::InboundDid;
use Vicidial::FilterPhoneGroup;
use base (Exporter);
our @EXPORT = qw(show create destroy);

sub create {
    my $params = shift;
    my @errors;

    my $did_pattern = $params->{'entrance'};
    my $did = Vicidial::InboundDid->find_by_did_pattern($did_pattern);
    my $filter_group = $did->get_filter_group;
    if (!defined $filter_group) {
        $filter_group = Vicidial::FilterPhoneGroup->add({filter_phone_group_id => $did_pattern});
        $did->set_filter_group_id($did_pattern)
    }
    
    foreach my $number (@{$params->{'ids'}}) {
        eval {
            my $added = $filter_group->add_number($number);
            if (!$added) {            
                push @errors, $number;
            } else {
                push @errors, "| $number |";
            }
        };
        if ($@) {
            push @errors, $number;
        }
    }

    return \@errors;

}

sub destroy {
    my $params = shift;
    my @errors;

    my $did_pattern = $params->{'entrance'};
    my $did = Vicidial::InboundDid->find_by_did_pattern($did_pattern);
    my $filter_group = $did->get_filter_group;
    if (!defined $filter_group) {
        return $params->{'ids'};
    }
    
   foreach my $number (@{$params->{'ids'}}) {
        eval {
            my $deleted = $filter_group->del_number($number);
	    if (!$deleted) {
	    	push @errors, $number;
            }
        };
        if ($@) {
            push @errors, $number;
        }
    }

    return \@errors;
    
}

sub show {
    my $params = shift;

    my $did_pattern = $params->{'entrance'};
    my $did = Vicidial::InboundDid->find_by_did_pattern($did_pattern);
    my $filter_group = $did->get_filter_group;
    if (!defined $filter_group) {
        return [];
    }
    
    return $filter_group->get_numbers;
}

1;

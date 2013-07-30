#!/usr/bin/perl
package Blacklist::Controller;
use Carp;
use Vicidial::InboundDid;
use Vicidial::FilterPhoneGroup;
use base (Exporter);
our @EXPORT = qw(show clear create destroy);

sub remove_int_prefix {
	my $numbers = shift;
	
	return map { $_ =~ s!^\+!!; $_; } @$numbers;
}

sub add_int_prefix {
	my $numbers = shift;
	my @r = map { $_ =~ s!^(\d{11,})!\+$1!; $_; } @$numbers;
	return \@r;
}


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
    
    foreach my $number (remove_int_prefix($params->{'ids'})) {
        eval {
            my $added = $filter_group->add_number($number);
            if (!$added) { 
                push @errors, $number;
            }
        };
        if ($@) {
            push @errors, $number;
        }
    }

    return add_int_prefix(\@errors);

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
    
   foreach my $number (remove_int_prefix($params->{'ids'})) {
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

    return add_int_prefix(\@errors);
    
}

sub clear {
	my $params = shift;
	
	if (!defined $params->{'entrance'}) {
		return undef;
	}
	
    my $did_pattern = $params->{'entrance'};
    my $did = Vicidial::InboundDid->find_by_did_pattern($did_pattern);
    my $filter_group = $did->get_filter_group;
    if (!defined $filter_group) {
        return undef;
    }
	
	my $deleted = $filter_group->del_numbers;
	
	return $deleted;
}

sub show {
    my $params = shift;

    my $did_pattern = $params->{'entrance'};
    my $did = Vicidial::InboundDid->find_by_did_pattern($did_pattern);
    my $filter_group = $did->get_filter_group;
    if (!defined $filter_group) {
        return [];
    }
    
    return add_int_prefix($filter_group->get_numbers);
}

1;

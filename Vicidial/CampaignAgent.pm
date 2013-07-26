#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::CampaignAgent;
use base qw(Vicidial::DataObject);

sub table {'vicidial_campaign_agents'}
sub keys {['user', 'campaign_id']}

sub sync {
	my ($self, $args) = @_;
	
	eval {
		$self->SUPER::sync({columns => $args->{columns}}, { exception => 1});
	};
	if ($@) {
		$self->{campaign_weight} = '0';
		$self->{calls_today}	 = '0';
		$self->{campaign_grade}  = '1';
		
		$self->add;
	}
	
	return 1;
}

1;

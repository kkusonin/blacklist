#!/usr/bin/perl
package Vicidial::CampaignDNC;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_campaign_dnc'}
sub keys {['phone_number','campaign_id']}

1;

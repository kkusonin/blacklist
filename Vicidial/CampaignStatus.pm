#!/usr/bin/perl
package Vicidial::CampaignStatus;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table { 'vicidial_campaign_statuses' }
sub keys {['status','campaign_id']}

1;

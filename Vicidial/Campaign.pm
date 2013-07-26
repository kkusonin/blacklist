#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::Campaign;
use base qw(Vicidial::DataObject);

sub table {'vicidial_campaigns'}
sub keys { ['campaign_id'] };

1;

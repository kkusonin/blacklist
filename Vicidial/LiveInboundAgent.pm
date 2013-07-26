#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::LiveInboundAgent;
use base qw(Vicidial::DataObject);

sub table {'vicidial_live_inbound_agents'}

sub keys { ['user','group_id'] } 

1;
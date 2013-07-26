#!/usr/bin/perl
package Vicidial::LiveInboundAgent;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_live_inbound_agents'}
sub keys {[qw(user group_id)]}

1;

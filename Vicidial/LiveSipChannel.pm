#!/usr/bin/perl
package Vicidial::LiveSipChannel;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'live_sip_channels'}
sub keys { [ 'extension', 'server_ip'] }

1;

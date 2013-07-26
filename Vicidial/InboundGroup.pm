#!/usr/bin/perl
package Vicidial::InboundGroup;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_inbound_groups'}
sub keys {[qw(group_id)]}

1;

#!/usr/bin/perl
package Vicidial::AutoCall;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_auto_calls'}
sub keys {['callerid']}

1;

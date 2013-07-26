#!/usr/bin/perl
package Vicidial::CloserLog;
use strict;
use warnings;
use base qw(Vicidial::LogObject);

sub table {'vicidial_closer_log'}
sub log_id {'uniqueid'}

1;

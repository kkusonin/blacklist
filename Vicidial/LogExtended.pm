#!/usr/bin/perl
package Vicidial::LogExtended;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_log_extended'}
sub keys {['iniqueid']}
sub log_id {'uniqueid'}

1;

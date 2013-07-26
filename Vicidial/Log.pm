#!/usr/bin/perl
package Vicidial::Log;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_log'}
sub keys {['uniqueid']}
sub log_id {'uniqueid'}

1;

#!/usr/bin/perl
package Vicidial::Status;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table { 'vicidial_statuses' }
sub keys {['status']}

1;

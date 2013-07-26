#!/usr/bin/perl
package Vicidial::DNC;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_dnc'}
sub keys {['phone_number']}

1;

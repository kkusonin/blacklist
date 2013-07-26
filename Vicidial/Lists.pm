#!/usr/bin/perl
package Vicidial::Lists;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'vicidial_lists'}
sub keys { ['list_id'] }

1;
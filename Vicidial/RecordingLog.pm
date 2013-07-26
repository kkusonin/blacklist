#!/usr/bin/perl
package Vicidial::RecordingLog;
use strict;
use warnings;
use base qw(Vicidial::DataObject);

sub table {'recording_log'}
sub keys {['recording_id']}
sub log_id {'recording_id'}

1;

#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::UserCallLog;
use base qw(Vicidial::LogObject);

sub table {'user_call_log'}

sub log_id {'user_call_log_id'}

1;

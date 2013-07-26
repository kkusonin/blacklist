#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::UserLog;
use base qw(Vicidial::LogObject);

sub table {'vicidial_user_log'}

sub log_id {'user_log_id'}

1;

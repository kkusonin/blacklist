#!/usr/bin/perl
use strict;
use warnings;
package Vicidial::Functions;
our @EXPORT_OK = qw(cid_date mcid_date now_time random tsnow_time);
use base qw(Exporter);

sub cid_date {
	my $time = shift || time;
	
	return sprintf '%02d%02d%02d%02d%02d%02d',
		sub {($_[5] + 1900) % 100,$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($time));
}

sub mcid_date {
        my $time = shift || time;

        return sprintf '%02d%02d%02d%02d%02d',
                sub {$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($time));
}

sub now_time {
	my $time = shift || time;
	
	return sprintf '%04d-%02d-%02d %02d:%02d:%02d', 
		sub {$_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($time));
}		
sub tsnow_time {
	my $time = shift || time;
	
	return sprintf '%04d%02d%02d%02d%02d%02d',
		sub {$_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($time));
}

sub random {
    int(rand(9000000)) + 11000000;
}

1;

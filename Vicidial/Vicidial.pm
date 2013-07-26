#!/usr/bin/perl
package Vicidial;
use strict;
use warnings;
use Config::General;
use DBI;

my $dbh;

sub new {
        my $class = shift;
        my $self = bless {}, $class;

        $self->config_read;

        return $self;
}

sub config_read {
        my $self = shift;
        $self->{configfile} = shift || '/etc/astguiclient.conf';

        my $reader = new Config::General(
        -ConfigFile     => $self->{configfile},
        -SplitPolicy    => 'custom',
        -SplitDelimiter => '\s+=>\s+',
        );

        %{$self->{config}} = $reader->getall;
}

sub db_connect {
        my $self = shift;
        if ( !defined $dbh || !$dbh->ping) {
                if (!defined $self->{config}) {
                        $self->config_read;
                }
                $dbh = DBI->connect("DBI:mysql:$self->{config}->{VARDB_database}:$self->{config}->{VARDB_server}:$self->{config}->{VARDB_port}",
                            "$self->{config}->{VARDB_user}",
                            "$self->{config}->{VARDB_pass}",
                            {RaiseError => 1},
                            )
        }

        return $dbh;
}

1;
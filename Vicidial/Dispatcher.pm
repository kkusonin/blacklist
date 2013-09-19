#!/usr/bin/perl
package Vicidial::Dispatcher;
use strict;
use warnings;
use Apache2::Connection;
use Apache2::Const -compile => qw(OK HTTP_METHOD_NOT_ALLOWED HTTP_NOT_IMPLEMENTED LOG_DEBUG);
use Apache2::Request;
use Apache2::RequestRec;
use Apache2::SubProcess;
use POSIX 'setsid';
use Vicidial::Agent;

my $dispatch_table = {
        '/agent/login'  => \&agent_login,
        '/agent/logout' => \&agent_logout,
        '/agent/status' => \&agent_status,
        '/agent/pause'  => \&agent_pause,
        '/agent/resume' => \&agent_resume,
        '/agent/dial'   => \&agent_dial,
        '/agent/hangup' => \&agent_hangup,
        '/agent/dispo'  => \&agent_dispo,
	'/agent/transfer' => \&agent_transfer,
};

sub handler {
    my $r = shift;
    my $s = $r->server;
        $s->loglevel(Apache2::Const::LOG_DEBUG);

        # Only GET is supported now
        return Apache2::Const::HTTP_METHOD_NOT_ALLOWED if $r->method ne 'GET';
        # 
        return Apache2::Const::HTTP_NOT_IMPLEMENTED if !defined($dispatch_table->{$r->uri});
    my $resstr = '';
    eval {
        $resstr = $dispatch_table->{$r->uri}->($r);
    };
    if ($@) {
        $r->print($@,"\n")
    } else {
        $r->print($resstr,"\n");
    }
    return Apache2::Const::OK;
}

sub agent_login {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        $args{ip} = $r->connection->remote_ip;
        $args{browser} = $r->headers_in->{ 'User-Agent' } || "Unknown";
        my $agent;

        $r->log->debug("-->Vicidial::Dispatcher: Login attempt $args{username} from $args{ip}");
        eval {
                $agent = Vicidial::Agent->login(\%args);
        };
        if ($@) {
                return "ERROR: Login error";
        }
        
        $SIG{CHLD} = 'IGNORE';
        defined (my $child = fork) or die "Cannot fork: $!\n";
        if ($child) {
                return "SUCCESS: User $args{username} logged in";
        } else {
                chdir '/';
                open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
                open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
                open STDERR, '>/tmp/log'  or die "Can't write to /tmp/log: $!";
                setsid                    or die "Can't start a new session: $!";

                $agent->run;
                CORE::exit(0);
        }

}

sub agent_logout {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        eval {
                $agent = Vicidial::Agent->load(\%args);
                $agent->logout;
        };
        if ($@) {
            return "ERROR: Logout error";
        }
        return "SUCCESS: User $args{username} logged out";
}
sub agent_status {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent = Vicidial::Agent->load(\%args);
        my $status = $agent->status;
        
        return "SUCCESS: $status";
}

sub agent_pause {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load(\%args);
        my $status = $agent->pause;
        
        return "SUCCESS: User $args{username} status PAUSED";
}

sub agent_resume {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load(\%args);
        my $status = $agent->resume;
        
        return "SUCCESS: User $args{username} status READY";
}

sub agent_dial {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load({
            username     => $args{username},
	    password     => $args{password} 
            });
        $agent->dial({
            phone_number    => $args{phone_number},
            phone_code      => $args{phone_code},
            });
        
        return "SUCCESS: Call started";
}

sub agent_hangup {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load(\%args);
        $agent->hangup;
        
        return "SUCCESS: Hangup";
}

sub agent_dispo {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load(\%args);
        $agent->dispo({
            dispo_code  => $args{dispo_code},
            });
            
        return "SUCCESS: disposition code set";
}

sub agent_transfer {
        my $r = shift;
        my %args = map { split('=', $_)} split(/&/, $r->args);
        my $agent;

        $agent = Vicidial::Agent->load({
            username     => $args{username},
			password     => $args{password} 
            });
        $agent->transfer({
            phone_number    => $args{phone_number},
            });
        
        return "SUCCESS: Call started";
}

1;

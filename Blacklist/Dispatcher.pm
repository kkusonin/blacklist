
#!/usr/bin/perl
package Blacklist::Dispatcher;
use strict;
use Apache2::RequestRec; 
use Apache2::RequestIO; 
use Apache2::Const -compile => qw(OK HTTP_NOT_FOUND HTTP_NOT_IMPLEMENTED HTTP_INTERNAL_SERVER_ERROR);
use Blacklist::Controller;
use JSON;

my $post_actions = {
    'add'     => sub {
                    my ($r, $params) = @_;
                    render_json($r, $params, \&create);
                    },
    'remove'  => sub { 
                    my ($r, $params) = @_;
                    render_json($r, $params, \&destroy);
                    },
    'clear'	  => sub {
		    my ($r, $params) = @_;
			if (defined clear($params)) {
			    return Apache2::Const::OK;
			}
		        return Apache2::Const::HTTP_NOT_FOUND;
		    },
    _DEFAULT_ => sub { return Apache2::Const::HTTP_NOT_FOUND },
};

my $get_actions = {
    '_DEFAULT_' => sub {
                    my ($r, $params) = @_;
                    render_json($r, $params, \&show);
                    },
    'clear'     => sub {
                    my ($r, $params) = @_;
                    if (defined clear($params)) {
                        return Apache2::Const::OK;
                    }       
                    return Apache2::Const::HTTP_NOT_FOUND;
                    },
};

my $actions = {
    GET         => sub {
                    my ($r, $params) = @_;
                    my $action = $get_actions->{$params->{'action'}} || $get_actions->{_DEFAULT_};
                    $action->($r,$params);
                    },
    POST        => sub { 
                    my ($r, $params) = @_;
                    my $json;
                    if ($r->can('read')) {
                        $r->read($json, $r->headers_in->{'Content-length'});
                    }
                    my $jref = from_json($json);
                    my $action = $post_actions->{$params->{'action'}} || $post_actions->{_DEFAULT_};
                    $action->($r,{%$params, %$jref});
                    },
    _DEFAULT_   => sub { return Apache2::Const::HTTP_NOT_IMPLEMENTED; },
};

sub render_json {
    my ($r, $params, $get_data) = @_;
    eval {
        my $app_data = $get_data->($params);
        my $json = to_json({ ids => $app_data });
        $r->content_type('application/json');
        $r->set_content_length(length($json));
        $r->print($json);
        return Apache2::Const::OK;
    };
    if (@!) {
        return Apache2::Const::HTTP_INTERNAL_SERVER_ERROR;
    }
}


sub handler {
    my $r = shift;

    # Grab the query string... 
    my %params = map{ split '=', $_ } split("&", $r->args);
    
    my $action = $actions->{$r->method} || $actions->{_DEFAULT_};
    
    $action->($r, \%params);   

} 

1;


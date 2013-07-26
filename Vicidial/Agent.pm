#!/usr/bin/perl
package Vicidial::Agent;
use base qw(Vicidial::LiveAgent);
use Vicidial::AgentLog;
use Vicidial::AutoCall;
use Vicidial::Campaign;
use Vicidial::CampaignAgent;
use Vicidial::CampaignDNC;
use Vicidial::CampaignStatus;
use Vicidial::CloserLog;
use Vicidial::Conference;
use Vicidial::DNC;
use Vicidial::Hopper;
use Vicidial::InboundGroup;
use Vicidial::List;
use Vicidial::Lists;
use Vicidial::LiveInboundAgent;
use Vicidial::LiveSipChannel;
use Vicidial::Log;
use Vicidial::LogExtended;
use Vicidial::Manager;
use Vicidial::Phone;
use Vicidial::Functions qw(cid_date mcid_date now_time random tsnow_time);
use Vicidial::Status;
use Vicidial::User;
use Vicidial::UserLog;
use Vicidial::UserCallLog;
use Carp;
use Data::Dumper;

sub load {
	my ($class, $args) = @_;
	
	if (
                   !defined $args->{username}
                || !defined $args->{password}
	) {
                croak "ERROR: Mandatory parameter is missing!";
        }
	my $self = $class->SUPER::load({user => $args->{username}},{exception => 1});

	return $self;
}

sub login {
        my ($class, $args) = @_;
        my $self = bless {}, $class;
        ### Begin input arguments checking
        if (
                   !defined $args->{username}
                || !defined $args->{password}
                || !defined $args->{phone_login}
                || !defined $args->{phone_passwd}
                || !defined $args->{campaign}
                || !defined $args->{ip}
                || !defined $args->{browser}
                ) {
                croak "ERROR: Mandatory parameter is missing!";
        }
        ### End of input arguments checking

        my $dbh = $self->db_connect;

        ### Read user data 
        my $user = Vicidial::User->authload({
                 user => $args->{username},
                 pass => $args->{password},
                 columns => [qw(user_group user_level closer_campaigns)],
                 });

        ### Read campaign settings 
        my $campaign = Vicidial::Campaign->load({
            campaign_id => $args->{campaign},
            columns     => [qw(auto_dial_level campaign_allow_inbound)],
            });

        ### Read phone settings 
        my $phone = Vicidial::Phone->authload({
                        login   => $args->{phone_login},
                        pass    => $args->{phone_passwd},
                        columns => ['extension','server_ip','protocol','ext_context','phone_ring_timeout','on_hook_agent'],
                        });
        my $extension = $phone->{protocol} . '/' . $phone->{extension};

        my $TEMP_SIP_user_DiaL = '';
        if ($phone->{protocol} eq 'SIP') {
                $TEMP_SIP_user_DiaL = ($phone->{on_hook_agent} eq 'Y') ? 'Local/8300@default' : $extension;
        } else {
                croak "ERROR: phone protocol $phone->{protocol} not supported";
        }

        #### Set time variables 
        my $StarTtimE   = time;
        my $CIDdate     = cid_date($StarTtimE);
        my $NOW_TIME    = now_time($StarTtimE);
        my $tsNOW_TIME  = tsnow_time($StarTtimE);
        #### End of time variables setting

        ### Grab free vicidial conference
        my $meetme = Vicidial::Conference->allocate({
                        extension       => $extension,
                        server_ip       => $phone->{server_ip}
                        });
       
        # Пока оставим session_id для облегчения понимания
        my $session_id = $meetme->get_conf_exten;

        ### Clear data in case last time agent was disconnected incorrectly
        my $vlERIaffected_rows  = Vicidial::List->mark_eri($args->{username});
        my $vhICaffected_rows   = Vicidial::Hopper->clean($args->{username});
        my $la  = new Vicidial::LiveAgent({ user => $args->{username}});
        my $vlaLIaffected_rows  = $la->delete;
        my $lia = new Vicidial::LiveInboundAgent({ user => $args->{username}},{ keys => ['user']});
        my $vliaLIaffected_rows = $lia->delete({ keys => ['user']});
        my $vul_data = "$vlERIaffected_rows|$vhICaffected_rows|$vlaLIaffected_rows|$vliaLIaffected_rows";

        ### Add record to user log
        Vicidial::UserLog->add({
                user                    => $args->{username},
                event                   => 'LOGIN',
                campaign_id             => $args->{campaign},
                event_date              => $NOW_TIME,
                event_epoch             => $StarTtimE,
                user_group              => $user->{user_group},
                session_id              => $session_id,
                server_ip               => $phone->{server_ip},
                extension               => $extension,
                computer_ip             => $args->{ip},
                browser                 => $args->{browser},
                data                    => $vul_data,
                });
        ### set the callerID for manager middleware-app to connect the phone to the user
        my $SIqueryCID = "S$CIDdate$session_id";

        ### Connect agent phone
        Vicidial::Manager->command({
                uniqueid                => '',
                entry_date              => $NOW_TIME,
                status                  => 'NEW',
                response                => 'N',
                server_ip               => $phone->{server_ip},
                channel                 => '',
                action                  => 'Originate',
                callerid                => $SIqueryCID,
                cmd_line_b              => 'Channel: ' . $TEMP_SIP_user_DiaL,
                cmd_line_c              => 'Context: ' . $phone->{ext_context},
                cmd_line_d              => 'Exten: ' . $session_id,
                cmd_line_e              => 'Priority: 1',
                cmd_line_f              => 'Callerid: "' . $SIqueryCID . '" <' . $campaign->{campaign_cid} . '>',
                cmd_line_g              => '',
                cmd_line_h              => '',
                cmd_line_i              => '',
                cmd_line_j              => '',
                cmd_line_k              => '',
                });
        my $ca = Vicidial::CampaignAgent->load({
                                user            => $args->{username},
                                campaign_id     => $args->{campaign},
                                columns         => [qw(calls_today campaign_weight campaign_grade)]
                                });

        ### Set all necessary parameters
        $self->set({
            user                        => $args->{username},
            campaign_id                 => uc($args->{campaign}),
            server_ip                   => $phone->{server_ip},
            on_hook_ring_time           => $phone->{phone_ring_timeout},
            on_hook_agent               => $phone->{on_hook_agent},
            extension                   => $phone->{protocol} . '/' . $phone->{extension},
            conf_exten                  => $session_id,
            user_level                  => $user->{user_level},
            last_call_time              => $NOW_TIME,
            last_state_change           => $NOW_TIME,
            last_update_time            => $tsNOW_TIME,
            last_call_finish            => $NOW_TIME,
            closer_campaigns            => ($campaign->{campaign_allow_inbound} eq 'Y') ? $user->{closer_campaigns} : '',
            last_inbound_call_time      => ($campaign->{auto_dial_level} > 0) ? $NOW_TIME : undef,
            last_inbound_call_finish    => ($campaign->{auto_dial_level} > 0) ? $NOW_TIME : undef,
            outbound_autodial           => ($campaign->{auto_dial_level} > 0) ? 'Y'       : 'N',
            random_id                   => random(),
            status                      => 'PAUSED',
            lead_id                     => '',
            uniqueid                    => '',
            callerid                    => '',
            channel                     => '',
            campaign_weight             => $ca->{campaign_weight},
            calls_today                 => $ca->{calls_today},
            campaign_grade              => $ca->{campaign_grade},
            });
        ### Add object to database
        $self->add;

        ### Add record to agent log
        my $al = Vicidial::AgentLog->add({
                user            => $self->{user},
                server_ip       => $self->{server_ip},
                event_time      => $NOW_TIME,
                campaign_id     => $self->{campaign_id},
                pause_epoch     => $StarTtimE,
                pause_sec       => 0,
                wait_epoch      => $StarTtimE,
                user_group      => $user->{user_group},
                sub_status      => 'LOGIN',
                });

        $self->update({ agent_log_id => $al->{agent_log_id} });

        ##### update vicidial_campaigns to show agent has logged in
        $campaign->update({campaign_logindate => $NOW_TIME});

        $user->update({shift_override_flag => '0'});

        #Agent logged in (possibly)


        return $self;
}


sub logout {
    my $self = shift;

    ##### Get user group 
    my $user = Vicidial::User->load({
            user            => $self->{user},
            columns         => ['user_group'],
            });
    my $user_group = $user->{user_group};

    #### Set time variables 
    my $StarTtimE   = time;
    my $CIDdate     = cid_date($StarTtimE);
    my $NOW_TIME    = now_time($StarTtimE);
    my $tsNOW_TIME  = tsnow_time($StarTtimE);
    #### End of time variables setting

    ##### Insert a LOGOUT record into the user log
    my $ul = Vicidial::UserLog->add({
            user            => $self->{user},
            event           => 'LOGOUT',
            campaign_id     => $self->{campaign_id},
            event_date      => $NOW_TIME,
            event_epoch     => $StarTtimE,
            user_group      => $user_group, 
            });
        
    ##### Remove the reservation on the vicidial_conferences meetme room
    my $meetme = Vicidial::Conference->new({
            conf_exten      => $self->{conf_exten},
            server_ip       => $self->{server_ip},
            });
    $meetme->free;
    ###### Delete the web_client_sessions
    #my ws = Vicidial::WebSession->new({
    #       sesion_name     => $session_name,
    #       server_ip       => $self->{server_ip},
    #       });
    #$ws->delete;
    ###### Web Session идет нах

    ##### Hangup the client phone
    my $lsc = Vicidial::LiveSipChannel->load({
            extension   => $self->{conf_exten},
            server_ip   => $self->{server_ip},
            columns     => ['channel'],
            });

    if (defined $lsc->{channel}) {
        Vicidial::Manager->command({
            uniqueid        => '',
            entry_date      => $NOW_TIME,
            status          => 'NEW',
            response        => 'N',
            server_ip       => $self->{server_ip},
            channel         => '',
            action          => 'Hangup',
            callerid        => 'ULGH3459' . $StarTtimE,
            cmd_line_b      => 'Channel: ' . $lsc->{channel},
            cmd_line_c      => '',
            cmd_line_d      => '',
            cmd_line_e      => '',
            cmd_line_f      => '',
            cmd_line_g      => '',
            cmd_line_h      => '',
            cmd_line_i      => '',
            cmd_line_j      => '',
            cmd_line_k      => '',
            });
    }
    
    # Hangup all channells in this conference (logaut kick all = 1) it's default
    ### Read our phone data
    my ($protocol, $extension) = split '/', $self->{extension};
    my $phone = Vicidial::Phone->load({
            extension   => $extension,
            server_ip   => $self->{server_ip},
            columns     => [ qw(ext_context) ],
            });

        my $queryCID = 'ULGH3458' . $StarTtimE;

        Vicidial::Manager->command({
            uniqueid        => '',
            entry_date      => $NOW_TIME,
            status          => 'NEW',
            response        => 'N',
            server_ip       => $self->{server_ip},
            channel         => '',
            action          => 'Originate',
            callerid        => $queryCID,
            cmd_line_b      => 'Channel: Local/5555' . $self->{conf_exten} . '@' . $phone->{ext_context},
            cmd_line_c      => 'Context: ' . $phone->{ext_context},
            cmd_line_d      => 'Exten: 8300',
            cmd_line_e      => 'Priority: 1',
            cmd_line_f      => 'Callerid: ' . $queryCID,
            cmd_line_g      => '',
            cmd_line_h      => '',
            cmd_line_i      => '',
            cmd_line_j      => $self->{channel},
            cmd_line_k      => '',
            });
            
    ##### Delete the vicidial_live_agents record for this session
    $self->delete;
   
    ##### Delete the vicidial_live_inbound_agents records for this session
    my $lia = Vicidial::LiveInboundAgent->new({ user => $self->{user}, {keys => ['user']} });
    $lia->delete({ keys => ['user']});

    #### Update agent log
    my $al= Vicidial::AgentLog->load({
            agent_log_id    => $self->{agent_log_id},
            columns         => ['pause_epoch','pause_sec','wait_epoch','talk_epoch','dispo_epoch'],
            });
    my $pause_sec = (($StarTtimE - $al->{pause_epoch}) + $al->{pause_sec});
    $al->update({
            pause_sec   => $pause_sec,
            wait_epoch  => $StarTtimE,
            });

    return 1;
}

sub dial {
    my ($self, $args) = @_;
    
    if (!defined $args->{phone_number}) {
        croak "Mandatory parameter is missing";
    }
    
    #### Set time variables 
    my $StarTtimE   = time;
    my $CIDdate     = mcid_date($StarTtimE);
    my $NOW_TIME    = now_time($StarTtimE);
    my $tsNOW_TIME  = tsnow_time($StarTtimE);
    #### End of time variables setting
    
    ### Read our phone data
    my ($protocol, $extension) = split '/', $self->{extension};
    
    my $phone = Vicidial::Phone->load({
        extension   => $extension,
        server_ip   => $self->{server_ip},
        columns     => [ qw(ext_context outbound_cid) ],
        });
        
    
    ## Read campaign data
    my $campaign = Vicidial::Campaign->load({
        campaign_id => $self->{campaign_id},
        columns     => [ qw(manual_dial_list_id omit_phone_code use_custom_cid manual_dial_cid campaign_cid
                        dial_timeout dial_prefix extension_appended_cidname) ], 
        });
    
    ## Read user data
    my $user = Vicidial::User->load({
        user    => $self->{user},
        columns => ['user_group'],
        });
        
    ## Add new record to vicidial list specified
    my $lead = Vicidial::List->add({
        phone_code              => $args->{phone_code},
        phone_number            => $args->{phone_number},
        list_id                 => $campaign->{manual_dial_list_id},
        status                  => 'QUEUE',
        user                    => $self->{user},
        called_since_last_reset => 'Y',
        entry_date              => $tsNOW_TIME,
        last_local_call_time    => $NOW_TIME,
        });
    ## Get back lead_id for dialed number 
    my $lead_id = $lead->{lead_id};
    ### Now we have lead fucking id

    
    my $PADlead_id = sprintf("%09s", $lead_id);
    $PADlead_id = (length($PADlead_id) > 9) ? substr($PADlead_id, -9) : $PADlead_id;
    
    ## Create unique calleridname to track the call: MmmddhhmmssLLLLLLLLL
        my $MqueryCID = 'M' . $CIDdate . $PADlead_id;
    
    ### callerid definition
    my $list = Vicidial::Lists->load({
        list_id                 => $campaign->{manual_dial_list_id},
        columns                 => [ qw(campaign_cid_override) ],
        });
    # На самом деле первая строка должна выглядеть так:
    # my $CIDnumber =  ($campaign->{use_custom_cid} eq 'Y' and defined $lead->{security_phrase})  ? $lead->{security_phrase},
    # но мы только что завели новый lead_id, поэтому ясно, что security_phrase IS NULL
    my $CIDnumber = (defined $list->{campaign_cid_override})        ? $list->{campaign_cid_override}
                :  ($campaign->{manual_dial_cid} eq 'AGENT_PHONE')  ? $phone->{outbound_cid}
                :                                                     $campaign->{campaign_cid};
    
    my $CIDstring = ($campaign->{extension_appended_cidname} eq 'Y') ? '"' . $MqueryCID . $extension . '"'
                    :                                                  '"' . $MqueryCID . '"';
    $CIDstring .= (defined $CIDnumber) ? '  <' . $CIDnumber . '>' : '';
    
    my $RAWaccount;
    my $account = '';
    my $variable = '';
    if (defined $args->{group_alias}) {
        $RAWaccount = $args->{group_alias};
        $account = 'Account: ' . $args->{account};
        $variable = 'Variable: usegroupalias=1';
    }
    
    my $Local_dial_timeout = ($campaign->{dial_timeout} > 4) ? $campaign->{dial_timeout} * 1000 : 60000;
    my $Local_out_prefix = ($campaign->{dial_prefix} =~ /x/i) ? ''
                        :  ($campaign->{dial_prefix} ne '')   ? $campaign->{dial_prefix}
                        :                                       '9';
    ### whether to omit phone_code or not
    my $Ndialstring = ($campaign->{omit_phone_code} eq 'Y') ? $Local_out_prefix . $args->{phone_number}
                    :                                  $Local_out_prefix . $args->{phone_code} . $args->{phone_number};
    
    ### insert the call action into the vicidial_manager table to initiate the call
    my $dial_action = Vicidial::Manager->command({
        uniqueid            => '',
        entry_date          => $NOW_TIME,
        status              => 'NEW',
        response            => 'N',
        server_ip           => $self->{server_ip},
        channel             => '',
        action              => 'Originate',
        callerid            => $MqueryCID,
        cmd_line_b          => 'Exten: ' . $Local_out_prefix . $Ndialstring,
        cmd_line_c          => 'Context: ' . $phone->{ext_context},
        cmd_line_d          => 'Channel: ' . 'Local/' . $self->{conf_exten} . '@' . $phone->{ext_context} . '/n',
        cmd_line_e          => 'Priority: 1',
        cmd_line_f          => 'Callerid: ' . $CIDstring,
        cmd_line_g          => 'Timeout: ' . $Local_dial_timeout,
        cmd_line_h          => $account,
        cmd_line_i          => $variable,
        cmd_line_j          => '',
        cmd_line_k          => '',
        });
        
    my $ca = Vicidial::CampaignAgent->load({
        user                => $self->{user},
        campaign_id         => $self->{campaign_id},
	columns		    => [ 'calls_today' ],
        });
    $ca->{calls_today}++;
    
    Vicidial::AutoCall->add({
        server_ip           => $self->{server_ip},
        campaign_id         => $self->{campaign_id},
        status              => 'XFER',
        lead_id             => $lead_id,
        callerid            => $MqueryCID,
        phone_code          => $args->{phone_code},
        phone_number        => $args->{phone_number},
        call_time           => $NOW_TIME,
        call_type           => 'OUT',
        });
        
    ### update the agent status to INCALL in vicidial_live_agents
    $self->update({
        status              => 'INCALL',
        last_call_time      => $NOW_TIME,
        callerid            => $MqueryCID,
        lead_id             => $lead_id,
        comments            => 'MANUAL',
        calls_today         => $calls_today,
        external_hangup     => 0,
        external_status     => '',
        external_pause      => '',
        external_dial       => '',
        last_state_change   => $NOW_TIME,
        });
        
    ### update calls_today count in vicidial_campaign_agents
    $ca->update({
        calls_today         => $calls_today,
        });
    ### update agent log
    my $al = Vicidial::AgentLog->new({
        agent_log_id        => $self->{agent_log_id},
        });
    my $val_pause_epoch = $al->pause_epoch($al->{agent_log_id});
    my $val_pause_sec = $StarTtimE - $val_pause_epoch;
    $al->update({
        pause_sec           => $val_pause_sec,
        wait_epoch          => $StarTtimE,
        });

    my $ucl = Vicidial::UserCallLog->add({
        user                => $self->{user},
        call_date           => $NOW_TIME,
        call_type           => $args->{agent_dialed_type},
        server_ip           => $self->{server_ip},
        phone_number        => $args->{phone_number},
        number_dialed       => $Ndialstring,
        lead_id             => $lead_id,
        callerid            => $CIDnumber,
        group_alias_id      => $RAWaccount,
        });
    ### Check status of started call
    foreach my $i (0..9) {
        $dial_action->sync({
	    columns	=> [ 'channel', 'uniqueid' ],
	    });
        last if length($dial_action->{uniqueid}) > 5;
        sleep 1; 
    }
    ### Update call record
    my $call = Vicidial::AutoCall->new({
            callerid    => $MqueryCID,
            });
    
    $call->update({
            uniqueid    => $dial_action->{uniqueid},
            channel     => $dial_action->{channel},
            });
    $self->update({
            uniqueid    => $dial_action->{uniqueid},
            channel     => $dial_action->{channel},
            });
    ### Add Vicidial Log record
    my $log = Vicidial::Log->add({
	uniqueid    => $dial_action->{uniqueid},
        lead_id     => $lead_id,
        list_id     => $campaign->{manual_dial_list_id},
        campaign_id => $self->{campaign_id},
        call_date   => $NOW_TIME,
        start_epoch => $StarTtimE,
        status      => 'INCALL',
        phone_code  => $args->{phone_code},
        phone_number=> $args->{phone_number},
        user        => $self->{user},
        comments    => 'MANUAL',
        processed   => 'N',
        user_group  => $user->{user_group},
        term_reason => 'NONE',
        alt_dial    => 'MAIN',
        });
}

sub pause {
    my $self = shift;
    
    my $status = $self->status;
    if ($status eq 'READY') {
        $self->update({
            status              => 'PAUSED',
            callerid            => '',
            channel             => '',
            ring_callerid       => '',
            comments            => '',
            uniqueid            => 0,
            last_state_change   => now_time(time),
            random_id           => int(rand(9000000)) + 11000000,
            });
    } elsif ($status eq 'PAUSED') {
    } else {
        croak "ERROR: User $self->{user} can not be paused. Current state is $self->{status}";
    }
    
    return $status;
}

sub resume {
    my $self = shift;
    
    my $status = $self->status;
    if ($status eq 'PAUSED') {
        $self->update({
            status              => 'READY',
            callerid            => '',
            channel             => '',
            lead_id             => 0,
            comments            => '',
            uniqueid            => 0,
            last_state_change   => now_time(time),
            random_id           => int(rand(9000000)) + 11000000,
            });
    } 
    
    return $status;
}


sub run {
    my $self = shift;
    
    while ($self->sync({columns => ['status', 'lead_id', 'callerid']})) {
        my $StarTtimE = time;
        my $NOW_TIME = now_time($StarTtimE);
        
        if ($self->status eq 'QUEUE') {
            
            ### Increment number of calls today for this campaign
            my $ca = Vicidial::CampaignAgent->new({
                user        => $self->{user},
                campign_id  => $self->{campaign_id},
                });
            $self->{calls_today}++;
            $ca->update({
                calls_today => $self->{calls_today},
                });
                
            ### grab the data from vicidial_list for the lead_id
            my $vl = Vicidial::List->load({
                lead_id             => $self->{lead_id},
                columns             => ['list_id'],
                });
                
            ### update the lead status to INCALL
            $vl->update({
                status              => 'INCALL',
                user                => $self->{user},
                });
            
            my $user = Vicidial::User->load({
                user        => $self->{user},
                columns     => ['user_group'],
                });
            my $user_group = $user->{user_group};
            
            my $ac = Vicidial::AutoCall->load({
                	callerid  => $self->{callerid},
                	columns   => ['campaign_id','phone_number','alt_dial','call_type'],
                },
		{
			order	  => 'ORDER BY call_time DESC LIMIT 1',
		});
                
            if ($call_type eq 'OUT' || $call_type || 'OUTBALANCE') {
                ### Update Vicidial Log
                my $vlog = Vicidial::Log->new({
                    lead_id         => $self->{lead_id},
                    uniqueid        => $self->{uniqueid},
                    });
                $vlog->update({
                    status      => 'INCALL',
                    user        => $self->{user},
                    comments    => 'AUTO',
                    list_id     => $vl->{list_id},
                    user_group  => $user_group,
                    });
                
                ### update the agent status to INCALL
                $self->update({
                    status              => 'INCALL',
                    last_call_time      => $NOW_TIME,
                    calls_today         => $self->{calls_today},
                    external_hangup     => 0,
                    external_status     => '',
                    external_pause      => '',
                    external_dial       => '',
                    last_state_change   => $NOW_TIME,
                    random_id           => random(),
                    });
            } else {
                ### Update vicidial Closer Log 
                my $vclog = Vicidial::CloserLog->new({
                    uniqueid        => $self->{uniqueid},
                    });
                    
                $vclog->update({
                    status      => 'INCALL',
                    user        => $self->{user},
                    comments    => 'AUTO',
                    list_id     => $vl->{list_id},
                    user_group  => $user_group,
                    });
                    
                $self->update({
                    status              => 'INCALL',
                    last_call_time      => $NOW_TIME,
                    calls_today         => $self->{calls_today},
                    external_hangup     => 0,
                    external_status     => '',
                    external_pause      => '',
                    external_dial       => '',
                    last_state_change   => $NOW_TIME,
                    random_id           => random(),
                    comments            => 'INBOUND',
                    });

            }
            ### Update Vicidial Agent Log
            my $al = Vicidial::AgentLog->load({
                agent_log_id    => $self->{agent_log_id},
                columns         => ['wait_epoch','wait_sec'],
                });
            $al->update({
                wait_sec    => $StarTtimE - $al->{wait_epoch} + $al->{wait_sec},
                talk_epoch  => $StarTtimE,
                lead_id     => $self->{lead_id},
                });
        } elsif ($self->{status} eq 'INCALL') {
            my $ac = Vicidial::AutoCall->new({
                callerid    => $self->{callerid}
                });
            if ($ac->exists) {
                $ac->update({
                    last_update_time    => $NOW_TIME,
                    });
            } else {
                ### find whether the agent log record has already logged DEAD
                my $al = Vicidial::AgentLog->load({
                    agent_log_id    => $self->{agent_log_id},
                    columns         => ['dead_epoch'],
                    });
                if (defined $al->{dead_epoch} && $al->{dead_epoch} < 10000) {
                    $al->update({
                        dead_epoch  => $StarTtimE,
                        });
                    $self->update({
                        random_id           => random(),
                        last_state_change   => $NOW_TIME,
                        });
                }
            } 
        } else {
            $self->update({
                random_id           => random(),
                });
        }
        
        sleep 1;
    }
        
    return;
}
sub status {
    my $self = shift;

    if (!defined $self->{status}) {
        $self->get_status;
    }

    return $self->{status};
}

sub hangup {
    my $self = shift;
    
    #### Set time variables 
    my $StarTtimE   = time;
    my $CIDdate     = cid_date($StarTtimE);
    my $NOW_TIME    = now_time($StarTtimE);
    my $tsNOW_TIME  = tsnow_time($StarTtimE);
    #### End of time variables setting
    
    my $user_abb = substr ( "$self->{user}" x 4, -4);
    my $queryCID = "HLvdcW" . $StarTtimE . $user_abb;
    
    Vicidial::Manager->command({
    uniqueid        => '',
    entry_date      => $NOW_TIME,
    status          => 'NEW',
    response        => 'N',
    server_ip       => $self->{server_ip},
    channel         => '',
    action          => 'Hangup',
    callerid        => $queryCID,
    cmd_line_b      => 'Channel: ' . $self->{channel},
    cmd_line_c      => '',
    cmd_line_d      => '',
    cmd_line_e      => '',
    cmd_line_f      => '',
    cmd_line_g      => '',
    cmd_line_h      => '',
    cmd_line_i      => '',
    cmd_line_j      => '',
    cmd_line_k      => '',
    });


    if ($self->{comments} eq 'MANUAL' or $self->{comments} eq 'AUTO') {
        ### it is manual dialed call
        my $log = Vicidial::Log->load({
            uniqueid    => $self->{uniqueid},
            columns     => [qw(start_epoch)],
            });
        ##### update the duration and end time in the vicidial_log table
        $log->update({
            term_reason     => 'AGENT', 
            end_epoch       => $StarTtimE,
            length_in_sec   => ($StarTtimE - $log->{start_epoch}),
            status          => 'DISPO',
            });
    } else {
        ### Incoming call
        my $log = Vicidial::CloserLog->load({
            uniqueid    => $self->{uniqueid},
            columns     => [qw(start_epoch)],
            });
        ##### update the duration and end time in the vicidial_closer_log table
        $log->update({
            term_reason     => 'AGENT', 
            end_epoch       => $StarTtimE,
            length_in_sec   => ($StarTtimE - $log->{start_epoch}),
            status          => 'DISPO',
            });
    }
    ### Update vicidial live agent record
    $self->update({
        status              => 'PAUSED',
        call_server_ip      => '',
        last_call_finish    => $NOW_TIME,
        comments            => '',
        last_state_change   => $NOW_TIME,
        });
}

sub dispo {
    my ($self, $args) = @_;
    
    if ($self->{comments} eq 'MANUAL' or $self->{comments} eq 'AUTO') {
        ### it is manual dialed call
        my $log = Vicidial::Log->new({
             uniqueid => $self->{uniqueid},
        });
        $log->update({
            status   => $args->{dispo_code},
            });
    } else {
        my $log = Vicidial::CloserLog->new({
             uniqueid => $self->{uniqueid},
        });
        $log->update({
            status   => $args->{dispo_code},
            });
    }

    ### Update vicidial live agent record
    $self->update({
        status              => 'PAUSED',
        last_state_change   => now_time(time),
        lead_id             => 0,
        uniqueid            => '',
        callerid            => '',
        channel             => '',
        });
}

sub disposition {
    my $self = shift;
    
    #### Set time variables 
    my $StarTtimE   = time;
    my $NOW_TIME    = now_time($StarTtimE);
    #### End of time variables setting
    
    #Read campaign data
    my $campaign = Vicidial::Campaign->load({
        campaign_id => $self->{campaign_id},
        columns     => [qw(auto_dial_level use_campaign_dnc use_internal_dnc)],
        });
    my $user = Vicidial::User->load({
	user	=> $self->{user},
	columns	=> [qw(user_group)],
	});
    
    ### reset the API fields in vicidial_live_agents record
    $self->update({
        lead_id                         => 0,
        external_hangup                 => 0,
        external_status                 => '',
        external_update_fields          => '0',
        external_update_fields_data     => '',
        external_timer_action_seconds   => '-1',
        external_dtmf                   => '',
        external_transferconf           => '',
        external_park                   => '',
        last_state_change               => $NOW_TIME,
        });
        
    if (!$campaign->{auto_dial_level}) {
        $self->update({
            status      => 'PAUSED',
            callerid    => '',
        });
    }
    
    my $vl = Vicidial::List->new({
        lead_id     => $self->{lead_id},
        });
    $vl->update({
        status      => $args->{dispo_code},
        user        => $self->{user},
        });
    
    ### сначала надо понять мы покупаем или продаем
    #SELECT campaign_id,closecallid,xfercallid from vicidial_closer_log where uniqueid='$uniqueid' and user='$user' order by call_date desc limit 1
    my $closerlog = Vicidial::CloserLog->load({
            uniqueid    => $self->{uniqueid},
            user        => $self->{user},
            columns     => [qw(campaign_id)],
        },
        {   
            order       => 'ORDER BY call_date DESC LIMIT 1',
        });
    my $ingroup = Vicidial::InboundGroup->new({ group_id    => $closerlog->{campaign_id} });
    
    if ($ingroup->exists) {
        # Это был входящиий вызов
        my $vclog = Vicidial::CloserLog->new({
            user    => $self->{user},
            lead_id => $self->{lead_id},
            });
        $vclog->update({
            status  => $args->{dispo_code},
        });
        
        my $vlia = Vicidial::LiveInboundAgent->new({
            group_id    => $closerlog->{campaign_id},
            user        => $self->{user},
            });
        $vlia->update({
            last_call_finish    => $NOW_TIME,
        });
        
    } else {
        # Это был исходящий вызов
        if ( (!$campaign->{auto_dial_level}) or ($self->{callerid} =~ /^M/) ) {
            # Manual dialed call
            my $vlog = Vicidial::Log->new({
                uniqueid    => $self->{uniqueid},
                });
            if ($vlog->exists) {
                $vlog->update({
                    status  => $args->{dispo_code},
                    });
            } else {
                my $user = Vicidial::User->load({
                        user    => $self->{user},
                        columns => ['user_group'],
                    });
                my $list = Vicidial::List->load({
                    lead_id     => $self->{lead_id},
                    columns     => ['list_id','phone_number','phone_code','alt_phone','address3'],
                    });
                my $vl = Vicidial::Log->new({
                    uniqueid        => $StarTtimE . '.' . substr(sprintf("%010s", $self->{lead_id}), -9),
                    lead_id         => $self->{lead_id},
                    list_id         => $list->{list_id},
                    campaign_id     => $self->{campaign_id},
                    call_date       => $NOW_TIME,
                    start_epoch     => $StarTtimE,
                    end_epoch       => $StarTtimE,
                    length_in_sec   => 0,
                    status          => $args->{dispo_code},
                    phone_code      => $list->{phone_code},
                    phone_number    => $list->{phone_number},
                    user            => $self->{user},
                    comments        => 'MANUAL',
                    processed       => 'N',
                    user_group      => $user->{user_group},
                    term_reason     => 'AGENT',
                    alt_dial        => $list->{alt_phone},
                });
                
                $vl->add;
            }
            ##### insert log into vicidial_log_extended for manual VICIDiaL call
            ## INSERT IGNORE ON DUPLICATE KEY UPDATE server_ip='$server_ip',call_date='$NOW_TIME',lead_id='$lead_id',caller_code='$MDnextCID'
            my $vle = Vicidial::LogExtended->add({
                uniqueid        => $StarTtimE . '.' . substr(sprintf("%010s", $self->{lead_id}), -9),
                server_ip       => $self->{server_ip},
                call_date       => $NOW_TIME,
                lead_id         => $self->{lead_id},
                caller_code     => $self->{callerid},
                custom_call_id  => '', 
                });
                
            # Delete call record from vicidial_auto_calls
            my $call = Vicidial::AutoCall->new({
                callerid        => $self->{callerid},
                });
            $call->delete;
                
            $self->update({
                ring_callerid   => '',
                });
                
            my $val = Vicidial::AgentLog->add({
                user        => $self->{user},
                server_ip   => $self->{server_ip},
                event_time  => $NOW_TIME,
                campaign_id => $self->{campaign_id},
                pause_epoch => $StarTtimE,
                pause_sec   => 0,
                wait_epoch  => $StarTtimE,
                user_group  => $user->{user_group},
                lead_id     => $self->{lead_id},
                });

            $self->update({
                agent_log_id    => $val->{agent_log_id},
                });
        } else {
            # Automatic dialed call
            my $vlog = Vicidial::Log->new({
                uniqueid    => $self->{uniqueid},
                });
            $vlog->update({
                status  => $args->{dispo_code},
                });
        }
        
        # Check if dispo_code is of DNC kind
        my $vs = Vicidial::Status->new({
                status  => $args->{dispo_code},
                dnc     => 'Y',
                });
        if ($vs->exists) {
                $vl = Vicidial::List->load({
                        lead_id     => $self->{lead_id},
                        });
            if ($campaign->{use_internal_dnc} eq 'Y') {                
                    my $dnc = Vicidial::DNC->new({
                        phone_number    => $vl->{phone_number},
                        });
                    $dnc->add;
                }
            if ($campaign->{use_campaign_dnc} eq 'Y') {
                    my $dnc = Vicidial::CampaignDNC->new({
                        phone_number    => $vl->{phone_number},
                        campaign_id     => $self->{campaign_id},
                        });
                    $dnc->add;
            }
        }
            
        ## "select dispo_epoch,dispo_sec,talk_epoch,wait_epoch,lead_id,comments,agent_log_id from vicidial_agent_log where agent_log_id <='$agent_log_id' and lead_id='$lead_id' order by agent_log_id desc limit 1;"
        my $val = Vicidial::AgentLog->load({
                agent_log_id    => $self->{agent_log_id},
                columns         => ['dispo_epoch','dispo_sec','talk_epoch','wait_epoch','lead_id','comments','wait_sec'],
                });
             
        $val->update({
                dispo_sec   => $StarTtimE - $val->{dispo_epoch} + $val->{dispo_sec},
                status      => $args->{dispo_code},
                uniqueid    => $self->{uniqueid},
                wait_sec    => (defined $al->{talk_epoch})  ? $al->{talk_epoch} - $al->{wait_epoch} : $al->{wait_sec},
                dispo_epoch => (defined $al->{dispo_epoch}) ? $StarTtimE : $al->{dispo_epoch},
                dispo_sec   => (defined $al->{dispo_epoch}) ? $StarTtimE - $al->{dispo_epoch} + $al->{dispo_sec} : $StarTtimE - $al->{talk_epoch} + $al->{dispo_sec},
                });
            
        my $campaign = Vicidial::Campaign->new({
                campaign_id     => $self->{campaign_id},
                });
            
        $campaign->update({
                campaign_calldate   => $NOW_TIME,
                });
        }    
}

1;

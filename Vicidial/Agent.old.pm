#!/usr/bin/perl
package Vicidial::Agent;
use Vicidial;
@ISA = ('Vicidial');
use strict;
use warnings;
use Carp;
use Vicidial::Conference;

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	return $self;
}

sub login {
	my ($self, $args) = @_;
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
		croak "Mandatory parameter is missing!";
	}
	### End of input arguments checking
	
	####################################################################
	my $VD_login = $args->{username};
	my $VD_password = $args->{password};
	my $VD_campaign = $args->{campaign};
	my $phone_login = $args->{phone_login};
	my $phone_passwd = $args->{phone_passwd};
	my $ip = $args->{ip};
	my $browser = $args->{browser};	
	#####################################################################
	
	my $dbh = $self->db_connect;

	### Read user data 
	my $agent = user_read($dbh,$VD_login, $VD_password);
	if (!defined $agent) {
		croack "Invalid username or password";
	}

	### Read campaign settings from database
	my $campaign = campaign_read($dbh,$campaign_id);
	### Read phone settings from database
	my $phone = phone_read($dbh,$phone_login, $phone_passwd);

	### Set additional phone data
	$phone->{SIP_user} = $phone->{protocol} . '/' . $phone->{extension};
	my $SIP_user_DiaL = $phone->{protocol} . '/' . $phone->{extension};
	my $TEMP_SIP_user_DiaL = ($phone->{on_hook_agent} eq 'Y') ? 'Local/8300@default' : $SIP_user_DiaL;

	#### Set time variables used later
	my $StarTtimE = time;

	my $CIDdate = sprintf '%02d%02d%02d%02d%02d%02d',
			sub {$_[5],$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($StarTtimE));

	my $NOW_TIME = sprintf '%04d-%02d-%02d %02d:%02d:%02d', 
			sub {$_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($StarTtimE));
			
	my $tsNOW_TIME = sprintf '%04d%02d%02d%02d%02d%02d',
			sub {$_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0]}->(localtime($StarTtimE));
	#### End of time variables setting

	### Grab free vicidial conference
	my $meetme = new Vicidial::Conference({
			extension 	=> $phone->{SIP_user},
			server_ip	=> $phone->{server_ip}
			});
	my $session_id = $meetme->get_conf_exten;
	
	### set the callerID for manager middleware-app to connect the phone to the user
	my $SIqueryCID = "S$CIDdate$session_id";

	### Clear data in case last time agent was disconnected incorrectly
	my $vlERIaffected_rows  = vd_list_mark_eri($dbh,$VD_login);
	my $vhICaffected_rows   = hopper_clear($dbh,$VD_login);
	my $vlaLIaffected_rows  = live_agent_remove($dbh,$VD_login);
	my $vliaLIaffected_rows = live_inbound_agent_remove($dbh,$VD_login);
	my $vul_data = "$vlERIaffected_rows|$vhICaffected_rows|$vlaLIaffected_rows|$vliaLIaffected_rows";

	### Add record to  user log
	user_log_write($dbh,
                $VD_login,
                $VD_campaign,
                $NOW_TIME,
                $StarTtimE,
                $agent->{user_group},
                $session_id,
                $phone->{server_ip},
                $SIP_user_DiaL,
                $ip,$browser,
                $vul_data
                );
	### Connect agent phone
	phone_ring($dbh,
        $NOW_TIME,
        $phone->{server_ip},
        $SIqueryCID, 
        $campaign->{campaign_cid}, 
        $TEMP_SIP_user_DiaL,
        $phone->{ext_context}, 
        $session_id);

	my $random = (int(rand(9000000)) + 11000000);

	### Get user stats if he has already worked today in this campaign
	my $campaign_agent = campaign_agent_read($dbh, $VD_login, $VD_campaign);
	
	### Init stats if has not
	if (!defined $campaign_agent) {
        $campaign_agent = {
            user            => $VD_login,
            campaign_id     => $VD_campaign,
            campaign_weight => '0',
			calls_today     => '0',
			campaign_grade  => '1',
        };
        campaign_agent_write( $dbh, $campaign_agent);
	}

	### Init live agent 
    if ($campaign->{auto_dial_level} > 0) {
        my $closer_chooser_string='';
                live_agent_add($dbh,
                        $VD_login,
                        $phone->{server_ip},
                        $session_id,
                        $phone->{SIP_user},
                        'PAUSED',
                        '',
                        $VD_campaign,
                        '',
                        '',
                        '',
                        $random,
                        $NOW_TIME,
                        $tsNOW_TIME,
                        $NOW_TIME,
                        '$closer_chooser_string',
                        $agent->{user_level},
                        $campaign_agent->{campaign_weight},
                        $campaign_agent->{calls_today},
                        $NOW_TIME,
                        'Y',
                        'N',
                        $phone->{phone_ring_timeout},
                        $phone->{on_hook_agent},
                        $NOW_TIME,
                        $NOW_TIME,
                        $campaign_agent->{campaign_grade},
                        );
    } else {
            live_agent_add($dbh,
                        $VD_login,
                        $phone->{server_ip},
                        $session_id,
                        $phone->{SIP_user},
                        'PAUSED',
                        '',
                        $VD_campaign,
                        '',
                        '',
                        '',
                        $random,
                        $NOW_TIME,
                        $tsNOW_TIME,
                        $NOW_TIME,
                        $agent->{user_level},
                        $campaign_agent->{campaign_weight},
                        $campaign_agent->{calls_today},
                        $NOW_TIME,
                        'N',
                        'N',
                        $phone->{phone_ring_timeout},
                        $phone->{on_hook_agent},
                        $campaign_agent->{campaign_grade}
                        );
    }


	### Add record to agent log
	my $agent_log_id = agent_log_write($dbh,
                $VD_login,
                $phone->{server_ip},
                $NOW_TIME,
				$VD_campaign,
                $StarTtimE,
                0,
                $StarTtimE,
                $agent->{user_group},
                'LOGIN',
                );
	##### update vicidial_campaigns to show agent has logged in
	campaign_update($dbh,$VD_campaign,{campaign_logindate => $NOW_TIME});

	### Add agent log id to live agent setttings
	live_agent_update($dbh,$VD_login,{agent_log_id => $agent_log_id});

	user_update($dbh,$VD_login,{shift_override_flag => '0'});

	#Agent logged in (possibly)

	
	return 1;
}

sub agent_log_write {
        my $dbh = shift;
        my ($user,$server_ip,$event_time,$campaign_id,$pause_epoch,$pause_sec,$wait_epoch,$user_group,$sub_status) = @_;
        my $sth = $dbh->prepare_cached(
"INSERT INTO vicidial_agent_log (user,server_ip,event_time,campaign_id,pause_epoch,pause_sec,wait_epoch,user_group,sub_status) values(?,?,?,?,?,?,?,?,?)"
                );
        $sth->execute($user,$server_ip,$event_time,$campaign_id,$pause_epoch,$pause_sec,$wait_epoch,$user_group,$sub_status);

        return $dbh->last_insert_id(undef,undef,'vicidial_agent_log',undef);
}

sub campaign_read {
        my $dbh = shift;
        my $campaign_id = shift;

        my $sth = $dbh->prepare_cached(
"SELECT park_ext,park_file_name,web_form_address,allow_closers,auto_dial_level,dial_timeout,dial_prefix,campaign_cid,campaign_vdad_exten,campaign_rec_exten,campaign_recording,campaign_rec_filename,campaign_script,get_call_launch,am_message_exten,xferconf_a_dtmf,xferconf_a_number,xferconf_b_dtmf,xferconf_b_number,alt_number_dialing,scheduled_callbacks,wrapup_seconds,wrapup_message,closer_campaigns,use_internal_dnc,allcalls_delay,omit_phone_code,agent_pause_codes_active,no_hopper_leads_logins,campaign_allow_inbound,manual_dial_list_id,default_xfer_group,xfer_groups,disable_alter_custphone,display_queue_count,manual_dial_filter,agent_clipboard_copy,use_campaign_dnc,three_way_call_cid,dial_method,three_way_dial_prefix,web_form_target,vtiger_screen_login,agent_allow_group_alias,default_group_alias,quick_transfer_button,prepopulate_transfer_preset,view_calls_in_queue,view_calls_in_queue_launch,call_requeue_button,pause_after_each_call,no_hopper_dialing,agent_dial_owner_only,agent_display_dialable_leads,web_form_address_two,agent_select_territories,crm_popup_login,crm_login_address,timer_action,timer_action_message,timer_action_seconds,start_call_url,dispo_call_url,xferconf_c_number,xferconf_d_number,xferconf_e_number,use_custom_cid,scheduled_callbacks_alert,scheduled_callbacks_count,manual_dial_override,blind_monitor_warning,blind_monitor_message,blind_monitor_filename,timer_action_destination,enable_xfer_presets,hide_xfer_number_to_dial,manual_dial_prefix,customer_3way_hangup_logging,customer_3way_hangup_seconds,customer_3way_hangup_action,ivr_park_call,manual_preview_dial,api_manual_dial,manual_dial_call_time_check,my_callback_option,per_call_notes,agent_lead_search,agent_lead_search_method,queuemetrics_phone_environment,auto_pause_precall,auto_pause_precall_code,auto_resume_precall,manual_dial_cid,custom_3way_button_transfer,callback_days_limit,disable_dispo_screen,disable_dispo_status,screen_labels,status_display_fields,pllb_grouping,pllb_grouping_limit,in_group_dial,in_group_dial_select FROM vicidial_campaigns where campaign_id = ?"
                );
        $sth->execute($campaign_id);
        my $row = $sth->fetchrow_hashref('NAME_lc');

        return $row;
}

sub campaign_update {
        my $dbh = shift;
        my ($campaign_id, $attr) = @_;

        my $set = '';
        foreach (keys %$attr) {
                $set .= ($set ne '') ? ', ' : '';
                $set .= $_ . ' = ' . $dbh->quote($attr->{$_});
        }

        my $sth = $dbh->prepare_cached(
"UPDATE vicidial_campaigns SET " . $set . " WHERE campaign_id = ?"
                );
        $sth->execute($campaign_id);
        $sth->finish;

        return $sth->rows;
}

sub campaign_agent_read {
        my $dbh = shift;
        my ($user, $campaign_id) = @_;

        my $sth = $dbh->prepare_cached(
"SELECT campaign_weight,calls_today,campaign_grade FROM vicidial_campaign_agents where user= ? and campaign_id = ?"
                );
        $sth->execute($user, $campaign_id);
        my $campaign_agent = $sth->fetchrow_hashref('NAME_lc');

        return $campaign_agent;
}

sub campaign_agent_write {
        my $dbh = shift;
        my $ca = shift;

        my $sth = $dbh->prepare_cached(
"INSERT INTO vicidial_campaign_agents (user,campaign_id,campaign_rank,campaign_weight,calls_today,campaign_grade) VALUES (?,?,?,?,?,?)"
                );
        $sth->execute(
                $ca->{user},
                $ca->{campaign_id},
                '0',
                $ca->{campaign_weight},
                $ca->{calls_today},
                $ca->{campaign_grade},
                );
        $sth->finish;
}

sub conference_allocate {
        my $dbh = shift;
        my ($extension, $server_ip) = @_;
        my $conf_exten = conference_is_allocated($dbh, $extension, $server_ip);

        if (!defined $conf_exten) {
                my $sth = $dbh->prepare_cached(
"UPDATE vicidial_conferences set extension= ?, leave_3way='0' where server_ip= ? and ((extension = '') or (extension is null)) limit 1"
                );
                $sth->execute($extension,$server_ip);
                if ($sth->rows) {
                        $conf_exten = confernce_is_allocated($dbh, $extension, $server_ip);
                }
        }


        return $conf_exten;
}

sub conference_is_allocated {
        my $dbh = shift;
        my ($extension, $server_ip) = @_;
        my $conf_exten;

        my $sth = $dbh->prepare_cached(
"SELECT conf_exten from vicidial_conferences where extension = ? and server_ip = ?"
                );
        $sth->execute($extension,$server_ip);
        $sth->bind_columns(\$conf_exten);
        $sth->fetch;

        return $conf_exten;
}

sub hopper_clear {
        my $dbh = shift;
        my $user = shift;

        my $sth = $dbh->prepare_cached(
"DELETE FROM vicidial_hopper where status IN('QUEUE','INCALL','DONE') and user = ?"
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

sub live_agent_add {
        my $dbh = shift;
        my ($user,$server_ip,$conf_exten,$extension,$status,$lead_id,$campaign_id,$uniqueid,$callerid,$channel,$random_id,$last_call_time,$last_update_time,$last_call_finish,$closer_campaigns,$user_level,$campaign_weight,$calls_today,$last_state_change,$outbound_autodial,$manager_ingroup_set,$on_hook_ring_time,$on_hook_agent,$last_inbound_call_time,$last_inbound_call_finish,$campaign_grade) = @_;
        my $sth = $dbh->prepare_cached(
"INSERT INTO vicidial_live_agents (user,server_ip,conf_exten,extension,status,lead_id,campaign_id,uniqueid,callerid,channel,random_id,last_call_time,last_update_time,last_call_finish,closer_campaigns,user_level,campaign_weight,calls_today,last_state_change,outbound_autodial,manager_ingroup_set,on_hook_ring_time,on_hook_agent,last_inbound_call_time,last_inbound_call_finish,campaign_grade) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
                );
        print "Phone server ip = $server_ip\n";

        $sth->execute($user,$server_ip,$conf_exten,$extension,$status,$lead_id,$campaign_id,$uniqueid,$callerid,$channel,$random_id,$last_call_time,$last_update_time,$last_call_finish,$closer_campaigns,$user_level,$campaign_weight,$calls_today,$last_state_change,$outbound_autodial,$manager_ingroup_set,$on_hook_ring_time,$on_hook_agent,$last_inbound_call_time,$last_inbound_call_finish,$campaign_grade);
        $sth->finish;

        return $sth->rows;
}

sub live_agent_remove {
        my $dbh = shift;
        my $user = shift;

        my $sth = $dbh->prepare_cached(
"DELETE from vicidial_live_agents where user = ?"
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

sub live_agent_update {
        my $dbh = shift;
        my ($user, $attr) = @_;

        my $set = '';
        foreach (keys %$attr) {
                $set .= ($set ne '') ? ', ' : '';
                $set .= $_ . ' = ' . $dbh->quote($attr->{$_});
        }

        my $sth = $dbh->prepare_cached(
"UPDATE vicidial_live_agents SET " . $set . " WHERE user = ?"
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

sub live_inbound_agent_remove {
        my $dbh = shift;
        my $user = shift;

        my $sth = $dbh->prepare_cached(
"DELETE from vicidial_live_inbound_agents where user = ?"
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

sub phone_read {
        my $dbh = shift;
        my ($login, $passwd) = @_;

        my $sth = $dbh->prepare_cached(
"SELECT extension,dialplan_number,voicemail_id,phone_ip,computer_ip,server_ip,login,pass,status,active,phone_type,fullname,company,picture,messages,old_messages,protocol,local_gmt,ASTmgrUSERNAME,ASTmgrSECRET,login_user,login_pass,login_campaign,park_on_extension,conf_on_extension,VICIDIAL_park_on_extension,VICIDIAL_park_on_filename,monitor_prefix,recording_exten,voicemail_exten,voicemail_dump_exten,ext_context,dtmf_send_extension,call_out_number_group,client_browser,install_directory,local_web_callerID_URL,VICIDIAL_web_URL,AGI_call_logging_enabled,user_switching_enabled,conferencing_enabled,admin_hangup_enabled,admin_hijack_enabled,admin_monitor_enabled,call_parking_enabled,updater_check_enabled,AFLogging_enabled,QUEUE_ACTION_enabled,CallerID_popup_enabled,voicemail_button_enabled,enable_fast_refresh,fast_refresh_rate,enable_persistant_mysql,auto_dial_next_number,VDstop_rec_after_each_call,DBX_server,DBX_database,DBX_user,DBX_pass,DBX_port,DBY_server,DBY_database,DBY_user,DBY_pass,DBY_port,outbound_cid,enable_sipsak_messages,email,template_id,conf_override,phone_context,phone_ring_timeout,conf_secret,is_webphone,use_external_server_ip,codecs_list,webphone_dialpad,phone_ring_timeout,on_hook_agent,webphone_auto_answer FROM phones WHERE login = ? and pass = ? and active = 'Y'"
                );
        $sth->execute($login, $passwd);
        my $row = $sth->fetchrow_hashref('NAME_lc');

        return $row;
}

sub phone_ring {
        my $dbh = shift;
        my ($entry_date, $server_ip, $callerid_name, $callerid_num, $channel, $ext_context, $session_id) = @_; 
        my $sth = $dbh->prepare_cached(
"INSERT INTO vicidial_manager VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
                );

        $sth->execute(
                '',                                                                                                                     # man_id
                '',                                                                                                                     # uniqueid
                $entry_date,                                                                                            # entry_date
                'NEW',                                                                                                          # status
                'N',                                                                                                            # response
                $server_ip,                                                                                                     # server ip
                '',                                                                                                                     # channel
                'Originate',                                                                                            # action
                $callerid_name,                                                                                         # callerid
                "Channel: $channel",                                                                            # cmd_line_b
                "Context: $ext_context",                                                                        # cmd_line_c
                "Exten: $session_id",                                                                           # cmd_line_d
                'Priority: 1',                                                                                          # cmd_line_e
                "Callerid: \"$callerid_name\" <$callerid_num>",                         # cmd_line_f
                '',                                                                                                                     # cmd_line_g
                '',                                                                                                                     # cmd_line_h
                '',                                                                                                                     # cmd_line_i
                '',                                                                                                                     # cmd_line_j
                '',                                                                                                                     # cmd_line_k
                );
        $sth->finish;

        return $sth->rows
}

sub user_read {
        my $dbh = shift;
        my ($user, $pass) = @_;
        my $sth = $dbh->prepare_cached(
"SELECT full_name,user_level,hotkeys_active,agent_choose_ingroups,scheduled_callbacks,agentonly_callbacks,agentcall_manual,vicidial_recording,vicidial_transfers,closer_default_blended,user_group,vicidial_recording_override,alter_custphone_override,alert_enabled,agent_shift_enforcement_override,shift_override_flag,allow_alerts,closer_campaigns,agent_choose_territories,custom_one,custom_two,custom_three,custom_four,custom_five,agent_call_log_view_override,agent_choose_blended,agent_lead_search_override,preset_contact_search from vicidial_users where user= ? and pass= ?"
                );

        $sth->execute($user, $pass);
        my $row = $sth->fetchrow_hashref('NAME_lc');

        return $row;
}

sub user_update {
        my $dbh = shift;
        my ($user, $attr) = @_;

        my $set = '';
        foreach (keys %$attr) {
                $set .= ($set ne '') ? ', ' : '';
                $set .= $_ . ' = ' . $dbh->quote($attr->{$_});
        }

        my $sth = $dbh->prepare_cached(
"UPDATE vicidial_users SET " . $set . " WHERE user = ?"
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

sub user_log_write {
        my $dbh = shift;
        my ($user, $event, $campaign_id, $event_date, $event_epoch, $user_group, $session_id, $server_ip, $extension, $computer_ip, $browser, $data) = @_;

        my $sth = $dbh->prepare_cached(
"INSERT INTO vicidial_user_log (user,event,campaign_id,event_date,event_epoch,user_group,session_id,server_ip,extension,computer_ip,browser,data) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)"
                );
        $sth->execute(
                $user,
                $event,
                $campaign_id,
                $event_date,
                $event_epoch,                                               
                $user_group,
                $session_id,
                $server_ip,
                $extension,
                $computer_ip,
                $browser,
                $data,
                );
        $sth->finish;

        return $sth->rows;
}

sub vd_list_mark_eri {
        my $dbh = shift;
        my $user = shift;

        my $sth = $dbh->prepare_cached(
"UPDATE vicidial_list set status = 'ERI', user = '' where status IN('QUEUE','INCALL') and user = ? "
                );
        $sth->execute($user);
        $sth->finish;

        return $sth->rows;
}

1;
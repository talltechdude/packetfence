package pf::services::manager::radiusd_child;

=head1 NAME

pf::services::manager::radiusd_child

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd_child

Used to create the childs of the submanager radiusd
The first manager will create the config for all radiusd processes through the global variable.

=cut

use strict;
use warnings;

use List::MoreUtils qw(any uniq);
use Moo;
use NetAddr::IP;
use Template;
use Data::Dumper;
use File::Slurp qw(write_file);

use pfconfig::cached_array;
use pfconfig::cached_hash;

use pf::authentication;
use pf::cluster;
use pf::util;
use Socket;

use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_error);

use pf::file_paths qw(
    $conf_dir
    $install_dir
    $var_dir
);

use pf::config qw(
    %Config
    $management_network
    %ConfigDomain
    %ConfigRealm
    @ConfigOrderedRealm
    $local_secret
    @radius_ints
    %ConfigAuthenticationLdap
    %ConfigEAP
);

tie my @cli_switches, 'pfconfig::cached_array', 'resource::cli_switches';

extends 'pf::services::manager';

has options => (is => 'rw');

sub _build_executable {
    my ($self) = @_;
    require pf::config;
    return $pf::config::Config{'services'}{"radiusd_binary"};
}


sub _cmdLine { 
    my $self = shift;
    $self->executable . " -d $install_dir/raddb";
}

sub _cmdLineArgs {
    my $self = shift;
    return " -n " . $self->options . " -fm ";
}

our $CONFIG_GENERATED = 0;

=head2 generateConfig

Generate the configuration for ALL radiusd childs
Executed once for ALL processes

=cut

sub generateConfig {
    my ($self, $quick) = @_;

    unless($CONFIG_GENERATED){
        $self->_generateConfig();

        $CONFIG_GENERATED = 1;
    }
}

=head2 _generateConfig

Generate the configuration files for radiusd processes

=cut

sub _generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(
        ABSOLUTE => 1,
        FILTERS  => { escape_string => \&escape_freeradius_string },
    );
    $self->generate_radiusd_mainconf();
    $self->generate_radiusd_authconf($tt);
    $self->generate_radiusd_acctconf($tt);
    $self->generate_radiusd_eapconf($tt);
    $self->generate_radiusd_restconf();
    $self->generate_radiusd_sqlconf();
    $self->generate_radiusd_sitesconf($tt);
    $self->generate_radiusd_proxy();
    $self->generate_radiusd_cluster($tt);
    $self->generate_radiusd_cliconf($tt);
    $self->generate_radiusd_eduroamconf($tt);
    $self->generate_radiusd_ldap($tt);
    $self->generate_radiusd_mschap($tt);
    $self->generate_multi_domain_constants();
}


=head2 generate_radiusd_sitesconf
Generates the packetfence and packetfence-tunnel configuration file
=cut

sub generate_radiusd_sitesconf {
    my ($self, $tt) = @_;
    my %tags;

    $tags{'remote'} = "";
    $tags{'authorize_eap_choice'} = "";
    $tags{'authentication_auth_type'} = "";
    $tags{'authorize_eap_choice_degraded'} = "";
    $tags{'authentication_auth_type_degraded'} = "";

    generate_eap_choice(\$tags{'authorize_eap_choice'}, \$tags{'authentication_auth_type'});

    generate_eap_choice(\$tags{'authorize_eap_choice_degraded'}, \$tags{'authentication_auth_type_degraded'}, "eap-degraded");

    if(isenabled($Config{radius_configuration}{record_accounting_in_sql})){
        $tags{'accounting_sql'} = "sql";
    }
    else {
        $tags{'accounting_sql'} = "# sql not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_authorize})){
        $tags{'authorize_filter'} .= <<"EOT";
        rest

EOT
    }
    else {
        $tags{'authorize_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_pre_proxy})){
        $tags{'pre_proxy_filter'} = "rest";
    }
    else {
        $tags{'pre_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_post_proxy})){
        $tags{'post_proxy_filter'} = "rest";
    }
    else {
        $tags{'post_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_preacct})){
        $tags{'preacct_filter'} = "rest";
    }
    else {
        $tags{'preacct_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }

    $tags{'local_realm'} = '';
    my @realms;
    foreach my $realm ( @pf::config::ConfigOrderedRealm ) {
        if (isenabled($pf::config::ConfigRealm{$realm}->{'radius_auth_compute_in_pf'})) {
            if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                push (@realms, "Realm =~ /$pf::config::ConfigRealm{$realm}->{'regex'}/");
            } else {
                push (@realms, "Realm == \"$realm\"");
            }
        }
    }
    if (@realms) {
        $tags{'local_realm'} .= '        if ( ';
        $tags{'local_realm'} .=  join(' || ', @realms);
        $tags{'local_realm'} .= ' ) {'."\n";
        $tags{'local_realm'} .= <<"EOT";
            rest
        }
EOT
    }

    # Remote config

    if (pf::cluster::isSlaveMode()) {

        $tags{'remote'} = "YES";
        $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');

        $tags{'members'} = '';
        $tags{'config'} ='';
        my $i = 0;
        my $radius_remote = pf::cluster::getDBMaster();

        $tags{'members'} .= <<"EOT";
home_server pf.remote {
        type = auth+acct
        ipaddr = $radius_remote
        src_ipaddr = $tags{'management_ip'}
        port = 1812
        secret = $local_secret
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
EOT
            $tags{'home_server'} .= <<"EOT";
        home_server =  pf.remote
EOT
    }

    $tags{proxy_pfacct} = isenabled($Config{services}{pfacct});

    $tt->process("$conf_dir/radiusd/packetfence", \%tags, "$install_dir/raddb/sites-enabled/packetfence") or die $tt->error();

    %tags = ();

    if(isenabled($Config{advanced}{disable_pf_domain_auth})){
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because explicitly disabled in pf.conf';
    }
    elsif(keys %ConfigDomain){
        $tags{'multi_domain'} = 'packetfence-multi-domain';
    }
    else {
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because no domains configured';
    }
    if(isenabled($Config{radius_configuration}{'filter_in_packetfence-tunnel_authorize'})){
        $tags{'authorize_filter'} = "rest";
    }
    else {
        $tags{'authorize_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{ntlm_redis_cache})) {
        my $username_prefix = "NTHASH:%{%{PacketFence-Domain}:-''}";
        $tags{'redis_ntlm_cache_fetch'} = <<EOT
if(User-Name =~ /^host\\//) {
    update {
        &control:NT-Password := "%{redis_ntlm:GET $username_prefix:%{tolower:%{%{mschap:User-Name}:-None}}}"
    }
}
else {
    update {
        &control:NT-Password := "%{redis_ntlm:GET $username_prefix:%{tolower:%{%{Stripped-User-Name}:-%{%{User-Name}:-None}}}}"
    }
}
EOT
    }
    else {
        $tags{'redis_ntlm_cache_fetch'} = "# redis-ntlm-cache disabled in configuration"
    }

    $tags{'userPrincipalName'} = '';
    my $flag = $TRUE;
    foreach my $realm ( @pf::config::ConfigOrderedRealm ) {
        if (isenabled($pf::config::ConfigRealm{$realm}->{'permit_custom_attributes'}) && (scalar @{$ConfigAuthenticationLdap{$pf::config::ConfigRealm{$realm}->{ldap_source}}->{searchattributes}})) {
            if ($flag) {
                $tags{'userPrincipalName'} .= <<"EOT";
        update control {
            Cache-Status-Only = 'yes'
        }
        userprincipalname
        if (notfound) {
EOT
            }
            $flag = $FALSE;
            if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                $tags{'userPrincipalName'} .= "            if (Realm =~ /$pf::config::ConfigRealm{$realm}->{'regex'}/) {";
            } else {
                $tags{'userPrincipalName'} .= "            if (Realm == \"$realm\") {";
            }
            $tags{'userPrincipalName'} .= <<"EOT";

                $pf::config::ConfigRealm{$realm}->{ldap_source}
            }
EOT
        }
    }
    if ($flag == $FALSE) {
        $tags{'userPrincipalName'} .= <<"EOT";
        }
        userprincipalname
EOT
    }

    $tags{'authorize_eap_choice'} = "";
    $tags{'authentication_auth_type'} = "";

    generate_eap_choice(\$tags{'authorize_eap_choice'}, \$tags{'authentication_auth_type'});

    $tags{'authorize_ldap_choice'} = "";
    $tags{'authentication_ldap_auth_type'} = "";
    $tags{'edir_configuration'} = "";

    generate_ldap_choice(\$tags{'authorize_ldap_choice'}, \$tags{'authentication_ldap_auth_type'}, \$tags{'edir_configuration'});

    $tags{'oauth2_if_enabled'} = (any { $_->{azuread_source_ttls_pap} } values(%ConfigRealm)) ? "oauth2" : "#oauth2 is not in use by any realm";

    $tags{'local_auth_if_enabled'} = isenabled($Config{radius_configuration}{local_auth}) ? "packetfence-local-auth" : "# packetfence-local-auth is not enabled in the configuration";

    $tt->process("$conf_dir/radiusd/packetfence-tunnel", \%tags, "$install_dir/raddb/sites-enabled/packetfence-tunnel") or die $tt->error();

    %tags = ();
    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence-cli";
    $tt->process("$conf_dir/radiusd/packetfence-cli", \%tags, "$install_dir/raddb/sites-enabled/packetfence-cli") or die $tt->error();

}


=head2 generate_radiusd_mainconf
Generates the radiusd.conf configuration file
=cut

sub generate_radiusd_mainconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/radiusd.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'arch'} = `uname -m` eq "x86_64" ? "64" : "";
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/radiusd.conf", "$install_dir/raddb/radiusd.conf" );
    parse_template( \%tags, "$conf_dir/radiusd/radiusd_loadbalancer.conf", "$install_dir/raddb/radiusd_loadbalancer.conf" );
    parse_template( \%tags, "$conf_dir/radiusd/radiusd_cli.conf", "$install_dir/raddb/radiusd_cli.conf" );
}

sub generate_radiusd_restconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/rest.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/rest.conf", "$install_dir/raddb/mods-enabled/rest" );
}

sub generate_radiusd_authconf {
    my ($self, $tt) = @_;
    my %tags;
    my @listen_ips;
    if ($cluster_enabled) {
        my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        push @listen_ips, $ip;

    } else {
        foreach my $interface ( uniq(@radius_ints) ) {
            my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
            push @listen_ips, $ip;
        }
    }

    $tags{'virtual_server'} = "packetfence";
    if (pf::cluster::isSlaveMode()) {
        $tags{'virtual_server'} = "pf-remote";
    }

    $tags{'listen_ips'} = [uniq @listen_ips];
    $tags{'pid_file'} = "$var_dir/run/radiusd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd.sock";
    $tt->process("$conf_dir/radiusd/auth.conf", \%tags, "$install_dir/raddb/auth.conf") or die $tt->error();
}

sub generate_radiusd_acctconf {
    my ($self, $tt) = @_;
    my %tags;
    my @listen_ips;
    if ($cluster_enabled) {
        my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        push @listen_ips, $ip;

    } else {
        foreach my $interface ( uniq(@radius_ints) ) {
            my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
            push @listen_ips, $ip;
        }
    }

    $tags{'listen_ips'} = [uniq @listen_ips];
    $tags{'pid_file'} = "$var_dir/run/radiusd-acct.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-acct.sock";
    $tt->process("$conf_dir/radiusd/acct.conf", \%tags, "$install_dir/raddb/acct.conf") or die $tt->error();
}

sub generate_radiusd_eduroamconf {
    my ($self) = @_;
    my %tags;
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        $tags{'template'}    = "$conf_dir/radiusd/eduroam.conf";
        if ($cluster_enabled) {
            my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
            $tags{'listen'} .= << "EOT";
listen {
    ipaddr = $ip
    port =  $eduroam_authentication_source[0]{'auth_listening_port'}
    type = auth
    virtual_server = eduroam
}

EOT
        } else {
            foreach my $interface ( uniq(@radius_ints) ) {
                my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
                $tags{'listen'} .= <<"EOT";
listen {
    ipaddr = $ip
    port =  $eduroam_authentication_source[0]{'auth_listening_port'}
    type = auth
    virtual_server = eduroam
}

EOT
            }
        }
        $tags{'pid_file'} = "$var_dir/run/radiusd-eduroam.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-eduroam.sock";
        parse_template( \%tags, $tags{template}, "$install_dir/raddb/eduroam.conf" );

        # Eduroam configuration
        %tags = ();
        $tags{'template'} = "$conf_dir/raddb/sites-available/eduroam";
        $tags{'local_realm'} = '';
        $tags{'local_realm_exception'} = '';
        $tags{'eduroam_post_auth'} = '';
        $tags{'local_realm_acct'} = '        if (User-Name =~ /@/) {';
        my $found_acct = $FALSE;
        my @realms;
        $tags{'local_realm'} .= << "EOT";
            update control {
                Proxy-To-Realm := "eduroam"
            }
EOT
        foreach my $realm ( @{$eduroam_authentication_source[0]{'local_realm'}} ) {
            if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} ) {
                if (isenabled($pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth_compute_in_pf'})) {
                    push (@realms, "Realm == \"eduroam.$realm\"");
                }
                if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                    $tags{'local_realm'} .= '            if ( "Realm =~ /"'.$pf::config::ConfigRealm{$realm}->{'regex'}.'"/" ) {'."\n";
                } else {
                    $tags{'local_realm'} .= '            if ( Realm == "'.$realm.'" ) {'."\n";
                }
                $tags{'local_realm'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "eduroam.$realm"
                }
            }
EOT
            }
            if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'} ) {
                $found_acct = $TRUE;
                if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                    $tags{'local_realm_acct'} .= '            if ( "Realm =~ /"'.$pf::config::ConfigRealm{$realm}->{'regex'}.'"/" ) {'."\n";
                } else {
                    $tags{'local_realm_acct'} .= '            if ( Realm == "'.$realm.'" ) {'."\n";
                }
                $tags{'local_realm_acct'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "eduroam.$realm"
                }
            }
EOT
            }
        }
        my @local_realms;
        foreach my $realm ( @{$eduroam_authentication_source[0]{'local_realm'}} ) {
            if (!$pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} ) {
                 if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                     push (@local_realms, "Realm =~ /$pf::config::ConfigRealm{$realm}->{'regex'}/");
                 } else {
                     push (@local_realms, "Realm == \"$realm\"");
                 }
            }
        }
        if (@local_realms) {
            $tags{'local_realm'} .= '            if ( ';
            $tags{'local_realm'} .=  join(' || ', @local_realms);
            $tags{'local_realm'} .= ' ) {'."\n";
            $tags{'local_realm'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "packetfence"
                }
            }
EOT
            $tags{'local_realm_exception'} .= '            if ( ';
            $tags{'local_realm_exception'} .=  join(' || ', @local_realms);
            $tags{'local_realm_exception'} .= ' ) {'."\n";
            $tags{'local_realm_exception'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "packetfence"
                }
            } else {
                reject
            }
EOT
        } else {
            $tags{'local_realm_exception'} .= '            reject';
        }
        if ($found_acct) {
            $tags{'local_realm_acct'} .= '        }';
        } else {
            $tags{'local_realm_acct'} = '';
        }
        $tags{'reject_realm'} = '';
        my @reject_realms;
        foreach my $reject_realm ( @{$eduroam_authentication_source[0]{'reject_realm'}} ) {
                 if (defined $pf::config::ConfigRealm{$reject_realm}->{'regex'} && $pf::config::ConfigRealm{$reject_realm}->{'regex'} ne '') {
                     push (@reject_realms, "Realm =~ /$pf::config::ConfigRealm{$reject_realm}->{'regex'}/");
                 } else {
                     push (@reject_realms, "Realm == \"$reject_realm\"");
                 }
        }
        if (@reject_realms) {
            $tags{'reject_realm'} .= '            if ( ';
            $tags{'reject_realm'} .=  join(' || ', @reject_realms);
            $tags{'reject_realm'} .= ' ) {'."\n";
            $tags{'reject_realm'} .= <<"EOT";
                reject
            }
EOT
        }
        if (@realms) {
            $tags{'eduroam_post_auth'} .= '        if ( ';
            $tags{'eduroam_post_auth'} .=  join(' || ', @realms);
            $tags{'eduroam_post_auth'} .= ' ) {'."\n";
            $tags{'eduroam_post_auth'} .= <<"EOT";
                update request {
                        Realm := "eduroam"
                }
        }
EOT
        }
        $tags{'authentication_auth_type'} = "";
        $tags{'authorize_eap_choice'} = "";

        generate_eap_choice(\$tags{'authorize_eap_choice'}, \$tags{'authentication_auth_type'});

        if(isenabled($Config{radius_configuration}{filter_in_eduroam_authorize})){
        $tags{'authorize_filter'} .= <<"EOT";
        rest

EOT
        }
        else {
            $tags{'authorize_filter'} = "# filter not activated because explicitly disabled in pf.conf";
        }
        if(isenabled($Config{radius_configuration}{filter_in_eduroam_pre_proxy})){
            $tags{'pre_proxy_filter'} = "rest";
        }
        else {
            $tags{'pre_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
        }
        if(isenabled($Config{radius_configuration}{filter_in_eduroam_post_proxy})){
            $tags{'post_proxy_filter'} = "rest";
        }
        else {
            $tags{'post_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
        }
        if(isenabled($Config{radius_configuration}{filter_in_eduroam_preacct})){
            $tags{'preacct_filter'} = "rest";
        }
        else {
            $tags{'preacct_filter'} = "# filter not activated because explicitly disabled in pf.conf";
        }
        parse_template( \%tags, "$conf_dir/radiusd/eduroam", "$install_dir/raddb/sites-available/eduroam" );
        symlink("$install_dir/raddb/sites-available/eduroam", "$install_dir/raddb/sites-enabled/eduroam");

        %tags = ();
        my $server1_address = $eduroam_authentication_source[0]{'server1_address'};
        my $server2_address = $eduroam_authentication_source[0]{'server2_address'};
        my $radius_secret = $eduroam_authentication_source[0]{'radius_secret'};
        my $virtual_server = "packetfence";
        if ($cluster_enabled) {
            $virtual_server = "pf.cluster";
        }
            $tags{'config'} .= <<"EOT";
client eduroam_tlrs_server_1 {
        ipaddr = $server1_address
        secret = $radius_secret
        shortname = eduroam_tlrs1
        virtual_server = $virtual_server
}

client eduroam_tlrs_server_2 {
        ipaddr = $server2_address
        secret = $radius_secret
        shortname = eduroam_tlrs2
        virtual_server = $virtual_server
}

EOT
    } else {
        $tags{'config'} = "# Eduroam integration is not configured";
        unlink("$install_dir/raddb/sites-enabled/eduroam");
        unlink("$install_dir/raddb/sites-available/eduroam");
        unlink("$install_dir/raddb/eduroam.conf");
    }
    # Ensure raddb/clients.eduroam.conf.inc exists. radiusd won't start otherwise.
    $tags{'template'} = "$conf_dir/radiusd/clients.eduroam.conf.inc";
    parse_template( \%tags, "$conf_dir/radiusd/clients.eduroam.conf.inc", "$install_dir/raddb/clients.eduroam.conf.inc" );
}

sub generate_radiusd_cliconf {
    my ($self) = @_;
    my %tags;
    if (@cli_switches > 0) {
        $tags{'template'}    = "$conf_dir/radiusd/cli.conf";
        if ($cluster_enabled) {
            my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');

$tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $ip
        port = 1815
        type = auth
        virtual_server = packetfence-cli
        limit {
              max_connections = 16
              lifetime = 0
              idle_timeout = 60
        }
}

EOT
        } else {
            foreach my $interface ( uniq(@radius_ints) ) {
                my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
                $tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $ip
        port = 1815
        type = auth
        virtual_server = packetfence-cli
}

EOT
            }
        }
        $tags{'pid_file'} = "$var_dir/run/radiusd-cli.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-cli.sock";
        parse_template( \%tags, $tags{template}, "$install_dir/raddb/cli.conf" );
    } else {
        my $file = $install_dir."/raddb/cli.conf";
        unlink($file);
    }
}

=head2 generate_radiusd_eapconf

Generates the eap.conf configuration file

=cut

sub generate_radiusd_eapconf {
    my ($self, $tt) = @_;
    my $radius_configuration = $Config{radius_configuration};
    my %vars;
    $vars{'eap'} = \%ConfigEAP;
    $tt->process("$conf_dir/radiusd/eap.conf", \%vars, "$install_dir/raddb/mods-enabled/eap") or die $tt->error();
}

=head2 generate_radiusd_sqlconf

Generates the sql.conf configuration file

=cut

sub generate_radiusd_sqlconf {
   my %tags;
   $tags{'template'}    = "$conf_dir/radiusd/sql.conf";
   $tags{'install_dir'} = $install_dir;
   $tags{'db_host'} = $Config{'database'}{'host'};
   $tags{'db_port'} = $Config{'database'}{'port'};
   $tags{'db_database'} = $Config{'database'}{'db'};
   $tags{'db_username'} = $Config{'database'}{'user'};
   $tags{'db_password'} = $Config{'database'}{'pass'};
   for my $k (qw(db_username db_password)) {
      $tags{$k} = escape_freeradius_string($tags{$k});
   }

    parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/mods-enabled/sql" );
}

=head2 escape_freeradius_string

escape_freeradius_string

=cut

sub escape_freeradius_string {
    my ($s) = @_;
    $s =~ s/"/\\"/g;
    return $s;
}

=head2 generate_radiusd_ldap

Generates the ldap_packetfence configuration file

=cut

sub generate_radiusd_ldap {
    my ($self, $tt) = @_;

    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/ldap_packetfence.conf";
    $tags{'install_dir'} = $install_dir;
    my $ldap_config = $FALSE;
    foreach my $ldap (keys %ConfigAuthenticationLdap) {
        my $active = $FALSE;
        foreach my $realm ( @pf::config::ConfigOrderedRealm ) {
            if (defined($pf::config::ConfigRealm{$realm}->{ldap_source}) && ($pf::config::ConfigRealm{$realm}->{ldap_source} eq $ldap) ) {
                $active = $TRUE;
            }
            elsif (defined($pf::config::ConfigRealm{$realm}->{ldap_source_ttls_pap}) && ($pf::config::ConfigRealm{$realm}->{ldap_source_ttls_pap} eq $ldap) ) {
                $active = $TRUE;
            }
        }
        next unless $active;
        my $searchattributes = '';
        my $edir_options;
        if ($ConfigAuthenticationLdap{$ldap}->{type} eq 'EDIR') {
            $edir_options .= << "EOT";

    # Enable Novell eDirectory support
    edir = yes
    edir_account_policy_check = yes
    #
    # eDirectory attribute for Universal Password
    password_attribute = nspmPassword

EOT
        } else {
            $edir_options = '';
        }

        if (scalar @{$ConfigAuthenticationLdap{$ldap}->{searchattributes}}) {
            foreach my $searchattribute (@{$ConfigAuthenticationLdap{$ldap}->{searchattributes}}) {
                $searchattributes .= '('.$searchattribute.'=%{User-Name})('.$searchattribute.'=%{Stripped-User-Name})';
            }
        }
        $ldap_config = $TRUE;
        my $server_list;
        my @ldap_server = @{$ConfigAuthenticationLdap{$ldap}->{host}};
        foreach my $ldap_server (@ldap_server) {
            $server_list .= "    server          = $ldap_server\n";
        }
        my $append = '';
        if (defined($ConfigAuthenticationLdap{$ldap}->{append_to_searchattributes})) {
            $append = $ConfigAuthenticationLdap{$ldap}->{append_to_searchattributes};
        }
        $tags{'servers'} .= <<"EOT";

ldap $ldap {
$server_list
    port            = "$ConfigAuthenticationLdap{$ldap}->{port}"
    identity        = "$ConfigAuthenticationLdap{$ldap}->{binddn}"
    password        = "$ConfigAuthenticationLdap{$ldap}->{password}"
    base_dn         = "$ConfigAuthenticationLdap{$ldap}->{basedn}"
    filter          = "(userPrincipalName=%{User-Name})"
    scope           = "$ConfigAuthenticationLdap{$ldap}->{scope}"
    base_filter     = "(objectclass=user)"
    rebind          = "yes"
    chase_referrals = "yes"
$edir_options

    update {
        control:AD-Samaccountname := 'sAMAccountName'
        request:PacketFence-UserNameAttribute := "$ConfigAuthenticationLdap{$ldap}->{usernameattribute}"
    }
    user {
        base_dn = "\${..base_dn}"
        filter = "(&(|$searchattributes($ConfigAuthenticationLdap{$ldap}->{usernameattribute}=%{%{Stripped-User-Name}:-%{User-Name}}))$append)"
    }
    options {
        chase_referrals = yes
        rebind = yes
    }
    pool {
        start = 0
    }
EOT

        my $client_auth = "";
        if($ConfigAuthenticationLdap{$ldap}{client_cert_file} && $ConfigAuthenticationLdap{$ldap}{client_key_file}) {
            $client_auth = <<"EOT";
        certificate_file = $ConfigAuthenticationLdap{$ldap}{client_cert_file}
        private_key_file = $ConfigAuthenticationLdap{$ldap}{client_key_file}
EOT
        }

        if ($ConfigAuthenticationLdap{$ldap}->{encryption} eq "ssl") {
            $tags{'servers'} .= <<"EOT";
    tls {
        start_tls = no
       require_cert    = 'allow'
       $client_auth
    }
EOT
        } elsif ($ConfigAuthenticationLdap{$ldap}->{encryption} eq "starttls") {
            $tags{'servers'} .= <<"EOT";
    tls {
        start_tls = yes
       require_cert    = 'allow'
       $client_auth
    }
EOT
        }
            $tags{'servers'} .= <<"EOT";
}

EOT

    }
    if ($ldap_config) {
        parse_template( \%tags, "$conf_dir/radiusd/ldap_packetfence.conf", "$install_dir/raddb/mods-enabled/ldap_packetfence" );
    } else {
        unlink("$install_dir/raddb/mods-enabled/ldap_packetfence");
    }
}

=head2 generate_radiusd_proxy

Generates the proxy.conf.inc configuration file

=cut

sub generate_radiusd_proxy {
    my %tags;

    $tags{'template'} = "$conf_dir/radiusd/proxy.conf.inc";
    $tags{'install_dir'} = $install_dir;
    $tags{'config'} = '';
    $tags{'radius_sources'} = '';
    my @radius_sources;

    foreach my $realm ( @pf::config::ConfigOrderedRealm ) {
        my $options = $pf::config::ConfigRealm{$realm}->{'options'} || '';
        my $real_realm;
        if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
            $real_realm = "\"~".$pf::config::ConfigRealm{$realm}->{'regex'}."\"";
        } else {
            $real_realm = $realm;
        }
        $tags{'config'} .= <<"EOT";
realm $real_realm {
$options
EOT
        if ($pf::config::ConfigRealm{$realm}->{azuread_source_ttls_pap}) {
            my $source = getAuthenticationSource($pf::config::ConfigRealm{$realm}->{azuread_source_ttls_pap});
            my $client_id = $source->client_id;
            my $client_secret = $source->client_secret;
            $tags{'config'} .= <<"EOT";
oauth2 {
    discovery = "https://login.microsoftonline.com/%{Realm}/v2.0"
    client_id = "$client_id"
    client_secret = "$client_secret"
    cache_password = yes
}
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_auth'} ) {
            $tags{'config'} .= <<"EOT";
auth_pool = auth_pool_$realm
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
acct_pool = acct_pool_$realm
EOT
        }
        if($pf::config::ConfigRealm{$realm}->{'radius_auth'} || $pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
}
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_auth'} ) {
            $tags{'config'} .= <<"EOT";
home_server_pool auth_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'radius_auth_proxy_type'}
EOT
            push(@radius_sources, split(',',$pf::config::ConfigRealm{$realm}->{'radius_auth'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'radius_auth'})) {
                if (pf::authentication::getAuthenticationSource($radius)->{'type'} eq "Eduroam") {
                    $tags{'config'} .= <<"EOT";
home_server = eduroam_server1
home_server = eduroam_server2
EOT
                } else {
                $tags{'config'} .= <<"EOT";
home_server = $radius
EOT
                }
            }
            $tags{'config'} .= <<"EOT";
}
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";

home_server_pool acct_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'radius_acct_proxy_type'}
EOT
            push(@radius_sources,split(',',$pf::config::ConfigRealm{$realm}->{'radius_acct'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'radius_acct'})) {

                $tags{'config'} .= <<"EOT";
home_server = $radius
EOT
            }
            $tags{'config'} .= <<"EOT";
}
EOT
        }
         if(!$pf::config::ConfigRealm{$realm}->{'radius_auth'} && !$pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
}
EOT
        }
        # Generate Eduroam realms config
    my $eduroam_options = $pf::config::ConfigRealm{$realm}->{'eduroam_options'} || '';
        $tags{'eduroam_config'} .= <<"EOT";
realm eduroam.$realm {
$eduroam_options
EOT
        if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} ) {
            $tags{'eduroam_config'} .= <<"EOT";
auth_pool = eduroam_auth_pool_$realm
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'}) {
            $tags{'eduroam_config'} .= <<"EOT";
acct_pool = eduroam_acct_pool_$realm
EOT
        }
        if($pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} || $pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'}) {
            $tags{'eduroam_config'} .= <<"EOT";
}

EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} ) {
            $tags{'eduroam_config'} .= <<"EOT";
home_server_pool eduroam_auth_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth_proxy_type'}
EOT
            push(@radius_sources, split(',',$pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'})) {

                $tags{'eduroam_config'} .= <<"EOT";
home_server = $radius
EOT
            }
            $tags{'eduroam_config'} .= <<"EOT";
}

EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'}) {
            $tags{'eduroam_config'} .= <<"EOT";
home_server_pool eduroam_acct_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct_proxy_type'}
EOT
            push(@radius_sources,split(',',$pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'})) {

                $tags{'eduroam_config'} .= <<"EOT";
home_server = $radius
EOT
            }
            $tags{'eduroam_config'} .= <<"EOT";
}

EOT
        }
         if(!$pf::config::ConfigRealm{$realm}->{'eduroam_radius_auth'} && !$pf::config::ConfigRealm{$realm}->{'eduroam_radius_acct'}) {
            $tags{'eduroam_config'} .= <<"EOT";
}

EOT
        }
    }
    foreach my $radius (uniq @radius_sources) {
        my $source = pf::authentication::getAuthenticationSource($radius);
        next if ($source->{'type'} eq "Eduroam");
        my @addresses = gethostbyname($source->{'host'});
        my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
        my $src_ip = pf::util::find_outgoing_srcip($ips[0]);
        $source->{'options'} =~ s/\$src_ip/$src_ip/;
        $tags{'radius_sources'} .= <<"EOT";

home_server $radius {
ipaddr = $source->{'host'}
port = $source->{'port'}
secret = $source->{'secret'}
$source->{'options'}
}

EOT
    }
    # Eduroam configuration
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my $server1_address = $eduroam_authentication_source[0]{'server1_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server1_port = $eduroam_authentication_source[0]{'server1_port'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server2_address = $eduroam_authentication_source[0]{'server2_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server2_port = $eduroam_authentication_source[0]{'server2_port'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $radius_secret = $eduroam_authentication_source[0]{'radius_secret'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)

        $tags{'eduroam'} = <<"EOT";
# Eduroam integration

realm eduroam {
    auth_pool = eduroam_auth_pool
    nostrip
}
home_server_pool eduroam_auth_pool {
    home_server = eduroam_server1
    home_server = eduroam_server2
}
home_server eduroam_server1 {
    type = auth
    ipaddr = $server1_address
    port = $server1_port
    secret = '$radius_secret'
}
home_server eduroam_server2 {
    type = auth
    ipaddr = $server2_address
    port = $server2_port
    secret = '$radius_secret'
}
EOT
    } else {
        $tags{'eduroam'} = "# Eduroam integration is not configured";
    }

    if(isenabled($Config{services}{pfacct})) {
        my $management_ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        $tags{'pfacct'} = <<"EOT";
# pfacct configuration

realm pfacct {
    acct_pool = pfacct_pool
    nostrip
}

home_server_pool pfacct_pool {
    home_server = pfacct_local
}

home_server pfacct_local {
    type = acct
    ipaddr = 127.0.0.1
    port = 1813
    secret = '$local_secret'
    src_ipaddr = $management_ip
}

EOT
    }
    else {
        $tags{'pfacct'} = "# pfacct is not enabled";
    }

    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.inc", "$install_dir/raddb/proxy.conf.inc" );

    undef %tags;
    my $real_realm;

    foreach my $realm ( @pf::config::ConfigOrderedRealm ) {
        if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
            $real_realm = "\"".$pf::config::ConfigRealm{$realm}->{'regex'}."\"";
        } else {
            $real_realm = $realm;
        }
        $tags{'config'} .= <<"EOT";
realm $real_realm {
nostrip
}
EOT
    }
    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.loadbalancer", "$install_dir/raddb/proxy.conf.loadbalancer" );

    if(isenabled($Config{radius_configuration}{forward_key_balanced})){
       $tags{'PacketFence-KeyBalanced'} = "PacketFence-KeyBalanced                !* ANY,";
    } else {
        $tags{'PacketFence-KeyBalanced'} = "";
    }

    parse_template( \%tags, "$conf_dir/radiusd/packetfence-pre-proxy", "$install_dir/raddb/mods-config/attr_filter/packetfence-pre-proxy" );
}

=head2 generate_radiusd_cluster

Generates the load balancer configuration

=cut

sub generate_radiusd_cluster {
    my ($self) = @_;
    my %tags;

    my $int = $management_network->{'Tint'};
    my $cfg = $Config{"interface $int"};

    $tags{'members'} = '';
    $tags{'config'} ='';
    $tags{'home_server'} ='';

    if ($cluster_enabled) {
        my $cluster_ip = pf::cluster::management_cluster_ip();
        my @radius_backend = values %{pf::cluster::members_ips($int)};

        # RADIUS PacketFence cluster virtual server configuration
        # raddb/sites-available/packetfence-cluster
        $tags{'template'}    = "$conf_dir/radiusd/packetfence-cluster";
        $tags{'virt_ip'} = $cluster_ip;
        my $i = 0;
        foreach my $radius_back (@radius_backend) {
            next if($radius_back eq $management_network->{Tip} && isdisabled($Config{active_active}{auth_on_management}));
$tags{'members'} .= <<"EOT";
home_server pf$i.cluster {
        type = auth+acct
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = 1812
        secret = $local_secret
        response_window = 6
        status_check = status-server
        check_interval = 20
        num_answers_to_alive = 3
        response_timeouts = 3
        zombie_period = 40
}
home_server pf$i.cli.cluster {
        type = auth
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = 1815
        secret = $local_secret
        response_window = 60
        status_check = status-server
        check_interval = 20
        num_answers_to_alive = 3
        response_timeouts = 3
        zombie_period = 40
}
EOT
            $tags{'home_server'} .= <<"EOT";
        home_server =  pf$i.cluster
EOT
            $tags{'home_server_cli'} .= <<"EOT";
        home_server =  pf$i.cli.cluster
EOT
            $i++;
        }
        parse_template( \%tags, "$conf_dir/radiusd/packetfence-cluster", "$install_dir/raddb/sites-enabled/packetfence-cluster" );


        # RADIUS eduroam cluster virtual server configuration
        # raddb/sites-available/eduroam-cluster
        if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
            my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
            %tags = ();
            $tags{'template'}    = "$conf_dir/radiusd/eduroam-cluster";
            $tags{'virt_ip'} = $cluster_ip;
            my $listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};
            my $i = 0;
            foreach my $radius_back (@radius_backend) {
                next if($radius_back eq $management_network->{Tip} && isdisabled($Config{active_active}{auth_on_management}));
                $tags{'members'} .= <<"EOT";
home_server eduroam$i.cluster {
        type = auth
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = $listening_port
        secret = $local_secret
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
EOT
                $tags{'home_server'} .= <<"EOT";
        home_server =  eduroam$i.cluster
EOT
                $i++;
            }
            $tags{'local_realm'} = '';
            my @realms;
            foreach my $realm ( @{$eduroam_authentication_source[0]{'local_realm'}} ) {
                 if (defined $pf::config::ConfigRealm{$realm}->{'regex'} && $pf::config::ConfigRealm{$realm}->{'regex'} ne '') {
                     push (@realms, "Realm =~ /$pf::config::ConfigRealm{$realm}->{'regex'}/");
                 } else {
                     push (@realms, "Realm == \"$realm\"");
                 }
            }
            if (@realms) {
                $tags{'local_realm'} .= 'if ( ';
                $tags{'local_realm'} .=  join(' || ', @realms);
                $tags{'local_realm'} .= ' ) {'."\n";
                $tags{'local_realm'} .= <<"EOT";
                update control {
                    Load-Balance-Key := "%{Calling-Station-Id}"
                    Proxy-To-Realm := "packetfence"
                }
            } else {
                update control {
                    Load-Balance-Key := "%{Calling-Station-Id}"
                    Proxy-To-Realm := "eduroam.cluster"
                }
            }
EOT
            } else {
$tags{'local_realm'} = << "EOT";
                    update control {
                        Load-Balance-Key := "%{Calling-Station-Id}"
                        Proxy-To-Realm := "eduroam.cluster"
                    }
EOT
            }
            parse_template( \%tags, "$conf_dir/radiusd/eduroam-cluster", "$install_dir/raddb/sites-enabled/eduroam-cluster" );
        } else {
            unlink($install_dir."/raddb/sites-enabled/eduroam-cluster");
        }


        # RADIUS load_balancer instance configuration
        # raddb/load_balancer.conf
        %tags = ();
        $tags{'template'} = "$conf_dir/radiusd/load_balancer.conf";
        $tags{'pid_file'} = "$var_dir/run/radiusd-load_balancer.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-load_balancer.sock";

        foreach my $interface ( uniq(@radius_ints) ) {

            my $cluster_ip = pf::cluster::cluster_ip($interface->{Tint});
            $tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $cluster_ip
        port = 0
        type = auth
        virtual_server = pf.cluster
}


listen {
        ipaddr = $cluster_ip
        port = 0
        type = acct
        virtual_server = pf.cluster
}

listen {
        ipaddr = $cluster_ip
        port = 1815
        type = auth
        virtual_server = pfcli.cluster
}

EOT
        }

        # Eduroam integration
        if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
            my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
            my $listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};
            $tags{'eduroam'} = <<"EOT";
# Eduroam integration
EOT
            foreach my $interface ( uniq(@radius_ints) ) {
                my $cluster_ip = pf::cluster::cluster_ip($interface->{Tint});
                $tags{'eduroam'} .= <<"EOT";
listen {
        ipaddr = $cluster_ip
        port = $listening_port
        type = auth
        virtual_server = eduroam.cluster
}
EOT
            }
        } else {
            $tags{'eduroam'} = "# Eduroam integration is not configured";
        }

        parse_template( \%tags, $tags{'template'}, "$install_dir/raddb/load_balancer.conf");

        
        push @radius_backend, $cluster_ip;
        push @radius_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();

        foreach my $radius_back (uniq(@radius_backend)) {
        $tags{'config'} .= <<"EOT";
client $radius_back {
        ipaddr = $radius_back
        secret = $local_secret
        shortname = pf
}
EOT
        }

    } else {
        my $file = $install_dir."/raddb/sites-enabled/packetfence-cluster";
        unlink($file);
        my $management_ip
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
        $tags{'config'} .= <<"EOT";
client $management_ip {
        ipaddr = $management_ip
        secret = $local_secret
        shortname = pf
}
EOT
    }
    # Ensure raddb/clients.conf.inc exists. radiusd won't start otherwise.
    $tags{'template'} = "$conf_dir/radiusd/clients.conf.inc";
    parse_template( \%tags, "$conf_dir/radiusd/clients.conf.inc", "$install_dir/raddb/clients.conf.inc" );
}

=head2 generate_radiusd_mschap

Generates the mschap configuration file

=cut

sub generate_radiusd_mschap {
    my ($self, $tt) = @_;

    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/mschap.conf";

    $tags{'statsd_port' } = "$Config{'advanced'}{'statsd_listen_port'}";

    parse_template( \%tags, "$conf_dir/radiusd/mschap.conf", "$install_dir/raddb/mods-enabled/mschap" );

}

=head2 generate_eap_choice

Generate the configuration for eap choice

=cut

sub generate_eap_choice {
    my ($authorize_eap_choice, $authentication_auth_type, $suffix) = @_;
    if (!(defined($suffix) && $suffix ne "" )) {
        $suffix = "";
    }
    my $if = 'if';
    foreach my $key ( @pf::config::ConfigOrderedRealm ) {
        next if $pf::config::ConfigRealm{$key}->{'eap'} eq 'default';
        my $choice = $key;
        $choice = $pf::config::ConfigRealm{$key}->{'regex'} if (defined $pf::config::ConfigRealm{$key}->{'regex'} && $pf::config::ConfigRealm{$key}->{'regex'} ne '');
        my $eap = ( defined($pf::config::ConfigRealm{$key}->{'eap'}) && $pf::config::ConfigRealm{$key}->{'eap'} ne '') ? $pf::config::ConfigRealm{$key}->{'eap'} : 'eap';
        $eap = $eap."-".$suffix if ($suffix ne "" && $suffix ne "eap-degraded");
        $$authorize_eap_choice .= <<"EOT";
            $if (Realm =~ /$choice/) {
                $eap {
                    ok = return
                }
            }
EOT
            $if = 'elsif';
    }
    if ($if eq 'elsif') {
        $$authorize_eap_choice .= <<"EOT";
            else {
                eap {
                    ok = return
                }
            }
EOT
    } else {
        my $eap = (defined($suffix) && $suffix ne "" ) ? $suffix : "eap";
        $$authorize_eap_choice .= <<"EOT";
            $eap {
                ok = return
            }
EOT
    }
    foreach my $key (keys %ConfigEAP) {
        next if $key eq 'default';
        $key = $key."-".$suffix if ($suffix ne "");
        $$authentication_auth_type .= <<"EOT";
        Auth-Type $key {
            $key
        }
EOT
    }
    if ($suffix ne "") {
    $$authentication_auth_type .= <<"EOT";
        Auth-Type $suffix {
            $suffix
        }
EOT
    }
}

sub generate_ldap_choice {
    my ($authorize_ldap_choice, $authentication_ldap_auth_type, $edir_configuration) = @_;
    my $if = 'if';
    my $of = 'if';
    my $oauth2_if = 'if';
    my $edir_config = "";
    foreach my $key ( @pf::config::ConfigOrderedRealm ) {
        my $choice = "^$key\$";
        if (defined($pf::config::ConfigRealm{$key}->{azuread_source_ttls_pap}) && exists($pf::config::ConfigRealm{$key}->{azuread_source_ttls_pap})) {
            $choice = $pf::config::ConfigRealm{$key}->{'regex'} if (defined $pf::config::ConfigRealm{$key}->{'regex'} && $pf::config::ConfigRealm{$key}->{'regex'} ne '');
            $$authorize_ldap_choice .= <<"EOT";
        $oauth2_if (Realm =~ /$choice/) {
            oauth2
        }
EOT
            $oauth2_if = 'elsif';
        }

        if (defined($pf::config::ConfigRealm{$key}->{ldap_source_ttls_pap}) && exists($pf::config::ConfigRealm{$key}->{ldap_source_ttls_pap})) {
            $choice = $pf::config::ConfigRealm{$key}->{'regex'} if (defined $pf::config::ConfigRealm{$key}->{'regex'} && $pf::config::ConfigRealm{$key}->{'regex'} ne '');
            $$authorize_ldap_choice .= <<"EOT";
        $if (Realm =~ /$choice/) {
            $pf::config::ConfigRealm{$key}->{'ldap_source_ttls_pap'}
            update control {
                Auth-Type := $pf::config::ConfigRealm{$key}->{'ldap_source_ttls_pap'}
            }
        }
EOT
            $if = 'elsif';
            $$authentication_ldap_auth_type .= <<"EOT";
        Auth-Type $pf::config::ConfigRealm{$key}->{ldap_source_ttls_pap} {
            $pf::config::ConfigRealm{$key}->{ldap_source_ttls_pap}
        }
EOT

        }
        if (defined($pf::config::ConfigRealm{$key}->{edir_source}) && exists($pf::config::ConfigRealm{$key}->{edir_source})) {
            $choice = $pf::config::ConfigRealm{$key}->{'regex'} if (defined $pf::config::ConfigRealm{$key}->{'regex'} && $pf::config::ConfigRealm{$key}->{'regex'} ne '');
            $edir_config .= <<"EOT";
            $of (Realm =~ /$choice/) {
                -$pf::config::ConfigRealm{$key}->{edir_source}
                if (updated) {
                    update control {
                        &MS-CHAP-Use-NTLM-Auth := No
                    }
                }
            }
EOT
            my $of = 'elsif';
        }
    }
    if ($edir_config ne "") {
        $$edir_configuration .= << "EOT"
        update control {
            Cache-Status-Only = 'yes'
        }
        cache_password
        if (ok) {
            update control {
                &MS-CHAP-Use-NTLM-Auth := No
            }
        }
        if (notfound) {
$edir_config
        }
        cache_password
EOT
    }
}

sub generate_multi_domain_constants {
    my $data = {};
    my ($status, $iter) = pf::dal::tenant->search();
    if (is_error($status)) {
        die "Unable to fetch tenants to generate the multi-domain constants";
    }
    for my $tenant (@{$iter->all}) {
        my $tenant_id = $tenant->id;
        pf::config::tenant::set_tenant($tenant_id);
        $data->{$tenant_id} = {
            ConfigRealm => { %ConfigRealm }, 
            ConfigOrderedRealm => [ @ConfigOrderedRealm ],
            ConfigDomain => { %ConfigDomain }, 
        };
    }
    $Data::Dumper::Purity = 1;
    my $content = "package multi_domain_constants;\n\n";
    $content .= "our " . Dumper($data);
    $content .= "our \$DATA = \$VAR1;\n";
    $content .= "1;\n";
    write_file("$install_dir/raddb/mods-config/perl/multi_domain_constants.pm", $content);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;


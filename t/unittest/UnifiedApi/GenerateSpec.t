#!/usr/bin/perl

=head1 NAME

GenerateSpec

=cut

=head1 DESCRIPTION

unit test for GenerateSpec

=cut

use strict;
use warnings;
#

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::UnifiedApi::GenerateSpec;
use pfappserver::Form::Config::Domain;
use pfappserver::Form::Config::Profile;
use pfappserver::Form::Config::Pfdetect::dhcp;
use pfappserver::Form::Config::Pfdetect::fortianalyser;
use pfappserver::Form::Config::Pfdetect::regex;
use pfappserver::Form::Config::Pfdetect::security_onion;
use pfappserver::Form::Config::Pfdetect::snort;
use pfappserver::Form::Config::Pfdetect::suricata_md5;
use pfappserver::Form::Config::Pfdetect::suricata;

use Test::More tests => 4;
use Test::Deep;

#This test will running last
use Test::NoWarnings;

is_deeply(
    pf::UnifiedApi::GenerateSpec::formHandlerToSchema( pfappserver::Form::Config::Domain->new ),
    {
        Domain => {
            type       => 'object',
            properties => {
                id => {
                    type => 'string',
                    description => 'Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain' ,
                },
                workgroup => {
                    type => 'string',
                    description => 'Workgroup',
                },
                ad_server => {
                    type => 'string',
                    description => 'The IP address or DNS name of your Active Directory server' ,
                },
                bind_pass => {
                    type => 'string',
                    description => 'The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.' ,
                },
                bind_dn => {
                    type => 'string',
                    description => 'The username of a Domain Admin to use to join the server to the domain',
                },
                dns_servers => {
                    type => 'string',
                    description => 'The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.',
                },
                server_name => {
                    type => 'string',
                    description => 'This server\'s name (account name) in your Active Directory. \'%h\' is a placeholder for this server hostname. In a cluster, you must use %h and ensure your hostnames are less than 14 characters. You can mix \'%h\' with a prefix or suffix (ex: \'pf-%h\') ',
                },
                sticky_dc => {
                    type => 'string',
                    description => 'This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller',
                },
                dns_name => {
                    type => 'string',
                    description => 'The DNS name (FQDN) of the domain.'
                },
                ou => {
                    type => 'string',
                    description => 'Use a specific OU for the PacketFence account. The OU string read from top to bottom without RDNs and delimited by a \'/\'. E.g. "Computers/Servers/Unix".',
                },
                registration => {
                    type => 'string',
                    description => 'If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.',
                },
                ntlm_cache => {
                    type => 'string',
                    description => 'Should the NTLM cache be enabled for this domain?',
                },
                ntlm_cache_source => {
                    type => 'string',
                    description => 'The source to use to connect to your Active Directory server for NTLM caching.',
                },
                ntlm_cache_expiry => {
                    type => 'integer',
                    description => 'The amount of seconds an entry should be cached.',
                },
                status => {
                    type => 'string',
                    description => 'Enabled',
                },
                ntlmv2_only => {
                    type => 'string',
                    description => 'If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level',
                },
            },
            required => [qw(
                id
                workgroup
                ad_server
                dns_servers
                server_name
                sticky_dc
                dns_name
                ou
            )],
        },
        DomainList => {
            '$ref'     => '#/components/schemas/Iterable',
            type       => 'object',
            properties => {
                items => {
                    'description' => 'List',
                    type    => 'array',
                    'items' => {
                        '$ref' => "#/components/schemas/Domain"
                    }
                }
            },
        },
    },
    "Testing the Domain schema",
);

cmp_deeply(
    pf::UnifiedApi::GenerateSpec::formHandlerToSchema(
        pfappserver::Form::Config::Profile->new
    ),
    {
        Profile => {
            type       => 'object',
            properties => {
                id => {
                    type => 'string',
                    description => 'A profile id can only contain alphanumeric characters, dashes, period and or underscores.',
                },
                'access_registration_when_registered' => {
                    type => 'string',
                    description => 'This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.',
                },
                'advanced_filter' => {
                    type => 'object',
                    description => 'Advanced filter',
                    properties => {
                        'field' => {
                            type => 'string',
                            description => 'Field',
                        },
                        'op' => {
                            type => 'string',
                            description => 'Value',
                        },
                        'value' => {
                            type => 'string',
                            description => 'Value',
                        },
                        'values' => {
                            type => 'array',
                            description => 'Values',
                            items => {
                                type => 'string',
                                description => 'Value',
                            },
                        },
                    },
                },
                'always_use_redirecturl' => {
                    type => 'string',
                    description =>  'Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.',
                },
                'autoregister' => {
                    type => 'string',
                    description => 'This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.',
                },
                'billing_tiers' => {
                    type => 'array',
                    description => 'Billing tiers',
                    items => {
                        type => 'string',
                        description => 'Billing tier',
                    },
                },
                "dot1x_unset_on_unmatch" => {
                    type => 'string',
                    description => "When enabled, PacketFence will unset the role of the device if no authentication sources returned one.",
                },
                'block_interval' => {
                    type => 'object',
                    description => 'The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.',
                    properties => {
                        unit => {
                            type => 'string',
                            description => 'Unit',
                        },
                        interval => {
                            type => 'integer',
                            description => 'Interval',
                        }
                    },
                },
                'description' => {
                    type => 'string',
                    description => 'Profile Description',
                },
                'self_service' => {
                    type => 'string',
                    description => 'Self service',
                },
                unbound_dpsk => {
                    type => 'string',
                    description => 'Unbound dpsk',
                },
                'dot1x_recompute_role_from_portal' => {
                    type => 'string',
                    description => 'When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.',
                },
                'mac_auth_recompute_role_from_portal' => {
                    type => 'string',
                    description => 'When enabled, PacketFence will not use the role initialy computed on the portal but will use an authorized source if defined to recompute the role.',
                },
                'filter' => {
                    type => 'array',
                    description => 'Filters',
                    items => {
                        description => 'Filter',
                        type => 'object',
                        properties => {
                            type => {
                                description => 'Type',
                                type => 'string'
                            },
                            match => {
                                description => 'Match',
                                type => 'string'
                            },
                        }
                    },
                },
                'filter_match_style' => {
                    type => 'string',
                    description => 'Filter match style'
                },
                'locale' => {
                    type => 'array',
                    description => 'Locales',
                    items => {
                        type => 'string',
                        description => 'Locale',
                    }
                },
                'login_attempt_limit' => {
                    type => 'integer',
                    description => 'Limit the number of login attempts. A value of 0 disables the limit.',
                },
                'logo' => {
                    type => 'string',
                    description => 'Logo',
                },
                'preregistration' => {
                    type => 'string',
                    description => 'This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have "Create local account" enabled.',
                },
                'provisioners' => {
                    type => 'array',
                    description => 'Provisioners',
                    items => {
                        type => 'string',
                        description => 'Provisioner',
                    },
                },
                'redirecturl' => {
                    type => 'string',
                    description => 'Default URL to redirect to on registration/mitigation release. This is only used if a per security event redirect URL is not defined.',
                },
                'reuse_dot1x_credentials' => {
                    type => 'string',
                    description => 'This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.'
                },
                'root_module' => {
                    type => 'string',
                    description => 'The Root Portal Module to use',
                },
                'scans' => {
                    type => 'array',
                    description => 'Scans',
                    items => {
                        type => 'string',
                        description => 'Scan',
                    },
                },
                'sms_pin_retry_limit' => {
                    type => 'integer',
                    description => 'Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.',
                },
                'sms_request_limit' => {
                    type => 'integer',
                    description => 'Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit.',
                },
                'sources' => {
                    type => 'array',
                    items => {
                        type => 'string',
                        description => 'Source',
                    },
                    description => 'Sources',
                },
                'default_psk_key' => {
                    type => 'string',
                    description => 'This is the default PSK key when you enable DPSK on this connection profile. The minimum length is eight characters.'
                },
                'dpsk' => {
                    type => 'string',
                    description => 'This enables the Dynamic PSK feature on this connection profile. It means that the RADIUS server will answer requests with specific attributes like the PSK key to use to connect on the SSID.',
                },
                'status' => {
                    type => 'string',
                    description => 'Enable profile',
                },
                'unreg_on_acct_stop' => {
                    type => 'string',
                    description => 'This activates automatic deregistation of devices for the profile if PacketFence receives a RADIUS accounting stop.',
                },
                'vlan_pool_technique' => {
                    type => 'string',
                    'description' => 'The Vlan Pool Technique to use',
                },
                'network_logoff' => {
                    type => 'string',
                    description => 'This allows users to access the network logoff page (http://pf.pfdemo.org/networklogoff) in order to terminate their network access (switch their device back to unregistered)',
                },
                'network_logoff_popup' => {
                    type => 'string',
                    description => 'When the "Network Logoff" feature is enabled, this will have it opened in a popup at the end of the registration process.',
                },
            },
            required => [
                qw(
                  id
                  root_module
                  )
            ],
          },
        ProfileList => {
            '$ref'     => '#/components/schemas/Iterable',
            type       => 'object',
            properties => {
                items => {
                    'description' => 'List',
                    type    => 'array',
                    'items' => {
                        '$ref' => "#/components/schemas/Profile"
                    }
                }
            },
        },
    },
    "Testing the Profile schema",
);

cmp_deeply(
    pf::UnifiedApi::GenerateSpec::subTypesSchema(
        pfappserver::Form::Config::Pfdetect::dhcp->new,
        pfappserver::Form::Config::Pfdetect::fortianalyser->new,
        pfappserver::Form::Config::Pfdetect::security_onion->new,
        pfappserver::Form::Config::Pfdetect::snort->new,
        pfappserver::Form::Config::Pfdetect::suricata_md5->new,
        pfappserver::Form::Config::Pfdetect::suricata->new,
        pfappserver::Form::Config::Pfdetect::regex->new,
    ),
    {
        oneOf         => [
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    'rate_limit' => {
                        type => 'object',
                        description => 'Rate limit requests.',
                        properties => {
                            unit => {
                                type => 'string',
                                description => 'Unit',
                            },
                            interval => {
                                type => 'integer',
                                description => 'Interval',
                            }
                        }
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                },
            },
            {
                type => 'object',
                required => ['id', 'path', 'type'],
                properties => {
                    id => {
                        type => 'string',
                        description => 'Detector',
                    },
                    status => {
                        type => 'string',
                        description => 'Enabled',
                    },
                    type => {
                        type => 'string',
                        description => 'Type',
                    },
                    path => {
                        type => 'string',
                        description => 'Alert pipe',
                    },
                    tenant_id => {
                        type => 'string',
                        description => 'Tenant ID',
                    },
                    rules => {
                        type => 'array',
                        items => {
                            type          => 'object',
                            'description' => 'Rule - New',
                            'properties'  => {
                                'actions'            => {
                                    type => 'array',
                                    description => 'Actions',
                                    items => {
                                        type => 'object',
                                        description => 'Action',
                                        properties => {
                                            api_method => {
                                                type => 'string',
                                                description => 'Api method',
                                            },
                                            api_parameters => {
                                                type => 'string',
                                                description => 'Api parameters',
                                            },
                                        },
                                    },
                                },
                                'rate_limit' => {
                                    type => 'object',
                                    description => 'Rate limit requests.',
                                    properties => {
                                        unit => {
                                            type => 'string',
                                            description => 'Unit',
                                        },
                                        interval => {
                                            type => 'integer',
                                            description => 'Interval',
                                        }
                                    }
                                },
                                'ip_mac_translation' => {
                                    type => 'string',
                                    description => 'Perform automatic translation of IPs to MACs and the other way around',
                                },
                                'last_if_match'      => {
                                    type => 'string',
                                    description => 'Stop processing rules if this rule matches',
                                },
                                'name'               => {
                                    type => 'string',
                                    description => 'Name',
                                },
                                'regex'              => {
                                    type => 'string',
                                    description => 'Regex',
                                },
                            },
                          },
                        description => 'Rules',
                    },
                },
            },
        ],
        discriminator => {
            propertyName => 'type',
        }
    },
    "Testing SubType"
);

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


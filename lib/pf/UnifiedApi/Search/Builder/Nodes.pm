package pf::UnifiedApi::Search::Builder::Nodes;

=head1 NAME

pf::UnifiedApi::Search::Builder::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Nodes

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::Search::Builder);
use pf::dal::node;
use pf::dal::locationlog;
use pf::dal::radacct;
use pf::util qw(clean_mac ip2int valid_ip);
use pf::constants qw($ZERO_DATE);

our @LOCATION_LOG_JOIN = (
    "=>{locationlog.mac=node.mac,node.tenant_id=locationlog.tenant_id,locationlog.end_time='$ZERO_DATE'}",
    "locationlog",
);

our @IP4LOG_JOIN = (
    {
        operator  => '=>',
        condition => {
            'ip4log.ip' => {
                "=" => \
"( SELECT `ip` FROM `ip4log` WHERE `mac` = `node`.`mac` AND `tenant_id` = `node`.`tenant_id`  ORDER BY `start_time` DESC LIMIT 1 )",
            },
            'ip4log.tenant_id' => {
                -ident => 'node.tenant_id'
            },
        }
    },
    'ip4log',
);

our @IP6LOG_JOIN = (
    {
        operator  => '=>',
        condition => {
            'ip6log.ip' => {
                "=" => \
"( SELECT `ip` FROM `ip6log` WHERE `mac` = `node`.`mac` AND `tenant_id` = `node`.`tenant_id`  ORDER BY `start_time` DESC LIMIT 1 )",
            }
        }
    },
    'ip6log',
);

our @ONLINE_JOIN = (
    '=>{node.mac=online.mac,node.tenant_id=online.tenant_id}',
    'bandwidth_accounting|online',
    {
        operator  => '=>',
        condition => [
            -and => [
            'online.node_id' => { '=' => { -ident => '%2$s.node_id' } },
            \"(online.last_updated,online.unique_session_id,online.time_bucket) < (b2.last_updated,b2.unique_session_id,b2.time_bucket)",
            ],
        ],
    },
    'bandwidth_accounting|b2',
);

sub online_join {
    my ($self, $s) = @_;
    return (
        {
            operator  => '=>',
            condition => {
                'node.mac' => { '=' => { -ident => '%2$s.mac' } },
                'online.tenant_id' => $s->{dal}->get_tenant() ,
            },
        },
        'bandwidth_accounting|online',
        {
            operator  => '=>',
            condition => [
                -and => [
                'online.node_id' => { '=' => { -ident => '%2$s.node_id' } },
                \"(online.last_updated,online.unique_session_id,online.time_bucket) < (b2.last_updated,b2.unique_session_id,b2.time_bucket)",
                ],
            ],
        },
        'bandwidth_accounting|b2',
    );
}

our %ONLINE_WHERE = (
    'b2.node_id' => undef,
);

our @NODE_CATEGORY_JOIN = (
    '=>{node.category_id=node_category.category_id}', 'node_category',
);

our @NODE_CATEGORY_ROLE_JOIN = (
    '=>{node.bypass_role_id=node_category_bypass_role.category_id}', 'node_category|node_category_bypass_role',
);

our @SECURITY_EVENT_OPEN_JOIN = (
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.mac' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            'security_event_open.status' => { '=' => "open" },
        },
    },
    'security_event|security_event_open',
);

our @SECURITY_EVENT_CLOSED_JOIN = (
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.mac' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            'security_event_close.status' => { '=' => "closed" },
        },
    },
    'security_event|security_event_close',
);

our %ALLOWED_JOIN_FIELDS = (
    'ip4log.ip' => {
        join_spec     => \@IP4LOG_JOIN,
        column_spec   => make_join_column_spec( 'ip4log', 'ip' ),
        namespace     => 'ip4log',
    },
    'ip6log.ip' => {
        join_spec     => \@IP6LOG_JOIN,
        column_spec   => make_join_column_spec( 'ip6log', 'ip' ),
        namespace     => 'ip6log',
    },
    'online' => {
        namespace     => 'online',
        rewrite_query => \&rewrite_online_query,
        column_spec   => "CASE IFNULL( (SELECT last_updated from bandwidth_accounting as ba WHERE ba.mac = node.mac AND ba.tenant_id = node.tenant_id order by last_updated DESC LIMIT 1), 'unknown') WHEN 'unknown' THEN 'unknown' WHEN '0000-00-00 00:00:00' THEN 'off' ELSE 'on' END|online"
    },
    'node_category.name' => {
        join_spec   => \@NODE_CATEGORY_JOIN,
        namespace   => 'node_category',
        column_spec => \"IFNULL(node_category.name, '') as `node_category.name`",
    },
    'node_category_bypass_role.name' => {
        join_spec   => \@NODE_CATEGORY_ROLE_JOIN,
        namespace   => 'node_category_bypass_role',
        column_spec => \"IFNULL(node_category_bypass_role.name, '') as `node_category_bypass_role.name`",
    },
    map_dal_fields_to_join_spec("pf::dal::locationlog", \@LOCATION_LOG_JOIN, undef, {switch_ip => 1}),
    'locationlog.switch_ip' => {
        join_spec     => \@LOCATION_LOG_JOIN,
        namespace     => 'locationlog',
        rewrite_query => \&rewrite_switch_ip,
        column_spec   => make_join_column_spec( 'locationlog', 'switch_ip' ),
    },
    'security_event.open_count' => {
        namespace => 'security_event_open',
        join_spec => \@SECURITY_EVENT_OPEN_JOIN,
        rewrite_query => \&rewrite_security_event_open_count,
        group_by => 1,
        column_spec => \"COUNT(security_event_open.id) AS `security_event.open_count`",
    },
    'security_event.open_security_event_id' => {
        namespace => 'security_event_open',
        join_spec => \@SECURITY_EVENT_OPEN_JOIN,
        rewrite_query => \&rewrite_security_event_open_security_event_id,
        group_by => 1,
        column_spec => \"GROUP_CONCAT(security_event_open.security_event_id) AS `security_event.open_security_event_id`"
    },
    'security_event.close_count' => {
        namespace => 'security_event_close',
        join_spec => \@SECURITY_EVENT_CLOSED_JOIN,
        rewrite_query => \&rewrite_security_event_close_count,
        group_by => 1,
        column_spec => \"COUNT(security_event_close.id) AS `security_event.close_count`",
    },
    'security_event.close_security_event_id' => {
        namespace => 'security_event_close',
        join_spec => \@SECURITY_EVENT_CLOSED_JOIN,
        rewrite_query => \&rewrite_security_event_close_security_event_id,
        group_by => 1,
        column_spec => \"GROUP_CONCAT(security_event_close.security_event_id) AS `security_event.close_security_event_id`"
    },
    'mac' => {
        rewrite_query => \&rewrite_mac_query,
    }
);

sub rewrite_mac_query {
    my ( $self, $s, $q ) = @_;

    my $value       = $q->{value};
    my $cleaned_mac = clean_mac($value);
    if ( $cleaned_mac ne "0" ) {
        $q->{value} = $cleaned_mac;
    }

    return ( 200, $q );
}

sub non_searchable {
    my ($self, $s, $q) = @_;
    return (422, { message => "$q->{field} is not searchable" });
}

sub rewrite_security_event_open_security_event_id {
    my ($self, $s, $q) = @_;
    $q->{field} = 'security_event_open.security_event_id';
    return (200, $q);
}

sub rewrite_security_event_open_count {
    my ($self, $s, $q) = @_;
    $q->{field} = 'COUNT(security_event_open.id)';
    return (200, $q);
}

sub rewrite_security_event_close_security_event_id {
    my ($self, $s, $q) = @_;
    $q->{field} = 'security_event_close.security_event_id';
    return (200, $q);
}

sub rewrite_security_event_close_count {
    my ($self, $s, $q) = @_;
    $q->{field} = 'COUNT(security_event_close.id)';
    return (200, $q);
}

our $ON_QUERY = "EXISTS (SELECT MAX(last_updated) as last_updated from bandwidth_accounting as ba WHERE ba.mac = node.mac AND ba.tenant_id = node.tenant_id group by ba.last_updated HAVING MAX(last_updated) != '0000-00-00 00:00:00')";
our $OFF_QUERY = "EXISTS (SELECT MAX(last_updated) as last_updated from bandwidth_accounting as ba WHERE ba.mac = node.mac AND ba.tenant_id = node.tenant_id group by ba.last_updated HAVING MAX(last_updated) = '0000-00-00 00:00:00')";
our $NOT_UNKNOWN_QUERY = 'EXISTS (SELECT last_updated from bandwidth_accounting as ba WHERE ba.mac = node.mac AND ba.tenant_id = node.tenant_id order by ba.last_updated DESC LIMIT 1)';
our $UNKNOWN_QUERY = "NOT $NOT_UNKNOWN_QUERY";

sub rewrite_online_query {
    my ($self, $s, $q) = @_;
    my $op =$q->{op};
    if ($op ne 'equals' && $op ne 'not_equals') {
        return (422, { message => "$op is not valid for the online field" });
    }

    my $value = $q->{value};
    if (!defined $value || ($value ne 'on' && $value ne 'off' && $value ne 'unknown')) {
        return (422, { message => "value of " . ($value // "(null)"). " is not valid for the online field" });
    }

    if ($value eq 'unknown') {
        if ($op eq 'equals') {
            return (200, \[$UNKNOWN_QUERY]);
        }

        return (200, \[$NOT_UNKNOWN_QUERY]);
    }

    if ($op eq 'equals') {
        if ($value eq 'on') {
            return (200, \[$ON_QUERY]);
        }

        return (200, \[$OFF_QUERY]);
    }

    if ($value eq 'on') {
        return (200, \["( ($UNKNOWN_QUERY) OR ($OFF_QUERY) )"]);
    }

    return (200, \["( ($UNKNOWN_QUERY) OR ($ON_QUERY) )"]);
}

sub map_dal_fields_to_join_spec {
    my ($dal, $join_spec, $where_spec, $exclude) = @_;
    $exclude //= {};
    my $table = $dal->table;
    return map { map_dal_field_to_join_spec($table, $_,$join_spec, $where_spec) } grep {!exists $exclude->{$_}} @{$dal->table_field_names}; 
}

sub map_dal_field_to_join_spec {
    my ($table, $field, $join_spec, $where_spec) = @_;
    return "${table}.${field}" => {
        join_spec => $join_spec,
        namespace => $table,
        (defined $where_spec ? (where_spec => $where_spec) : () ),
        column_spec => make_join_column_spec($table, $field),
   } 
}

sub make_join_column_spec {
    my ($t, $f) = @_;
    return \"`${t}`.`${f}` AS `${t}.${f}`";
}

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
}

sub rewrite_switch_ip {
    my ($self, $s, $q) = @_;
    if (valid_ip($q->{value})) {
        $q->{value} = ip2int($q->{value});
        $q->{field} = 'locationlog.switch_ip_int';
    }

    return (200, $q);
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


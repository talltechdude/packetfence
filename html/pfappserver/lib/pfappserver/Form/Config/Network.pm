package pfappserver::Form::Config::Network;

=head1 NAME

pfappserver::Form::Interface - Web form for a network

=head1 DESCRIPTION

Form definition to update a default network.

=cut

use pf::util;

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has 'network' => ( is => 'ro' );

has_field 'netmask' => (
    type => 'IPAddress',
    label => 'Netmask',
);

has_field 'type' =>
  (
   type => 'Hidden',
  );

has_field 'description' =>
  (
    type => 'Text',
  );

has_field 'dhcp_start' =>
  (
   type => 'IPAddress',
   label => 'Starting IP Address',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   messages => { required => 'Please specify the starting IP address of the DHCP scope.' },
  );
has_field 'dhcp_end' =>
  (
   type => 'IPAddress',
   label => 'Ending IP Address',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   messages => { required => 'Please specify the ending IP address of the DHCP scope.' },
  );
has_field 'dhcp_default_lease_time' =>
  (
   type => 'PosInteger',
   label => 'Default Lease Time',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   messages => { required => 'Please specify the default DHCP lease time.' },
  );
has_field 'dhcp_max_lease_time' =>
  (
   type => 'PosInteger',
   label => 'Max Lease Time',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   messages => { required => 'Please specify the maximum DHCP lease time.' },
  );
has_field 'algorithm' =>
  (
   type => 'Select',
   label => 'DHCP Algorithm',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   options => [
        { value => $pf::constants::dhcp::RANDOM_ALGORITHM, label => 'Random'},
        { value => $pf::constants::dhcp::OLDEST_RELEASED_ALGORITHM, label => 'Oldest Released'},
   ],
   default => $pf::constants::dhcp::RANDOM_ALGORITHM,
  );
has_field 'pool_backend' =>
  (
   type => 'Select',
   label => 'DHCP Pool Backend Type',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   options => [
        { value => $pf::constants::dhcp::MEMORY_POOL, label => 'Memory Pool'},
        { value => $pf::constants::dhcp::MYSQL_POOL, label => 'MySQL Pool'},
   ],
   default => $pf::constants::dhcp::MEMORY_POOL,
  );
has_field 'ip_reserved' =>
  (
   type => 'TextArea',
   label => 'IP Addresses reserved',
   messages => { required => "Range or IP addresses to exclude from the DHCP pool." },
   tags => { after_element => \&help,
             help => 'Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool' },
  );
has_field 'ip_assigned' =>
  (
   type => 'IPAssigned',
   label => 'IP Addresses assigned',
   messages => { required => "List of MAC:IP statically assigned." },
   tags => {
      after_element => \&help,
      help =>
        'List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13',
      option_pattern => sub {
          {
              message => "A list of MAC:IP couples (example: 00:11:22:33:44:55:192.168.0.12)",
              regex   => "^[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}:\\d{1,3}(.\\d{1,3}){3}(,[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}:\\d{1,3}(.\\d{1,3}){3})*\$"
,
          };
      }
   },
  );
has_field 'dns' =>
  (
   type => 'IPAddresses',
   label => 'DNS Server',
   required_when => { 'dhcpd' => sub { $_[0] eq 'enabled' } },
   messages => { required => "Please specify the DNS server's IP address(es)." },
   tags => { after_element => \&help,
             help => 'Should match the IP of a registration interface or the production DNS server(s) if the network is Inline L2/L3 (space delimited list of IP addresses)' },
  );

has_field 'portal_fqdn' =>
  (
   type => 'Text',
   label => 'Portal FQDN',
   messages => { required => "Please specify the FQDN of the portal." },
   tags => { after_element => \&help,
             help => 'Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server' },
  );

has_field 'netflow_accounting_enabled' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'disabled',
   label => 'Enable Net Flow Accounting'
   );

has_field 'tenant_id' =>
  (
   type => 'Tenant',
   label => 'Tenant for network',
   required => 1,
   );

=head2 validate

Make sure the ending DHCP IP address is after the starting DHCP IP address.

Make sure the max lease time is higher than the default lease time.

=cut

sub validate {
    my $self = shift;

    if ($self->value->{dhcp_start} && $self->value->{dhcp_end}
        && ip2int($self->value->{dhcp_start}) > ip2int($self->value->{dhcp_end})) {
        $self->field('dhcp_end')->add_error('The ending DHCP address must be greater than the starting DHCP address.');
    }
    if ($self->value->{dhcp_default_lease_time} && $self->value->{dhcp_max_lease_time}
        && $self->value->{dhcp_default_lease_time} > $self->value->{dhcp_max_lease_time}) {
        $self->field('dhcp_max_lease_time')->add_error('The maximum lease time must be greater than the default lease time.');
    }
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

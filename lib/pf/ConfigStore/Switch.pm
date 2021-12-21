package pf::ConfigStore::Switch;

=head1 NAME

pf::ConfigStore::Switch add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Switch;

=cut

use Moo;
use namespace::autoclean;
use pf::log;
use pf::file_paths qw($switches_config_file $switches_default_config_file);
use pf::util;
use HTTP::Status qw(:constants is_error is_success);
use List::MoreUtils qw(part any);
use pfconfig::manager;
use pf::freeradius;

extends qw(pf::ConfigStore);

sub configFile { $switches_config_file }

sub importConfigFile { $switches_default_config_file }

sub default_section { 'default' }

sub pfconfigNamespace {'config::Switch'}

our %MappingKey = (
    AccessListMapping => 'accesslist',
    VlanMapping => 'vlan',
    UrlMapping => 'url',
    ControllerRoleMapping => 'controller_role',
);

our %MappingKey2 = (
    AccessListMapping => 'AccessList',
    VlanMapping => 'Vlan',
    UrlMapping => 'Url',
    ControllerRoleMapping => 'Role',
);

=head2 Methods

=over

=cut

=item commit

Repopulate the radius_nas table after commiting

=cut

sub commit {
    my ($self) = @_;
    my ($result, $error) = $self->SUPER::commit();
    pf::log::get_logger->info("commiting via Switch configstore");
    freeradius_populate_nas_config( \%pf::SwitchFactory::SwitchConfig );
    return ($result, $error);
}

=item cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ( $self, $id, $switch ) = @_;

    my $config = $self->cachedConfig;
    # if the uplink attribute is set to dynamic or not set and the group we inherit from is dynamic
    if ( ($switch->{uplink} && $switch->{uplink} eq 'dynamic') ) {
        $switch->{uplink_dynamic} = 'dynamic';
        $switch->{uplink}         = undef;
    } elsif (defined $switch->{uplink_dynamic} && $switch->{uplink_dynamic} eq '0') {
        $switch->{uplink_dynamic} = undef;
    }
    $self->expand_list( $switch, 'inlineTrigger' );
    if ( exists $switch->{inlineTrigger} ) {
        $switch->{inlineTrigger} =
          [ map { _splitInlineTrigger($_) } @{ $switch->{inlineTrigger} } ];
    }

    _expandMapping($switch);
}

sub _expandMapping {
    my ($switch) = @_;
    # Config::Inifiles expands the access lists into an array
    # We put it back as a string so it works in the admin UI
    my $toset = {};
    while (my ($attr, $val) = each %$switch) {
        if ($attr =~ /(.*)(AccessList|Vlan|Url|Role)$/) {
            my $type = $2;
            my $role = $1;
            if ($type eq 'AccessList' && ref($val) eq 'ARRAY') {
                $val = join("\n", @$val);
                $toset->{$attr} = $val;
            }

            my $key;
            if ($type eq 'Role') {
                $type = 'ControllerRole';
                $key = 'controller_role';
            } else {
                $key = lc($type);
            }

            push @{$toset->{"${type}Mapping"}}, { role => $role, $key => $val };
        }
    }

    while(my ($attr, $val) = each %$toset) {
        $switch->{$attr} = $val;
    }

    for my $k (qw(AccessListMapping VlanMapping UrlMapping ControllerRoleMapping))  {
        next if !exists $switch->{$k};
        $switch->{$k} = [sort { $a->{role} cmp $b->{role} } @{$switch->{$k} // []}]
    }

}

sub _splitInlineTrigger {
    my ($trigger) = @_;
    my ( $type, $value ) = split( /::/, $trigger );
    return { type => $type, value => $value };
}

=item cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ( $self, $id, $switch ) = @_;
    $self->_normalizeUplink($switch);
    $self->_normalizeInlineTrigger($switch);
    _flattenRoleMappings($switch);
    _deleteRoleMappings($switch);
}

sub _flattenRoleMappings {
    my ( $switch ) = @_;
    for my $namespace (qw(AccessListMapping VlanMapping UrlMapping ControllerRoleMapping))  {
        my $list = $switch->{$namespace} // [];
        for my $mapping (@$list) {
            my $role = $mapping->{role};
            $switch->{"${role}$MappingKey2{$namespace}"} = $mapping->{$MappingKey{$namespace}};
        }
    }
}

sub _deleteRoleMappings {
    my ( $switch ) = @_;
    delete @{$switch}{qw(AccessListMapping VlanMapping UrlMapping ControllerRoleMapping)};
}

=head2 _normalizeUplink

_normalizeUplink

=cut

sub _normalizeUplink {
    my ($self, $switch) = @_;
    my $uplink_dynamic = $switch->{uplink_dynamic};
    if ( defined $uplink_dynamic ) {
        if ($uplink_dynamic eq 'dynamic' ) {
            $switch->{uplink}         = 'dynamic';
            $switch->{uplink_dynamic} = undef;
        } elsif ($uplink_dynamic eq '0') {
            $switch->{uplink_dynamic} = undef;
        }
    }
}

=head2 parentSections

parentSections

=cut

sub parentSections {
    my ($self, $id, $item) = @_;
    my $inherit_from = $item->{group} // $self->cachedConfig->val($id, 'group');
    my $default_section = $self->default_section;
    return if defined $default_section && $id eq $default_section;
    my @parents;
    if (defined $inherit_from && (!defined $default_section || $default_section ne $inherit_from) && $id ne $inherit_from) {
        push @parents, "group $inherit_from";
    }

    return @parents, $self->SUPER::parentSections($id, $item);
}

=head2 _normalizeInlineTrigger

_normalizeInlineTrigger

=cut

sub _normalizeInlineTrigger {
    my ($self, $switch) = @_;
    if ( exists $switch->{inlineTrigger} ) {

        # Build string definition for inline triggers (see pf::role::isInlineTrigger)
        my $has_always;
        my @triggers = map {
            $has_always = 1 if $_->{type} eq 'always';
            $_->{type} . '::' . ( $_->{value} || '1' )
        } @{ $switch->{inlineTrigger} };
        @triggers = ('always::1') if $has_always;
        $switch->{inlineTrigger} = join( ',', @triggers );
    }
    return ;
}

=item remove

Delete an existing item

=cut

sub remove {
    my ( $self, $id ) = @_;
    if ( defined $id && $id eq 'default' ) {
        return undef;
    }
    return $self->SUPER::remove($id);
}

before rewriteConfig => sub {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    #partioning my their ids
    # default which is also first
    # ip address which is next
    # everything else
    my ($default,$ips,$rest) = part { $_ eq 'default' ? 0  : valid_ip($_) ? 1 : 2 } $config->Sections;
    my @newSections;
    push @newSections, @$default if defined $default;
    push @newSections, sort_ip(@$ips) if defined $ips;
    push @newSections, sort @$rest if defined $rest;
    $config->{sects} = \@newSections;
};

=head2 _Sections

=cut

sub _Sections {
    my ($self) = @_;
    return grep { $_ ne 'default' && /^\S+$/ } $self->SUPER::_Sections();
}

sub defaultGroupFilter {
    my $group = $_[0]->{group};
    return !defined $group || $group eq 'default';
}

sub membersOfGroup {
    my ( $self, $groupName ) = @_;
    return $groupName eq 'default'
      ? $self->filter( \&defaultGroupFilter, 'id' )
      : $self->search( 'group', $groupName, 'id' );
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=back

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

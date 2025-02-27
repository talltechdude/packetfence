package pf::factory::mfa;

=head1 NAME

pf::factory::mfa

=cut

=head1 DESCRIPTION

The factory for MFA

=cut

use strict;
use warnings;

use List::MoreUtils qw(any);
use Module::Pluggable
  search_path => 'pf::mfa',
  sub_name    => 'modules',
  inner       => 0,
  require     => 1;

use pf::config qw(%ConfigMfa);

sub factory_for { 'pf::mfa' }

our @MODULES = __PACKAGE__->modules;

our @TYPES = map { /^pf::mfa::(.*)$/ ; $1 } @MODULES;

our %MODULES;
foreach ( @MODULES ) {
    my $type = $_;
    $type =~ s/^.*://;
    $MODULES{$_}{'type'} = $type;
    $MODULES{$_}{'description'} = $_->module_description || $_;
}

=head2 new

Will create a new pf::mfa sub class based off the name
If no provider is found the return undef

=cut

sub new {
    my ($class,$name) = @_;
    my $object;
    my $data = $ConfigMfa{$name};
    $data->{id} = $name;
    if ($data) {
        my $subclass = $class->getModuleName($name,$data);
        $object = $subclass->new($data);
    }
    return $object;
}


=head2 getModuleName

Get the sub module pf::mfa base off it's configuration

=cut

sub getModuleName {
    my ($class,$name,$data) = @_;
    my $mainClass = $class->factory_for;
    my $type = $data->{type};
    my $subclass = "${mainClass}::${type}";
    die "type is not defined for $name" unless defined $type;
    die "$type is not a valid type" unless any { $_ eq $subclass  } @MODULES;
    $subclass;
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

#!/usr/bin/perl

=head1 NAME

Tenant

=head1 DESCRIPTION

unit test for Tenant

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

use Test::Mojo;
use Test::More tests => 15;
my $t = Test::Mojo->new('pf::UnifiedApi');

#This test will running last
use Test::NoWarnings;
my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

$t->get_ok('/api/v1/tenant/1')
  ->status_is(200)
  ->json_is('/item/not_deletable' => $true) ;

$t->get_ok('/api/v1/tenant/0')
  ->status_is(200)
  ->json_is('/item/not_deletable' => $true) ;

my $tenant_name = "test_tenant_$$";

$t->post_ok('/api/v1/tenants' => json => { name => $tenant_name })
  ->status_is(201);

my $location = $t->tx->res->headers->location;
$t->get_ok($location)
  ->status_is(200)
  ->json_is('/item/not_deletable' => $false);

my $tenant = $t->tx->res->json->{item};
my $tenant_id = $tenant->{id};

$t->get_ok($location => {'X-PacketFence-Tenant-Id' => $tenant_id})
  ->status_is(200)
  ->json_is('/item/not_deletable', $true);

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


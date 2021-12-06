#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Nodes

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

use Date::Parse;
use pf::dal::node;
use pf::dal::locationlog;
use Test2::Tools::Compare qw(bag hash item end field etc array);

#insert known data
#run tests
use Test::More tests => 22;
use Test::Mojo;
use Test::NoWarnings;
use Utils;
use pf::dal::bandwidth_accounting;
use pf::util;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $mac1 = Utils::test_mac();
my $mac2 = Utils::test_mac();
my $mac3 = Utils::test_mac();

for my $m ($mac1, $mac2, $mac3) {
    $t->delete_ok("/api/v1/node/$m" => json => { });
    $t->post_ok('/api/v1/nodes' => json => { mac => $m })
      ->status_is(201);
}

my $node_id2 = make_node_id(1, $mac2);
my $node_id3 = make_node_id(1, $mac3);

my $status = pf::dal::bandwidth_accounting->create({
    node_id => $node_id2,
    unique_session_id  => 1,
    time_bucket => \['DATE_ADD(DATE(NOW()), INTERVAL HOUR(NOW()) HOUR)'],
    source_type => 'radius',
    in_bytes => 100,
    out_bytes => 100,
    mac => $mac2,
    tenant_id => 1,
});

$status = pf::dal::bandwidth_accounting->create({
    node_id => $node_id3,
    unique_session_id  => 1,
    time_bucket => \['DATE_ADD(DATE(NOW()), INTERVAL HOUR(NOW()) HOUR)'],
    source_type => 'radius',
    in_bytes => 100,
    out_bytes => 100,
    mac => $mac3,
    tenant_id => 1,
    last_updated => '0000-00-00 00:00:00',
});

pf::dal::bandwidth_accounting->update_items(
    -set => {
        last_updated => '0000-00-00 00:00:00',
    },
    -where => {
        node_id => $node_id3,
        unique_session_id => 1,
    },
);

$t->post_ok( '/api/v1/nodes/search' => json =>
      {
          fields => [qw(mac online)],
          query => {
              op => 'or',
              values => [
                  map {{ field => 'mac', op => 'equals', value => $_ }} ($mac1, $mac2, $mac3)
              ]
          } 
      }
  )
  ->status_is(200);

Test2::Tools::Compare::is(
    $t->tx->res->json,
    {
            items => bag {
                item hash {
                    field mac => $mac1;
                    field online => "unknown"
                };
                item hash {
                    field mac => $mac2;
                    field online => "on"
                };
                item hash {
                    field mac => $mac3;
                    field online => "off"
                };
                end();
            },
            status => 200,
            prevCursor => 0,
    },
    "Check if online status is correct"
);

$t->post_ok( '/api/v1/nodes/search' => json =>
      {
          fields => [qw(mac online)],
          query => {
              op => 'and',
              values => [
                  {
                      field => 'online',
                      op => 'equals',
                      value => 'on',
                  },
                  {
                      op => 'or',
                      values => [
                          map {{ field => 'mac', op => 'equals', value => $_ }} ($mac1, $mac2, $mac3)
                      ]
                  }
              ]
          } 
      }
  )
  ->status_is(200);

Test2::Tools::Compare::is(
    $t->tx->res->json,
    {
            items => array {
                item hash {
                    field mac => $mac2;
                    field online => "on";
                };
                end();
            },
            status => 200,
            prevCursor => 0,
    },
    "Search for online nodes"
);

$t->post_ok( '/api/v1/nodes/search' => json =>
      {
          fields => [qw(mac online)],
          query => {
              op => 'and',
              values => [
                  {
                      field => 'online',
                      op => 'equals',
                      value => 'off',
                  },
                  {
                      op => 'or',
                      values => [
                          map {{ field => 'mac', op => 'equals', value => $_ }} ($mac1, $mac2, $mac3)
                      ]
                  }
              ]
          } 
      }
  )
  ->status_is(200);

Test2::Tools::Compare::is(
    $t->tx->res->json,
    {
            items => array {
                item hash {
                    field mac => $mac3;
                    field online => "off"
                };
                end();
            },
            status => 200,
            prevCursor => 0,
    },
    "Search for offline nodes"
);

$t->post_ok( '/api/v1/nodes/search' => json =>
      {
          fields => [qw(mac online)],
          query => {
              op => 'and',
              values => [
                  {
                      field => 'online',
                      op => 'equals',
                      value => 'unknown',
                  },
                  {
                      op => 'or',
                      values => [
                          map {{ field => 'mac', op => 'equals', value => $_ }} ($mac1, $mac2, $mac3)
                      ]
                  }
              ],
          } 
      }
  )
  ->status_is(200);

Test2::Tools::Compare::is(
    $t->tx->res->json,
    {
            items => array {
                item hash {
                    field mac => $mac1;
                    field online => "unknown"
                };
                end();
            },
            status => 200,
            prevCursor => 0,
    },
    "Search for unknown nodes"
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

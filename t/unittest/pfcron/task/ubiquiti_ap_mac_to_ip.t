#!/usr/bin/perl

=head1 NAME

ubiquiti_ap_mac_to_ip

=head1 DESCRIPTION

unit test for ubiquiti_ap_mac_to_ip

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::pfcron::task::ubiquiti_ap_mac_to_ip;
use pf::Switch::Ubiquiti::Unifi;

my $task = pf::pfcron::task::ubiquiti_ap_mac_to_ip->new(
     {
         status   => "enabled",
         id       => 'test',
		 interval  => 0,
         type     => 'ubiquiti_ap_mac_to_ip',
     }
 );

my $COUNT = 0;
{
    no warnings qw(redefine);
    local *pf::Switch::Ubiquiti::Unifi::populateAccessPointMACIP = sub { $COUNT++ };
    $task->run();
}

is($COUNT, 1);

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


#!/usr/bin/perl

=head1 NAME

to-10.1-realm-conf.pl

=head1 DESCRIPTION

Add the eap configuration parameter.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($realm_config_file);
use pf::util;

run_as_pf();

my $ini = pf::IniFiles->new(-file => $realm_config_file, -allowempty => 1);

for my $section ($ini->Sections()) {
    my $val = $ini->val($section, 'eap');
    if (!defined($val)) {
        $ini->newval($section, 'eap', 'default');
    }
}

$ini->RewriteConfig();

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

package pf::pki_provider::inverse;

=head1 NAME

pf::pki_provider::inverse

=cut

=head1 DESCRIPTION

pf::pki_provider::inverse

=cut

use strict;
use warnings;
use Moo;
use WWW::Curl::Easy;
use URI::Escape::XS qw(uri_escape uri_unescape);

use pf::log;

=head2 uri

The uri of the inverse pki service

=cut

has uri => ( is => 'rw' );

=head2 username

The username to connect to the inverse pki service

=cut

has username => ( is => 'rw' );

=head2 password

The password to connect to the inverse pki service

=cut

has password => ( is => 'rw' );

=head2 profile

The profile to use for the inverse pki service

=cut

has profile => ( is => 'rw' );

=head2 country

What country to use for the certificate

=cut

has country => ( is => 'rw' );

=head2 state

What state to use for the certificate

=cut

has state => ( is => 'rw' );

=head2 organisation

What organisation to use for the certificate

=cut

has organisation => ( is => 'rw' );

=head2 get_cert

Get the certificate from the inverse pki service

=cut

sub get_cert {
    my ($self,$args) = @_;
    my $logger = get_logger();
    my $uri = $self->uri;
    my $username = $self->username;
    my $password = $self->password;
    my $email = $args->{'certificate_email'};
    my $dot1x_username = $args->{'certificate_cn'};
    my $organisation = $self->organisation;
    my $state = $self->state;
    my $profile = $self->profile;
    my $country = $self->country;
    my $certpwd = $args->{'certificate_pwd'};
    my $curl = WWW::Curl::Easy->new;
    my $request =
        "username=" . uri_escape($username)
      . "&password=" . uri_escape($password)
      . "&cn=" . uri_escape($dot1x_username)
      . "&mail=" . uri_escape($email)
      . "&organisation=" . uri_escape($organisation)
      . "&st=" . uri_escape($state)
      . "&country=" . uri_escape($country)
      . "&profile=" . uri_escape($profile)
      . "&pwd=" . uri_escape($certpwd);
    my $response_body = '';
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    if ($curl_return_code == 0) {
        return $response_body;
    }
    else {
        $logger->error("certificate could not be acquire, check out logs on the pki");
    }
    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

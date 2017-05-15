#!/usr/bin/env perl

use 5.024;    # version included with Git for Windows
use strict;
use warnings;
use URI;
use HTTP::Tiny;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use JSON::PP;
use Data::Dumper;

my $source;
my $destination;
my $github_token;

GetOptions(
    'source=s'      => \$source,
    'destination=s' => \$destination,
    'token=s'       => \$github_token,
) or pod2usage(2);

pod2usage(1)
    unless ( defined($source)
    && defined($destination)
    && defined($github_token) );

my $http = HTTP::Tiny->new(
    default_headers => { 'Authorization' => "token $github_token" } );

my $from = get_team( split( /\//, $source ) );
my $to   = get_team( split( /\//, $destination ) );

pod2usage(2) unless ( defined($from) && defined($to) );

say "Adding all members of " . $from->{name} . " to " . $to->{name} . ' ...';
copy_team( $from, $to );

# helper functions

sub http_error {
    my ( $response, $msg ) = @_;
    unless ( $response->{success} ) {
        say STDERR "error: $response->{status}";
        say STDERR "reason: $response->{reason}";
        die "$msg\n";
    }
}

sub get_team {
    my ( $org, $name ) = @_;
    my $response = $http->get(
        "https://git.autodesk.com/api/v3/orgs/$org/teams?per_page=1000");
    http_error( $response, "Failed to get teams!" );

    my @teams = @{ decode_json( $response->{content} ) };

    my $result;
    for my $team (@teams) {
        if ( $team->{name} =~ /$name/ ) {
            $result = $team;
            last;
        }
    }
    return $result;
}

sub copy_team {
    my ( $src, $dst ) = @_;
    my $team_id = $dst->{id};
    my $members_url = $src->{members_url};
    $members_url =~ s/\{\/member\}$//;

    my $response = $http->get("$members_url?per_page=1000");
    http_error($response, "Failed to get members!\n");
    for my $member ( @{ decode_json( $response->{content} ) } ) {
        my $username = $member->{login};
        $response
            = $http->put(
            "https://git.autodesk.com/api/v3/teams/$team_id/memberships/$username"
            );
        http_error( $response, "Failed to add member: $username" );
        say "$username ... added";
    }
}

__END__

=head1 NAME

$0 - Copy all users from one team into another.

=head1 SYNOPSIS

$0.pl --source org1/team1 --destination org2/team2 --token abc123

=head1 OPTIONS

=over 4

=item B<--source>

specifies the team from which users will be copied

=item B<--destination>

specifies the team to which users will be copied

=item B<--token>

specifies the token used to authenticate to the GitHub API

=back

=head1 DESCRIPTION

B<This program> will copy all users from a team into a second team.

=cut

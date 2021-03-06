#!/usr/bin/env perl
package DIKUtools::Canvas;
use Mojo::Base -base;

use Mojo::UserAgent;

# Enable post-dereferencing and signature goodness!
use feature qw(postderef signatures);
no warnings qw(experimental::postderef experimental::signatures);

=head1 NAME

DIKUtools::Canvas - Provides API access to Canvas

=head1 ABSTRACT

 my $canvas = DIKUtools::Canvas->new( token => ... );
 my @students = $canvas->course_users( $courseid, 'enrollment_type[]' => 'student' );

=head1 FIELDS

=head2 token

The access token used for accessing the Canvas instance.

Can be generated by going to L<https://absalon.ku.dk/profile/settings> and clicking "+ New access token".

=cut
has token => sub { die("Please provide token for DIKUtools::Canvas!"); };

=head2 api_base

The API base URL.

Set to the KU API base url by default.

=cut

has api_base => 'https://absalon.ku.dk/api/v1';

has _ua => sub { return Mojo::UserAgent->new(); };

=head1 METHODS

=cut

sub _api_call($self, %args) {
    my $url = $self->api_base . $args{url};
    my $method = lc( $args{method} // 'GET' );
    my $args = $args{args} // {};
    my $token = $self->token;

    my $tx = $self->_ua->$method($url, { Authorization => "Bearer $token" }, form => $args);
    if ( my $res = $tx->success ) {
        return $res->json;
    } else {
        my $err = $tx->error;
        die "$err->{code} response: $err->{message}" if $err->{code};
        die "Connection error: $err->{message}";
    }
}

=head2 $canvas->course_users($courseid, %args)

Provides an array of users associated with a given course.

Endpoint documentation: L<https://canvas.instructure.com/doc/api/courses.html#method.courses.users>

=cut

sub course_users($self, $courseid) {
    my @sections = $self->_api_call( url => "/courses/$courseid/sections",
                                     args => { 'include' => 'students' } )->@*;
    return $sections[0]{students};
}

=head2 $canvas->create_group_category($courseid, $name)

Creates a group category under a given course, and returns a hashref with information about it.

Endpoint documentation: L<https://canvas.instructure.com/doc/api/group_categories.html#method.group_categories.create>

=cut

sub create_group_category($self, $courseid, $name) {
	my $args = {
		name => $name,
		self_signup => undef,
	};

	return $self->_api_call( url => "/courses/$courseid/group_categories", method => 'POST', args => $args );
}

=head2 $canvas->create_group($group_cat, $users, $group_name = '')

Creates a group belonging to a given group category, and puts the given users into it.

C<$group_cat> is a group category hashref. C<$users> is a hashref of user hashrefs.

Returns a group hashref.

Endpoints used:

* Creating the group: https://canvas.instructure.com/doc/api/groups.html#method.groups.create
* Adding users to the group: https://canvas.instructure.com/doc/api/groups.html#method.groups.update

=cut

sub create_group ($self, $group_cat, $users, $group_name = '') {
	my @userids = map { $_->{id} } @$users;

	# First create the group
	my $url = '/group_categories/' . $group_cat->{id} . '/groups';
	$group_name //= join(", ", map { $_->{short_name} } @$users);

	my $args = {
		name       => $group_name,
		join_level => 'invitation_only',
	};

	my $group = $self->_api_call( url => $url, method => 'POST', args => $args );

	my $groupid = $group->{id};

	# Then add the members
	$url = "/groups/$groupid";

	$args = {
		'members[]' => \@userids,
	};

	return $self->_api_call( url => $url, method => 'PUT', args => $args );
}

1;


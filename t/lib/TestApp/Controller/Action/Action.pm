package TestApp::Controller::Action::Action;

use strict;
use base 'TestApp::Controller::Action';

sub action_action_one : Global : Action('TestBefore') {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Action', $c->stash->{test} );
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_two : Global : Action('TestAfter') : Action('TestBefore') {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Action', $c->stash->{test} );
    $c->forward('TestApp::View::Dump::Request');
}

1;

package Catalyst::Action::TestBefore;

use strict;
use Moose::Role;

before 'execute' => sub {
    my ( $self, $controller, $c ) = @_;
    $c->stash->{test} = 'works';
};

1;

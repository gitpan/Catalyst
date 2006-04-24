package Catalyst::Action::TestAfter;

use strict;
use Moose::Role;

after 'execute' => sub {
    my ( $self, $controller, $c ) = @_;
    $c->res->header( 'X-Action-After', 'awesome' );
};

1;

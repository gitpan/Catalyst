package Catalyst::DispatchType::Path;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;

=head1 NAME

Catalyst::DispatchType::Path - Path DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->list($c)

=cut

sub list {
    my ( $self, $c ) = @_;
    my $paths = Text::SimpleTable->new( [ 36, 'Path' ], [ 37, 'Private' ] );
    for my $path ( sort keys %{ $self->{paths} } ) {
        my $action = $self->{paths}->{$path};
        $paths->row( "/$path", "/$action" );
    }
    $c->log->debug( "Loaded Path actions:\n" . $paths->draw )
      if ( keys %{ $self->{paths} } );
}

=item $self->match( $c, $path )

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    if ( my $action = $self->{paths}->{$path} ) {
        $c->req->action($path);
        $c->req->match($path);
        $c->action($action);
        $c->namespace( $action->namespace );
        return 1;
    }

    return 0;
}

=item $self->register( $c, $action )

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my $attrs = $action->attributes;
    my @register;

    foreach my $r ( @{ $attrs->{Path} || [] } ) {
        unless ($r) {
            $r = $action->namespace;
            $r = '' if $r eq '/';
        }
        elsif ( $r !~ m!^/! ) {    # It's a relative path
            $r = $action->namespace . "/$r";
        }
        push( @register, $r );
    }

    if ( $attrs->{Global} || $attrs->{Absolute} ) {
        push( @register, $action->name );    # Register sub name against root
    }

    if ( $attrs->{Local} || $attrs->{Relative} ) {
        push( @register, join( '/', $action->namespace, $action->name ) );

        # Register sub name as a relative path
    }

    $self->register_path( $c, $_, $action ) for @register;
    return 1 if @register;
    return 0;
}

=item $self->register_path($c, $path, $action)

=cut

sub register_path {
    my ( $self, $c, $path, $action ) = @_;
    $path =~ s!^/!!;
    $self->{paths}{$path} = $action;
}

=back

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;

package Catalyst::DispatchType::Action;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;
use Catalyst::Utils;

=head1 NAME

Catalyst::DispatchType::Action - Action DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

Debug output for Action dispatch points

=cut

sub list {
    my ( $self, $c ) = @_;
    my $actions =
      Text::SimpleTable->new( [ 35, 'Private' ], [ 36, 'Classes' ] );
    for my $name ( sort keys %{ $self->{actions} } ) {
        my $action = $self->{actions}{$name};
        $actions->row( "/$action", join "\n", @{ $self->{classes}->{$name} } );
    }
    $c->log->debug( "Loaded Action classes:\n" . $actions->draw )
      if ( keys %{ $self->{actions} } );
}

=head2 $self->match

=cut

sub match { return 0 }

=head2 $self->register( $c, $action )

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my @register = @{ $action->attributes->{Action} || [] };

    for my $register (@register) {
        $self->{actions}{"$action"} = $action;
        push @{ $self->{classes}{"$action"} }, $register;
    }

    return 0;
}

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;

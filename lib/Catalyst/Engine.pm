package Catalyst::Engine;

use strict;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use UNIVERSAL::require;
use B;
use Data::Dumper;
use HTML::Entities;
use HTTP::Headers;
use Time::HiRes qw/gettimeofday tv_interval/;
use Catalyst::Request;
use Catalyst::Response;

require Module::Pluggable::Fast;

$Data::Dumper::Terse = 1;

__PACKAGE__->mk_classdata($_) for qw/actions components/;
__PACKAGE__->mk_accessors(qw/entrance request response/);

*comp = \&component;
*req  = \&request;
*res  = \&response;

=head1 NAME

Catalyst::Engine - The Catalyst Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head2 METHODS

=head3 action

Add one or more actions.

    $c->action( _foo => sub { $_[1]->res->output('Foo!') } );

Get an action's class and coderef.

    my ($class, $code) = @{ $c->action('foo') };

Get a list of available actions.

    my @actions = $c->action;

It also automatically calls setup() if needed.

=cut

sub action {
    my $self = shift;
    $self->setup unless $self->components;
    $self->actions( {} ) unless $self->actions;
    my $action;
    $_[1] ? ( $action = {@_} ) : ( $action = shift );
    if ( ref $action eq 'HASH' ) {
        while ( my ( $name, $code ) = each %$action ) {
            my $class  = B::svref_2object($code)->STASH->NAME;
            my $caller = caller(0);
            if ( $name =~ /^\/(.*)\/$/ ) {
                my $regex = $1;
                $self->actions->{compiled}->{qr/$regex/} = $name;
                $self->actions->{regex}->{$name} = [ $class, $code ];
            }
            else { $self->actions->{plain}->{$name} = [ $class, $code ] }
            $self->log->debug(
                qq/"$caller" defined "$name" as "$code" from "$class"/)
              if $self->debug;
        }
    }
    elsif ($action) {
        if ( my $match = $self->actions->{plain}->{$action} ) {
            return [$match];
        }
        else {
            while ( my ( $regex, $name ) =
                each %{ $self->actions->{compiled} } )
            {
                if ( $action =~ $regex ) {
                    my $match = $self->actions->{regex}->{$name};
                    my @matches;
                    for my $i ( 1 .. 9 ) {
                        no strict 'refs';
                        last unless ${$i};
                        push @matches, ${$i};
                    }
                    return [ $match, $name, \@matches ];
                }
            }
        }
        return 0;
    }
    else {
        return (
            keys %{ $self->actions->{plain} },
            keys %{ $self->actions->{regex} }
        );
    }
}

=head3 benchmark

Takes a coderef with arguments and returns elapsed time as float.

    my ( $elapsed, $status ) = $c->benchmark( sub { return 1 } );
    $c->log->info( sprintf "Processing took %f seconds", $elapsed );

=cut

sub benchmark {
    my $c       = shift;
    my $code    = shift;
    my $time    = [gettimeofday];
    my @return  = &$code(@_);
    my $elapsed = tv_interval $time;
    return wantarray ? ( $elapsed, @return ) : $elapsed;
}

=head3 component (comp)

Get a component object by name.

    $c->comp('MyApp::Model::MyModel')->do_stuff;

Regex search for a component.

    $c->comp('mymodel')->do_stuff;

=cut

sub component {
    my ( $c, $name ) = @_;
    if ( my $component = $c->components->{$name} ) {
        return $component;
    }
    else {
        for my $component ( keys %{ $c->components } ) {
            return $c->components->{$component} if $component =~ /$name/i;
        }
    }
}

=head3 errors

Returns an arrayref containing errors messages.

    my @errors = @{ $c->errors };

Add a new error.

    $c->errors('Something bad happened');

=cut

sub errors {
    my $c = shift;
    my $errors = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
    push @{ $c->{errors} }, @$errors;
    return $c->{errors};
}

=head3 finalize

Finalize request.

=cut

sub finalize {
    my $c = shift;
    if ( !$c->res->output || $#{ $c->errors } >= 0 ) {
        $c->res->headers->content_type('text/html');
        my $name = $c->config->{name} || 'Catalyst Application';
        my ( $title, $errors, $infos );
        if ( $c->debug ) {
            $errors = join '<br/>', @{ $c->errors };
            $errors ||= 'No output';
            $title = $name = "$name on Catalyst $Catalyst::VERSION";
            my $req   = encode_entities Dumper $c->req;
            my $res   = encode_entities Dumper $c->res;
            my $stash = encode_entities Dumper $c->stash;
            my $roles = encode_entities Dumper $c->roles;
            $infos = <<"";
<br/>
<b><u>Request</u></b><br/>
<pre>$req</pre>
<b><u>Response</u></b><br/>
<pre>$res</pre>
<b><u>Stash</u></b><br/>
<pre>$stash</pre>
<b><u>Roles</u></b><br/>
<pre>$roles</pre>

        }
        else {
            $title  = $name;
            $errors = '';
            $infos  = <<"";
<pre>
(en) Please come back later
(de) Bitte versuchen sie es spaeter nocheinmal
(nl) Gelieve te komen later terug
(no) Vennligst prov igjen senere
(fr) Veuillez revenir plus tard
(es) Vuelto por favor mas adelante
(pt) Voltado por favor mais tarde
(it) Ritornato prego più successivamente
</pre>

            $name = '';
        }
        $c->res->{output} = <<"";
<html>
    <head>
        <title>$title</title>
        <style type="text/css">
            body {
                font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                             Tahoma, Arial, helvetica, sans-serif;
                color: #ddd;
                background-color: #eee;
                margin: 0px;
                padding: 0px;
            }
            div.box {
                background-color: #ccc;
                border: 1px solid #aaa;
                padding: 4px;
                margin: 10px;
                -moz-border-radius: 10px;
            }
            div.errors {
                background-color: #977;
                border: 1px solid #755;
                padding: 8px;
                margin: 4px;
                margin-bottom: 10px;
                -moz-border-radius: 10px;
            }
            div.infos {
                background-color: #797;
                border: 1px solid #575;
                padding: 8px;
                margin: 4px;
                margin-bottom: 10px;
                -moz-border-radius: 10px;
            }
            div.name {
                background-color: #779;
                border: 1px solid #557;
                padding: 8px;
                margin: 4px;
                -moz-border-radius: 10px;
            }
        </style>
    </head>
    <body>
        <div class="box">
            <div class="errors">$errors</div>
            <div class="infos">$infos</div>
            <div class="name">$name</div>
        </div>
    </body>
</html>

    }
    if ( my $location = $c->res->redirect ) {
        $c->log->debug(qq/Redirecting to "$location"/) if $c->debug;
        $c->res->headers->header( Location => $location );
        $c->res->status(302);
    }
    $c->res->headers->content_length( length $c->res->output );
    my $status = $c->finalize_headers;
    $c->finalize_output;
    return $status;
}

=head3 finalize_headers

Finalize headers.

=cut

sub finalize_headers { }

=head3 finalize_output

Finalize output.

=cut

sub finalize_output { }

=head3 forward

Forward processing to a private/public action or a method from a class.
If you define a class without method it will default to process().

    $c->forward('_foo');
    $c->forward('index.html');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward {
    my $c       = shift;
    my $command = shift;
    my ( $class, $code );
    if ( my $action = $c->action($command) ) {
        ( $class, $code ) = @{ $action->[0] };
        $c->log->debug(qq/Action "$command" in "$class" is "$code"/)
          if $c->debug;
    }
    else {
        $class = $command;
        my $method = shift || 'process';
        if ( $code = $class->can($method) ) {
            $c->log->debug(qq/Method "$method" in "$class" is "$code"/)
              if $c->debug;
        }
        else {
            $c->log->error(qq/Couldn't find method "$method" in "$class"/)
              if $c->debug;
            return 0;
        }
    }
    $class = $c->components->{$class} || $class;
    return $c->process( $class, $code );
}

=head3 handler

Handles the request.

=cut

sub handler {
    my ( $class, $r ) = @_;

    # Always expect worst case!
    my $status = -1;
    eval {
        my $handler = sub {
            my $c = $class->prepare($r);
            if ( $c->entrance ) {
                $c->forward('_begin') if $c->actions->{plain}->{_begin};
                my ( $class, $code ) = @{ $c->entrance };
                $class = $c->components->{$class} || $class;
                $c->process( $class, $code );
                $c->forward('_end') if $c->actions->{plain}->{_end};
            }
            else {
                my $action = $c->req->path;
                my $error  = $action
                  ? $action =~ /^_/
                  ? qq/Private resource "$action"/
                  : qq/Unknown resource "$action"/
                  : "Congratulations, you're on Catalyst!";
                $c->log->error($error) if $c->debug;
                $c->errors($error);
            }
            return $c->finalize;
        };
        if ( $class->debug ) {
            my $elapsed;
            ( $elapsed, $status ) = $class->benchmark($handler);
            $class->log->info( sprintf "Request took %f seconds", $elapsed );
        }
        else { $status = &$handler }
    };
    if ( my $error = $@ ) {
        chomp $error;
        $class->log->error(qq/Catched exception in engine "$error"/);
    }
    return $status;
}

=head3 prepare

Turns the request (Apache, CGI...) into a Catalyst context.

=cut

sub prepare {
    my ( $class, $r ) = @_;
    my $c = bless {
        request => Catalyst::Request->new(
            {
                arguments  => [],
                cookies    => {},
                headers    => HTTP::Headers->new,
                parameters => {},
                snippets   => [],
                uploads    => {}
            }
        ),
        response => Catalyst::Response->new(
            { cookies => {}, headers => HTTP::Headers->new, status => 200 }
        ),
        roles => [],
        stash => {}
    }, $class;
    $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION )
      if $c->debug;
    $c->prepare_request($r);
    $c->prepare_path;
    my $path = $c->request->path;
    $c->log->debug(qq/Requested path "$path"/) if $c->debug;
    $c->prepare_cookies;
    $c->prepare_headers;
    $c->prepare_action;
    $c->prepare_parameters;
    $c->prepare_uploads;
    return $c;
}

=head3 prepare_action

Prepare action.

=cut

sub prepare_action {
    my $c    = shift;
    my $path = $c->req->path;
    return if $path =~ /^_/;
    my @path = split /\//, $c->req->path;
    my @args;
    while (@path) {
        my $path = join '/', @path;
        if ( my $result = $c->action($path) ) {
            my $entrance = $result->[0];

            # It's a regex
            if ( $#{$result} == 2 ) {
                my $match    = $result->[1];
                my @snippets = @{ $result->[2] };
                $c->log->debug(qq/Requested action "$path" matched "$match"/)
                  if $c->debug;
                $c->log->debug(
                    'Snippets are "' . join( ' ', @snippets ) . '"' )
                  if ( $c->debug && @snippets );
                $c->req->match($match);
                $c->req->snippets( \@snippets );
            }
            else { $c->log->debug(qq/Requested action "$path"/) if $c->debug }
            $c->entrance($entrance);
            $c->req->action($path);
            $c->req->args( \@args );
            $c->log->debug( 'Arguments are "' . join( '/', @args ) . '"' )
              if ( $c->debug && @args );
            last;
        }
        unshift @args, pop @path;
    }
    unless ( $c->req->action ) {
        if ( my $result = $c->actions->{plain}->{_default} ) {
            $c->entrance($result);
            $c->req->action( $c->req->path );
            $c->log->debug('Using default action') if $c->debug;
        }
    }
}

=head3 prepare_cookies;

Prepare cookies.

=cut

sub prepare_cookies { }

=head3 prepare_headers

Prepare headers.

=cut

sub prepare_headers { }

=head3 prepare_parameters

Prepare parameters.

=cut

sub prepare_parameters { }

=head3 prepare_path

Prepare path and base.

=cut

sub prepare_path { }

=head3 prepare_request

Prepare the engine request.

=cut

sub prepare_request { }

=head3 prepare_uploads

Prepare uploads.

=cut

sub prepare_uploads { }

=head3 process

Process a coderef in given class and catch exceptions.
Errors are available via $c->errors.

=cut

sub process {
    my ( $c, $class, $code ) = @_;
    my $status;
    eval {
        if ( $c->debug )
        {
            my $elapsed;
            ( $elapsed, $status ) =
              $c->benchmark( $code, $class, $c, @{ $c->req->args } );
            $c->log->info( sprintf qq/Processing "$code" took %f seconds/,
                $elapsed )
              if $c->debug;
        }
        else { $status = &$code( $class, $c, @{ $c->req->args } ) }
    };
    if ( my $error = $@ ) {
        chomp $error;
        $error = qq/Catched exception "$error"/;
        $c->log->error($error);
        $c->errors($error) if $c->debug;
        return 0;
    }
    return $status;
}

=head3 process_permission

Calls process_roles.

=cut

sub process_permission {
    my ( $c, $roles ) = @_;
    if ($roles) {
        return 1 if $#$roles < 0;
        my $string = join ' ', @$roles;
        if ( $c->process_roles($roles) ) {
            $c->log->debug(qq/Permission granted "$string"/) if $c->debug;
        }
        else {
            $c->log->debug(qq/Permission denied "$string"/) if $c->debug;
            return 0;
        }
    }
    return 1;
}

=head3 process_roles

Check if the requesting user has one of the needed roles.
Defaults to 0.

=cut

sub process_roles { 0 }

=head3 remove_action

Remove an action.

    $c->remove_action('_foo');

=cut

sub remove_action {
    my ( $self, $action ) = @_;
    if ( delete $self->actions->{regex}->{$action} ) {
        while ( my ( $regex, $name ) = each %{ $self->actions->{compiled} } ) {
            if ( $name eq $action ) {
                delete $self->actions->{compiled}->{$regex};
                last;
            }
        }
    }
    else {
        delete $self->actions->{plain}->{$action};
    }
}

=head3 request (req)

Returns a C<Catalyst::Request> object.

    my $req = $c->req;

=head3 response (res)

Returns a C<Catalyst::Response> object.

    my $res = $c->res;

=head3 roles

Check permissions for roles and return true or false.

    $c->roles(qw/foo bar/);

Returns an arrayref containing the verified roles.

    my @roles = @{ $c->roles };

=cut

sub roles {
    my $c = shift;
    my $roles = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
    if ( $_[0] ) {
        my @roles;
        foreach my $role (@$roles) {
            push @roles, $role unless grep $role, @{ $c->{roles} };
        }
        return 1 unless @roles;
        if ( $c->process_permission( \@roles ) ) {
            $c->{roles} = [ @{ $c->{roles} }, @roles ];
            return 1;
        }
        else { return 0 }
    }
    return $c->{roles};
}

=head3 setup

Setup.

    MyApp->setup;

=cut

sub setup {
    my $self = shift;
    $self->setup_components;
    if ( $self->debug ) {
        my $name = $self->config->{name} || 'Application';
        $self->log->info("$name powered by Catalyst $Catalyst::VERSION");
    }
}

=head3 setup_components

Setup components.

=cut

sub setup_components {
    my $self = shift;

    # Components
    my $class = ref $self || $self;
    eval <<"";
        package $class;
        import Module::Pluggable::Fast
          name   => '_components',
          search =>
          [ '$class\::Controller', '$class\::Model', '$class\::View' ];

    if ( my $error = $@ ) {
        chomp $error;
        $self->log->error(
            qq/Couldn't initialize "Module::Pluggable::Fast", "$error"/);
    }
    $self->components( {} );
    for my $component ( $self->_components($self) ) {
        $self->components->{ ref $component } = $component;
    }
    $self->log->debug( 'Initialized components "'
          . join( ' ', keys %{ $self->components } )
          . '"' )
      if $self->debug;
}

=head3 stash

Returns a hashref containing all your data.

    $c->stash->{foo} ||= 'yada';
    print $c->stash->{foo};

=cut

sub stash {
    my $self = shift;
    if ( $_[0] ) {
        my $stash = $_[1] ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$stash ) {
            $self->{stash}->{$key} = $val;
        }
    }
    return $self->{stash};
}

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;

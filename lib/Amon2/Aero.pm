package Amon2::Aero;
use strict;
use warnings;
use 5.008008;
our $VERSION = '0.04';

use parent qw/Amon2 Amon2::Web/;
use Router::Simple 0.04;
use Text::Xslate;
use File::Spec;
use File::Basename qw(dirname);
use Data::Section::Simple ();
use Amon2::Config::Simple;

my $COUNTER;

sub import {
    my $class = shift;
    no strict 'refs';

    my $router = Router::Simple->new();
    my $caller = caller(0);

    my $base_class = 'Amon2::Aero::_child_' . $COUNTER++;
    {
        no warnings;
        unshift @{"$base_class\::ISA"}, qw/Amon2 Amon2::Web/;
        unshift @{"$caller\::ISA"}, $base_class;
    }

    *{"$caller\::to_app"} = sub {
        my ($class, %opts) = @_;

        my $app = $class->Amon2::Web::to_app();
        if (delete $opts{handle_static}) {
            require Plack::Middleware::Static;

            $app = Plack::Middleware::Static->wrap(
                $app,
                path => qr{^(?:/static/)},
                root => File::Spec->catdir( dirname((caller(0))[1]) ),
            );
            $app = Plack::Middleware::Static->wrap(
                $app,
                path => qr{^(?:/robots\.txt|/favicon\.ico)$},
                root => File::Spec->catdir( dirname((caller(0))[1]), 'static' ),
            );
        }
        return $app;
    };

    *{"$caller\::router"} = sub { $router };

    # any [qw/get post delete/] => '/bye' => sub { ... };
    # any '/bye' => sub { ... };
    *{"$caller\::any"} = sub ($$;$) {
        my $pkg = caller(0);
        if (@_==3) {
            my ($methods, $pattern, $code) = @_;
            $router->connect(
                $pattern,
                {code => $code},
                { method => [ map { uc $_ } @$methods ] }
            );
        } else {
            my ($pattern, $code) = @_;
            $router->connect(
                $pattern,
                {code => $code},
            );
        }
    };

    *{"$caller\::get"} = sub {
        $router->connect($_[0], {code => $_[1]}, {method => ['GET', 'HEAD']});
    };

    *{"$caller\::post"} = sub {
        $router->connect($_[0], {code => $_[1]}, {method => ['POST']});
    };

    *{"${base_class}\::dispatch"} = sub {
        my ($c) = @_;
        if (my $p = $router->match($c->request->env)) {
            return $p->{code}->($c, $p);
        } else {
            return $c->res_404();
        }
    };

    my $tmpl_dir = File::Spec->catdir(dirname((caller(0))[1]), 'tmpl');
    *{"${base_class}::create_view"} = sub {
        $base_class->template_options();
    };
    *{"${base_class}::template_options"} = sub {
        my ($class, %options) = @_;

        # using lazy loading to read __DATA__ section.
        my $vpath = Data::Section::Simple->new($caller)->get_data_section();
        my %params = (
            'syntax'   => 'Kolon',
            'module'   => [ 'Text::Xslate::Bridge::Star' ],
            'path'     => [ $vpath, $tmpl_dir ],
            'function' => {
                c        => sub { Amon2->context() },
                uri_with => sub { Amon2->context()->req->uri_with(@_) },
                uri_for  => sub { Amon2->context()->uri_for(@_) },
            },
        );
        my $merge = sub {
            my ($stuff) = @_;
            for (qw(module path)) {
                if ($stuff->{$_}) {
                    unshift @{$params{$_}}, @{delete $stuff->{$_}};
                }
            }
            for (qw(function)) {
                if ($stuff->{$_}) {
                    $params{$_} = +{ %{$params{$_}}, %{delete $stuff->{$_}} };
                }
            }
            while (my ($k, $v) = each %$stuff) {
                $params{$k} = $v;
            }
        };
        if (my $config = $caller->config->{'Text::Xslate'}) {
            $merge->($config);
        }
        if (%options) {
            $merge->(\%options);
        }
        my $xslate = Text::Xslate->new(%params);
        no warnings 'redefine';
        *{"${caller}::create_view"} = sub { $xslate };
        $xslate;
    };

    if (-d File::Spec->catdir($caller->base_dir, 'config')) {
        *{"${base_class}::load_config"} = sub { Amon2::Config::Simple->load(shift) };
    } else {
        *{"${base_class}::load_config"} = sub { +{ } };
    }
}


1;
__END__

=encoding utf8

=head1 NAME

Amon2::Aero - Variation of Amon2::Lite for Xslate/Kolon syntax

=head1 SYNOPSIS

    use Amon2::Aero;

    get '/' => sub {
        my ($c) = @_;
        return $c->render('index.tt');
    };

    __PACKAGE__->to_app();

    __DATA__

    @@ index.tt
    <!doctype html>
    <html>
        <body>Hello</body>
    </html>

=head1 DESCRIPTION

This is a Sinatra-ish wrapper for Amon2.

B<THIS MODULE IS BETA STATE. API MAY CHANGE WITHOUT NOTICE>.

=head1 FUNCTIONS

=over 4

=item any(\@methods, $path, \&code)

=item any($path, \&code)

Register new route for router.

=item get($path, $code->($c))

Register new route for router.

=item post($path, $code->($c))

Register new route for router.

=item __PACKAGE__->load_plugin($name, \%opts)

Load a plugin to the context object.

=item __PACKAGE__->to_app()

Create new PSGI application instance.

=back

=head1 FAQ

=over 4

=item How can I configure the options for Xslate?

You can provide a constructor arguments by configuration.
Write following lines on your app.psgi.

    __PACKAGE__->template_options(
        syntax => 'Kolon',
    );

=item How can I use other template engines instead of Text::Xslate?

You can use any template engine with Amon2::Aero. You can overwrite create_view method same as normal Amon2.

This is a example to use L<Text::MicroTemplate::File>.

    use Tiffany::Text::MicroTemplate::File;

    sub create_view {
        Tiffany::Text::MicroTemplate::File->new(+{
            include_path => ['./tmpl/']
        })
    }

=item How can I handle static files?

If you pass the 'handle_static' option to 'to_app' method, Amon2::Aero handles /static/ path to ./static/ directory.

    use Amon2::Aero;
    __PACKAGE__->to_app(handle_static => 1);

=back

=head1 AUTHOR

Fuji Goro (gfx) E<lt>gfuji at cpan.orgE<gt>

=head1 THANKS TO

This is a fork from Amon2::Lite, written by Tokuhiro Matsuno (tokuhirom).

=head1 SEE ALSO

L<Amon2>

L<Amon2::Lite>

=head1 LICENSE

Copyright (C) Fuji Goro (gfx)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

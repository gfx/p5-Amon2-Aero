package Amon2::Setup::Flavor::Aero;
use strict;
use warnings;
use utf8;

use parent qw/Amon2::Setup::Flavor/;
use Amon2::Aero (); # forVERSION
use Amon2       (); # for VERSION

sub run {
    my ($self) = @_;

    $self->{amon2_version}        = $Amon2::VERSION;
    $self->{amon2_flavor_version} = $Amon2::Aero::VERSION;

    $self->write_file('app.psgi', <<'...');
#!perl
use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Aero;

# put your configuration here
sub config {
    +{
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
        $res->header( 'X-Frame-Options' => 'DENY' );
    },
);

# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender');
# __PACKAGE__->load_plugin('Web::FillInFormLite');
# __PACKAGE__->load_plugin('Web::JSON');

use Plack::Session::State::Cookie;
builder {
    enable 'Plack::Middleware::Session',
        state => Plack::Session::State::Cookie->new(
            httponly => 1,
        );

    __PACKAGE__->to_app(handle_static => 1);
};

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title><% $module %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.0/jquery.min.js"></script>
    <link rel="stylesheet" href="http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css">
    <style>
    </style>
    <script type="text/javascript">
    </script>
</head>
<body>
    <% $module %>
</body>
</html>
...

    $self->write_file('Makefile.PL', <<'...');
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => '<% $module %>',
    AUTHOR        => 'Some Person <person@example.com>',
    VERSION_FROM  => 'app.psgi',
    PREREQ_PM     => {
        'Amon2'                           => '<% $amon2_version %>',
        'Amon2::Aero'                     => '<% $amon2_flavor_version %>',
        'Text::Xslate'                    => '1.5007',
        'Plack::Session'                  => '0.14',
    },
    MIN_PERL_VERSION => '5.010',
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
...

    $self->write_file('t/Util.pm', <<'...');
package t::Util;
BEGIN {
    unless ($ENV{PLACK_ENV}) {
        $ENV{PLACK_ENV} = 'test';
    }
}
use parent qw/Exporter/;
use Test::More 0.96;

our @EXPORT = qw//;

{
    # utf8 hack.
    binmode Test::More->builder->$_, ":utf8" for qw/output failure_output todo_output/;
    no warnings 'redefine';
    my $code = \&Test::Builder::child;
    *Test::Builder::child = sub {
        my $builder = $code->(@_);
        binmode $builder->output,         ":utf8";
        binmode $builder->failure_output, ":utf8";
        binmode $builder->todo_output,    ":utf8";
        return $builder;
    };
}

1;
...

    $self->write_file('t/01_root.t', <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        my $res = $cb->($req);
        is $res->code, 200;
        diag $res->content if $res->code != 200;
    };

done_testing;
...

    $self->write_file('xt/03_pod.t', <<'...');
use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();
...
}

1;
__END__

=head1 NAME

Amon2::Setup::Flavor::Aero - Amon2::Aero flavor

=head1 SYNOPSIS

    % amon2-setup.pl --flavor=Aero MyApp

=head1 DESCRIPTION

This is a flavor for project using Amon2::Aero.

=head1 AUTHOR

Fuji Goro (gfx)

The original version was written by tokuhirom


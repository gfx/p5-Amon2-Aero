use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use Test::Requires qw/HTTP::Request::Common/, 'Data::Section::Simple';
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../../lib');

use Amon2::Aero;

sub config {
    +{
        'Text::Xslate' => {
            syntax => 'Kolon'
        }
    }
}

get '/' => sub {
    my ($c) = @_;
    return Amon2::Web::Response->new(200, [], 'OK');
};

get '/hello' => sub {
    my ($c) = @_;
    return $c->render('hello.tt', { name => $c->req->param('name')});
};

my $app = __PACKAGE__->to_app;

test_psgi($app, sub {
    my $cb = shift;

    {
        my $res = $cb->(GET '/');
        is $res->content, 'OK';
    }

    {
        my $res = $cb->(GET '/hello?name=John');
        is $res->content, "Hello, John\n";
    }
});

done_testing;

__DATA__

@@ hello.tt
Hello, <: $name :>

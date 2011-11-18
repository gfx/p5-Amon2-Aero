use strict;
use warnings;
use utf8;
use Test::More;
use t::TestFlavor;
use Test::Requires 'JSON', 'Plack::Middleware::ReverseProxy', 'Data::Section::Simple';

test_flavor(sub {
    ok(-f 'app.psgi', 'app.psgi exists');
    ok((do 'app.psgi'), 'app.psgi is valid') or do {
        diag $@;
        diag do {
            open my $fh, '<', 'app.psgi' or die;
            local $/; <$fh>;
        };
    };
}, 'Aero');

done_testing;


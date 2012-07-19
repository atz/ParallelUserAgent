# perl
use strict;
use warnings;
use Test::More tests => 3;

my $core = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
use_ok($core);
use_ok('HTTP::Request');

my $url = "http://jigsaw.w3.org/HTTP/neg";
my $ua  = $core->new(keep_alive => 1);
my $req = HTTP::Request->new(GET => $url);
$req->header(Connection => "close");
my $res = $ua->request($req);

is($res->code, 300, "\$res->code == 300 [$url]") or print $res->as_string;


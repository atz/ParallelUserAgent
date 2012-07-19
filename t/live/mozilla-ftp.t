# perl
use strict;
use warnings;
use Test::More tests => 7;

my $core = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
use_ok($core);
use_ok('HTTP::Request');

my $url = "ftp://ftp.mozilla.org/pub/";
my $ua  = $core->new(keep_alive => 1);
my $req = HTTP::Request->new(GET => $url);
$req->header(Connection => "close");
my $res = $ua->request($req);

is($res->code, 200, "\$res->code == 200 [$url]") or print $res->as_string;
like($res->header("Content-Type"), qr/ftp-dir-listing/, "Content-Type [$url]");
like($res->content, qr/README/, "Content match [$url]");

$url = "ftp://ftp.mozilla.org/pub/README";
$req = HTTP::Request->new(GET => $url);
$res = $ua->request($req);

# do not print the contents in a real test -- it contains 'not' :-)
is($res->header("Content-Type"), 'application/octet-stream', "Content-Type [$url]");  # was text/plain
like($res->content, qr/mirrors\.html/, "Content match [$url]");


# perl
use strict;
use warnings;
use Test::More tests => 5;

my $core = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
use_ok($core);
use_ok('HTTP::Request');
use_ok('Digest::MD5', qw(md5_base64));

my $url = "http://jigsaw.w3.org/HTTP/h-content-md5.html";
my $ua  = $core->new(keep_alive => 1);
my $req = HTTP::Request->new(GET => $url);
$req->header("TE", "deflate");
my $res = $ua->request($req);

is($res->header("Content-MD5"), md5_base64($res->content) . "==", "\$res->header('Content-MD5') [$url]");

$req->header("If-None-Match" => $res->header("etag"));
$res = $ua->request($req);

is($res->code, 304, "\$res->code [$url] w/ etag") or print $res->as_string;
# && $res->header("Client-Response-Num") == 2;

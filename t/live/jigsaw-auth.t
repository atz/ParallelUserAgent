# perl
use strict;
use warnings;
use Test::More;

plan tests => 15;

my $core = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
use_ok($core);
use_ok('HTTP::Request');

use vars qw/ $head /;
my $ok_regex = qr/Your browser made it!/;
my $url = "http://jigsaw.w3.org/HTTP/Basic/";
my $ua  = $core->new(keep_alive => 1);
my $req = HTTP::Request->new(GET => $url);
my $res = $ua->request($req);

#print $res->as_string;

is($res->code, 401, "\$res->code == 401") or print $res->as_string;
ok($head = $req->headers, "\$head = \$req->headers");

# authorization_basic returns false value, apparently
ok(!$head->authorization_basic('guest', 'guest'), "\$head->authorization_basic('guest', 'guest')");
is($req->header("Authorization"), 'Basic Z3Vlc3Q6Z3Vlc3Q=', '$req->header("Authorization")');
#ok($res = $ua->simple_request($req), "\$ua->simple_request(\$req)");
ok($res = $ua->request($req), "\$ua->request(\$req)");
is($res->code, 200, '$ua->simple_request($req)->code - [guest:guest]') or print $res->as_string;
like($res->content, $ok_regex, '$res->content match');

#print $res->as_string;
{
    package MyUA;
    use vars qw(@ISA);
    push @ISA, ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');

    my @try = (['foo', 'bar'], ['', ''], ['guest', ''], ['guest', 'guest']);

    sub next_try { shift @try; }

    sub get_basic_credentials {
        my ($self, $realm, $uri, $proxy) = @_;
        # print "$realm:$uri:$proxy => ";
        my $p = $self->next_try() or return;      # get the class' next shot
        # print join("/", @$p), "\n";
        return @$p;
    }
}

{
   package OtherUA;     # a sub-subclass
   use vars qw(@ISA);
   @ISA = qw(MyUA);

   my @try = (['foo', 'bar'], ['', ''], ['guest', ''], ['guest', 'guest']); # our own try list

   sub next_try { shift @try; }     # override method for local list
}

my %classes = (
    MyUA    => $url,
    OtherUA => 'http://jigsaw.w3.org/HTTP/Digest/',
);
foreach my $class (sort keys %classes) {
    my $target = $classes{$class};
    my $desc = "[subclass $class] $target";
    $ua  = $class->new(keep_alive => 1);
    $req = HTTP::Request->new(GET => $target);
    $res = $ua->request($req);
    like($res->content, $ok_regex,             "\$res->content match $desc");
    is($res->header("Client-Response-Num"), 5, "\$res->header('Client-Response-Num') $desc");
    is($res->code, 200,                        "\$res->code") or print $res->as_string;
}

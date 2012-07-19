# -*- perl -*- 
$| = 1; # autoflush

my $DEBUG = 0;
my $CRLF = "\015\012";

# use Data::Dumper;
#
# First we create HTTP server for testing our http protocol
# (this is stolen from libwww's t/local/http.t)

use Test::More;
use vars qw/ $D /;

$D = shift || '';
if ($D eq 'daemon') {       # Avoid Test::More trappings
    require HTTP::Daemon;   # since the whole daemon lives up here before the use_ok.
    my $d = HTTP::Daemon->new(Timeout => 10);

    print "Pleased to meet you at: <URL:", $d->url, ">\n";

    # open(STDOUT, ">/dev/null");
    open(STDOUT, ">foobar.log");

    my $i = 0;
    while ($c = $d->accept) {
        $i++;
        if ($r = $c->get_request) {     # assignment, not conditional
            my $p = ($r->url->path_segments)[1];
            my $func = lc("httpd_" . $r->method . "_$p");
            print "$i: " . $r->url . " ==> $func\n";
            if (defined &$func) {
                &$func($c, $r);
            } else {
                $c->send_error(404);
            }
        } else {
            print STDERR "$i Failed: Reason was '". $c->reason ."'\n";
        }
        $c = undef;  # close connection
    }
    print STDERR "HTTP Server terminated\n" if $DEBUG;
    close STDOUT;
    done_testing;   # no tests run;
    exit;
} 

plan(tests => 63);
use_ok(qw/ IO::Socket /);
use_ok(qw/ URI /);
use_ok(qw/ Config /);
use_ok(qw/ HTTP::Request /);
use_ok(qw/ HTTP::Daemon /);
# we check HTTP::Daemon even though the rest of the process won't use it, because the child process won't report back in Test style

my $core = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
require_ok($core);

# First we make ourself a daemon in another process

our $Config;
my $perl;
ok($perl = $Config{perlpath}, '$Config{perlpath}');
open(DAEMON, "$perl local/compatibility.t daemon |") or die "Cannot exec daemon: $!";
my $greeting = <DAEMON>;
$greeting =~ /(<[^>]+>)/ or die "No URI found in DAEMON input:\n$greeting";

my $base = URI->new($1) or die "Cannot form URI from $1";
sub url {
   my $u = URI->new(@_);
   $u = $u->abs($_[1]) if @_ > 1;
   $u->as_string;
}

print "Will access HTTP server at $base\n";

# do tests from here on

my $ua = $core->new();
$ua->agent("Mozilla/0.01 " . $ua->agent);
$ua->from('marclang@cpan.org');

# ============
my $url = '/not_found';
my $desc = "Bad request ('$url'): ";
$req = new HTTP::Request GET => url($url, $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;

$req->header(X_Foo => "Bar");
$res = $ua->request($req);

ok(! $res->is_success, $desc .'$res->is_success (should fail)');
is($res->code, 404,    $desc .'$res->code (404)');
ok($res->message =~ /not\s+found/i, $desc . '\$res->message =~ /not\s+found/i');

print STDERR "\t$desc Response was '".$res->code. " ". $res->message."'\n" if $DEBUG;

# we also expect a few headers
ok($res->server, $desc . '\$res->server');
ok($res->date,   $desc . '\$res->date');

# =============
$url = '/echo/path_info?query';
$desc = "Simple echo ('$url'): ";
sub httpd_get_echo
{
    my($c, $req) = @_;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c $req->as_string;
}

$req = new HTTP::Request GET => url("/echo/path_info?query", $base);
$req->push_header(Accept => 'text/html');
$req->push_header(Accept => 'text/plain; q=0.9');
$req->push_header(Accept => 'image/*');
$req->if_modified_since(time - 300);
$req->header(Long_text => 'This is a very long header line
which is broken between
more than one line.');
$req->header(X_Foo => "Bar");

$res = $ua->request($req);
#print $res->as_string;

ok($res->is_success,    $desc . '$res->is_success');
is($res->code, 200,     $desc . '$res->code == 200');
is($res->message, 'OK', $desc . '$res->message eq "OK');

$_ = $res->content;
@accept = /^Accept:\s*(.*)/mg;

like($_, qr/^Host:/m,                             $desc . '/^Host:/m');
is(scalar(@accept), 3,                            $desc . '@accept == 3');
like($_, qr/^Accept:\s*text\/html/m,              $desc . '/^Accept:\s*text\/html/m');
like($_, qr/^Accept:\s*text\/plain/m,             $desc . '/^Accept:\s*text\/plain/m');
like($_, qr/^Accept:\s*image\/\*/m,               $desc . '/^Accept:\s*image\/\*/m');
like($_, qr/^If-Modified-Since:\s*\w{3},\s+\d+/m, $desc . '/^If-Modified-Since:\s*\w{3},\s+\d+/m');
like($_, qr/^Long-Text:\s*This.*broken between/m, $desc . '/^Long-Text:\s*This.*broken between/m');
like($_, qr/^X-Foo:\s*Bar$/m,                     $desc . '/^X-Foo:\s*Bar$/m');
# like($_, qr/^From:\s*marclang\@cpan\.org$/m,      $desc . '/^From:\s*marclang\@cpan\.org$/m');
# like($_, qr/^User-Agent:\s*Mozilla\/0.01/m,       $desc . '/^User-Agent:\s*Mozilla\/0.01/m');
#print $_, "\n\n";

# ===========
my $file = "test-$$.html";
open(FILE, ">$file") or die "Cannot create $file: $!";
binmode FILE or die "Cannot binmode $file: $!";
print FILE <<EOT;
<html><title>Test</title>
<h1>This should work</h1>
Now for something completely different, since it seems that
the file transfer does work ok, right?
EOT
close(FILE);

sub httpd_get_file
{
    my($c, $r) = @_;
    my %form = $r->url->query_form;
    my $file = $form{'name'} or return $c->send_error(400, "Missing parameter 'name'");
    $c->send_file_response($file);
    unlink($file) if $file =~ /^test-/;
}

$url  = "/file?name=$file";
$desc = "Delete URL ('$url'): ";
$req  = new HTTP::Request GET => url($url, $base);
$res  = $ua->request($req);
$_    = $res->content;
ok($res->is_success,                  $desc . '$res->is_success');
is($res->content_type,   'text/html', $desc . '$res->content_type');
is($res->content_length, 151,         $desc . '$res->content_length');
# is($res->title, 'Test',      $desc . '$res->title');  # ->title method no longer exists
ok(/different, since/,                $desc . 'Content =~ /different, since/');

# A second try on the same file, should fail because we unlink it
$res = $ua->request($req);
$desc = "Delete URL ('$url') #2: ";
#print $res->as_string;
ok($res->is_error,  $desc . '$res->is_error');
is($res->code, 404, $desc . '$res->code (404)');
		
# Then try to list current directory
$url  = "/file?name=.";
$desc = "File URL ('$url'): ";
$req  = new HTTP::Request GET => url($url, $base);
$res  = $ua->request($req);
#print $res->as_string;
is($res->code, 501, $desc . '$res->code (501)');
use Data::Dumper;
print Dumper($res). "\nnot " unless $res->code == 501;   # NYI

# =============
$url  = "/redirect/foo";
$desc = "Redirect: ('$url'): ";
$req  = new HTTP::Request GET => url($url, $base);
$res  = $ua->request($req);
#print $res->as_string;

ok($res->is_success,                    $desc . '$res->is_success');
like($res->content, qr|/echo/redirect|, $desc . '$res->content =~ m|/echo/redirect|');
ok($res->previous,                      $desc . '$res->previous');
SKIP: {
    skip("\$res->previous undefined", 2) unless $res->previous;
    ok($res->previous->is_redirect, $desc . '$res->is_redirect');
    is($res->previous->code, 301,   $desc . '$res->previous->code');
}

my $max = $ua->max_redirect;

sub httpd_get_redirect  { shift->send_redirect("/echo/redirect"); }
sub httpd_get_redirect2 { shift->send_redirect('/redirect3/');    }
sub httpd_get_redirect3 { shift->send_redirect('/redirect4/');    }
sub httpd_get_redirect4 { shift->send_redirect('/redirect5/');    }
sub httpd_get_redirect5 { shift->send_redirect('/redirect6/');    }
sub httpd_get_redirect6 { shift->send_redirect('/redirect7/');    }
sub httpd_get_redirect7 { shift->send_redirect('/redirect8/');    }
sub httpd_get_redirect8 { shift->send_redirect('/redirect_loop/');}
sub httpd_get_redirect_loop { shift->send_redirect('/redirect2/');}     # loop -- note Parallel detects a previously hit URI as a loop

$url = "/redirect2";
$desc = "Redirect 2 ('$url'): ";
$req->url(url($url, $base));
$res = $ua->request($req);
#print $res->as_string;
ok($res->is_redirect, $desc . '$res->is_redirect');
like($res->header("Client-Warning"), qr/loop detected/i, $desc . '$res->header("Client-Warning") =~ /loop detected/i');

$i = 0;
while ($res->previous) {
   ok($res = $res->previous, '... $res = $res->previous -- ' . ++$i . " of $max") or last;
}
is($i, $max, "Max $max previous (redirects)");

#----------------------------------------------------------------
sub httpd_get_basic
{
    my($c, $r) = @_;
    #print STDERR $r->as_string;
    my($u,$p) = $r->authorization_basic;
    if (defined($u) && $u eq 'ok 12' && $p eq 'xyzzy') {
        $c->send_basic_header(200);
        print $c "Content-Type: text/plain";
        $c->send_crlf;
        $c->send_crlf;
        $c->print("$u\n");
    } else {
        $c->send_basic_header(401);
        $c->print("WWW-Authenticate: Basic realm=\"libwww-perl\"\015\012");
        $c->send_crlf;
    }
}

{
   package MyUA;
   our @ISA = ($ENV{PERL_LWP_TEST_ENGINE} || 'LWP::UserAgent');
  #use base qw(LWP::Parallel::UserAgent);
   sub get_basic_credentials {
      my($self, $realm, $uri, $proxy) = @_;
      if ($realm and $realm eq "libwww-perl" and $uri->rel($base) eq "basic") {
          return ("ok 12", "xyzzy");
      }
      return undef;
   }
#  sub request { my $self = shift; warn "request()!!!"; return $self->SUPER::request(@_); }
   1;
}
print "Check basic authorization...\n";
$url  = "/basic";
$desc = "Basic auth request ('$url'):";
my $ua2;
ok($req = HTTP::Request->new( GET => url($url, $base) ), $desc . ' $req = HTTP::Request->new(...)');
ok($ua2 = MyUA->new(),         "$desc \$ua2 = MyUA->new()");
ok($res = $ua2->request($req), "$desc \$res = \$ua2->request(\$req)");
#print $res->as_string;

ok($res->is_success, "$desc \$res->is_success") or print STDERR "$desc DUMP:\n" . $res->dump, "\n";

# Lets try with a $ua that does not pass out credentials
$res = $ua->request($req);
is($res->code, 401, "$desc \$res->code == 401");

# Lets try to set credentials for this realm
$ua->credentials($req->url->host_port, "libwww-perl", "ok 12", "xyzzy");
$res = $ua->request($req);
ok($res->is_success, "$desc \$res->is_success") or print STDERR "$desc DUMP:\n" . $res->dump, "\n";

# Then illegal credentials
$ua->credentials($req->url->host_port, "libwww-perl", "user", "passwd");
$res = $ua->request($req);
is($res->code, 401, "$desc \$res->code == 401");

#----------------------------------------------------------------
sub httpd_get_proxy_http
{
   my($c,$r) = @_;
   if ($r->method eq "GET" and
       $r->url->scheme eq "http") {
       $c->send_basic_header(200);
       $c->send_crlf;
   } else {
       $c->send_error;
   }
}

sub httpd_get_proxy_ftp
{
   my($c,$r) = @_;
   if ($r->method eq "GET" and
       $r->url->scheme eq "ftp") {
       $c->send_basic_header(200);
       $c->send_crlf;
   } else {
       $c->send_error;
   }
}


$url  = "ftp://cpan.cpantesters.org/proxy_ftp";
$desc = "FTP proxy ($url): ";
$ua->proxy('ftp' => $base);   # returns old proxy (probaby undef or '')
is($ua->proxy('ftp'), $base, "$desc\$ua->proxy('ftp')");
$req  = HTTP::Request->new(GET => $url);
$res  = $ua->request($req);
$res->is_success or print $res->dump;
ok($res->is_success, $desc . '$res->is_success');

$url  = "http://www.perl.com/proxy_http";
$desc = "HTTP proxy ($url): ";
$ua->proxy('http' => $base);   # returns old proxy (probaby undef or '')
is($ua->proxy('http'), $base, "$desc\$ua->proxy('http')");
$req  = HTTP::Request->new(GET => $url);
$res  = $ua->request($req);
$res->is_success or print $res->dump;
ok($res->is_success, $desc . '$res->is_success');

$ua->no_proxy();

#----------------------------------------------------------------
print "Check POSTing...\n";
sub httpd_post_echo {
   my($c,$r) = @_;
   $c->send_basic_header;
   $c->print("Content-Type: text/plain");
   $c->send_crlf;
   $c->send_crlf;
   $c->print($r->as_string);
}

$url = "/echo/foo";
$desc = "HTTP POST ($url): ";
$req = HTTP::Request->new(POST => url($url, $base));
$req->content_type("application/x-www-form-urlencoded");
$req->content("foo=bar&bar=test");
$res = $ua->request($req);
#print $res->as_string;

ok($res->is_success, $desc . '$res->is_success');
$_ = $res->content;
like($_, qr/^Content-Length:\s*16$/mi, $desc . 'Content-Length:');
like($_, qr/^Content-Type:\s*application\/x-www-form-urlencoded$/mi, $desc . '/^Content-Type:\s*application\/x-www-form-urlencoded$/mi');
like($_, qr/^foo=bar&bar=test/m, $desc . '/^foo=bar&bar=test/m');

#----------------------------------------------------------------
print "\nTerminating server...\n";
sub httpd_get_quit {
    shift->send_error(503, "Bye, bye");
    exit;  # terminate HTTP server
}

$req = HTTP::Request->new(GET => url("/quit", $base));
SKIP: {
    $core eq 'LWP::Parallel::UserAgent' or skip("LWP::Parallel::UserAgent specific tests (not $core)", 3);
    $ua->initialize;
    print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
    ok(!($res = $ua->register($req)), '! $ua->register($req)');     # for some reason, register returns an object IFF fail
    print STDERR $res->error_as_HTML if $res;

    my $entries = $ua->wait(5);
    foreach (keys %$entries) {
        # each entry available under the url-string of their request contains
        # a number of fields. The most important are $entry->request and $entry->response.
        $res = $entries->{$_}->response;
        print STDERR "Answer for '",$res->request->url, "' was \t",
              $res->code,": ", $res->message,"\n" if $DEBUG;
        is($res->code, 503, '$res->code (503)');
        like($res->content, qr/Bye, bye/, '$res->content =~ /Bye, bye/');
    }
}

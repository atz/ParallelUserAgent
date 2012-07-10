# -*- perl -*- 
$| = 1; # autoflush

my $DEBUG = 0;
my $CRLF = "\015\012";

# use Data::Dumper;
#
# First we create HTTP server for testing our http protocol
# (this is stolen from the libwww t/local/http.t file)

use Test::More;
use vars qw/ $D /;

$D = shift || '';
if ($D eq 'daemon') {       # Avoid Test::More trappings
    require HTTP::Daemon;   # since the whole daemon lives up here before the use_ok.
    my $d = HTTP::Daemon->new(Timeout => 10);

    print "Pleased to meet you at: <URL:", $d->url, ">\n";

    open(STDOUT, ">/dev/null");

    while ($c = $d->accept) {
        if ($r = $c->get_request) {     # assignment, not conditional
            my $p = ($r->url->path_segments)[1];
            my $func = lc("httpd_" . $r->method . "_$p");
            if (defined &$func) {
                &$func($c, $r);
            } else {
                $c->send_error(404);
            }
        } else {
            print STDERR "Failed: Reason was '". $c->reason ."'\n";
        }
        $c = undef;  # close connection
    }
    print STDERR "HTTP Server terminated\n" if $DEBUG;
    done_testing;   # no tests run;
    exit;
} 

plan(tests => 60);
use_ok(qw/ IO::Socket /);
use_ok(qw/ URI /);
use_ok(qw/ Config /);
use_ok(qw/ LWP::Parallel::UserAgent /);
use_ok(qw/ HTTP::Request /);
use_ok(qw/ HTTP::Daemon /);

# First we make ourself a daemon in another process

our $Config;
my $perl;
ok($perl = $Config{perlpath}, '$Config{perlpath}');
open(DAEMON, "$perl local/compatibility.t daemon |") or die "Cannot exec daemon: $!";
my $greeting = <DAEMON>;
$greeting =~ /(<[^>]+>)/ or die "No URI found in DAEMON input:\n$greeting";

my $base = URI->new($1);
sub url {
   my $u = URI->new(@_);
   $u = $u->abs($_[1]) if @_ > 1;
   $u->as_string;
}

print "Will access HTTP server at $base\n";

# do tests from here on

my $ua = new LWP::Parallel::UserAgent;
$ua->agent("Mozilla/0.01 " . $ua->agent);
$ua->from('marclang@cpan.org');

#----------------------------------------------------------------
print "\nLWP::UserAgent compatibility...\n";

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

ok(/^Host:/m,                             $desc . '/^Host:/m');
is(scalar(@accept), 3,                    $desc . '@accept == 3');
ok(/^Accept:\s*text\/html/m,              $desc . '/^Accept:\s*text\/html/m');
ok(/^Accept:\s*text\/plain/m,             $desc . '/^Accept:\s*text\/plain/m');
ok(/^Accept:\s*image\/\*/m,               $desc . '/^Accept:\s*image\/\*/m');
ok(/^If-Modified-Since:\s*\w{3},\s+\d+/m, $desc . '/^If-Modified-Since:\s*\w{3},\s+\d+/m');
ok(/^Long-Text:\s*This.*broken between/m, $desc . '/^Long-Text:\s*This.*broken between/m');
ok(/^X-Foo:\s*Bar$/m,                     $desc . '/^X-Foo:\s*Bar$/m');
# ok(/^From:\s*marclang\@cpan\.org$/m,      $desc . '/^From:\s*marclang\@cpan\.org$/m');
# ok(/^User-Agent:\s*Mozilla\/0.01/m,       $desc . '/^User-Agent:\s*Mozilla\/0.01/m');
 print $_, "\n\n";

# ===========
print " - Send file...\n";

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
    my $file = $form{'name'};
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

ok($res->is_success,                   $desc . '$res->is_success');
ok($res->content =~ m|/echo/redirect|, $desc . '$res->content =~ m|/echo/redirect|');
ok($res->previous,                     $desc . '$res->previous');
SKIP: {
    skip("\$res->previous undefined", 2) unless $res->previous;
    ok($res->previous->is_redirect, $desc . '$res->is_redirect');
    is($res->previous->code, 301,   $desc . '$res->previous->code');
}

sub httpd_get_redirect  { shift->send_redirect("/echo/redirect"); }
sub httpd_get_redirect2 { shift->send_redirect("/redirect3/") }
sub httpd_get_redirect3 { shift->send_redirect("/redirect4/") }
sub httpd_get_redirect4 { shift->send_redirect("/redirect5/") }
sub httpd_get_redirect5 { shift->send_redirect("/redirect6/") }
sub httpd_get_redirect6 { shift->send_redirect("/redirect2/") }     # loop !

$url = "/redirect2";
$desc = "Redirect 2 ('$url'): ";
$req->url(url($url, $base));
$res = $ua->request($req);
#print $res->as_string;
ok($res->is_redirect, $desc . '$res->is_redirect');
ok($res->header("Client-Warning") =~ /loop detected/i, $desc . '$res->header("Client-Warning") =~ /loop detected/i');

$i = 1;
while ($res->previous) {
   ok($res = $res->previous, '... $res = $res->previous ' . $i++) or last;
}
is($i, 6, 'Six previous (redirects)');

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
   use base qw(LWP::Parallel::UserAgent);
   sub get_basic_credentials {
      my($self, $realm, $uri, $proxy) = @_;
      if ($realm and $realm eq "libwww-perl" and $uri->rel($base) eq "basic") {
          return ("ok 12", "xyzzy");
      }
      return undef;
   }
}
print "Check basic authorization...\n";
$url  = "/basic";
$desc = "Basic request ('$url'):";
ok($req = HTTP::Request->new( GET => url($url, $base) ), $desc . ' $req = HTTP::Request->new(...)');
ok($res = MyUA->new->request($req), "$desc \$res = MyUA->new->request(\$req)");
#print $res->as_string;

ok($res->is_success, "$desc \$res->is_success");
print "$desc " . $res->content, "\n";

# Lets try with a $ua that does not pass out credentials
$res = $ua->request($req);
is($res->code, 401, "$desc \$res->code == 401");

# Lets try to set credentials for this realm
$ua->credentials($req->url->host_port, "libwww-perl", "ok 12", "xyzzy");
$res = $ua->request($req);
ok($res->is_success, "$desc \$res->is_success");

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

$url  = "ftp://ftp.perl.com/proxy_ftp";
$desc = "FTP proxy ($url): ";
$ua->proxy(ftp => $base);
$req = new HTTP::Request GET => $url;
$res = $ua->request($req);
#print $res->as_string;
ok($res->is_success, $desc . '$res->is_success');

$url = "http://www.perl.com/proxy_http";
$desc = "HTTP proxy ($url): ";
$ua->proxy(http => $base);
$req = new HTTP::Request GET => $url;
$res = $ua->request($req);
#print $res->as_string;
ok($res->is_success, '$res->is_success');

$ua->proxy(http => '', ftp => '');

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

$req = new HTTP::Request POST => url("/echo/foo", $base);
$req->content_type("application/x-www-form-urlencoded");
$req->content("foo=bar&bar=test");
$res = $ua->request($req);
#print $res->as_string;

ok($res->is_success, '$res->is_success');
$_ = $res->content;
ok(/^Content-Length:\s*16$/mi, 'Content-Length:');
ok(/^Content-Type:\s*application\/x-www-form-urlencoded$/mi, '/^Content-Type:\s*application\/x-www-form-urlencoded$/mi');
ok(/^foo=bar&bar=test/m, '/^foo=bar&bar=test/m');

#----------------------------------------------------------------
print "\nTerminating server...\n";
sub httpd_get_quit {
    shift->send_error(503, "Bye, bye");
    exit;  # terminate HTTP server
}
$ua->initialize;
$req = new HTTP::Request GET => url("/quit", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
ok($res = $ua->register($req), '$res = $ua->register($req)');
print STDERR $res->error_as_HTML if $res;

$entries = $ua->wait(5);
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;
    is($res->code, 503, '$res->code (503)');
    ok($res->content =~ /Bye, bye/, '$res->content =~ /Bye, bye/');
}

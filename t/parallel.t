$| = 1; # autoflush

$DEBUG = 0;

# use lib ('./lib');

# First we create HTTP server for testing our http protocol
# (this is stolen from the libwww t/local/http.t file)

require IO::Socket;  # make sure this work before we try to make a HTTP::Daemon

# First we make ourself a daemon in another process
my $D = shift || '';
if ($D eq 'daemon') {

    require HTTP::Daemon;

    my $d = new HTTP::Daemon Timeout => 10;

    print "Please to meet you at: <URL:", $d->url, ">\n";
    open(STDOUT, ">/dev/null");

    while ($c = $d->accept) {
	$r = $c->get_request;
	if ($r) {
	    my $p = ($r->url->path_components)[1];
	    my $func = lc("httpd_" . $r->method . "_$p");
	    if (defined &$func) {
		&$func($c, $r);
	    } else {
		$c->send_error(404);
	    }
	}
	$c = undef;  # close connection
    }
    print STDERR "HTTP Server terminated\n" if $DEBUG;
    exit;
} else {
    use Config;
    open(DAEMON, "$Config{'perlpath'} t/parallel.t daemon |") or die "Can't exec daemon: $!";
}

print "1..24\n";

my $greeting = <DAEMON>;
$greeting =~ /(<[^>]+>)/;

require URI::URL;
URI::URL->import;
my $base = new URI::URL $1;

print "Will access HTTP server at $base\n";

# do tests from here on

#use LWP::Debug qw(+);

require LWP::Parallel::UserAgent;
require HTTP::Request;
my $ua = new LWP::Parallel::UserAgent;
$ua->agent("Mozilla/0.01 " . $ua->agent);
$ua->from('marclang@cs.washington.edu');

#----------------------------------------------------------------
print "\nLWP::UserAgent compatibility...\n";

# ============
print " - Bad request...\n";
$req = new HTTP::Request GET => url("/not_found", $base);
$req->header(X_Foo => "Bar");
$res = $ua->request($req);

print "not " unless $res->is_error
                and $res->code == 404
                and $res->message =~ /not\s+found/i;
print "ok 1\n";
# we also expect a few headers
print "not " if !$res->server and !$res->date;
print "ok 2\n";

# =============
print " - Simple echo...\n";
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

print "not " unless $res->is_success
               and  $res->code == 200 && $res->message eq "OK";
print "ok 3\n";

$_ = $res->content;
@accept = /^Accept:\s*(.*)/mg;

print "not " unless /^From:\s*marclang\@cs\.washington\.edu$/m
                and /^Host:/m
                and @accept == 3
	        and /^Accept:\s*text\/html/m
	        and /^Accept:\s*text\/plain/m
	        and /^Accept:\s*image\/\*/m
		and /^If-Modified-Since:\s*\w{3},\s+\d+/m
                and /^Long-Text:\s*This.*broken between/m
		and /^X-Foo:\s*Bar$/m
		and /^User-Agent:\s*Mozilla\/0.01/m;
print "ok 4\n";

# ===========
print " - Send file...\n";

my $file = "test-$$.html";
open(FILE, ">$file") or die "Can't create $file: $!";
binmode FILE or die "Can't binmode $file: $!";
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
    unlink($file);
}

$req = new HTTP::Request GET => url("/file?name=$file", $base);
$res = $ua->request($req);

#print $res->as_string;

print "not " unless $res->is_success
                and $res->content_type eq 'text/html'
                and $res->content_length == 151
		and $res->title eq 'Test'
		and $res->content =~ /different, since/;
print "ok 5\n";		


# A second try on the same file, should fail because we unlink it
$res = $ua->request($req);
#print $res->as_string;
print "not " unless $res->is_error
                and $res->code == 404;   # not found
print "ok 6\n";
		
# Then try to list current directory
$req = new HTTP::Request GET => url("/file?name=.", $base);
$res = $ua->request($req);
#print $res->as_string;
print "not " unless $res->code == 501;   # NYI
print "ok 7\n";

# =============
print " - Check redirect...\n";
sub httpd_get_redirect
{
   my($c) = @_;
   $c->send_redirect("/echo/redirect");
}

$req = new HTTP::Request GET => url("/redirect/foo", $base);
$res = $ua->request($req);
#print $res->as_string;

print "not " unless $res->is_success
                and $res->content =~ m|/echo/redirect|;
print "ok 8\n";
print "not " unless $res->previous->is_redirect
                and $res->previous->code == 301;
print "ok 9\n";

# Let's test a redirect loop too
sub httpd_get_redirect2 { shift->send_redirect("/redirect3/") }
sub httpd_get_redirect3 { shift->send_redirect("/redirect4/") }
sub httpd_get_redirect4 { shift->send_redirect("/redirect5/") }
sub httpd_get_redirect5 { shift->send_redirect("/redirect6/") }
sub httpd_get_redirect6 { shift->send_redirect("/redirect2/") }

$req->url(url("/redirect2", $base));
$res = $ua->request($req);
#print $res->as_string;
print "not " unless $res->is_redirect
                and $res->header("Client-Warning") =~ /loop detected/i;
print "ok 10\n";
$i = 1;
while ($res->previous) {
   $i++;
   $res = $res->previous;
}
print "not " unless $i == 6;
print "ok 11\n";

#---------------------------------------------------------------
print "\nLWP::Parallel::UserAgent interface...";
print "\nSingle bad request..\n";
$req = new HTTP::Request GET => url("/not_found", $base);
$req->header(X_Foo => "Bar");

print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 12\n";
} else {
    print "ok 12\n";
}

my $entries = $ua->wait(5);
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->is_error
                        and $res->code == 404
                        and $res->message =~ /not\s+found/i;

    print "ok 13\n";
    print "not " if !$res->server and !$res->date;
    print "ok 14\n";
}

#----------------------------------------------------------------
print "\nMultiple Requests...\n";
sub httpd_get_page0
{
    my($c) = @_;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c "This is page 0";
}

sub httpd_get_page1
{
    my($c) = @_;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c "This is page 1";
}

sub httpd_get_page2
{
    my($c) = @_;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c "This is page 2";
}

$ua->initialize;
for $i (0..11) {
    my $page = $i % 3;
    $req = new HTTP::Request GET => url("/page$page", $base);
    print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
    if ( $res = $ua->register ($req) ) { 
	print STDERR $res->error_as_HTML;
	print "not";
	last;
    } 
}
print "ok 15\n";

$entries = $ua->wait(5);
foreach (keys %$entries) {
    $res = $entries->{$_}->response;
    my $url = $res->request->url;
    $url =~ /([0-9]+)$/;
    my $num = $1;

    print STDERR "Answer for '$url' was \n\t", 
          $res->code,": ", $res->message," \"", $res->content, "\"\n"
	      if $DEBUG;

    unless ( $res->content =~ /This is page $num/ ) {
	print "not ";
	last;
    }
}
print "ok 16\n";

#----------------------------------------------------------------
print "\nLarger number of requests (40)..\n";

$ua->initialize;

for $i (0..40) {
    my $page = $i % 3;
    $req = new HTTP::Request GET => url("/page$page", $base);
    print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
    if ( $res = $ua->register ($req) ) { 
	print STDERR $res->error_as_HTML;
	print "not";
	last;
    } 
}
print "ok 17\n";
$i=0;
$entries = $ua->wait(5);
foreach (keys %$entries) {
    $res = $entries->{$_}->response;
    my $url = $res->request->url;
    $url =~ /([0-9]+)$/;
    my $num = $1;

    print STDERR "Answer for '$url' was \n\t", 
          $res->code,": ", $res->message," \"", $res->content, "\"\n"
	      if $DEBUG;
    unless ($res->content =~ /This is page $num/) 
    {
	print STDERR "Oops: Answer ($i) for '$url' was \n\t", 
	$res->code,": ", $res->message," \"", $res->content, "\"\n";
	          
	print ("not ");
	last;
    }
    $i++;
}
print "ok 18\n";

#----------------------------------------------------------------

print "Check redirect on/off...\n";

$ua->initialize;
$ua->redirect(1);

$req = new HTTP::Request GET => url("/redirect/foo", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 19\nnot ok 20\n";
} else {
    $entries = $ua->wait(5);
    foreach (keys %$entries) {
	$res = $entries->{$_}->response;
	print "not " unless $res->is_success
	    and $res->content =~ m|/echo/redirect|;
	print "ok 19\n";
	print "not " unless $res->previous->is_redirect
	    and $res->previous->code == 301;
	print "ok 20\n";
	last;
    }
}

$ua->initialize;
$ua->redirect(0);

print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 21\nnot ok 22\n";
} else {
    $entries = $ua->wait(5);
    foreach (keys %$entries) {
	$res = $entries->{$_}->response;
	print "not " if $res->is_success
	    and $res->content =~ m|/echo/redirect|;
	print "ok 21\n";
	print "not " unless $res->code == 301;
	print "ok 22\n";
	last;
    }
}
#----------------------------------------------------------------
print "\nTerminating server...\n";
sub httpd_get_quit
{
    my($c) = @_;
    $c->send_error(503, "Bye, bye");
    exit;  # terminate HTTP server
}
$ua->initialize;
$req = new HTTP::Request GET => url("/quit", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 23\n";
} else {
    print "ok 23\n";
}
$entries = $ua->wait(5);
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->code == 503 and $res->content =~ /Bye, bye/;
    print "ok 24\n";
}


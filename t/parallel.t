$| = 1; # autoflush

$DEBUG = 0;
$NONBLOCK = 0; # set to 1 to try out non-blocking connects (new in 2.51)
# use LWP::Debug qw(+debug +trace);


# uncomment the following line if you want to run these tests from the command
# line using the local version of Parallel::UserAgent (otherwise perl will take
# the already installed version):
use lib ('./lib');

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
	    my $p = ($r->url->path_segments)[1];
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

print "1..13\n";

my $greeting = <DAEMON>;
$greeting =~ /(<[^>]+>)/;

require URI;
my $base = URI->new($1);
sub url {
   my $u = URI->new(@_);
   $u = $u->abs($_[1]) if @_ > 1;
   $u->as_string;
}

print "Will access HTTP server at $base\n";

# do tests from here on

#use LWP::Debug qw(+);

require LWP::Parallel::UserAgent;
require HTTP::Request;
my $ua = new LWP::Parallel::UserAgent;
$ua->agent("Mozilla/0.01 " . $ua->agent);
$ua->from('marclang@cpan.org');
$ua->nonblock($NONBLOCK);  


#---------------------------------------------------------------
print "\nLWP::Parallel::UserAgent interface...";
print "\nSingle bad request..\n";
$req = new HTTP::Request GET => url("/not_found", $base);
$req->header(X_Foo => "Bar");

print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not";
} 
print "ok 1\n";

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

    print "ok 2\n";
    print "not " if !$res->server and !$res->date;
    print "ok 3\n";
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
print "ok 4\n";

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
print "ok 5\n";

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
print "ok 6\n";
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
print "ok 7\n";

#----------------------------------------------------------------
sub httpd_get_echo
{
    my($c, $req) = @_;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c $req->as_string;
}

sub httpd_get_redirect
{
   my($c) = @_;
   $c->send_redirect("/echo/redirect");
}

print "Check redirect on/off...\n";

$ua->initialize;
$ua->redirect(1);

$req = new HTTP::Request GET => url("/redirect/foo", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 8\nnot ok 9\n";
} else {
    $entries = $ua->wait(5);
    foreach (keys %$entries) {
	$res = $entries->{$_}->response;
	print "not " unless $res->is_success
	    and $res->content =~ m|/echo/redirect|;
	print "ok 8\n";
	print "not " unless $res->previous 
                        and $res->previous->is_redirect
          	        and $res->previous->code == 301;
	print "ok 9\n";
	last;
    }
}

$ua->initialize;
$ua->redirect(0);

print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ok 10\nnot ok 11\n";
} else {
    $entries = $ua->wait(5);
    foreach (keys %$entries) {
	$res = $entries->{$_}->response;
	print "not " if $res->is_success
	    and $res->content =~ m|/echo/redirect|;
	print "ok 10\n";
	print "not " unless $res->code == 301;
	print "ok 11\n";
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
    print "not";
} 
print "ok 12\n";

$entries = $ua->wait(5);
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->code == 503 and $res->content =~ /Bye, bye/;
    print "ok 13\n";
}


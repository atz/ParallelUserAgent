$| = 1; # autoflush

$DEBUG = 0;

# uncomment the following line if you want to run these tests from the command
# line using the local version of Parallel::UserAgent (otherwise perl will take
# the already installed version):
# use lib ('./lib');

# First we create HTTP server for testing our http protocol
# (this is stolen from the libwww t/local/http.t file)

require IO::Socket;  # make sure this work before we try to make a HTTP::Daemon

# First we make ourself a daemon in another process
my $D = shift || '';
if ($D eq 'daemon') 
  {
    # I am the Daemon
    require HTTP::Daemon;

    my $d = new HTTP::Daemon Timeout => 10;

    print "Please to meet you at: <URL:", $d->url, ">\n";
    open(STDOUT, ">/dev/null");

    my $slave;
    &handle_connection($slave) while $slave = $d->accept;
    print STDERR "HTTP Server terminated\n" if $DEBUG;
    exit 0;
  } else {  
    # I am the testing program
    use Config;
    open(DAEMON, "$Config{'perlpath'} t/timeouts.t daemon |") or die "Can't exec daemon: $!";
  }

sub handle_connection {
  my $connection = shift;       # HTTP::Daemon::ClientConn

  my $pid = fork;
  if ($pid) {                   # spawn OK, and I'm the parent
    close $connection;
    return;
  }
  ## spawn failed, or I'm a good child
  my $request = $connection->get_request;
  if (defined($request)) {
    my $p = ($request->url->path_components)[1];
    my $func = lc("httpd_" . $request->method . "_$p");
    if (defined &$func) {
      &$func($connection, $request);
    } else {
      $connection->send_error(404);
    }
    close $connection;
    $connection = undef;  # close connection
  }
  exit 0 if defined $pid;       # exit if I'm a good child with a good parent
}

# This is the testing script

print "1..6\n";

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
print "\n - Checking Timeouts:\n";
sub httpd_get_timeout
{
    my($c)  = @_;
    sleep(4); # do not answer for 4 seconds;
    $c->send_basic_header(200);
    print $c "Content-Type: text/plain\015\012";
    $c->send_crlf;
    print $c "This page took 10 seconds";
}

$ua->initialize;
print "   * for single request..\n";
$req = new HTTP::Request GET => url("/timeout", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;

if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not";
} 
print "ok 1\n"; 

$entries = $ua->wait(2); # be impatient

foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->is_error
                        and $res->code == 408    # timeout
                        and $res->message =~ /timeout/i;

    print "ok 2\n";
}

$ua->initialize;
print "   * for multiple requests...\n";

$req = new HTTP::Request GET => url("/timeout", $base);
my $i;
for $i (0..19) {
    print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
    if ( $res = $ua->register ($req) ) { 
	print STDERR $res->error_as_HTML;
	print "not";
	last;
    } 
}
print "ok 3\n";

$entries = $ua->wait(2); # be impatient

foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->is_error
                        and $res->code == 408    # timeout
                        and $res->message =~ /timeout/i;

    print "ok 4\n";
}


#----------------------------------------------------------------
print "\nTerminating server...\n";
sub httpd_get_quit
{
    my($c) = @_;
    $c->send_error(503, "Bye, bye");
    exit;  # terminate HTTP server (does not work anymore since we're forking)
}
$ua->initialize;
$req = new HTTP::Request GET => url("/quit", $base);
print STDERR "\tRegistering '".$req->url."'\n" if $DEBUG;
if ( $res = $ua->register ($req) ) { 
    print STDERR $res->error_as_HTML;
    print "not ";
}
print "ok 5\n";

$entries = $ua->wait();
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
    $res = $entries->{$_}->response;
    print STDERR "Answer for '",$res->request->url, "' was \t", 
          $res->code,": ", $res->message,"\n" if $DEBUG;

    print "not " unless $res->code == 503 and $res->content =~ /Bye, bye/;
    print "ok 6\n";
}


# -*- perl -*-
# $Id: http.pm,v 1.5 1998/11/10 06:01:32 marc Exp $
# derived from http.pm,v 1.43 1998/08/04 12:37:58 aas Exp $

package LWP::Parallel::Protocol::http;

require LWP::Debug;
require HTTP::Response;
require HTTP::Status;
require IO::Socket;
require IO::Select;
use Carp ();

require LWP::Parallel::Protocol;
require LWP::Protocol::http;
@ISA = qw(LWP::Parallel::Protocol LWP::Protocol::http);

use strict;
my $CRLF         = "\015\012";     # how lines should be terminated;
				   # "\r\n" is not correct on all systems, for
				   # instance MacPerl defines it to "\012\015"


# The following 4 methods are more or less a simple breakdown of the
# original $http->request method:
=item ($socket, $fullpath) = $prot->handle_connect ($req, $proxy, $timeout);

This method connects with the server on the machine and port specified
in the $req object. If a $proxy is given, it will translate the
request into an appropriate proxy-request and return the new URL in
the $fullpath argument.

$socket is either an IO::Socket object (in parallel mode), or a
LWP::Socket object (when used via Std. non-parallel modules, such as
LWP::UserAgent) 

=cut

sub handle_connect {
    my ($self, $request, $proxy, $timeout) = @_;

    # check method
    my $method = $request->method;
    unless ($method =~ /^[A-Za-z0-9_!\#\$%&\'*+\-.^\`|~]+$/) {  # HTTP token
	return new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
				  'Library does not allow method ' .
				  "$method for 'http:' URLs";
    }

    my $url = $request->url;
    my($host, $port, $fullpath) = $self->get_address ($proxy, $url);

    # connect to remote site
    my $socket = $self->connect ($host, $port, $timeout);

#  LWP::Debug::debug("Socket is $socket");

# get LINGER get it!
#    my $data = $socket->sockopt(13);  #define SO_LINGER = 13
#    my @a_data = unpack ("ii",$data);
#    $a_data[0] = 1; $a_data[1] = 0;
#    $data = pack ("ii",@a_data);
#
#    $socket->sockopt(13, $data);  #define SO_LINGER = 13    
#    my $newdata = $socket->sockopt(13);  #define SO_LINGER = 13    
#    @a_data = unpack ("ii",$newdata);
#
#    print "Socket $socket: SO_LINGER (", $a_data[0],", ",$a_data[1],")\n";
# got Linger got it!


    ($socket, $fullpath);
}

sub get_address {
    my ($self, $proxy, $url) = @_;
    my($host, $port, $fullpath);

    # Check if we're proxy'ing
    if (defined $proxy) {
	# $proxy is an URL to an HTTP server which will proxy this request
	$host = $proxy->host;
	$port = $proxy->port;
	$fullpath = $url->as_string;
    }
    else {
	$host = $url->host;
	$port = $url->port;
	$fullpath = $url->full_path;
    }
    ($host, $port, $fullpath);
}

sub connect {
    my ($self, $host, $port, $timeout) = @_;
    # this method inherited from LWP::Protocol::http
    my $socket = $self->_new_socket($host, $port, $timeout);
    # currently empty function in LWP::Protocol::http
    # $self->_check_sock($request, $socket);
#  LWP::Debug::debug("Socket is $socket");
	    
    $socket;
}

sub write_request {
  my ($self, $request, $socket, $fullpath, $arg, $timeout) = @_;

  my $method = $request->method;
  my $url    = $request->url;

 LWP::Debug::trace ("write_request (".
		    (defined $request ? $request : '[undef]').
		    ", ". (defined $socket ? $socket : '[undef]').
		    ", ". (defined $fullpath ? $fullpath : '[undef]').
		    ", ". (defined $arg ? $arg : '[undef]').
		    ", ". (defined $timeout ? $timeout : '[undef]'). ")");

  my $sel = IO::Select->new($socket) if $timeout;

  my $request_line = "$method $fullpath HTTP/1.0$CRLF";
  
  my $h = $request->headers->clone;
  my $cont_ref = $request->content_ref;
  $cont_ref = $$cont_ref if ref($$cont_ref);
  my $ctype = ref($cont_ref);

  # If we're sending content we *have* to specify a content length
  # otherwise the server won't know a messagebody is coming.
  if ($ctype eq 'CODE') {
    die 'No Content-Length header for request with dynamic content'
      unless defined($h->header('Content-Length')) ||
	$h->content_type =~ /^multipart\//;
    # For HTTP/1.1 we could have used chunked transfer encoding...
  } else {
    $h->header('Content-Length' => length $$cont_ref)
      if defined($$cont_ref) && length($$cont_ref);
  }  
    
  # HTTP/1.1 will require us to send the 'Host' header, so we might
  # as well start now.
  my $hhost = $url->netloc;
  $hhost =~ s/^([^\@]*)\@//;  # get rid of potential "user:pass@"
  $h->header('Host' => $hhost) unless defined $h->header('Host');
  
  # add authorization header if we need them.  HTTP URLs do
  # not really support specification of user and password, but
  # we allow it.
  if (defined($1) && not $h->header('Authorization')) {
    $h->authorization_basic($url->user, $url->password);
  }
  
  my $buf = $request_line . $h->as_string($CRLF) . $CRLF;
  my $n;  # used for return value from syswrite/sysread

  # die's will be caught if user specified "use_eval".
  die "write timeout" if $timeout && !$sel->can_write($timeout);
  $n = $socket->syswrite($buf, length($buf));
  die $! unless defined($n);
  die "short write" unless $n == length($buf);
  LWP::Debug::conns($buf);
  
  if ($ctype eq 'CODE') {
    while ( ($buf = &$cont_ref()), defined($buf) && length($buf)) {
      die "write timeout" if $timeout && !$sel->can_write($timeout);
      $n = $socket->syswrite($buf, length($buf));
      die $! unless defined($n);
      die "short write" unless $n == length($buf);
      LWP::Debug::conns($buf);
    }
  } elsif (defined($$cont_ref) && length($$cont_ref)) {
    die "write timeout" if $timeout && !$sel->can_write($timeout);
    $n = $socket->syswrite($$cont_ref, length($$cont_ref));
    die $! unless defined($n);
    die "short write" unless $n == length($$cont_ref);
    LWP::Debug::conns($buf);
  }
  
  # For a HTTP request, the 'command' socket is the same as the
  # 'listen' socket, so we just return the socket here.
  # (In the ftp module, we usually have one socket being the command
  # socket, and another one being the read socket, so that's why we
  # have this overhead here)
  return $socket;
}

# whereas 'handle_connect' (with its submethods 'get_address' and
# 'connect') and 'write_request' mainly just encapsulate different
# parts of the old http->request method, 'read_chunk' has an added
# level of complexity. This is because we have to be content with
# whatever data is available, and somehow 'save' our current state
# between multiple calls.

# To faciliate things later, when we need redirects and
# authentication, we insist that we _always_ have a response object
# available, which is generated outside and initialized with bogus
# data (code = 0). Also, we can then save ourselves the trouble of
# using a call-by-variable for $response in order to return a freshly
# generated $response-object.

# We have to provide IO::Socket-objects with a pushback mechanism,
# which comes pretty handy in case we can't use all the information read
# so far. Instead of changing the IO::Socket code, we just have our own
# little pushback buffer, $pushback, indexed by $socket object here.

my %pushback;

sub read_chunk {
  my ($self, $response, $socket, $request, $arg, $size, 
      $timeout, $entry) = @_;

 LWP::Debug::trace ("read_chunk (".
		    (defined $response ? $response : '[undef]').
		    ", ". (defined $socket ? $socket : '[undef]').
		    ", ". (defined $request ? $request : '[undef]').
		    ", ". (defined $arg ? $arg : '[undef]').
		    ", ". (defined $size ? $size : '[undef]').
		    ", ". (defined $timeout ? $timeout : '[undef]').
		    ", ". (defined $entry ? $entry : '[undef]'). ")");

  # hack! Can we just generate a new Select object here? Or do we
  # have to take the one we created in &write_request?!?
  my $sel = IO::Select->new($socket) if $timeout;

  LWP::Debug::debug('reading response');

  my $buf = "";
  # read one chunk at a time from $socket
  
  if ( $timeout && !$sel->can_read($timeout) ) {
      $response->message("Read Timeout");
      $response->code(&HTTP::Status::RC_REQUEST_TIMEOUT);
      $response->request($request);
      return 0; # EOF
  };
  my $n = $socket->sysread($buf, $size, length($buf));
  unless (defined ($n)) {
      $response->message("Sysread Error: $!"); 
      $response->code(&HTTP::Status::RC_SERVICE_UNAVAILABLE);
      $response->request($request);
      return 0; # EOF
  };
  # need our own EOF detection here
  unless ( $n ) {
      unless ($response  and  $response->code) {
	  $response->message("Unexpected EOF while reading response");
	  $response->code(&HTTP::Status::RC_BAD_GATEWAY);
	  $response->request($request);
	  return 0; # EOF
      }
  }

  LWP::Debug::conns($buf);
  
  # determine Protocol type and create response object
  unless ($response  and  $response->code) {
    if ($buf =~ s/^(HTTP\/\d+\.\d+)[ \t]+(\d+)[ \t]*([^\012]*)\012//) { #1.39
      # HTTP/1.0 response or better
      my($ver,$code,$msg) = ($1, $2, $3);
      $msg =~ s/\015$//;
      LWP::Debug::debug("$ver $code $msg");
      $response->code($code);
      $response->message($msg);
      $response->protocol($ver);
      # store $request info in $response object
      $response->request($request);
    } elsif ((length($buf) >= 5 and $buf !~ /^HTTP\//) or
	     $buf =~ /\012/ ) {
      # HTTP/0.9 or worse
      LWP::Debug::debug("HTTP/0.9 assume OK");
      $response->code(&HTTP::Status::RC_OK);
      $response->message("OK");
      $response->protocol('HTTP/0.9');
      # store $request info in $response object
      $response->request($request);
    } else {
      # need more data
      LWP::Debug::debug("need more data to know which protocol");
    }
  }
  
  # if we have a protocol, read headers if neccessary
  if ( $response && !&headers($response) ) {
    # ensure that we have read all headers.  The headers will be
    # terminated by two blank lines
    unless ($buf =~ /^\015?\012/ || $buf =~ /\015?\012\015?\012/) {
      # must read more if we can...
      LWP::Debug::debug("need more data for headers");
    } else {
      # now we start parsing the headers.  The strategy is to
      # remove one line at a time from the beginning of the header
      # buffer ($buf).
      my($key, $val);
      while ($buf =~ s/([^\012]*)\012//) {
	my $line = $1;
	
	# if we need to restore as content when illegal headers
	# are found.
	my $save = "$line\012"; 
	
	$line =~ s/\015$//;
	last unless length $line;
	
	if ($line =~ /^([a-zA-Z0-9_\-]+)\s*:\s*(.*)/) {
	  $response->push_header($key, $val) if $key;
	  ($key, $val) = ($1, $2);
	} elsif ($line =~ /^\s+(.*)/) {
	  unless ($key) {
	      $response->header("Client-Warning" =>
				=> "Illegal continuation header");
	      $buf = "$save$buf";
	      last;
	  }
	  $val .= " $1";   # 1.39 ?
	  # $buf .= " $1"; # 1.31
	} else {
	    $response->header("Client-Warning" =>
			      "Illegal header '$line'");
	    $buf = "$save$buf";
	    last;
	}
      }
      $response->push_header($key, $val) if $key;

      # check to see if we have any header at all
      unless (&headers($response)) {
	# we need at least one header to go on
	$response->header ("Client-Date" => 
			   HTTP::Date::time2str(time));
      }
    } # of if then else
  } # of if $response
  
  # if we have both a response AND the headers, start parsing the rest
  if ( $response && &headers($response) ) {
    # need to read content
    # can't use $self->collect, since we don't want to give up
    # control (by letting Protocol::collect use a $collector callback)
    my $retval = $self->receive($arg, $response, \$buf, $entry);
    # A return value lower than zero means a command from our 
    # callback function. Make sure it reaches ParallelUA:
    #	return (defined($retval) and (0 > $retval) ? 
    #		$retval : $n);
    ## This is all not yet 100% working here I fear... 
    return (defined $retval? $retval : $n);
  }
  
  $pushback{$socket} = $buf if $buf;
  
  return $n;
}

# This function indicates if we have already parsed the headers.  In
# case of HTTP/0.9 we (obviously?!) don't have any (which means that
# we already 'parsed' them, so return 'true' no matter what)

sub headers {
    my ($response) = @_;

    return 1  if $response->protocol eq 'HTTP/0.9';

    ($response->headers_as_string ? 1 : 0);
}

sub close_connection {
  my ($self, $response, $listen_socket, $request, $cmd_socket) = @_;
#  print "Closing socket $listen_socket\n";
#  $listen_socket->close;
#  $cmd_socket->close;
}

# the old (single request) frontend, defunct.
sub request {
    die "LWP::Parallel::Protocol::http does not support single requests\n";
}

1;

# -*- perl -*-
# $Id: ftp.pm,v 1.5 1998/09/01 06:41:11 marc Exp $
# derived from ftp.pm,v 1.24 1998/07/17 10:37:29 aas Exp $

# Implementation of the ftp protocol (RFC 959). We let the Net::FTP
# package do all the dirty work.

package LWP::Parallel::Protocol::ftp;

use Carp ();

use HTTP::Status ();
use HTTP::Negotiate ();
use HTTP::Response ();
use LWP::MediaTypes ();
use File::Listing ();

require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;
eval {
    require Net::FTP;
    Net::FTP->require_version(2.00);
};
my $init_failed = $@;

=item ($socket, $second_arg) = $prot->handle_connect ($req, $proxy, $timeout);

This method connects with the server on the machine and port specified
in the $req object. If a $procy is given, it will return an error,
since the FTP protocol does not allow proxying. (See below on how such
an error is propagated to the caller).

If successful, the first argument will contain the IO::Socket object
that connects to the specified site. The second argument is empty (for
ftp, that is. See LWP::Protocol::http for different usage).

If the connection fails, $socket is set to 'undef', and the second
argument contains a HTTP::Response object holding a textual
representation of the error. (You can use its 'code' and 'message'
methods to find out what went wrong)

=cut

sub handle_connect {
  my ($self, $request, $proxy, $timeout) = @_;
  
  # mostly directly copied from the original Protocol::ftp, changes
  # are marked with "# ML" comment (mostly return values)

  # check proxy
  if (defined $proxy)
    {
      return (undef, new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
	      'You can not proxy through the ftp'); # ML
    }
  
  my $url = $request->url;
  if ($url->scheme ne 'ftp') {
    my $scheme = $url->scheme;
    return (undef, new HTTP::Response &HTTP::Status::RC_INTERNAL_SERVER_ERROR,
	    "LWP::Protocol::ftp::request called for '$scheme'"); # ML
  }
  
  # check method
  my $method = $request->method;
  
  unless ($method eq 'GET' || $method eq 'HEAD' || $method eq 'PUT') {
    return (undef, new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
	    'Library does not allow method ' .
	    "$method for 'ftp:' URLs"); # ML
  }
  
  if ($init_failed) {
    return (undef, new HTTP::Response &HTTP::Status::RC_INTERNAL_SERVER_ERROR,
	    $init_failed); # ML
  }
  
  my $host     = $url->host;
  my $port     = $url->port;
  # taken out some additional variable declarations here, that are now
  # only needed in 'write_request' method.  

  alarm($timeout) if $self->use_alarm and $timeout; # ML
  my $ftp = new Net::FTP $host, Port => $port;
  alarm(0) if $self->use_alarm; # ML

  my $response;
  unless ($ftp) {
    $response = new HTTP::Response &HTTP::Status::RC_INTERNAL_SERVER_ERROR,$@;
  } else {
    # Create an initial response object
    $response = new HTTP::Response &HTTP::Status::RC_OK, "Document follows";
    $response->request($request);
  } 

  return ($ftp, $response); # ML
}

sub write_request {
  my ($self, $request, $ftp, $response, $arg, $timeout) = @_;

  # Some of the following variable declarations, directly copied from
  # the original Protocol::ftp module, appear both in 'handle_connect'
  # _and_ 'write_request' method. Although it introduces additional
  # overhead, we can't pass additional variables between those two
  # methods, but we need some of the values in both routines.  We
  # allow the account to be specified in the "Account" header
  my $acct     = $request->header('Account');
  
  my $url = $request->url;
  my $host     = $url->host;
  my $port     = $url->port;
  my $user     = $url->user;
  my $password = $url->password;
  
  # If a basic autorization header is present than we prefer these over
  # the username/password specified in the URL.
  {
    my($u,$p) = $request->authorization_basic;
    if (defined $u) {
      $user = $u;
      $password = $p;
    }
  }
  
  my $method = $request->method;

  # from here on mostly directly clipped from the original
  # Protocol::ftp. Changes are marked with "# ML" comment

  alarm($timeout) if $self->use_alarm and $timeout; # ML
  my $mess = $ftp->message;	# welcome message
  alarm(0) if $self->use_alarm; # ML

  LWP::Debug::debug($mess);
  $mess =~ s|\n.*||s; # only first line left  
    $mess =~ s|\s*ready\.?$||;
  # Make the version number more HTTP like
  $mess =~ s|\s*\(Version\s*|/| and $mess =~ s|\)$||;
  $response->header("Server", $mess);
  
  # from here on it seems FTP will handle timeouts, right? # ML
  $ftp->timeout($timeout) if $timeout;
  
  LWP::Debug::debug("Logging in as $user (password $password)...");
  unless ($ftp->login($user, $password, $acct)) {
    # Unauthorized.  Let's fake a RC_UNAUTHORIZED response
    my $res = new HTTP::Response &HTTP::Status::RC_UNAUTHORIZED, $ftp->message;
    $res->header("WWW-Authenticate", qq(Basic Realm="FTP login"));
    return (undef, $res); # ML
  }
  LWP::Debug::debug($ftp->message);
  
  # Get & fix the path
  my @path =  $url->path_components;
  shift(@path);			# There will always be an empty first component
  pop(@path) while @path && $path[-1] eq ''; # remove empty tailing comps
  my $remote_file = pop(@path);
  $remote_file = '' unless defined $remote_file;
  
  my $params = $url->params;
  if (defined($params) && $params eq 'type=a') {
    $ftp->ascii;
  } else {
    $ftp->binary;
  }
  
  for (@path) {
    LWP::Debug::debug("CWD $_");
    unless ($ftp->cwd($_)) {
      return (undef, new HTTP::Response &HTTP::Status::RC_NOT_FOUND,
	      "Can't chdir to $_");
    }
  }
  
  if ($method eq 'GET' || $method eq 'HEAD') {
    # new in ftp.pm,v 1.23 (fixed in ftp.pm,v 1.24)
    LWP::Debug::debug("MDTM");
    if (my $mod_time = $ftp->mdtm($remote_file)) {
      $response->last_modified($mod_time);
      if (my $ims = $request->if_modified_since) {
	if ($mod_time <= $ims) {
	  $response->code(&HTTP::Status::RC_NOT_MODIFIED);
	  $response->message("Not modified");
	  return $response;
	}
      }
    }
    # end_of_new_stuff

    my $data;			# the data handle
    LWP::Debug::debug("retrieve file?");
    if (length($remote_file) and $data = $ftp->retr($remote_file)) {
      # remove reading from socket into 'read_chunk' method. 
      # just return our new $listen_socket here. 
      my($type, @enc) = LWP::MediaTypes::guess_media_type($remote_file);
      $response->header('Content-Type',   $type) if $type;
      for (@enc) {
	$response->push_header('Content-Encoding', $_);
      }
      my $mess = $ftp->message;
      LWP::Debug::debug($mess);
      if ($mess =~ /\((\d+)\s+bytes\)/) {
	$response->header('Content-Length', "$1");
      }
      return ($data, $response);	# ML
    } elsif (!length($remote_file) || $ftp->code == 550) {
      # no file, the remote file is actually a directory, so cdw into directory
      if (length($remote_file) && !$ftp->cwd($remote_file)) {
	LWP::Debug::debug("chdir before listing failed");
	return (undef, new HTTP::Response &HTTP::Status::RC_NOT_FOUND,
		"File '$remote_file' not found"); # ML
      }
      
      # It should now be safe to try to list the directory
      LWP::Debug::debug("dir");
      my @lsl = $ftp->dir;
      
      # Try to figure out if the user want us to convert the
      # directory listing to HTML.
      my @variants =
	(
	 ['html',  0.60, 'text/html'            ],
	 ['dir',   1.00, 'text/ftp-dir-listing' ]
	);
      #$HTTP::Negotiate::DEBUG=1;
      my $prefer = HTTP::Negotiate::choose(\@variants, $request);
      
      my $content = '';
      
      if (!defined($prefer)) {
	return (undef, new HTTP::Response &HTTP::Status::RC_NOT_ACCEPTABLE,
		"Neither HTML nor directory listing wanted"); # ML
      } elsif ($prefer eq 'html') {
	$response->header('Content-Type' => 'text/html');
	$content = "<HEAD><TITLE>File Listing</TITLE>\n";
	my $base = $request->url->clone;
	my $path = $base->epath;
	$base->epath("$path/") unless $path =~ m|/$|;
	$content .= qq(<BASE HREF="$base">\n</HEAD>\n);
	$content .= "<BODY>\n<UL>\n";
	for (File::Listing::parse_dir(\@lsl, 'GMT')) {
	  my($name, $type, $size, $mtime, $mode) = @$_;
	  $content .= qq(  <LI> <a href="$name">$name</a>);
	  $content .= " $size bytes" if $type eq 'f';
	  $content .= "\n";
	}
	$content .= "</UL></body>\n";
      } else {
	$response->header('Content-Type', 'text/ftp-dir-listing');
	$content = join("\n", @lsl, '');
      }
      
      $response->header('Content-Length', length($content));

      if ($method ne 'HEAD') {
	$self->receive_once($arg, $response, $content);
	return (undef, $response);
      }
    } else {
      my $res = new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
      "FTP return code " . $ftp->code;
      $res->content_type("text/plain");
      $res->content($ftp->message);
      return (undef, $res); # ML
    }
  } elsif ($method eq 'PUT') {
    # method must be PUT
    unless (length($remote_file)) {
      return (undef, new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
	      "Must have a file name to PUT to"); # ML
    }
    my $data;
    if ($data = $ftp->stor($remote_file)) {
      LWP::Debug::debug($ftp->message);
      LWP::Debug::debug("$data");
      my $content = $request->content;
      my $bytes = 0;
      if (defined $content) {
	if (ref($content) eq 'SCALAR') {
	  $bytes = $data->write($$content, length($$content));
	} elsif (ref($content) eq 'CODE') {
	  my($buf, $n);
	  while (length($buf = &$content)) {
	    $n = $data->write($buf, length($buf));
	    last unless $n;
	    $bytes += $n;
	  }
	} elsif (!ref($content)) {
	  if (defined $content && length($content)) {
	    $bytes = $data->write($content, length($content));
	  }
	} else {
	  die "Bad content";
	}
      }
      $data->close;
      LWP::Debug::debug($ftp->message);
      
      $response->code(&HTTP::Status::RC_CREATED);
      $response->header('Content-Type', 'text/plain');
      $response->content("$bytes bytes stored as $remote_file on $host\n")
    } else {
      my $res = new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
      "FTP return code " . $ftp->code;
      $res->content_type("text/plain");
      $res->content($ftp->message);
      return (undef, $res);	# ML
    }  
  } else {
    return (undef, new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
	    "Illegal method $method"); # ML
  }
  return (undef, $response);
}

sub read_chunk {
  my ($self, $response, $data, $request, $arg, $size, $timeout, $entry) = @_;
  
  my $method = $request->method;
  if ($method ne 'HEAD') {
    LWP::Debug::debug('reading response');

    my $buf = "";
    # read one chunk at a time from $socket
    my $bytes_read;
    # decide whether to use 'read' or 'sysread'
    if ($self->parallel) {
      $bytes_read = $data->sysread( $buf, $size );	# IO::Socket
    } else {
      alarm($timeout) if $self->use_alarm and $timeout;
      $bytes_read = $data->read(\$buf, undef, $timeout);	# LWP::Socket
      alarm(0) if $self->use_alarm;
    }
        
    # parse data from server
    my $retval = $self->receive($arg, $response, \$buf, $entry);
    # A return value lower than zero means a command from our 
    # callback function. Make sure it reaches ParallelUA:
    #	return (defined($retval) and (0 > $retval) ? 
    #		$retval : $bytes_read);
    return (defined $retval? $retval : $bytes_read);
  }
}
 
sub close_connection {
  my ($self, $response, $data, $request, $ftp) = @_;

  my $method = $request->method;
  if ($method ne 'HEAD') {
    unless ($data->close) {
      # Something did not work too well
      $response->code(&HTTP::Status::RC_INTERNAL_SERVER_ERROR);
      $response->message("FTP close response: " . $ftp->code .
			 " " . $ftp->message);
    }
  }
}

sub request
{
  my($self, $request, $proxy, $arg, $size, $timeout) = @_;
  
  $size = 4096 unless $size;
  
  LWP::Debug::trace('()');

  # handle connect already gives us our response object
  # porting remark: ParallelUA expects this function to return
  # ($socket, $fullpath). Luckily, the Net::FTP is a IO::Socket::INET
  # object, so ParallelUA won't notice the difference between the
  # $socket object returned by http.pm's "handle_connect" method, and
  # the $ftp object returned by ftp.pm's "handle_connect" method :)
  # As for the $fullpath parameter -- ParallelUA doesn't do anything
  # with this value other than passing it as a second argument to 
  # the "write_request" method (well, and storing it in its entry list,
  # in the meantime. But so who cares -- perl certainly doesn't -- if
  # we store a string or a pointer to an object in there!). 
  my ($ftp, $response) = $self->handle_connect ($request, $proxy, $timeout);
  
  # if its status is not "OK", then something went wrong during our
  # call to handle_connect, and we should stop here and return the
  # response object containing the reason for this error:
  return $response unless $response->is_success;
  
  # issue request (in case of error creates Error-Response)
  my ($listen_socket, $error_response) = 
	$self->write_request ($request, $ftp, $response, $arg, $timeout);
  
  unless ($error_response) {
    # now we can start reading from our $listen_socket
    while (1) {
      last unless $self->read_chunk ($response, $listen_socket, 
				     $request, $arg, $size, $timeout, $ftp);
    }
    $self->close_connection ($response, $listen_socket, $request, $ftp);
    $listen_socket = undef;  
  } else {
    $response = $error_response;
  }
    
  $ftp = undef;  # close it (ditto)
  $response;
}

1;

__END__

# This is what RFC 1738 has to say about FTP access:
# --------------------------------------------------
#
# 3.2. FTP
#
#    The FTP URL scheme is used to designate files and directories on
#    Internet hosts accessible using the FTP protocol (RFC959).
#
#    A FTP URL follow the syntax described in Section 3.1.  If :<port> is
#    omitted, the port defaults to 21.
#
# 3.2.1. FTP Name and Password
#
#    A user name and password may be supplied; they are used in the ftp
#    "USER" and "PASS" commands after first making the connection to the
#    FTP server.  If no user name or password is supplied and one is
#    requested by the FTP server, the conventions for "anonymous" FTP are
#    to be used, as follows:
#
#         The user name "anonymous" is supplied.
#
#         The password is supplied as the Internet e-mail address
#         of the end user accessing the resource.
#
#    If the URL supplies a user name but no password, and the remote
#    server requests a password, the program interpreting the FTP URL
#    should request one from the user.
#
# 3.2.2. FTP url-path
#
#    The url-path of a FTP URL has the following syntax:
#
#         <cwd1>/<cwd2>/.../<cwdN>/<name>;type=<typecode>
#
#    Where <cwd1> through <cwdN> and <name> are (possibly encoded) strings
#    and <typecode> is one of the characters "a", "i", or "d".  The part
#    ";type=<typecode>" may be omitted. The <cwdx> and <name> parts may be
#    empty. The whole url-path may be omitted, including the "/"
#    delimiting it from the prefix containing user, password, host, and
#    port.
#
#    The url-path is interpreted as a series of FTP commands as follows:
#
#       Each of the <cwd> elements is to be supplied, sequentially, as the
#       argument to a CWD (change working directory) command.
#
#       If the typecode is "d", perform a NLST (name list) command with
#       <name> as the argument, and interpret the results as a file
#       directory listing.
#
#       Otherwise, perform a TYPE command with <typecode> as the argument,
#       and then access the file whose name is <name> (for example, using
#       the RETR command.)
#
#    Within a name or CWD component, the characters "/" and ";" are
#    reserved and must be encoded. The components are decoded prior to
#    their use in the FTP protocol.  In particular, if the appropriate FTP
#    sequence to access a particular file requires supplying a string
#    containing a "/" as an argument to a CWD or RETR command, it is
#    necessary to encode each "/".
#
#    For example, the URL <URL:ftp://myname@host.dom/%2Fetc/motd> is
#    interpreted by FTP-ing to "host.dom", logging in as "myname"
#    (prompting for a password if it is asked for), and then executing
#    "CWD /etc" and then "RETR motd". This has a different meaning from
#    <URL:ftp://myname@host.dom/etc/motd> which would "CWD etc" and then
#    "RETR motd"; the initial "CWD" might be executed relative to the
#    default directory for "myname". On the other hand,
#    <URL:ftp://myname@host.dom//etc/motd>, would "CWD " with a null
#    argument, then "CWD etc", and then "RETR motd".
#
#    FTP URLs may also be used for other operations; for example, it is
#    possible to update a file on a remote file server, or infer
#    information about it from the directory listings. The mechanism for
#    doing so is not spelled out here.
#
# 3.2.3. FTP Typecode is Optional
#
#    The entire ;type=<typecode> part of a FTP URL is optional. If it is
#    omitted, the client program interpreting the URL must guess the
#    appropriate mode to use. In general, the data content type of a file
#    can only be guessed from the name, e.g., from the suffix of the name;
#    the appropriate type code to be used for transfer of the file can
#    then be deduced from the data content of the file.
#
# 3.2.4 Hierarchy
#
#    For some file systems, the "/" used to denote the hierarchical
#    structure of the URL corresponds to the delimiter used to construct a
#    file name hierarchy, and thus, the filename will look similar to the
#    URL path. This does NOT mean that the URL is a Unix filename.
#
# 3.2.5. Optimization
#
#    Clients accessing resources via FTP may employ additional heuristics
#    to optimize the interaction. For some FTP servers, for example, it
#    may be reasonable to keep the control connection open while accessing
#    multiple URLs from the same server. However, there is no common
#    hierarchical model to the FTP protocol, so if a directory change
#    command has been given, it is impossible in general to deduce what
#    sequence should be given to navigate to another directory for a
#    second retrieval, if the paths are different.  The only reliable
#    algorithm is to disconnect and reestablish the control connection.

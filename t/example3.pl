  require LWP::Parallel::RobotUA;
  use HTTP::Request; 

  # persistent robot rules support. See 'perldoc WWW::RobotRules::AnyDBM_File'
  require WWW::RobotRules::AnyDBM_File;

  # shortcut for demo URLs
  my $url = "http://www.cs.washington.edu/"; 

  my $reqs = [  
     HTTP::Request->new('GET', $url),
	    # these are all redirects. depending on how you set
            # 'redirect_ok' they either just return the status code for
            # redirect (like 302 moved), or continue to follow redirection.
     HTTP::Request->new('GET', $url."research/ahoy/"),
     HTTP::Request->new('GET', $url."research/ahoy/doc/paper.html"),
     HTTP::Request->new('GET', "http://metacrawler.cs.washington.edu:6060/"),
	    # these are all non-existant server. the first one should take
            # some time, but the following ones should be rejected right
            # away
     HTTP::Request->new('GET', "http://www.foobar.foo/research/ahoy/"),
     HTTP::Request->new('GET', "http://www.foobar.foo/foobar/foo/"),
     HTTP::Request->new('GET', "http://www.foobar.foo/baz/buzz.html"),
	    # although server exists, file doesn't
     HTTP::Request->new('GET', $url."foobar/bar/baz.html"),
	    ];

  my ($req,$res);

  # establish persistant robot rules cache. See WWW::RobotRules for
  # non-permanent version. you should probably adjust the agentname
  # and cache filename.
  my $rules = new WWW::RobotRules::AnyDBM_File 'ParallelUA', 'cache';

  # create new UserAgent (actually, a Robot)
  my $pua = new LWP::Parallel::RobotUA ("ParallelUA", 'yourname@your.site.com', $rules);

  $pua->timeout   (2);  # in seconds
  $pua->delay    ( 5);  # in seconds
  $pua->max_req  ( 2);  # max parallel requests per server
  $pua->max_hosts(10);  # max parallel servers accessed
 
  # for our own print statements that follow below:
  local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR

  # register requests
  foreach $req (@$reqs) {
    print "Registering '".$req->url."'\n";
    $pua->register ($req, \&handle_answer);
    #  Each request, even if it failed to # register properly, will
    #  show up in the final list of # requests returned by $pua->wait,
    #  so you can examine it # later.
  }

  # $pua->wait returns a pointer to an associative array, containing
  # an '$entry' for each request made, sorted by its url. (as returned
  # by $request->url->as_string)
  my $entries = $pua->wait(); # give another timeout here, 25 seconds

  # let's see what we got back (see also callback function!!)
  foreach (keys %$entries) {
    $res = $entries->{$_}->response;

    # examine response to find cascaded requests (redirects, etc) and
    # set current response to point to the very first response of this
    # sequence. (not very exciting if you set '$pua->redirect(0)')
    my $r = $res; my @redirects;
    while ($r) { 
	$res = $r; 
	$r = $r->previous; 
	push (@redirects, $res) if $r;
    }
    
    # summarize response. see "perldoc LWP::Response"
    print "Answer for '",$res->request->url, "' was \t", $res->code,": ",
          $res->message,"\n";
    # print redirection history, in case we got redirected
    foreach (@redirects) {
	print "\t",$_->request->url, "\t", $_->code,": ", $_->message,"\n";
    }
  }

  # our callback function gets called whenever some data comes in
  # (same parameter format as standard LWP::UserAgent callbacks!)
  sub handle_answer {
    my ($content, $response, $protocol, $entry) = @_;

    print "Handling answer from '",$response->request->url,": ",
          length($content), " bytes, Code ",
          $response->code, ", ", $response->message,"\n";

    if (length ($content) ) {
	# just store content if it comes in
	$response->add_content($content);
    } else {
        # Having no content doesn't mean the connection is closed!
        # Sometimes the server might return zero bytes, so unless
        # you already got the information you need, you should continue
        # processing here (see below)
        
	# Otherwise you can return a special exit code that will
        # determins how ParallelUA will continue with this connection.

	# Note: We have to import those constants via "qw(:CALLBACK)"!

	# return C_ENDCON;  # will end only this connection
			    # (silly, we already have EOF)
	# return C_LASTCON; # wait for remaining open connections,
			    # but don't issue any new ones!!
	# return C_ENDALL;  # will immediately end all connections
			    # and return from $pua->wait
    }

    # ATTENTION!! If you want to keep reading from your connection,
    # you should have a final 'return undef' statement here. Even if
    # you think that all data has arrived, it does not hurt to return
    # undef here. The Parallel UserAgent will figure out by itself
    # when to close the connection!

    return undef;	    # just keep on connecting/reading/waiting 
                            # until the server closes the connection. 
  }

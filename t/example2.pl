  #
  # provide subclassed Robot to override on_connect, on_failure and
  # on_return methods
  #
  package myUA;

  use Exporter();
  use LWP::Parallel::UserAgent qw(:CALLBACK);
  @ISA = qw(LWP::Parallel::UserAgent Exporter);
  @EXPORT = @LWP::Parallel::UserAgent::EXPORT_OK;

  # redefine methods: on_connect gets called whenever we're about to
  # make a a connection
  sub on_connect {
    my ($self, $request, $response, $entry) = @_;
    print "Connecting to ",$request->url,"\n";
  }

  # on_failure gets called whenever a connection fails right away
  # (either we timed out, or failed to connect to this address before,
  # or it's a duplicate). Please note that non-connection based
  # errors, for example requests for non-existant pages, will NOT call
  # on_failure since the response from the server will be a well
  # formed HTTP response!
  sub on_failure {
    my ($self, $request, $response, $entry) = @_;
    print "Failed to connect to ",$request->url,"\n\t",
          $response->code, ", ", $response->message,"\n"
	    if $response;
  }

  # on_return gets called whenever a connection (or its callback)
  # returns EOF (or any other terminating status code available for
  # callback functions). Please note that on_return gets called for
  # any successfully terminated HTTP connection! This does not imply
  # that the response sent from the server is a success! 
  sub on_return {
    my ($self, $request, $response, $entry) = @_;
    if ($response->is_success) {
       print "\n\nWoa! Request to ",$request->url," returned code ", $response->code, 
          ": ", $response->message, "\n";
       print $response->content;
    } else {
       print "\n\nBummer! Request to ",$request->url," returned code ", $response->code,
          ": ", $response->message, "\n";
       # print $response->error_as_HTML;
    }
    return;
  }

  package main;
  use HTTP::Request; 

  # shortcut for demo URLs
  my $url = "http://localhost/"; 

  my $reqs = [  
     HTTP::Request->new('GET', $url),
     HTTP::Request->new('GET', $url."homes/marclang/"),
  ];

  my $pua = myUA->new();

  foreach my $req (@$reqs) {
    print "Registering '".$req->url."'\n";
    $pua->register ($req);
  }
  my $entries = $pua->wait(); # responses will be caught by on_return, etc


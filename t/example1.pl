  require LWP::Parallel::UserAgent;
  use HTTP::Request; 

  # display tons of debugging messages. See 'perldoc LWP::Debug'
  #use LWP::Debug qw(+);

  # shortcut for demo URLs
  my $url = "http://localhost/"; 

  my $reqs = [  
     HTTP::Request->new('GET', $url),
     HTTP::Request->new('GET', $url."homes/marclang/"),
  ];

  my $pua = LWP::Parallel::UserAgent->new();
  $pua->in_order  (1);  # handle requests in order of registration
  $pua->duplicates(0);  # ignore duplicates
  $pua->timeout   (2);  # in seconds
  $pua->redirect  (1);  # follow redirects

  foreach my $req (@$reqs) {
    print "Registering '".$req->url."'\n";
    if ( my $res = $pua->register ($req) ) { 
	print STDERR $res->error_as_HTML; 
    }  
  }
  my $entries = $pua->wait();

  foreach (keys %$entries) {
    my $res = $entries->{$_}->response;

    print "Answer for '",$res->request->url, "' was \t", $res->code,": ",
          $res->message,"\n";
  }

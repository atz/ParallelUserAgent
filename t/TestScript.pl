require 5.004;

## use this if you don't want to (or can't) install ParallelUA in the
## standard Perl library directory. 
use lib "../lib";  # path to LWP directory of ParallelUA (will be searched 1st)

#
# provide subclassed Robot to override on_connect, on_failure and
# on_return methods
#
package myRobot;

use Exporter();
use LWP::RobotPUA qw(:CALLBACK);
@ISA = qw(LWP::RobotPUA Exporter);
@EXPORT = @LWP::RobotPUA::EXPORT_OK;

# redefine methods: on_connect gets called whenever we're about to
# make a a connection
sub on_connect {
    my ($self, $request, $response, $entry) = @_;
    print "Connecting to ",$request->url,"\n";
}

# on_failure gets called whenever a connection fails right away
# (either we timed out, or failed to connect to this address before,
# or it's a duplicate)
sub on_failure {
    my ($self, $request, $response, $entry) = @_;
    print "Failed to connect to ",$request->url,"\n\t",
          $response->code, ", ", $response->message,"\n"
	    if $response;
}

# on_return gets called whenever a connection (or its callback)
# returns EOF (or any other terminating status code available for
# callback functions)
sub on_return {
    my ($self, $request, $response, $entry) = @_;
    print "Request to ",$request->url," returned. Code ", $response->code,
          ": ", $response->message, "\n";
    return;
}

#
# main package
#
package main;

use HTTP::Request; 

# persistent robot rules support. See 'perldoc WWW::RobotRules::AnyDBM_File'
require WWW::RobotRules::AnyDBM_File;

# display tons of debugging messages. See 'perldoc LWP::Debug'
use LWP::Debug qw(+);

# shortcut for demo URLs
my $url = "http://localhost/index.html"; 

# comment out what you want to try:
my $reqs = [  
	    # 'nice' URLs - these should all work
     HTTP::Request->new('GET', $url),
#     HTTP::Request->new('GET', $url."homes/marclang/"),
#     HTTP::Request->new('GET', "ftp://ftp.spu.edu/"),
#    HTTP::Request->new('GET', "ftp://ftp.spu.edu/README.html"),
#    HTTP::Request->new('GET', "ftp://ftp.spu.edu/HEADER.html"),
#    HTTP::Request->new('GET', $url."homes/marclang/resume.html"),
	    # and now for some duplicates. depending on how you set
            # 'handle_duplicates', they should either be connected 
            # or ignored.
#   HTTP::Request->new('GET', $url),
#   HTTP::Request->new('GET', $url."homes/marclang/"),
#   HTTP::Request->new('GET', $url."homes/marclang/resume.html"),
	    # these are all redirects. depending on how you set
            # 'redirect_ok' they either just return the status code for
            # redirect (like 302 moved), or continue to follow redirection.
#   HTTP::Request->new('GET', $url."research/ahoy/"),
#   HTTP::Request->new('GET', $url."research/ahoy/doc/paper.html"),
#   HTTP::Request->new('GET', "http://metacrawler.cs.washington.edu:6060/"),
	    # these are all non-existant server. the first one should take
            # some time, but the following ones should be rejected right
            # away
#   HTTP::Request->new('GET', "http://www.foobar.foo/research/ahoy/"),
#   HTTP::Request->new('GET', "http://www.foobar.foo/foobar/foo/"),
#   HTTP::Request->new('GET', "http://www.foobar.foo/baz/buzz.html"),
	    # although server exists, file doesn't
#   HTTP::Request->new('GET', $url."foobar/bar/baz.html"),
	    # and now for some FTP
#  HTTP::Request->new('GET', "ftp://localhost/pub/Fig"),
	    ];

my ($req,$res);
# establish persistant robot rules cache. See WWW::RobotRules for
# non-permanent version. you should probably adjust the agentname
# and cache filename.
my $rules = new WWW::RobotRules::AnyDBM_File 'ParallelUA', 'cache';

# create new UserAgent (actually, a Robot)
$pua = new myRobot ("ParallelUA", 'yourname@your.site.com', $rules);
# general ParallelUA settings
$pua->in_order  (1);  # handle requests in order of registration
$pua->duplicates(0);  # ignore duplicates
$pua->timeout   (2);  # in seconds
$pua->redirect  (1);  # follow redirects
# RobotPUA specific settings
$pua->delay    ( 1);  # in seconds
$pua->max_req  ( 1);  # max parallel requests per server
$pua->max_hosts(10);  # max parallel servers accessed

# $pua->max_size(1);

# for our own print statements that follow below:
local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR

# register requests
foreach $req (@$reqs) {
    print "Registering '".$req->url."'\n";

    # we register each request with a callback here, although we might
    # as well specify a (variable) filename here, or leave the second
    # argument blank so that the answer will be stored within the
    # response object (see $pua->wait further down)
    if ( $res = $pua->register ($req , \&handle_answer) ) { 
#    if ( $res = $pua->register ($req) ) { 
	# some requests will produce an error right away, such as
	# request featuring currently unsupported protocols (ftp,
	# gopher) or requests to server that failed to respond during
	# an earlier request.
	# You can examine the reason for this right away:
#	print STDERR $res->error_as_HTML; 
	# or simply ignore it here. Each request, even if it failed to
	# register properly, will show up in the final list of
	# requests returned by $pua->wait, so you can examine it
	# later. If you have overridden the 'on_failure' method of
	# ParallelUA or RobotPUA, it will be called if your request
	# fails.
    }  
}

# start waiting
print "-" x 80,"\n";
# $pua->wait returns a pointer to an associative array, containing
# an '$entry' for each request made, sorted by its url. (as returned
# by $request->url->as_string)
my $entries = $pua->wait(25); # give another timeout here, 25 seconds
# done!
print "-" x 80,"\n";

# let's see what we got back (see also callback function!!)
foreach (keys %$entries) {
    # each entry available under the url-string of their request contains
    # a number of fields. The most important are $entry->request and
    # $entry->response. 
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
	# our return value determins how ParallelUA will continue:
	# We have to import those constants via "qw(:CALLBACK)"!
	# return C_ENDCON;  # will end only this connection
			    # (silly, we already have EOF)
	# return C_LASTCON; # wait for remaining open connections,
			    # but don't issue any new ones!!
	# return C_ENDALL;  # will immediately end all connections
			    # and return from $pua->wait
    }
    # ATTENTION!! If you want to keep reading from your connection,
    # you should currently have a final 'return undef' statement here. 
    # Sometimes ParallelUA will cut the connection if it doesn't
    # get it's "undef" here. (that is, unless you want it to end, in
    # which case you should use the return values above)
    return undef;	    # just keep on connecting/reading/waiting
}


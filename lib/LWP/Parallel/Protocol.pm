#  -*- perl -*-
# $Id: Protocol.pm,v 1.1 1998/03/05 10:18:59 marc Exp $

package LWP::Parallel::Protocol;

=head1 NAME

LWP::Parallel::Protocol - Base class for parallel LWP protocols

=head1 SYNOPSIS

 package LWP::Parallel::Protocol::foo;
 require LWP::Parallel::Protocol;
 @ISA=qw(LWP::Parallel::Protocol);

=head1 DESCRIPTION

This class is used a the base class for all protocol implementations
supported by the LWP::Parallel library. It mirrors the behavior of the
original LWP::Parallel library by subclassing from it and adding a few
subroutines of its own.

Please see the LWP::Protocol for more information about the usage of
this module. 

In addition to the inherited methods from LWP::Protocol, The following 
methods and functions are provided:

=head1 ADDITIONAL METHODS AND FUNCTIONS

=over 4

=cut

#######################################################

require LWP::Protocol;
@ISA = qw(LWP::Protocol);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);


use HTTP::Status 'RC_INTERNAL_SERVER_ERROR';
use strict;
use Carp ();

my %ImplementedBy = (); # scheme => classname


=item $prot = new HTTP::Protocol;

The LWP::Protocol constructor is inherited by subclasses. As this is a
virtual base class this method should B<not> be called directly.

=cut

sub new
{
    my($class) = @_;

    my $self = bless {
	'timeout' => 0,
	'use_alarm' => 1,
	'parse_head' => 1,
    }, $class;
    $self;
}

=item $prot = LWP::Parallel::Protocol::create($url)

Create an object of the class implementing the protocol to handle the
given scheme. This is a function, not a method. It is more an object
factory than a constructor. This is the function user agents should
use to access protocols.

=cut

sub create
{
    my $scheme = shift;
    my $impclass = LWP::Parallel::Protocol::implementor($scheme) or
	Carp::croak("Protocol scheme '$scheme' is not supported");

    # hand-off to scheme specific implementation sub-class
    return $impclass->new($scheme);
}


=item $class = LWP::Parallel::Protocol::implementor($scheme, [$class])

Get and/or set implementor class for a scheme.  Returns '' if the
specified scheme is not supported.

=cut

sub implementor
{
    my($scheme, $impclass) = @_;

    if ($impclass) {
	$ImplementedBy{$scheme} = $impclass;
    }
    my $ic = $ImplementedBy{$scheme};
    return $ic if $ic;

    return '' unless $scheme =~ /^([.+\-\w]+)$/;  # check valid URL schemes
    $scheme = $1; # untaint
    $scheme =~ s/[.+\-]/_/g;  # make it a legal module name

    # scheme not yet known, look for a 'use'd implementation
    $ic = "LWP::Parallel::Protocol::$scheme";  # default location
    no strict 'refs';
    # check we actually have one for the scheme:
    unless (defined @{"${ic}::ISA"}) {
	# try to autoload it
        LWP::Debug::debug("Try autoloading $ic");
	eval "require $ic";
	if ($@) {
	    if ($@ =~ /^Can't locate/) { #' #emacs get confused by '
		$ic = '';
	    } else {
		die "$@\n";
	    }
	}
    }
    $ImplementedBy{$scheme} = $ic if $ic;
    $ic;
}

=item $prot->receive ($arg, $response, $content)

Called to store a piece of content of a request, and process it
appropriately into a scalar, file, or by calling a callback.  If $arg
is undefined, then the content is stored within the $response.  If
$arg is a simple scalar, then $arg is interpreted as a file name and
the content is written to this file.  If $arg is a reference to a
routine, then content is passed to this routine.

$content must be a reference to a scalar holding the content that
should be processed.

The return value from receive() is the $response object reference.

B<Note:> We will only use the file or callback argument if
$response->is_success().  This avoids sendig content data for
redirects and authentization responses to the file or the callback
function.

=cut

sub receive {
    my ($self, $arg, $response, $content, $entry) = @_;

    my($use_alarm, $parse_head, $timeout, $max_size, $parallel) =
      @{$self}{qw(use_alarm parse_head timeout max_size parallel)};

    my $parser;
    if ($parse_head && $response->content_type eq 'text/html') {
	$parser = HTML::HeadParser->new($response->{'_headers'});
    }
    my $content_size = 0;
    
    # Note: We don't need alarms here since we are not making any tcp
    # connections.  All the data we need is alread in \$content, so we
    # just read out a string value -- nothing should slow us down here
    # (other than processor speed or memory constraints :) ) PS: You
    # can't just add 'alarm' somewhere here unless you fix the calls
    # to ->receive in the subclasses such as 'ftp' or 'http' and wrap
    # them in an 'eval' statement that will catch our alarm-exceptions
    # we would throw here! But since we don't need alarms here, just
    # forget what I just said - it's irrelevant.

    if (!defined($arg) || !$response->is_success ) {
	# scalar
	if ($parser) {
	    $parser->parse($$content) or undef($parser);
	}
        LWP::Debug::debug("read " . length($$content) . " bytes");
	$response->add_content($$content);
	$content_size += length($$content);
	if ($max_size && $content_size > $max_size) {
  	    LWP::Debug::debug("Aborting because size limit exceeded");
	    my $tot = $response->header("Content-Length") || 0;
	    $response->header("X-Content-Range", "bytes 0-$content_size/$tot");
	}
    }
    elsif (!ref($arg)) {
	# Mmmh. Could this take so long that we want to use alarm here?
	unless ( open(OUT, ">>$arg") ) {
	    $response->code(RC_INTERNAL_SERVER_ERROR);
	    $response->message("Cannot write to '$arg': $!");
	    return;
	}
        binmode(OUT);
        local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR
	if ($parser) {
	    $parser->parse($$content) or undef($parser);
	}
        LWP::Debug::debug("read " . length($$content) . " bytes");
	print OUT $$content;
	$content_size += length($$content);
	if ($max_size && $content_size > $max_size) {
	    LWP::Debug::debug("Aborting because size limit exceeded");
	    my $tot = $response->header("Content-Length") || 0;
	    $response->header("X-Content-Range", "bytes 0-$content_size/$tot");
	}
	close(OUT);
    }
    elsif (ref($arg) eq 'CODE') {
	# read into callback
	if ($parser) {
	    $parser->parse($$content) or undef($parser);
	}
        LWP::Debug::debug("read " . length($$content) . " bytes");
	my $retval;
	eval {
	    $retval = &$arg($$content, $response, $self, $entry);
	};
	if ($@) {
	    chomp($@);
	    $response->header('X-Died' => $@);
	} else {
	    # pass return value from callback through to implementor class
	  LWP::Debug::debug("return-code from Callback was '$retval'");
	    return $retval; 
	}
    }
    else {
	$response->code(RC_INTERNAL_SERVER_ERROR);
	$response->message("Unexpected collect argument  '$arg'");
    }
    return;
}

=item $prot->receive_once($arg, $response, $content, $entry)

Can be called when the whole response content is available as
$content.  This will invoke receive() with a collector callback that
returns a reference to $content the first time and an empty string the
next.

=cut

sub receive_once {
    my ($self, $arg, $response, $content, $entry) = @_;

    # read once
    my $retval = $self->receive($arg, $response, \$content, $entry);

    # and immediately simulate EOF
    my $no_content = '';  # trick my emacs highlight package
    $retval = $self->receive($arg, $response, \$no_content, $entry) 
	unless $retval;

    return (defined $retval? $retval : 0);
}

1;

=head1 SEE ALSO

Inspect the F<LWP/Parallel/Protocol/http.pm> file for examples of usage.

=head1 COPYRIGHT

Copyright 1997,1998 Marc Langheinrich.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



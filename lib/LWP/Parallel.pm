# -*- perl -*-
# $Id: Parallel.pm,v 1.3 1998/09/03 05:46:48 marc Exp $

package LWP::Parallel;

$VERSION = '2.36';
sub Version { $VERSION };

require 5.004;
require LWP::Parallel::UserAgent;  # this should load everything you need

1;

__END__

=head1 NAME

LWP::Parallel - Extension for LWP to allow parallel HTTP and FTP access

=head1 SYNOPSIS

  use LWP::Parallel;
  print "This is LWP::Parallel_$LWP::Parallel::VERSION\n";

=head1 DESCRIPTION

ParallelUserAgent is an extension to the existing libwww module. It
allows you to take a list of URLs (currently supports only HTTP and
FTP protocol) and connect to all of them _in parallel_, then wait for
the results to come in.

=head1 AUTHOR

Marc Langheinrich, marclang@cs.washington.edu

=head1 SEE ALSO

LWP.pm

=cut

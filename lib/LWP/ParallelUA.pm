# -*- perl -*-
# $Id: ParallelUA.pm,v 1.3 2000/04/20 14:49:09 langhein Exp $

package LWP::ParallelUA;
use Exporter();
use LWP::Parallel::UserAgent qw(:CALLBACK);

require 5.004;
@ISA = qw(LWP::Parallel::UserAgent Exporter);
@EXPORT = qw(); 
@EXPORT_OK = @LWP::Parallel::UserAgent::EXPORT_OK;
%EXPORT_TAGS = %LWP::Parallel::UserAgent::EXPORT_TAGS;

1;

__END__

=head1 NAME

LWP::ParallelUA - Parallel LWP::UserAgent 

=head1 SYNOPSIS

  require LWP::ParallelUA;
  $ua = LWP::ParallelUA->new();

  (see description of LWP::Parallel::UserAgent)

=head1 DESCRIPTION

B<ParallelUA> is a simple frontend to the B<LWP::Parallel::UserAgent>
module. It is here in order to maintain the compatibility with
previous releases. However, in order to prevent the previous need for
changing the original LWP sources, all extension files have been moved
to the LWP::Parallel subtree.

If you start from scratch, maybe you should start using LWP::Parallel
and its submodules directly.

See the L<LWP::Parallel::UserAgent> for the documentation on
this module.

=head1 AUTHOR

Marc Langheinrich, marclang@cs.washington.edu

=head1 SEE ALSO

L<LWP::Parallel::UserAgent>

=head1 COPYRIGHT

Copyright 1997-2000 Marc Langheinrich.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


# -*- perl -*-
# $Id: RobotPUA.pm,v 1.1 1998/03/06 04:59:11 marc Exp $

package LWP::RobotPUA;
use Exporter();
use LWP::Parallel::RobotUA qw(:CALLBACK);

require 5.004;
@ISA = qw(LWP::Parallel::RobotUA Exporter);
@EXPORT = qw(); 
@EXPORT_OK = @LWP::Parallel::RobotUA::EXPORT_OK;
%EXPORT_TAGS = %LWP::Parallel::RobotUA::EXPORT_TAGS;

1;

__END__

=head1 NAME

LWP::RobotPUA - Parallel LWP::RobotUA

=head1 DESCRIPTION

RobotPUA is a simple frontend to the LWP::Parallel::RobotUA
module. It is here in order to maintain the compatibility with
previous releases. However, in order to prevent the previous need for
changing the original LWP sources, all extension files have been moved
to the LWP::Parallel subtree.

If you start from scratch, maybe you should start using LWP::Parallel
and its submodules directly.

See the L<LWP::Parallel::RobotUA> for the documentation on this
module.

=head1 AUTHOR

Marc Langheinrich, marclang@cs.washington.edu

=head1 SEE ALSO

L<LWP::Parallel::RobotUA>, L<LWP::Parallel::UserAgent>, L<LWP::RobotUA>

=cut

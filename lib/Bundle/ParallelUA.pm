# -*- perl -*-
# $Id: ParallelUA.pm,v 1.7 2001/02/21 11:10:33 langhein Exp $

package Bundle::ParallelUA;

$VERSION = '2.50'; 

1;

__END__

=head1 NAME

Bundle::ParallelUA - CPAN Bundle for the LWP Parallel User Agent extension

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::ParallelUA'>

=head1 CONTENTS

ExtUtils::MakeMaker  - should be in perl disribution

LWP::UserAgent       - Base for Parallel::UserAgent

LWP::RobotUA         - Base for Parallel::RobotUA

LWP::Protocol        - Base Protocol implementations

LWP::Parallel        - Parallel User Agent itself

=head1 DESCRIPTION

This bundle defines all required modules for ParallelUserAgent.

=head1 AUTHOR

Marc Langheinrich

=cut

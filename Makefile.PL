# This -*- perl -*- script writes the Makefile for LWP::Parallel
# $Id: Makefile.PL,v 1.3 1998/03/13 03:18:22 marc Exp $
use ExtUtils::MakeMaker;

print "Checking your version of libwww......";
my $required = "5.20";

eval {
    require LWP;
    my $version = LWP->Version;
    $version >= $required or die "\nLWP::Parallel only works with versions of libwww $required or greater.\nYou seem to have only version $version installed on your system\n";

    # Detailed Breakdown
    #
    # LWP:      || 5.21 | 5.20 | 5.18                    | 5.10
    # ----------++------+------+-------------------------+-----
    # UserAgent ||   -  | 1.58 | !1.51 (uses alarms)
    # RobotUA   ||   -  | 1.13 | 1.11
    # Protocol  ||   -  | 1.31 | !1.29 (uses alarms)
    # /http     || 1.41 | 1.39 | !1.33 (uses LWP::Sockets)
    # /ftp      ||   -  | 1.20 | 1.19

};
if ($@) {
    print " failed\n";
    print <<EOT;
$@
Parallel User Agent uses the standard libwww installation to provide
its basic functionality (i.e. connecting to remote sites and receiving
data). You will have to install a current version (>=$required) of the LWP
package before you can proceed.

The latest version of libwww-perl should always be available from:

     http://www.sn.no/libwww-perl/

The library is also available from the Comprehensive Perl Archive
Network (CPAN).  Visit <URL:http://www.perl.com/CPAN/> to find a CPAN
site near you.

EOT
    exit;  # No need to go on
} else {
    print " ok\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'LWP::Parallel',
    'VERSION_FROM' => 'lib/LWP/Parallel.pm', # finds $VERSION
);


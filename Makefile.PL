# This -*- perl -*- script writes the Makefile for LWP::Parallel
# $Id: Makefile.PL,v 1.4 1998/11/24 00:12:59 marc Exp $
use ExtUtils::MakeMaker;

print "Checking your version of libwww......";
my $required  = "5.20";
my $supported = "5.36";
eval {
    require LWP;
    my $version = LWP->Version;
    $version >= $required or die "\nLWP::Parallel only works with versions of libwww $required or greater.\nYou seem to have only version $version installed on your system\n";
    $version <= $supported or warn <<WARNING;

           **** WARNING: Unsupported Version of libwww found! ****

This library only supports libwww up to version $supported. You seem to have
version $version installed, which has not yet been tested by the package author
for compatibility. Some or all tests might fail!

Install at your own risk, or wait until a more recent version of this library
is available.

WARNING

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
    if ($version <= $supported) { print " unsupported (but might be ok)\n"; } 
    else { print " ok\n"; }
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'LWP::Parallel',
    'VERSION_FROM' => 'lib/LWP/Parallel.pm', # finds $VERSION
);


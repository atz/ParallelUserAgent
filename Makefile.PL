# This -*- perl -*- script writes the Makefile for LWP::Parallel
# $Id: Makefile.PL,v 1.9 2001/02/21 11:13:02 langhein Exp $
use ExtUtils::MakeMaker;

print "Checking your version of libwww...";
my $required  = "5.48";
my $supported = "5.50";
my $version;
eval {
    require LWP;
    $version = LWP->Version;
    $version >= $required or die "\nLWP::Parallel only works with versions of libwww $required or greater.\nYou seem to have only version $version installed on your system. If you can\nnot or do not want to upgrade to a later version of libwww you should check\nCPAN for an earlier version of this software that might support it.\n";
    $version <= $supported or warn <<WARNING;

           **** WARNING: Unsupported Version of libwww found! ****

This library only supports libwww up to version $supported. You seem to have
version $version installed, which has not yet been tested by the package author
for compatibility. Some or all tests might fail!

Install at your own risk, or wait until a more recent version of this library
is available.

WARNING

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
    if ($version < $supported) { print " ok ($version)\nNote: you should upgrade to $supported (although ParallelUA should work ok)\n"; } 
    else { print " ok\n"; }
}
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'LWP::Parallel',
    'VERSION_FROM' => 'lib/LWP/Parallel.pm', # finds $VERSION
);


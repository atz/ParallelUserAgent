# This -*- perl -*- script writes the Makefile for LWP::Parallel
# $Id: Makefile.PL,v 1.13 2003/03/11 16:48:56 langhein Exp $
use ExtUtils::MakeMaker;

print "Checking your version of libwww...";
my $required  = "5.64";
my $supported = "5.65";
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

     http://www.linpro.no/lwp/

The library is also available from the Comprehensive Perl Archive
Network (CPAN).  Visit <URL:http://www.perl.com/CPAN/> to find a CPAN
site near you.

PS: If you _do_ have the libwww-perl library installed, then this
    script was unable to find it. Either figure out why this happens,
    or go ahead and edit Makefile.PL to disable the version check
    (no, this is not recommended) :-)

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
    'DISTNAME'  => 'ParallelUserAgent',
    'VERSION_FROM' => 'lib/LWP/Parallel.pm', # finds $VERSION
);

package MY;

sub test
{
    q(
test: all
	$(FULLPERL) t/TEST 

);
}



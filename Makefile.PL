# This -*- perl -*- script writes the Makefile for LWP::Parallel
# $Id: Makefile.PL,v 1.14 2004/02/10 15:19:10 langhein Exp $
use ExtUtils::MakeMaker;

print "Checking your version of libwww...";
my $required  = "5.64";
my $supported = "5.76";
my $version;
eval {
    require LWP;
    $version = LWP->Version;
    $version <= $supported or warn <<WARNING;

       **** WARNING: Unsupported Version of libwww found! ****

     libwww version installed: $version
last libwww version supported: $supported

This package is crusty and not fully tested with newer LWP versions.
Some or all tests might fail!  Please consider such usage experiemental.

WARNING
};
if ($@) {
    print " failed\n\n$@\n";
    exit;  # No need to go on
}
if ($version < $supported) { print " ok ($version)\nNote: you should upgrade to LWP to $supported or newer (although ParallelUA should work ok)\n"; } 
else { print " ok\n"; }

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'LWP::Parallel',
    DISTNAME     => 'ParallelUserAgent',
    VERSION_FROM => 'lib/LWP/Parallel.pm', # finds $VERSION
    PREREQ_PM    => {
        'LWP::Protocol::http10' =>  0,
        'LWP'                   => '5.64',
    },
);

package MY;

sub test
{
    q(
test: all
	$(FULLPERL) t/TEST 

);
}



# -*- perl -*-
# $Id: https.pm,v 1.2 2001/02/21 11:12:19 langhein Exp $
# derived from: https.pm,v 1.8 1999/09/20 12:48:37 gisle Exp $

use strict;

package LWP::Parallel::Protocol::https;

# Figure out which SSL implementation to use (copy & paste from LWP)
use vars qw($SSL_CLASS);
if ($IO::Socket::SSL::VERSION) {
    $SSL_CLASS = "IO::Socket::SSL"; # it was already loaded
} else {
    eval { require Net::SSL; };     # from Crypt-SSLeay
    if ($@) {
	require IO::Socket::SSL;
	$SSL_CLASS = "IO::Socket::SSL";
    } else {
	$SSL_CLASS = "Net::SSL";
    }
}

use vars qw(@ISA);

require LWP::Parallel::Protocol::http;
require LWP::Protocol::https;
@ISA=qw(LWP::Protocol::https LWP::Parallel::Protocol::http);

1;

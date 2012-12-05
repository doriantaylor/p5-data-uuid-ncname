#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'UUID::NCName' ) || print "Bail out!\n";
}

diag( "Testing UUID::NCName $UUID::NCName::VERSION, Perl $], $^X" );

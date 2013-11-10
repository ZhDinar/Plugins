#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'Plugins' ) || print "Bail out!\n";
    use_ok( 'Plugins' ) || print "Bail out!\n";
}

diag( "Testing Plugins $Plugins::VERSION, Perl $], $^X" );

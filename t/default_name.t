#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Test::Exception;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::Class') };

###### VARS ###################################################################

###### CODE ###################################################################

{
  package DefaultNameTest;

  my $class = GungHo::Class->new();
  $class->Build();
}

my $obj = DefaultNameTest->new();
isa_ok($obj, 'DefaultNameTest');

# ==== Done ===================================================================

done_testing();

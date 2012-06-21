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

my $meta = GungHo::Class->build(
    'name' => 'Alma',
    'attributes' =>
        {
          'a' =>
              {
                'type' => 'Number',
                'get' => 'GetA',
                'set' => 'SetA'
              }
        });
isa_ok($meta, 'GungHo::Class');

ok(Alma->new('a' => 1), 'constructor');

# ==== Done ===================================================================

done_testing();

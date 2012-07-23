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

my $class_name = 'GUIDtest';

###### CODE ###################################################################

GungHo::Class->build(
    'name' => $class_name,
    'attributes' =>
        {
          'guid' =>
              {
                'type' => 'GUID',
                'get' => 'GetGUID',
                'set' => 'SetGUID',
              }
        });

my $obj = $class_name->new();
isa_ok($obj, $class_name);
like($obj->GetGUID(), qr/^[0-9a-f]{32}\z/i, 'guidlike');
lives_ok { $obj->SetGUID('5c153851b1414fcda24ebeb664b833b1') } 'set ok';
dies_ok { $obj->SetGUID('1') } 'set fail';

# ==== Done ===================================================================

done_testing();

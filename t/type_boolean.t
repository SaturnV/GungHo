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

my $class_name = 'BoolTest';

###### CODE ###################################################################

GungHo::Class->build(
    'name' => $class_name,
    'attributes' =>
        {
          'bool' =>
              {
                'type' => 'Boolean',
                'get' => 'GetBool',
                'set' => 'SetBool'
              }
        });

my $obj = BoolTest->new( 'bool' => 1 );
is($obj->GetBool(), 1, 'one');

$obj->SetBool('');
is($obj->GetBool(), '', 'empty');

$obj->SetBool('kalap');
is($obj->GetBool(), 1, 'x');

$obj->SetBool(undef);
is($obj->GetBool(), '', 'undef');

# ==== Done ===================================================================

done_testing();

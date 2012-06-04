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

my $class = GungHo::Class->new( 'name' => 'XX::TestClass' );
$class->AddAttribute(
    'attr' =>
        {
          'type' => 'Number',
          'getter' => 'GetAttr',
          'rawgetter' => 'RawGetAttr',
          'setter' => 'SetAttr',
          'rawsetter' => 'RawSetAttr',
          'default' => 0
        });
$class->Build();

my $obj = XX::TestClass->new();
isa_ok($obj, 'XX::TestClass');

dies_ok { $obj->SetAttr('alma') } 'setter';
lives_ok { $obj->RawSetAttr('alma') } 'rawsetter bad';
is($obj->GetAttr(), 'alma', 'getter bad');
is($obj->RawGetAttr(), 'alma', 'rawgetter bad');

lives_ok { $obj->SetAttr(5) } 'rawsetter good';
is($obj->GetAttr(), 5, 'getter good');
is($obj->RawGetAttr(), 5, 'rawgetter good');

# ==== Done ===================================================================

done_testing();

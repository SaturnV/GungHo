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
          'get' => 'GetAttr',
          'rawget' => 'RawGetAttr',
          'set' => 'SetAttr',
          'rawset' => 'RawSetAttr',
          'default' => 0
        });
$class->Build();

my $obj = XX::TestClass->new();
isa_ok($obj, 'XX::TestClass');

dies_ok { $obj->SetAttr('alma') } 'set';
lives_ok { $obj->RawSetAttr('alma') } 'rawset bad';
is($obj->GetAttr(), 'alma', 'get bad');
is($obj->RawGetAttr(), 'alma', 'rawget bad');

lives_ok { $obj->SetAttr(5) } 'rawset good';
is($obj->GetAttr(), 5, 'get good');
is($obj->RawGetAttr(), 5, 'rawget good');

# ==== Done ===================================================================

done_testing();

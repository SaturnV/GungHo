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

# ==== Sub ====================================================================

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClass1' );
  $class->AddAttribute(
      'attr' =>
          {
            'type' => 'Number',
            'get' => 'GetAttr',
            'set' => 'SetAttr',
            'builder' => sub { return -2 }
          });
  $class->Build();

  my $obj = XX::TestClass1->new();
  isa_ok($obj, 'XX::TestClass1');
  is($obj->GetAttr(), -2, 'default value');
  $obj->SetAttr(1);
  is($obj->GetAttr(), 1, 'set value over default');

  $obj = XX::TestClass1->new( 'attr' => 2 );
  is($obj->GetAttr(), 2, 'initializer value');
  $obj->SetAttr(3);
  is($obj->GetAttr(), 3, 'set value over initializer');

  dies_ok
      { XX::TestClass1->new( 'attr' => undef ) }
      'undef initializer';
}

# ==== Method =================================================================

{
  package XX::TestClass2;
  sub _AttrBuilder { return -3 }
}

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClass2' );
  $class->AddAttribute(
      'attr' =>
          {
            'type' => 'Number',
            'get' => 'GetAttr',
            'builder' => '_AttrBuilder'
          });
  $class->Build();

  my $obj;
  lives_ok { $obj = XX::TestClass2->new() } 'method init';
  is($obj->GetAttr(), -3, 'method get');
}

# ==== Reference ==============================================================

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClass3' );
  $class->AddAttribute(
      'attr' =>
          {
            'type' => 'Defined',
            'get' => 'GetAttr',
            'builder' => sub { return [] }
          });
  $class->Build();

  my ($obj1, $obj2);
  lives_ok
      {
        $obj1 = XX::TestClass3->new();
        $obj2 = XX::TestClass3->new();
      } 'ref init';
  isnt($obj1->GetAttr(), $obj2->GetAttr(), 'ref get');
}

# ==== Default ================================================================

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClass4' );
  $class->AddAttribute(
      'attr' =>
          {
            'type' => 'Defined',
            'get' => 'GetAttr',
            'builder' => sub { return () },
            'default' => 'z'
          });
  $class->Build();

  my $obj = XX::TestClass4->new();
  is($obj->GetAttr(), 'z', 'default get');
}

# ==== Done ===================================================================

done_testing();

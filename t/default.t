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

# ==== With default ===========================================================

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClassDefault' );
  $class->AddAttribute(
      'attr' =>
          {
            'type' => 'Number',
            'get' => 'GetAttr',
            'set' => 'SetAttr',
            'default' => -2
          });
  $class->Build();

  my $obj = XX::TestClassDefault->new();
  isa_ok($obj, 'XX::TestClassDefault');
  is($obj->GetAttr(), -2, 'default value');
  $obj->SetAttr(1);
  is($obj->GetAttr(), 1, 'set value over default');

  $obj = XX::TestClassDefault->new( 'attr' => 2 );
  is($obj->GetAttr(), 2, 'initializer value');
  $obj->SetAttr(3);
  is($obj->GetAttr(), 3, 'set value over initializer');

  dies_ok
      { XX::TestClassDefault->new( 'attr' => undef ) }
      'undef initializer';
}

# ==== Without default ========================================================

{
  my $class = GungHo::Class->new( 'name' => 'XX::TestClassNoDefault' );
  $class->AddAttribute( 'attr' => { 'type' => 'Defined' } );
  $class->Build();

  dies_ok { XX::TestClassNoDefault->new() } 'no default';
}

# ==== Reference ==============================================================

{
  my $default_ref = [];

  my $class = GungHo::Class->new( 'name' => 'XX::TestClassReference' );
  $class->AddAttribute(
     'attr' =>
         {
           'type' => 'Defined',
           'default' => $default_ref,
           'get' => 'GetAttr'
         });
  $class->Build();

  my $obj = XX::TestClassReference->new();
  is($obj->GetAttr(), $default_ref, 'default ref');
}

# ==== Done ===================================================================

done_testing();

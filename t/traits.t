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

###### Alma ###################################################################

{
  package Alma;

  our $a;

  sub SetA
  {
    my $self = shift;
    $a = $_[0];
    return $self->_SetA(@_);
  }
}

###### CODE ###################################################################

# ---- Basic ------------------------------------------------------------------

{
  $Alma::a = 0;

  GungHo::Class->build(
      'name' => 'BasicTest',
      'isa' => 'Alma',
      'attributes' =>
          {
            'a' =>
                {
                  'type' => 'Number',
                  'traits' => 'ConstructorCallsSetter',
                  'get' => 'GetA',
                  'set' => [ 'SetA', '_SetA' ]
                }
          });

  my $obj = BasicTest->new('a' => 1);
  is($Alma::a, 1, 'AttrTrait');
  is($obj->GetA(), 1, 'AttrTraitGetter');
}

# ---- Class trait ------------------------------------------------------------

{
  $Alma::a = 0;

  GungHo::Class->build(
      'name' => 'ClassTest',
      'isa' => 'Alma',
      'traits' => 'ConstructorCallsSetter',
      'attributes' =>
          {
            'a' =>
                {
                  'type' => 'Number',
                  'get' => 'GetA',
                  'set' => [ 'SetA', '_SetA' ]
                }
          });

  my $obj = ClassTest->new('a' => 1);
  is($Alma::a, 1, 'ClassTrait');
  is($obj->GetA(), 1, 'ClassTraitGetter');
}

# ---- Class trait deny -------------------------------------------------------

{
  $Alma::a = 0;

  GungHo::Class->build(
      'name' => 'DenyTest',
      'isa' => 'Alma',
      'traits' => 'ConstructorCallsSetter',
      'attributes' =>
          {
            'a' =>
                {
                  'type' => 'Number',
                  'get' => 'GetA',
                  'set' => [ 'SetA', '_SetA' ],
                  'flags' => 'NoConstructorCallsSetter'
                }
          });

  my $obj = DenyTest->new('a' => 1);
  is($Alma::a, 0, 'DenyTrait');
  is($obj->GetA(), 1, 'DenyTraitGetter');
}
# ==== Done ===================================================================

done_testing();

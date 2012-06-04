#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Test::Exception;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::Class') };

###### ForeignBase ############################################################

{
  package XX::ForeignBase;
  sub ForeignMethod { return 1 }
}

###### VARS ###################################################################

###### CODE ###################################################################

# ==== BaseClass ==============================================================

my $base_class = GungHo::Class->new(
    'name' => 'XX::BaseClass',
    'properties' =>
        {
          'Inherited' => 101,
          'Overriden' => 102,
          'Removed' => 103
        });
$base_class->AddAttribute(
    'alma' =>
        {
          'type' => 'Number',
          'getter' => 'GetAlma',
          'flags' => [qw( All Base Alma Removed )]
        },
    'barac' =>
        {
          'type' => 'Number',
          'getter' => 'GetBarac',
          'setter' => 'SetBarac',
          'flags' => [qw( All Base Barac )]
        });
$base_class->Build();

my $base_obj = XX::BaseClass->new( 'alma' => 1, 'barac' => 2 );
isa_ok($base_obj, 'XX::BaseClass');
can_ok($base_obj, qw( GetAlma GetBarac SetBarac ));
is($base_obj->GetAlma(), 1, 'base alma init');
is($base_obj->GetBarac(), 2, 'base barac init');
dies_ok { $base_obj->SetAlma(3) } 'base no alma setter';
lives_ok { $base_obj->SetBarac(4) } 'base barac setter';
is($base_obj->GetAlma(), 1, 'base alma getter');
is($base_obj->GetBarac(), 4, 'base barac getter');

# ==== DerivedClass ===========================================================

{
  my $derived_class = GungHo::Class->new(
      'name' => 'XX::DerivedClass',
      'isa' => [ 'XX::BaseClass', 'XX::ForeignBase' ],
      'properties' => 
        {
          'New' => 201,
          'Overriden' => 202,
          'Removed' => undef
        });
  $derived_class->AddAttribute(
      'alma' =>
          {
            'setter' => 'SetAlma',
            'flags' => [qw( Derived !Removed )]
          },
      'retek' => { 'flags' => [qw( All Derived )] } );
  $derived_class->Build();

  my $derived_obj = XX::DerivedClass->new( 'alma' => 1, 'barac' => 2 );
  isa_ok($derived_obj, 'XX::DerivedClass');
  isa_ok($derived_obj, 'XX::BaseClass');
  isa_ok($derived_obj, 'XX::ForeignBase');

  is($base_obj->GetAlma(), 1, 'derived alma init');
  is($derived_obj->GetBarac(), 2, 'derived barac init');
  lives_ok { $derived_obj->SetAlma(3) } 'derived alma setter';
  lives_ok { $derived_obj->SetBarac(4) } 'derived barac setter';
  is($derived_obj->GetAlma(), 3, 'derived alma getter');
  is($derived_obj->GetBarac(), 4, 'derived barac getter');

  my @expected = qw( barac );
  my @got = sort map { $_->Name() }
      $derived_class->GetAttributesWithFlag('Barac');
  is_deeply(\@got, \@expected, 'inherited attribute flag');

  @expected = qw( alma );
  @got = sort map { $_->Name() }
      $derived_class->GetAttributesWithFlag('Alma');
  is_deeply(\@got, \@expected, 'inherited flag');

  @expected = ();
  @got = sort map { $_->Name() }
      $derived_class->GetAttributesWithFlag('Removed');
  is_deeply(\@got, \@expected, 'removed flag');

  @expected = qw( alma barac );
  @got = sort map { $_->Name() }
      $derived_class->GetAttributesWithFlag('Base');
  is_deeply(\@got, \@expected, 'superclass flag');

  @expected = qw( alma retek );
  @got = sort map { $_->Name() }
      $derived_class->GetAttributesWithFlag('Derived');
  is_deeply(\@got, \@expected, 'added flag');

  is($derived_class->GetProperty('Inherited'), 101, 'InheritedProperty');
  is($derived_class->GetProperty('Overriden'), 202, 'OverridenProperty');
  is($derived_class->GetProperty('Removed'), undef, 'RemovedProperty');
  is($derived_class->GetProperty('New'), 201, 'NewProperty');
}

# ==== Bad isa ================================================================

dies_ok
    {
      GungHo::Class->new(
          'name' => 'XX::BadIsa',
          'isa' => 'Hettyem:Pitty')
    }
    'bad isa';

# ==== Done ===================================================================

done_testing();

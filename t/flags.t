#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::Class') };

###### VARS ###################################################################

###### CODE ###################################################################

# ==== Flags ==================================================================

{
  my $class = GungHo::Class->new(
      'name' => 'XX::TestClass',
      'properties' => { 'X' => 2 },
      'flags' => 'Class');
  $class->AddAttribute(
      'apple' =>
          {
            'type' => 'Number',
            'getter' => 'GetApple',
            'setter' => 'SetApple',
            'flags' => [qw( Fruit Apple )],
            'properties' => { 'A' => 3 }
          },
      'peach' =>
          {
            'type' => 'Number',
            'getter' => 'GetPeach',
            'setter' => 'SetPeach',
            'flags' => [qw( Fruit Peach )],
            'properties' => { 'B' => 'retek' }
          },
      'noflag' =>
          {
          });
  $class->Build();

  my @expected = sort qw( apple peach noflag );
  my @got = sort $class->GetAttributeNames();
  is_deeply(\@got, \@expected, 'GetAttributeNames');
  my @attrs = @got;

  my %attrs;
  foreach my $n (@attrs)
  {
    $attrs{$n} = $class->GetAttributeByName($n);
    isa_ok($attrs{$n}, 'GungHo::_Attribute');
  }

  @expected = @attrs{$class->GetAttributeNames()};
  @got = $class->GetAttributes();
  is_deeply(\@got, \@expected, 'GetAttributes');

  @expected = ( $attrs{'apple'} );
  @got = $class->GetAttributesWithFlag('Apple');
  is_deeply(\@got, \@expected, 'GetAttributesWithFlag(1)');

  @expected = sort ( @attrs{qw( apple peach )} );
  @got = sort $class->GetAttributesWithFlag('Fruit');
  is_deeply(\@got, \@expected, 'GetAttributesWithFlag(1+)');

  @expected = ();
  @got = $class->GetAttributesWithFlag('TelegraphRoad');
  is_deeply(\@got, \@expected, 'GetAttributesWithFlag(0)');

  ok($class->HasFlag('Class'), 'HasFlag+');
  ok(!$class->HasFlag('Atom'), 'HasFlag-');

  is($class->HasFlag('Class'), 1, 'FlagsAreProperties');
  is($class->GetProperty('X'), 2, 'ClassProperties');
  is($attrs{'apple'}->GetProperty('A'), 3, 'AttributeProperties');
}

# ==== Properties =============================================================



# ==== Done ===================================================================

done_testing();

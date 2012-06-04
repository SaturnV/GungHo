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

my $class_spec =
    {
      'isa' => 'XX::DummyBase',
    };

my $attr_spec =
    {
      'type' => 'Number',
      'getter' => 'GetAttr',
      'rawgetter' => 'RawGetAttr',
      'setter' => 'SetAttr',
      'rawsetter' => 'RawSetAttr',
      'builder' => sub { return () },
      'default' => 0,
    };

###### SUBS ###################################################################

sub make_class
{
  state $seq = 1;
  my $spec = { %{$class_spec} };
  $spec->{'name'} = shift // 'XX::TestClass' . $seq++;

  my $n;
  while (@_)
  {
    $n = shift;
    $spec->{$n} = shift;
  }

  return GungHo::Class->new($spec);
}

sub make_attr
{
  my $spec = { %{$attr_spec} };

  my $n;
  while (@_)
  {
    $n = shift;
    $spec->{$n} = shift;
  }

  return $spec;
}

###### CODE ###################################################################

{
  package XX::DummyBase;
  sub Dummy {}
}

# ==== Class ==================================================================

lives_ok
    {
      my $class = make_class();
      $class->Build();
    } 'ok class';

dies_ok { make_class(undef, 'badarg' => '') } 'bad class arg';
dies_ok { make_class('XX:TestClass') } 'bad class name';

# ==== Attribute ==============================================================

{
  dies_ok
      {
        my $class = make_class();
        $class->AddAttribute( 'attr' => make_attr( 'badarg' => '' ) );
        $class->Build();
      } 'bad attr arg';

  dies_ok
      {
        my $class = make_class();
        $class->AddAttribute( 'attr' => make_attr( 'type' => 'Alma' ) );
        $class->Build();
      } 'bad attr type';

  dies_ok
      {
        my $class = make_class();
        $class->AddAttribute( 'attr' => make_attr( 'getter' => '*' ) );
        $class->Build();
      } 'bad method name';
}

# ==== Done ===================================================================

done_testing();

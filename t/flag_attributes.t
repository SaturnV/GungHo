#! /usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

use GungHo::Class;

use Test::More;

sub get_attrs_with_flag($$)
{
  my ($class, $flag) = @_;
  return join('',
      sort map { $_->Name() } $class->GetAttributesWithFlag($flag));
}

my $root_meta = GungHo::Class->build(
    'name' => 'RootClass',
    'attributes' =>
        {
          'a' => {},
          'b' => { 'flags' => [qw( A )] },
          'c' => { 'flags' => [qw( A !Z )] },
          'd' => { 'flags' => [qw( A !Q )] },

          'e' => {},
          'f' => { 'flags' => [qw( A )] },
          'g' => { 'flags' => [qw( A !Z )] },
          'h' => { 'flags' => [qw( A !Q )] },

          'n' => { 'flags' => [qw( !Y )]}
        });

my $trunk_meta = GungHo::Class->build(
    'name' => 'TrunkClass',
    'isa' => 'RootClass',
    'traits' =>
        {
          'FlagAttributes' => [qw( Z )]
        },
    'attributes' =>
        {
          'e' => {},
          'f' => { 'flags' => [qw( B )] },
          'g' => { 'flags' => [qw( B !Z )] },
          'h' => { 'flags' => [qw( B !Q )] },

          'i' => {},
          'j' => { 'flags' => [qw( B )] },
          'k' => { 'flags' => [qw( B !Z )] },
          'l' => { 'flags' => [qw( B !Q )] },
        });

my $branch1_meta = GungHo::Class->build(
    'name' => 'Branch1Class',
    'isa' => 'TrunkClass',
    'traits' =>
        {
          'FlagAttributes' => [qw( Y )]
        },
    'attributes' =>
        {
          'm' => {},
          'n' => {}
        });

my $branch2_meta = GungHo::Class->build(
    'name' => 'Branch2Class',
    'isa' => 'TrunkClass',
    'attributes' =>
        {
          'm' => {},
          'n' => {}
        });

is( get_attrs_with_flag($branch1_meta, 'A'), 'bcdfgh',   'A1' );
is( get_attrs_with_flag($branch1_meta, 'B'), 'fghjkl',   'B1' );
is( get_attrs_with_flag($branch1_meta, 'Q'), '',         'Q1' );
is( get_attrs_with_flag($branch1_meta, 'Y'), 'm',        'Y1' );
is( get_attrs_with_flag($branch1_meta, 'Z'), 'efhijl',   'Z1' );

is( get_attrs_with_flag($branch2_meta, 'A'), 'bcdfgh',   'A2' );
is( get_attrs_with_flag($branch2_meta, 'B'), 'fghjkl',   'B2' );
is( get_attrs_with_flag($branch2_meta, 'Q'), '',         'Q2' );
is( get_attrs_with_flag($branch2_meta, 'Y'), '',         'Y2' );
is( get_attrs_with_flag($branch2_meta, 'Z'), 'efhijlmn', 'Z2' );

done_testing();

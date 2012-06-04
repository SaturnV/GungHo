#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Test::Exception;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::Registry') };

###### VARS ###################################################################

my @got;
my @expected;

###### CODE ###################################################################

# ==== Low-level ==============================================================

{
  my $type = '_alma_';

  is(scalar(GungHo::Registry::_get($type, 'a')), undef,
     'type not exists scalar');
  @expected = ();
  @got = GungHo::Registry::_get($type, 'a');
  is_deeply(\@got, \@expected, 'type not exists list');

  my $obj = {};
  GungHo::Registry::_register($type, 'a', $obj);
  is(scalar(GungHo::Registry::_get($type, 'a')), $obj, 'exists scalar');
  @expected = ($obj);
  @got = GungHo::Registry::_get($type, 'a');
  is_deeply(\@got, \@expected, 'exists list');

  is(scalar(GungHo::Registry::_get($type, 'b')), undef,
      'not exists scalar');
  @expected = ();
  @got = GungHo::Registry::_get($type, 'b');
  is_deeply(\@got, \@expected, 'not exists list');

  is(
      scalar(GungHo::Registry::_get_or_load($type, 'Registry', 'GungHo')),
      'GungHo::Registry',
      '_get_or_load');
}

# ==== High-level =============================================================

# Todo

# ==== Done ===================================================================

done_testing();

#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Test::Exception;

# use Data::Dumper;

use GungHo::CodeGenerator;

###### VARS ###################################################################

my %patterns =
    (
      '' => [],
      'a' => ['a'],
      '#{a}#' => [['a']],
      'a#{b}#c' => ['a',['b'],'c'],
      'a#{b()}#c' => ['a',['b',''],'c'],
      'a#{b(c)}#d' => ['a',['b','c'],'d'],
      'a#{#{b}#}#c' => ['a',[['b']],'c'],
      'a#{b(c,d)}#e' => ['a',['b','c','d'],'e'],
      'a#{b(#{c}#,d)}#e' => ['a',['b',['c'],'d'],'e'],

      '#{' => undef,
      '}#' => ['}#'],
      '#{}#' => [['']],
      '#{a,b}#' => undef,
      '#{a(}#' => undef,
      '#{a)}#' => undef,
    );

###### SUBS ###################################################################

sub _parse($)
{
  my @p;
  eval { @p = GungHo::CodeGenerator::parse_pattern($_[0]) };
  # print ">$_[0]< => [$@]" . Data::Dumper::Dumper(\@p);
  return $@ ? undef : \@p;
}

###### CODE ###################################################################

foreach my $p (sort { length($a) <=> length($b) } keys(%patterns))
{
  is_deeply(_parse($p), $patterns{$p}, "pattern >$p<");
}

# ==== Done ===================================================================

done_testing();

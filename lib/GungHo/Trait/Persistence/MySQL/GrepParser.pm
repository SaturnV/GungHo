#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::Persistence::MySQL::GrepParser;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

# TODO remove before flight
use Data::Dumper;

use Exporter qw( import );

###### INIT ###################################################################

our @EXPORT_OK = qw( parse_grep );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $HK_parser_table = 'parser_table';

our %ParserMap =
    (
      'arg' => '_ParseArg',
      'attr' => '_ParseAttr',

      '+' => '_ParseNaturalOpMultiarg',
      '-' => '_ParseNaturalOpMultiarg',
      '*' => '_ParseNaturalOpMultiarg',
      '/' => '_ParseNaturalOpMultiarg',

      'and' => '_ParseNaturalOpMultiarg',
      'or' => '_ParseNaturalOpMultiarg',
#      'not' => 'TODO',

      '==' => '_ParseNaturalEQ',
      '!=' => '_ParseNaturalNE',
      '<=' => '_ParseNaturalOp2arg',
      '>=' => '_ParseNaturalOp2arg',
      '<' => '_ParseNaturalOp2arg',
      '>' => '_ParseNaturalOp2arg',
    );

###### METHODS ################################################################

sub _InfixExprParser
{
  my $self = shift;
  my $may_need_parens = shift;
  my $op = shift;
  my @parsed_args = map { $self->Parse(1, $_) } @_;
  my ($sql, @execute);

  $sql = join(uc(" $op "), map { $_->{'sql'} } @parsed_args);
  $sql = "($sql)" if $may_need_parens;
  @execute =
      map { @{$_->{'execute'}} } grep { $_->{'execute'} } @parsed_args;

  return { 'sql' => $sql, 'execute' => \@execute };
}

sub _ParseNaturalOpMultiarg
{
  # my ($self, $may_need_parens, $expr) = @_;
  return $_[0]->_InfixExprParser($_[1], @{$_[2]});
}

sub _ParseNaturalOp2arg
{
  # my ($self, $may_need_parens, $expr) = @_;
  # my ($op, $left_arg, $right_arg) = @{$expr};
  my $expr = $_[2];
  my $op = $expr->[0];
  die "bad number of arguments to $op"
    unless (scalar(@{$expr}) == 3);
  return shift->_ParseNaturalOpMultiarg(@_);
}

sub _ParseNaturalEQ
{
  # my ($self, $may_need_parens, $expr) = @_;
  # my ($op, $left_arg, $right_arg) = @{$expr};
  my $expr = $_[2];
  my ($op, @args) = @{$expr};
  die "bad number of arguments to $op"
    unless (scalar(@args) == 2);
  return $_[0]->_InfixExprParser($_[1], '=', @args);
}

sub _ParseNaturalNE
{
  # my ($self, $may_need_parens, $expr) = @_;
  # my ($op, $left_arg, $right_arg) = @{$expr};
  my $expr = $_[2];
  my ($op, @args) = @{$expr};
  die "bad number of arguments to $op"
    unless (scalar(@args) == 2);
  return $_[0]->_InfixExprParser($_[1], '<>', @args);
}

sub _ParseArg
{
  # my ($stash, $may_need_parens, $expr) = @_;
  my $expr = $_[2];
  my $ret;

  my ($op, $n) = @{$expr};
  die "bad number of arguments to $op"
    if (scalar(@{$expr}) != 2);

  given ($n)
  {
    when (/^(-?\d+)\z/)
    {
      $ret = { 'sql' => '?', 'execute' => [ "\$#{args_av}#[$1]" ] };
    }
    # when (/^\@(-?\d+)\z/)
    # {
    # }
    default
    {
      die "can't parse $op '$n'";
    }
  }

  return $ret;
}

sub _ParseAttr
{
  my $expr = $_[2];
  my $ret;

  my ($op, $n) = @{$expr};
  die "bad number of arguments to $op"
    if (scalar(@{$expr}) != 2);

  return { 'sql' => "#{persistence.sql_col_str($n)}#", 'execute' => [] };
}

sub Parse
{
  my ($self, $may_need_parens, $expr) = @_;
  my $ret;

  if (ref($expr))
  {
    my $ref = ref($expr);
    die "don't know what to do whit a(n) $ref"
      unless ($ref eq 'ARRAY');

    my $op = $expr->[0] // '<undef>';
    $op = ref($op) if ref($op);

    my $parser = $self->{$HK_parser_table}->{$op};
    die "can't parse op $op"
      unless (defined($parser) && ($parser = $self->can($parser)));
    $ret = $self->$parser($may_need_parens, $expr);
  }
  elsif (defined($expr))
  {
    my $expr_qm = quotemeta($expr);
    $ret = ($expr eq $expr_qm) ?
        { 'sql' => "'$expr'", 'execute' => [] } :
        { 'sql' => '?', 'execute' => [ qq("$expr_qm") ] };
  }
  else
  {
    $ret = { 'sql' => 'NULL', 'execute' => [] };
  }

  return $ret;
}

# ==== parse ==================================================================

sub parse_grep
{
  my $self = bless({ $HK_parser_table => { %ParserMap } });
  my $ret = $self->Parse(0, $_[0]);
  print Data::Dumper::Dumper($ret);
  return $ret;
}

###### THE END ################################################################

1

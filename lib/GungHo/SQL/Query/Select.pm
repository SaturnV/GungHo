#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query::Select;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

my $next_alias = 'a';

###### METHODS ################################################################

sub new
{
  my $class = $_[0];
  # my $orig_class = $_[1];
  # my $query_type = $_[2];

  my $self =
      {
        'select' => [],
        'from' => [],
        'where' => [],
        'params' => []
      };

  return bless($self, $class);
}

sub AddSelect
{
  my $self = shift;
  push(@{$self->{'select'}}, @_);
  return $self;
}

sub AddFrom
{
  my $self = shift;
  die "TODO: Add what?" unless @_;

  my $alias = '__sta_' . $next_alias++;
  die "TODO: JOINs not implemented"
    if (@{$self->{'from'}} || $#_);
  push(@{$self->{'from'}}, "$_[0] $alias");

  return $alias;
}

sub AddWhere
{
  my $self = shift;
  die "TODO: Add what?" unless @_;
  push(@{$self->{'where'}}, shift);
  push(@{$self->{'params'}}, @_);
  return $self;
}

sub Build
{
  my $self = shift;
  my $sql;

  {
    my @fs = @{$self->{'select'}};
    die "TODO: No fields SELECTed" unless @fs;

    local $" = ', ';
    $sql = "SELECT @fs"
  }

  {
    my @ts = @{$self->{'from'}};
    die "TODO: No tables SELECTed" unless @ts;
    die "TODO: JOINs not implemented" if $#ts;
    $sql .= ' FROM ' . join(', ', @ts);
  }

  {
    local $" = ' AND ';
    my @ws = @{$self->{'where'}};
    $sql .= " WHERE @ws" if @ws;
  }

  return ($sql, @{$self->{'params'}});
}

###### THE END ################################################################

1

#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query::_Where;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

###### METHODS ################################################################

sub _Init
{
  # my $self = $_[0];
  $_[0]->{'where'} = [];
  $_[0]->{'where_params'} = [];
  return 1;
}

sub AddWhere
{
  my $self = shift;
  die "TODO: Add what?" unless @_;
  push(@{$self->{'where'}}, shift);
  push(@{$self->{'where_params'}}, @_);
  return $self;
}

sub _BuildWhere
{
  # my ($self, $sql, $params) = @_;
  my $self = $_[0];

  if (my @ws = @{$self->{'where'}})
  {
    @ws = map { "($_)" } @ws if $#ws;
    local $" = ' AND ';
    $_[1] .= " WHERE @ws";
    push(@{$_[2]}, @{$self->{'where_params'}});
  }

  return 1;
}

###### THE END ################################################################

1

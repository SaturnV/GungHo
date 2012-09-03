#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query::Delete;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::SQL::Query::_Where );

###### VARS ###################################################################

our @ISA;

###### METHODS ################################################################

sub new
{
  my $class = $_[0];
  # my $orig_class = $_[1];
  # my $query_type = $_[2];

  my $m;
  my $self = bless({}, $class);
  foreach (@ISA)
  {
    $self->$m() if ($m = $_->can('_Init'));
  }

  return $self;
}

sub AddFrom
{
  my $self = shift;

  die "TODO: Add what?"
    unless (@_ && defined($_[0]));
  die "TODO: No JOIN in delete.\n"
    if (defined($self->{'from'}) || $#_);
  $self->{'from'} = $_[0];

  return undef;
}

sub Build
{
  my $self = shift;
  my ($sql, @params);

  die "TODO: Delete from?" unless defined($self->{'from'});
  $sql = "DELETE FROM " . $self->{'from'};

  $self->_BuildWhere($sql, \@params);

  return ($sql, @params);
}

###### THE END ################################################################

1

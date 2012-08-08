#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query::Literal;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### METHODS ################################################################

sub new
{
  my $class = shift;
  my $orig_class = shift;
  my $query_type = shift;

  my $self = {};
  $self->{'sql'} = shift;
  $self->{'params'} = [ @_ ];

  return bless($self, $class);
}

sub Sql { return $_[0]->{'sql'} }
sub SqlParameters { return @{$_[0]->{'params'}} }

###### THE END ################################################################

1

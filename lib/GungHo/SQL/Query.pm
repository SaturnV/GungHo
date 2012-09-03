#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::SQL::Query::Select;
use GungHo::SQL::Query::Delete;
use GungHo::SQL::Query::Literal;

###### METHODS ################################################################

sub new
{
  my $orig_class = shift;
  my $query_type = shift // 'SELECT';
  my $self;

  my $query_class = ucfirst(lc($query_type));
  die 'TODO' if ($query_class =~ /\W/);

  my $qc;
  foreach my $base ($orig_class, __PACKAGE__)
  {
    $qc = join('::', $base, $query_class);
    if ($qc->can('new'))
    {
      $self = $qc->new($orig_class, $query_type, @_);
      last;
    }
  }
  die "TODO: Can't create '$query_type' query"
    unless $self;

  return $self;
}

sub literal { return shift->new('Literal', @_) }

###### THE END ################################################################

1

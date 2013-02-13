#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Type::SmartMatch;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Carp;

###### INIT ###################################################################

use parent qw( GungHo::Type::Any );

###### VARS ###################################################################

our $ModName = __PACKAGE__;
our $TypeName = $ModName->Name();

###### METHODS ################################################################

sub new
{
  my $class = shift;
  my $parent_type = shift;

  my $self = bless({}, $class);
  if (defined($parent_type))
  {
    $self->{'parent'} = $parent_type;
    Scalar::Util::weaken($self->{'parent'})
      if ref($parent_type);
  }

  $self->{'match'} = \@_;

  return $self;
}

# $type->Validate($arg)
sub Validate
{
  my $self = shift;
  confess "TODO::TypeError[$TypeName]: Doesn't look good."
    unless ($_[0] ~~ $self->{'match'});
}

###### THE END ################################################################

1

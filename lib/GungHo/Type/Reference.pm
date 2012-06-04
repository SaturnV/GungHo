#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Reference;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### INIT ###################################################################

use parent qw( GungHo::Type::Defined );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $TypeName = $ModName->TypeName();

###### METHODS ################################################################

sub Validate
{
  my $self = shift;
  $self->SUPER::Validate(@_);
  die "TODO::TypeError[" . $self->TypeName() . "]: Not a reference"
    unless ref($_[1]);
}

sub _gh_ValidatorPattern
{
  my $self = shift;
  my $type_name = quotemeta($self->TypeName());
  return $self->SUPER::_gh_ValidatorPattern() .
         "die 'TODO::TypeError[$type_name]: Not a reference'\n" .
         "  unless ref(#{arg_value_e}#);\n";
}

###### THE END ################################################################

1

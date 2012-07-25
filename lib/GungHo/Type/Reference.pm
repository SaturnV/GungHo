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
our $TypeName = $ModName->Name();

###### METHODS ################################################################

# $type->Validate($arg)
sub Validate
{
  my $self = shift;
  $self->SUPER::Validate(@_);
  die "TODO::TypeError[$TypeName]: Not a reference"
    unless ref($_[0]);
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $self = shift;
  return $self->SUPER::_gh_ValidatorPattern(@_) .
         "die 'TODO::TypeError[$TypeName]: Not a reference'\n" .
         "  unless ref($_[0]);\n";
}

###### THE END ################################################################

1

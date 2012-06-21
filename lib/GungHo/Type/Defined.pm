#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Defined;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### INIT ###################################################################

use parent qw( GungHo::Type::Any );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $TypeName = $ModName->TypeName();

###### METHODS ################################################################

# $type->Validate($arg)
sub Validate
{
  die "TODO::TypeError[" . $_[0]->TypeName() . "]: Undefined value"
    unless defined($_[1]);
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $type_name = quotemeta($_[0]->TypeName());
  return "die 'TODO::TypeError[$type_name]: Undefined value'\n" .
         "  unless defined($_[1]);\n";
}

###### THE END ################################################################

1

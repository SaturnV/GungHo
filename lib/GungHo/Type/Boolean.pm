#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Boolean;

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
  die "TODO::TypeError[" . $_[0]->TypeName() . "]: Not a boolean"
    if (defined($_[1]) && ($_[1] !~ /^1?\z/));
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $self = shift;
  my $type_name = quotemeta($self->TypeName());
  return "die 'TODO::TypeError[$type_name]: Not a boolean'\n" .
         "  if (defined($_[0]) && ($_[0] !~ /^1?\\z/));\n";
}

# =============================================================================

sub ConvertToType
{
  # my $self = shift;
  return !!$_[1];
}

sub _gh_ConvertToTypePattern
{
  return "!!$_[1]";
}

# TODO Replace this with the right stuff
sub _gh_PrepareCodeGenerator
{
  my $self = shift;
  $self->SUPER::_gh_PrepareCodeGenerator(@_);

  my $cg = $_[3];
  $cg->AddNamedPattern('attr.convert_to_type_s' =>
      '#{define_cond_x(set_value_e,"!!#{arg_value_e}#")}#');

  return undef;
}

###### THE END ################################################################

1

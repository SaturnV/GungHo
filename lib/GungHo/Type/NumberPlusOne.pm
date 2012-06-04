#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::NumberPlusOne;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### INIT ###################################################################

use parent qw( GungHo::Type::Number );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $TypeName = $ModName->TypeName();

###### METHODS ################################################################

# $self->__hook__($hook_runner, $hook_name, $cg, $what, $step, $stash)
sub _gh_cgss_convert_to_type_s
{
  my $self = $_[0];
  my $cg = $_[3];
  my $ret;

  my $var_name = $cg->GetMyVariable();
  $ret = $cg->ExpandPattern("my $var_name = #{arg_value_e}# + 1;\n");
  $cg->AddNamedPattern('arg_value_e', $var_name);
  
  return $ret;
}

###### THE END ################################################################

1

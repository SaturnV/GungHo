#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Type::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

# $class->TypeName()
sub TypeName
{
  my $type = ref($_[0]) || $_[0] || '<unknown>';
  $type =~ s/^GungHo::Type:://;
  return $type;
}

# $type_obj->_gh_SetupAttributeHooks($attr, $attr_spec)
sub _gh_SetupAttributeHooks
{
  my $self = $_[0];
  my $attr = $_[1];
  # my $attr_spec = $_[2];

  $attr->_gh_AddHook($H_b_prepare_code_generator,
      $ModName => sub { $self->_gh_PrepareCodeGenerator(@_) });
}

# $self->__hook__($hook_runner, $hook_name, $cg_owner, $cg)
sub _gh_PrepareCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[4];

  if ($self->can('Validate'))
  {
    my $insert = $cg->GetUniqueName("$self.validate_s", '_s');
    $cg->AddNamedPattern($insert =>
        sub { return $self->_gh_EmitValidator(@_) });
    $cg->Patch($insert, 'into' => 'attr.validate_s');
  }

  return undef;
}

# ==== Validate ===============================================================

# $type->_gh_cgss_validate_s($hook_runner, $hook_name, $cg_args)
sub _gh_EmitValidator
{
  my $self = shift;
  my $hook_runner = shift;
  my $cg_args = $_[1];

  # Run the rest of the hooks
  my $ret = '';
  $ret = $hook_runner->Continue(@_) // ''
    if $hook_runner;

  my $validate = '#{arg_value_e}#';
  my $cg = $cg_args->{$CGHA_code_generator};
  my $stash = $cg_args->{$CGHA_generate_args}->[0];
  if ($self->can('_gh_ValidatorPattern'))
  {
    # We have a validator pattern
    $ret .= $cg->ExpandPattern(
        $self->_gh_ValidatorPattern($validate));
  }
  else
  {
    # Use $type->Validate($new_value);
    $stash->{'enclose'}->{'$attribute_type_obj'} = $self
      unless $stash->{'enclose'}->{'$attribute_type_obj'};
    $ret .= $cg->ExpandPattern(
                "\$attribute_type_obj->Validate($validate);\n");
  }
  $cg->MakeImportant();

  return $ret;
}

###### THE END ################################################################

1

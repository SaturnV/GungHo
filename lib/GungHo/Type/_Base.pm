#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Type::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES );

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

  $attr->_gh_AddHook($H_cg_prepare_code_generator,
      $ModName => sub { $self->_gh_PrepareCodeGenerator(@_) });
}

# $self->__hook__($hook_runner, $hook_name, $cg)
sub _gh_PrepareCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[3];
  $cg->_gh_AddHook('gh_cg_do_step',
      $ModName =>
          # __hook__($hook_runner, $hook_name, $cg, $what, $step, $stash)
          sub
          {
            # my $what = $_[3];
            # my $step = $_[4];
            my $ret;
            foreach ("_gh_cgsw_$_[3]", "_gh_cgss_$_[4]")
            {
              last if ($self->can($_) && defined($ret = $self->$_(@_)));
            }
            return $ret;
          });
  return undef;
}

# ==== Validate ===============================================================

# $type->_gh_cgss_validate_s($hook_runner, $hook_name,
#     $cg, $what, $step, $stash)
sub _gh_cgss_validate_s
{
  my $self = shift;
  my $ret;

  # This type does validate and we are in a setter that needs it
  $ret = $self->_gh_EmitValidator(@_)
    if ($self->can('Validate') &&
        (grep { $_[3] eq $_ } qw( attribute_setter_s
                                  attribute_gh_init_Validate_s )) &&
        !$_[2]->IsIn('attribute_rawsetter_s'));

  return $ret;
}

sub _gh_EmitValidator
{
  my $self = shift;
  my $hook_runner = shift;
  my $hook_name = shift;

  # Run the rest of the hooks
  my $ret = $hook_runner->Continue($hook_name, @_) // '';

  my ($cg, $what, $step, $stash) = @_;
  if ($self->can('_gh_ValidatorPattern'))
  {
    # We have a validator pattern
    $ret .= $cg->ExpandPattern($self->_gh_ValidatorPattern());
    $cg->MakeImportant();
  }
  else
  {
    # Use $type->Validate($new_value);
    $stash->{'enclose'}->{'$attribute_type_obj'} = $self
      unless $stash->{'enclose'}->{'$attribute_type_obj'};
    $ret .= $cg->ExpandPattern(
                "\$attribute_type_obj->Validate(#{new_value_e}#);\n");
    $cg->MakeImportant();
  }

  return $ret;
}

###### THE END ################################################################

1

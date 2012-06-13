#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Builder;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES );

###### VARS ###################################################################

our $HK_code_generator = 'code_generator';

###### METHODS ################################################################

# ==== _gh_Build ==============================================================

# Implement me in your class
#   _gh_MetaClass() => $meta_class

sub _gh_Build
{
  my $self = $_[0];
  my $meta_class = $self->_gh_MetaClass();

  my $cg;
  if (!$self->{$HK_code_generator})
  {
    $cg = $self->{$HK_code_generator} =
        GungHo::CodeGenerator->new_prepared($self);
  }

  $self->_gh_BuildMethods();
  $self->_gh_BuildHooks();

  delete($self->{$HK_code_generator})->Destroy()
    if $cg;
}

# ==== CodeGenerator interface ================================================

# Implement me in your class
#   _gh_PrepareStash($cg, $stash)

# ---- _gh_SetupCodeGenerator -------------------------------------------------

sub _gh_SetupCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[1];

  $cg->_gh_AddHook('new_stash', $self =>
      # __hook__($hook_runner, $hook_name, $cg, $stash)
      sub
      {
        $self->_gh_PrepareStash($_[3], $_[2]);
        return undef;
      })
    if $self->can('_gh_PrepareStash');

  # __hook__($hook_runner, $hook_name, $cg)
  $self->_gh_RunHooks($H_cg_prepare_code_generator, $self, $cg)
    if $self->can('_gh_RunHooks');
}

# ---- _gh_Assemble -----------------------------------------------------------

sub _gh_Assemble
{
  # my ($self, $what, $stash) = @_;
  my $self = shift;
  my $what = $self->_gh_TypeToWhat(shift);
  my $template = $self->_gh_CodeTemplate($what);
  return $self->{$HK_code_generator}->Assemble($what, $template, @_);
}

# ---- _gh_TypeToWhat ---------------------------------------------------------

sub _gh_TypeToWhat { return "$_[1]_s" }

# ---- _gh_CodeTemplate -------------------------------------------------------

sub _gh_CodeTemplate
{
  my $self = $_[0];
  my $what = $_[1];

  my $template = $self->{$HK_code_generator}->GetNamedPattern($what);
  if (defined($template))
  {
    $template = [ $template ] unless (ref($template) eq 'ARRAY');
  }
  else
  {
    $template = [];
  }

  return $template;
}

# ==== Methods ================================================================

# Implement me in your class:
#   _gh_GetMethodTypes() => @method_types
#   _gh_GetMethodNames($method_type) =>
#       ($reported_method_name, $generated_method_name)

sub _gh_BuildMethods
{
  my $self = $_[0];
  my $meta_class = $self->_gh_MetaClass();

  my ($method_name_gen, $method_name_rep, $method_ref);
  foreach my $method_type ($self->_gh_GetMethodTypes())
  {
    ($method_name_rep, $method_name_gen) =
        $self->_gh_GetMethodNames($method_type);

    $method_ref = ($method_name_gen &&
                   $meta_class->_gh_ShouldProvideMethod($method_name_gen)) ?
        $self->_gh_BuildMethod($method_type, $method_name_gen) :
        undef;
    $meta_class->_gh_AddMethodImplementation(
        $method_name_gen, $method_ref, $self, $method_type)
      if $method_ref;
    # $meta_class->_gh_AddMetaMethod('TODO')
  }
}

sub _gh_BuildMethod
{
  my ($self, $method_type, $method_name) = @_;
  my $stash = $self->{$HK_code_generator}->NewStash(
      {
        'cg_owner' => $self,
        'method_name' => $method_name,
        'method_type' => $method_type,
        'code_type' => 'method'
      });
  return $self->_gh_Assemble($method_type, $stash);
}

# ==== Hooks ==================================================================

# Implement me in your class:
#   _gh_GetHookNames() => @hook_names

sub _gh_BuildHooks
{
  my $self = $_[0];
  my $meta_class = $self->_gh_MetaClass();
  my $target = $_[1] || $meta_class;

  my ($hook_ref, $stash);
  foreach my $hook_name ($self->_gh_GetHookNames())
  {
    $stash = $self->{$HK_code_generator}->NewStash(
        {
          'cg_owner' => $self,
          'hook_name' => $hook_name,
          'hook_type' => $hook_name,
          'hook_target' => $target,
          'code_type' => 'hook'
        });
    $hook_ref = $self->_gh_Assemble($hook_name, $stash);
    $target->_gh_AddHook($hook_name, $self => $hook_ref)
      if $hook_ref;
    # warn "*** Adding hook $hook_name" if $hook_ref;
  }
}

sub _gh_GetHookNames { return () }

###### THE END ################################################################

1

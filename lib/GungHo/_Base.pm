#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Scalar::Util;

use GungHo::Utils;
use GungHo::Names qw( :HOOK_NAMES :STASH_KEYS_NEW );
use GungHo::Registry qw( get_meta_class );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

# ==== new ====================================================================

# ---- arguments -------------------------------------------------------------

# $class->_gh_hnpa_stash_args($stash, @new_args);
sub _gh_hnpa_stash_args
{
  my $class = shift;
  my $stash = shift;
  $stash->{$S_new_arguments} = GungHo::Utils::make_hashref(@_);
}

# $class->_gh_new_process_arguments($stash, @new_args);
sub _gh_new_process_arguments
{
  my $class = shift;
  my $stash = shift;

  # I see no point to allow plugins at this step
  $class->_gh_hnpa_stash_args($stash, @_);

  my $meta_class = $class->get_meta_class();
  # __hook__($hook_runner, $hook_name, $class, $stash)
  $meta_class->_gh_RunHooks($H_hnpa_expand_macros, $class, $stash);
  $meta_class->_gh_RunHooksAugmented(
      $H_hnpa_consume_args,
      sub
      {
        die 'TODO::ArgsRemain'
          if ($_[3]->{$S_new_arguments} &&
              %{$_[3]->{$S_new_arguments}});
      },
      $class, $stash);
}

# ---- new --------------------------------------------------------------------

sub new
{
  my $class = shift;
  my $stash = { $S_new_constructor => 'new' };
  my $self;

  my $meta_class = $class->get_meta_class();

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $meta_class->_gh_RunHooks(
      $H_new_prepare_environment, $class, $stash, @_);
  return $stash->{$S_new_return}
    if exists($stash->{$S_new_return});

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $meta_class->_gh_RunHooksAugmented(
      $H_new_create_image, sub { $_[3]->{$S_new_image} //= {} },
      $class, $stash, @_);
  return $stash->{$S_new_return}
    if exists($stash->{$S_new_return});

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $meta_class->_gh_RunHooksAugmented(
      $H_new_process_arguments,
      sub { shift; shift; shift->_gh_new_process_arguments(@_) },
      $class, $stash, @_);
  return $stash->{$S_new_return}
    if exists($stash->{$S_new_return});

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $self = $meta_class->_gh_RunHooksAugmented(
      $H_instantiate,
      sub { return bless($_[3]->{$S_new_image}, $_[2]) },
      $class, $stash, @_);
  if (Scalar::Util::blessed($self))
  {
    # __hook__($hook_runner, $hook_name, $self, $stash)
    $meta_class->_gh_RunHooksReversed(
        $H_init_Build, $self, $stash);
    $meta_class->_gh_RunHooks(
        $H_init_Validate, $self, $stash);
    $meta_class->_gh_RunHooksReversed(
        $H_init_InitParts, $self, $stash);
    $meta_class->_gh_RunHooks(
        $H_init_InitWhole, $self, $stash);
  }

  return $self;
}

# ---- _fast_new --------------------------------------------------------------

sub _fast_new
{
  my $class = $_[0];
  my $stash = { $S_new_constructor => '_fast_new', $S_new_image => $_[1] };
  my $self;

  my $meta_class = $class->get_meta_class();

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $meta_class->_gh_RunHooks(
      $H_new_prepare_environment, $class, $stash, @_);
  return $stash->{$S_new_return}
    if exists($stash->{$S_new_return});

  # SKIP new_create_image
  # SKIP new_process_arguments

  # __hook__($hook_runner, $hook_name, $class_name, $stash, @new_args)
  $self = $meta_class->_gh_RunHooksAugmented(
      $H_instantiate,
      sub { return bless($_[3]->{$S_new_image}, $_[2]) },
      $class, $stash, @_);
  if (Scalar::Util::blessed($self))
  {
    # __hook__($hook_runner, $hook_name, $self, $stash)
    # SKIP init_Build
    # SKIP init_Validate
    $meta_class->_gh_RunHooksReversed(
        $H_init_InitParts, $self, $stash);
    $meta_class->_gh_RunHooks(
        $H_init_InitWhole, $self, $stash);
  }

  return $self;
}

###### THE END ################################################################

1

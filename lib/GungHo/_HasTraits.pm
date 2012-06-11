#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_HasTraits;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# Hash keys
our $HK_spec = 'spec';
our $HK_traits = 'trait';
our $HK_trait_args = 'trait_args';

###### METHODS ################################################################

# ==== Traits =================================================================

sub _gh_MergeSuperTraits
{
  my $self = shift;
  my $trait_args = $self->{$HK_trait_args} //= Tie::IxHash->new();

  my $super_traits;
  foreach my $super_spec (map { $_->_gh_GetSpec() } @_)
  {
    next unless ($super_traits = $super_spec->{'traits'});

    foreach my $trait ($super_traits->Keys())
    {
      $trait_args->Push($trait, $super_traits->FETCH($trait))
        unless $trait_args->EXISTS($trait);
    }
  }
}

sub _gh_ProcessTraitParameters
{
  my $self = $_[0];
  my $spec = $_[1];

  my $requested_traits = delete($spec->{'traits'});
  if (defined($requested_traits) &&
      ($requested_traits = GungHo::Utils::make_ixhash($requested_traits)) &&
      $requested_traits->Length())
  {
    $self->{$HK_spec}->{'traits'} = $requested_traits;
  }
  else
  {
    delete($self->{$HK_spec}->{'traits'});
    undef($requested_traits);
  }

  my $trait_args = delete($self->{$HK_trait_args});
  if ($requested_traits)
  {
    $trait_args //= Tie::IxHash->new();
    foreach my $trait ($requested_traits->Keys())
    {
      $trait_args->Push($trait, $requested_traits->FETCH($trait));
    }
  }

  if ($trait_args)
  {
    foreach my $trait ($trait_args->Keys())
    {
      $self->_gh_AddTrait($spec, $trait, $trait_args->FETCH($trait));
    }
  }
}

sub _gh_AddTrait
{
  my ($self, $spec, $trait_name, $trait_args) = @_;
  my $traits = $self->{$HK_traits} //= Tie::IxHash->new();

  die "TODO::DuplicateTrait[$trait_name]"
    if $traits->FETCH($trait_name);

  # Load and instantiate trait
  my $trait_class = GungHo::Registry::get_or_load_trait($trait_name);
  my $trait_obj = $trait_class->can('new') ?
      $trait_class->new($self, $trait_args) : $trait_class;

  # Let it hook into code generation
  $trait_obj->_gh_SetupTrait($self, $spec)
    if $trait_obj->can('_gh_SetupTrait');

  $traits->Push($trait_name, $trait_obj);
}

sub _gh_AddDependencyTrait
{
  my ($self, $spec, $trait_name, $trait_args) = @_;
  $self->_gh_AddTrait($spec, $trait_name, $trait_args)
    unless ($self->{$HK_traits} && $self->{$HK_traits}->FETCH($trait_name));
}

sub GetTrait
{
  # my $self = $_[0];
  # my $trait = $_[1];
  return (defined($_[1]) && $_[0]->{$HK_traits}) ?
      $_[0]->{$HK_traits}->FETCH($_[1]) : undef;
}

###### THE END ################################################################

1

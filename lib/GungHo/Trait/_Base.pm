#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

sub TraitName
{
  my $class = ref($_[0]) || $_[0];
  my ($trait_name) = $class =~ /Trait::(\w+)/ or
    die 'TODO::TraitName';
  return $trait_name;
}

# ==== Setup ==================================================================

# ---- DoSetup ----------------------------------------------------------------

sub _gh_DoSetupClassTrait
{
  my $self = $_[0];
  my $host = $_[1];

  $host->_gh_AddHook('gh_class_add_attribute',
        $ModName => sub { $self->_gh_Class_AddAttribute(@_) })
      if $self->can('_gh_Class_AddAttribute');
}

sub _gh_DoSetupAttributeTrait
{
  my $self = $_[0];
  my $host = $_[1];

  $host->_gh_AddHook($H_cg_prepare_code_generator,
      $ModName => sub { $self->_gh_Attr_PrepareCodeGenerator(@_) })
    if $self->can('_gh_Attr_PrepareCodeGenerator');
}

# ---- Setup ------------------------------------------------------------------

sub _gh_SetupClassTrait
{
  my $self = shift;
  my $host = shift;

  my $trait_name = $self->TraitName();
  $self->_gh_DoSetupClassTrait($host, @_)
    unless $host->HasFlag("No$trait_name");
}

sub _gh_SetupAttributeTrait
{
  my $self = shift;
  my $host = shift;

  my $trait_name = $self->TraitName();
  $self->_gh_DoSetupAttributeTrait($host, @_)
    unless $host->HasFlag("No$trait_name");
}

sub _gh_SetupTrait
{
  my $self = shift;
  my $host = shift;

  $self->_gh_SetupClassTrait($host, @_)
    if $host->isa('GungHo::Class');
  $self->_gh_SetupAttributeTrait($host, @_)
    if $host->isa('GungHo::_Attribute');
}

# ==== _gh_Class_AddAttribute =================================================

# $self->__hook__($hook_runner, $hook_name, $class, $attr_name, $attr_spec_in)
sub _gh_Class_AddAttribute
{
  my $self = shift;
  my $attr_spec_out = shift->Continue(@_);

  if ($attr_spec_out)
  {
    $attr_spec_out = { %{$attr_spec_out} };

    my $traits = $attr_spec_out->{'traits'} =
        $attr_spec_out->{'traits'} ?
            GungHo::Utils::make_ixhash($attr_spec_out->{'traits'}) :
            Tie::IxHash->new();
    my $trait_name = $self->TraitName();
    $traits->Push( $trait_name => $self->{'args'} )
      unless $traits->EXISTS($trait_name);
  }

  return $attr_spec_out;
}

###### THE END ################################################################

1

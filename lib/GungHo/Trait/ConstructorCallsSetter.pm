#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::ConstructorCallsSetter;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

sub new
{
  # my ($class, $args) = @_;
  return bless({ 'args' => $_[1] }, $_[0]);
}

sub TraitName
{
  my $class = ref($_[0]) || $_[0];
  my ($trait_name) = $class =~ /Trait::(\w+)/ or
    die 'TODO::TraitName';
  return $trait_name;
}

sub _gh_SetupTrait
{
  my $self = $_[0];
  my $host = $_[1];
  # my $attr_spec = $_[2];

  my $trait_name = $self->TraitName();
  my @flags = keys(%{$host->GetPropertyHashRef()});
  if (!$host->HasFlag("No$trait_name"))
  {
    if ($host->isa('GungHo::Class'))
    {
      $host->_gh_AddHook('gh_class_add_attribute',
          $ModName => sub { $self->_gh_PatchAttribute(@_) });
    }
    elsif ($host->isa('GungHo::_Attribute'))
    {
      $host->_gh_AddHook($H_cg_prepare_code_generator,
          $ModName => sub { $self->_gh_PrepareCodeGenerator(@_) });
    }
  }
}

# ==== _gh_PatchAttribute =====================================================

# $self->__hook__($hook_runner, $hook_name, $attr_name, $attr_spec_in)
sub _gh_PatchAttribute
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

# ==== _gh_PrepareCodeGenerator ===============================================

# $self->__hook__($hook_runner, $hook_name, $cg)
sub _gh_PrepareCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[3];

  $cg->Patch("${ModName}_s",
      'into' => 'build_s',
      'before' => 'build_builder_s');

  $cg->_gh_AddHook('gh_cg_do_step',
      $ModName =>
          # __hook__($hook_runner, $hook_name, $cg, $what, $step, $stash)
          sub
          {
            my $what = $_[3];
            my $step = $_[4];
            my $ret;

            if (($what eq "attribute_${H_hnpa_consume_args}_s") &&
                ($step eq 'hnpacahook_s'))
            {
              my $cg = $_[2];
              my $stash = $_[5];
              my $hook_runner = shift;

              $cg->Push(undef, undef,
                    {
                      # Autovivification
                      'image_e' => "#{stash_e}#->{'$ModName'}"
                    });
              $ret = $hook_runner->Continue(@_);
              $cg->Pop();
            }
            elsif (($what eq 'build_s') &&
                   ($step eq "${ModName}_s"))
            {
              my $stash = $_[5];

              # TODO: Make this more parametric
              my $setter = $stash->{'attribute'}->GetMethodName('setter');
              if ($setter)
              {
                my $attr_name = $stash->{'attribute_name'};
                $ret = $cg->ExpandPattern(
                    "#{self_e}#->$setter(#{v_e}#) if exists(#{v_e}#);\n",
                    {
                      'v_e' => "#{stash_e}#->{'$ModName'}->{'$attr_name'}"
                    });
                $cg->MakeImportant();
              }
            }

            return $ret;
          });
  return undef;
}

###### THE END ################################################################

1

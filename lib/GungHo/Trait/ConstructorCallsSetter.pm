#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::ConstructorCallsSetter;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base );

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### SUBS ###################################################################

# Not a hook, really, but it's called like a hook.
# __hook__($hook_runner, $hook_name, $cg_args)
sub __builder_generator
{
  my $cg_args = $_[2];
  my $stash = $cg_args->{$CGHA_generate_args}->[0];
  my $ret;

  # TODO: Make this more parametric
  my $setter = $stash->{'attribute'}->GetMethodName('set');
  if ($setter)
  {
    my $cg = $cg_args->{$CGHA_code_generator};
    $ret = $cg->ExpandPattern(
        "#{self_e}#->$setter(#{v_e}#) if exists(#{v_e}#);\n",
        {
          'v_e' => "#{stash_e}#->{'$ModName'}->{#{attr.name_e}#}"
        });
    $cg->MakeImportant();
  }

  return $ret;
}

###### METHODS ################################################################

sub new
{
  # my ($class, $host, $args) = @_;
  return bless({ 'args' => $_[2] }, $_[0]);
}

# ==== _gh_Attr_PrepareCodeGenerator ==========================================

# $self->__hook__($hook_runner, $hook_name, $attr, $cg)
sub _gh_Attr_PrepareCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[4];

  # Re-wire hnpacahook to put away args in #{stash_e}#->{$ModName}
  $cg->AddNamedPattern(
      'attr.hnpacahook.set_s' =>
          "#{stash_e}#->{'$ModName'}->{#{attr.name_e}#} = " .
              "#{del_arg_value_e}#;\n");

  # Then arrange that the setter will be called with these values
  my $insert = $cg->GetUniqueName("$self.builder_s", '_s');
  $cg->AddNamedPattern( $insert => \&__builder_generator );
  $cg->Patch($insert,
      'into' => 'attr.inithook.build_s',
      'before' => '*');

  return undef;
}

###### THE END ################################################################

1

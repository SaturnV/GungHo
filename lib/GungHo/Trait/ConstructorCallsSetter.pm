#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::ConstructorCallsSetter;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base );

use GungHo::Names qw( :HOOK_NAMES );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

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

  $cg->Patch("${ModName}_s",
      'into' => 'build_s',
      'before' => 'build_builder_s');

  # TODO: Simplify this
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

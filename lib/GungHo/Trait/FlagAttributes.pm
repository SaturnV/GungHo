#! /usr/bin/perl
# TODO: License
# Automatically tag attributes with flags.
#  * Inherited attributes are not modified, unless mentioned in derived spec.
#    (That is an empty spec in the derived class is enough for the attribute
#    to get the flag.)
#  * If a derived class adds loads FlagAttributes again that completely
#    overwrites FlagAttributes specs.
###### NAMESPACE ##############################################################

package GungHo::Trait::FlagAttributes;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

# ==== Trait interface ========================================================

sub new
{
  my ($class, $host, $args) = @_;

  my $self = bless(
      {
        'args' => $args,
        'parent' => $host,
      }, $class);
  Scalar::Util::weaken($self->{'parent'});

  return $self;
}

sub _gh_SetupAttributeTrait
{
  my $self = shift;
  my $host = shift;
  my $trait_name = $self->TraitName();
  $host->_gh_AddHook('gh_attr_post_arguments', "$self" => sub
      {
        $self->__SetFlags($_[2]);
        return undef;
      });
}

# =============================================================================

sub __SetFlags
{
  my $self = $_[0];

  if (defined(my $args = $self->{'args'}))
  {
    my $tgt = $_[1];

    if (!ref($args))
    {
      $tgt->_gh_AddWeakFlag($args);
    }
    elsif (ref($args) eq 'ARRAY')
    {
      $tgt->_gh_AddWeakFlag($_) foreach (@{$args});
    }
    elsif (ref($args) eq 'HASH')
    {
      $tgt->_gh_AddWeakProperty( $_ => $args->{$_} )
        foreach (keys(%{$args}));
    }
    else
    {
      my $ref = ref($args);
      die "TODO: Don't know what to do with a(n) $ref.\n";
    }
  }
}

###### THE END ################################################################

1

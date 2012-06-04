#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_HookRunner;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw ( import );

###### INIT ###################################################################

our @EXPORT_OK = qw( run_hooks );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### SUBS ###################################################################

# run_hooks([$method_ref, ...], @args)
sub run_hooks { return @{$_[0]} ? $ModName->new(shift)->Start(@_) : undef }

###### METHODS ################################################################

# $class->new([$method_ref, ...])
sub new { return bless($_[1], $_[0]) }

sub IsDone { return !scalar(@{$_[0]}) }

sub Last { @{$_[0]} = () }

# $self->Start|Continue(@args)
sub Continue
{
  my $self = shift;
  my $ret;

  while (@{$self})
  {
    if (defined($ret = shift(@{$self})->($self, @_)))
    {
      @{$self} = ();
      last;
    }
  }

  return $ret;
}

*Start = \&Continue;

###### THE END ################################################################

1

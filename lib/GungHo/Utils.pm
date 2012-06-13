#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Utils;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw ( import );

use Scalar::Util;
use Tie::IxHash;

###### INIT ###################################################################

our @EXPORT_OK = qw(
    make_hashref make_arrayref make_ixhash clone_ixhash
    get_symbol set_symbol
    _ProcessParameters );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### SUBS ###################################################################

# ---- make_hashref -----------------------------------------------------------

# TODO docs
sub make_hashref
{
  my $ret;

  if (!$#_ && (ref($_[0]) eq 'HASH'))
  {
    $ret = $_[0];
  }
  elsif ($#_ & 1)
  {
    $ret = { @_ };
  }
  else
  {
    die 'TODO::ParameterError';
  }

  return $ret;
}

# ---- make_arrayref ----------------------------------------------------------

sub make_arrayref
{
  return ($#_ || (ref($_[0]) ne 'ARRAY')) ? [ @_ ] : $_[0];
}

# ---- make_ixhash ------------------------------------------------------------

sub make_ixhash
{
  my $ret;

  if (!$#_)
  {
    my $arg = $_[0];

    if (!ref($arg))
    {
      $ret = Tie::IxHash->new( $arg => undef );
    }
    elsif (ref($arg) eq 'ARRAY')
    {
      $ret = Tie::IxHash->new( map { $_ => undef } @{$arg} );
    }
    elsif (ref($arg) eq 'HASH')
    {
      $ret = Tie::IxHash->new( map { $_ => $arg->{$_} } keys(%{$arg}) );
    }
    elsif (Scalar::Util::blessed($arg) && $arg->isa('Tie::IxHash'))
    {
      $ret = $arg;
    }
    else
    {
      die "TODO::BadArg";
    }
  }
  elsif (@_)
  {
    $ret = Tie::IxHash->new(@_);
  }

  return $ret;
}

# ---- clone_ixhash -----------------------------------------------------------

sub clone_ixhash
{
  return Tie::IxHash->new( map { $_ => $_[0]->FETCH($_) } $_[0]->Keys() );
}

# ---- (get|set)_symbol -------------------------------------------------------

sub get_symbol
{
  no strict 'refs';
  return $_[1] ? *{$_[0]}{$_[1]} : \*{$_[0]};
}

sub set_symbol
{
  no strict 'refs';
  *{$_[0]} = $_[1];
}

###### METHODS ################################################################

sub _ProcessParameters
{
  my ($self, $params, $method_prefix) = @_;

  my $ref;
  foreach my $n (keys(%{$params}))
  {
    $ref = $self->can($method_prefix . $n) or
      die "TODO::ParameterError::Unknown[$n]";
    $self->$ref($n, $params->{$n});
  }
}

###### THE END ################################################################

1

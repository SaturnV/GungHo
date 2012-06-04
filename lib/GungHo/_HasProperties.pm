#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_HasProperties;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $HK_properties = 'properties';

###### METHODS ################################################################

# ---- _gh_MergeSuperProperties -----------------------------------------------

sub _gh_MergeSuperProperties
{
  my $self = shift;
  my $ps = $self->{$HK_properties} //= {};

  my $super_ps;
  foreach my $super (@_)
  {
    next unless $super->isa($ModName);

    foreach (keys(%{$super_ps = $super->GetPropertyHashRef()}))
    {
      $ps->{$_} = $super_ps->{$_}
        unless exists($ps->{$_});
    }
  }
}

# ---- Specs / Params ---------------------------------------------------------

sub _gh_ProcessPropertyParameters
{
  my $self = $_[0];
  my $spec = $_[1];

  $self->__ProcessParam_flags(
      'flags', delete($spec->{'flags'}))
    if exists($spec->{'flags'});
  $self->__ProcessParam_properties(
      'properties', delete($spec->{'properties'}))
    if exists($spec->{'properties'});
}

sub __ProcessParam_flags
{
  # my ($self, $n, $v) = @_;
  if (defined($_[2]))
  {
    my $ps = $_[0]->{$HK_properties} //= {};
    my @fs = (ref($_[2]) eq 'ARRAY') ? @{$_[2]} : ($_[2]);

    my $v;
    foreach (@fs)
    {
      $v = !s/^!//;
      $ps->{$_} = $v;
    }
  }
}

sub __ProcessParam_properties
{
  # my ($self, $n, $v) = @_;
  if (defined($_[2]))
  {
    my $ps = $_[0]->{$HK_properties} //= {};
    die "TODO:PropertiesNotHash"
      unless (ref($_[2]) eq 'HASH');
    $ps->{$_} = $_[2]->{$_} foreach (keys(%{$_[2]}));
  }
}

# ---- Get --------------------------------------------------------------------

sub GetPropertyHashRef { return $_[0]->{$HK_properties} //= {} }

sub GetProperty
{
  my $ps = $_[0]->{$HK_properties};
  return $ps ? $ps->{$_[1]} : 0;
}
*HasFlag = *GetProperty;

###### THE END ################################################################

1

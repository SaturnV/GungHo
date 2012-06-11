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

# ---- Modify -----------------------------------------------------------------

# NOTE Know what you are doing when using these. Modifying flags late
#      in the build process may result in inconsistencies.

# $x->_gh_AddProperty('name', 'value')
sub _gh_AddProperty
{
  my $ps = $_[0]->{$HK_properties} //= {};
  $ps->{$_[1]} = $_[2];
}

# $x->_gh_AddWeakProperty('name', 'value')
sub _gh_AddWeakProperty
{
  my $ps = $_[0]->{$HK_properties} //= {};
  $ps->{$_[1]} = $_[2] unless exists($ps->{$_[1]});
}

# $x->_gh_AddFlag('name')
# $x->_gh_AddFlag('!name')
sub _gh_AddFlag
{
  my $n = $_[1];
  my $v = $n !~ s/^!//;
  $_[0]->_gh_AddProperty($n, $v);
}

# $x->_gh_AddWeakFlag('name')
# $x->_gh_AddWeakFlag('!name')
sub _gh_AddWeakFlag
{
  my $n = $_[1];
  my $v = $n !~ s/^!//;
  $_[0]->_gh_AddWeakProperty($n, $v);
}

# $x->_gh_RemoveFlag('name')
# $x->_gh_RemoveProperty('name')
sub _gh_RemoveProperty
{
  my $ps = $_[0]->{$HK_properties};
  delete($ps->{$_[1]}) if $ps;
}
*_gh_RemoveFlag = *_gh_RemoveProperty;

###### THE END ################################################################

1

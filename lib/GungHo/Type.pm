#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Type;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw( import );

use GungHo::Registry;

our @EXPORT_OK = qw( parse_and_load_type );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### SUBS ###################################################################

sub split_requested_type
{
  my $type_spec = $_[0];
  my ($requested_type, @type_args) =
      ref($type_spec) ? @{$type_spec} : ($type_spec);
  return $requested_type unless wantarray;
  return ($requested_type, @type_args);
}

sub parse_and_load_type
{
  my $parent_type = $_[0];
  my $requested_type = $_[1];
  my $type_obj;

  # Parse type argument into type and parameters
  my ($requested_type_name, @requested_type_args) =
      split_requested_type($requested_type);

  # Load and instantiate type
  my $type_class = GungHo::Registry::get_or_load_type($requested_type_name);
  if ($type_class->can('new'))
  {
    $type_obj = $type_class->new($parent_type, @requested_type_args);
  }
  else
  {
    die "TODO: Can't pass parameters to non-parametric type " .
            "'$requested_type_name'"
      if @requested_type_args;
    $type_obj = $type_class;
  }
  
  return $type_obj;
}

###### THE END ################################################################

1

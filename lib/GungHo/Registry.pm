#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Registry;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw ( import );

###### INIT ###################################################################

our @EXPORT_OK = qw( register_meta_class get_meta_class );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### SUBS ###################################################################

# ==== Registry ===============================================================

our %Registry;

sub _register
{
  my $obj_type = $_[0];
  my $obj_name = $_[1];
  my $obj = $_[2];

  my $registry = $Registry{$obj_type} //= {};
  warn "TODO: $obj_type '$obj_name' redefined."
    if ($registry->{$obj_name} && ($registry->{$obj_name} ne $obj));
  return $registry->{$obj_name} = $obj;
}

sub _get
{
  # my $obj_type = $_[0];
  # my $obj_name = $_[1];

  my $registry = $Registry{$_[0]};
  return $registry && $registry->{$_[1]} ? ($registry->{$_[1]}) : ()
    if wantarray;
  return $registry && $registry->{$_[1]};
}

sub _get_or_load
{
  my $obj_type = $_[0];
  my $obj_name = $_[1] or
    die "TODO: No $obj_type name";
  my $obj_namespace = $_[2];

  my $obj = ref($obj_name) ? $obj_name : _get($obj_type, $obj_name);
  if (!$obj)
  {
    my $full_name = ($obj_name =~ /^GungHo::/) ?
        $obj_name : "${obj_namespace}::$obj_name";
    my $fn = "$full_name.pm";
    $fn =~ s{::}{/}g;
    eval { require "$fn" };
    die "TODO: Can't find $obj_type '$obj_name' [$@]." if $@;
    $obj = _register($obj_type, $obj_name, $full_name);
  }

  return $obj;
}

sub _get_all
{
  # my $obj_type = $_[0];
  # my $registry = $Registry{$_[0]};
  return $Registry{$_[0]} ? values(%{$Registry{$_[0]}}) : ();
}

# ---- Classes ----------------------------------------------------------------

# register_class($meta_class)
sub register_meta_class
{
  # my $meta_class = $_[0];
  # my $class_name = $meta_class->Name();
  return _register('metaclass', $_[0]->Name(), $_[0]);
}

# get_meta_class($class_name)
sub get_meta_class
{
  # my $class = ref($_[0]) || $_[0];
  return _get('metaclass', ref($_[0]) || $_[0]);
}

sub get_registered_classes { return _get_all('metaclass') }

# ---- Types ------------------------------------------------------------------

# register_type($type)
# register_type($type, 'ShortName')
sub register_type
{
  my $type = $_[0] or
    die "TODO: No type.";
  my $type_name = $_[1] || ref($type) || $type;
  $type_name =~ s/^GungHo::Type:://;
  _register('type', $type_name, $type);
}

sub get_type { return _get('type', $_[0]) }
sub get_or_load_type { return _get_or_load('type', $_[0], 'GungHo::Type') }

# ---- Traits -----------------------------------------------------------------

# register_trait($trait)
# register_trait($trait, 'ShortName')
sub register_trait
{
  my $trait = $_[0] or
    die "TODO: No trait.";
  my $trait_name = $_[1] || ref($trait) || $trait;
  $trait_name =~ s/^GungHo::Trait:://;
  _register('trait', $trait_name, $trait);
}

sub get_trait { return _get('trait', $_[0]) }
sub get_or_load_trait { return _get_or_load('trait', $_[0], 'GungHo::Trait') }

###### THE END ################################################################

1

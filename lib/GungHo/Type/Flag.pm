#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Flag;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### INIT ###################################################################

use parent qw( GungHo::Type::Any );

###### VARS ###################################################################

our $ModName = __PACKAGE__;
our $TypeName = $ModName->Name();

###### METHODS ################################################################

sub new
{
  my $class = shift;
  my $parent_type = shift;
  die "TODO: $TypeName expects two arguments (field, value)"
    unless (2 == scalar(@_));

  my $self = bless({}, $class);
  if (defined($parent_type))
  {
    $self->{'parent'} = $parent_type;
    Scalar::Util::weaken($self->{'parent'})
      if ref($parent_type);
  }

  # TODO: Check value
  $self->{'field'} = $_[0];
  $self->{'value'} = 0 + $_[1];

  return $self;
}

sub _gh_SetupAttributeHooks
{
  my $self = shift;

  $self->{'attr'} = $_[0];
  Scalar::Util::weaken($self->{'attr'});
  $self->{'meta_class'} = $_[0]->_gh_MetaClass();
  Scalar::Util::weaken($self->{'meta_class'});

  $_[0]->_gh_AddTrait(undef, 'ConstructorCallsSetter')
    unless $_[0]->GetTrait('ConstructorCallsSetter');

  return $self->SUPER::_gh_SetupAttributeHooks(@_);
}

sub _gh_PrepareCodeGenerator
{
  my $self = shift;
  my $cg = $_[3];

  my $value = $self->{'value'};

  my $field = $self->{'field'};
  my $meta_class = $self->{'meta_class'};
  my $field_attr = $meta_class->GetAttributeByName($field) or
    die "TODO: No field named '$field'";
  my $getter = $field_attr->GetMethodName('rawget') ||
               $field_attr->GetMethodName('get') or
    die "TODO: Attribute '$field' doesn't support 'get'";
  my $setter = $field_attr->GetMethodName('rawset') ||
               $field_attr->GetMethodName('set') or
    die "TODO: Attribute '$field' doesn't support 'set'";

  $cg->AddNamedPattern(
      'attr.read_e' =>
          "!!((#{self_e}#->$getter() || 0) & $value)",
      'attr.read_s' =>
          "#{define_x(attr_value_e,#{attr.read_e}#)}#",
      'attr.rawget_e' => '#{attr.read_e}#',
      'attr.get_e' => '#{attr.read_e}#',
      'attr.write_weak_e' =>
          "#{self_e}#->$setter(#{new_value_e}# ? " .
              "(#{self_e}#->$getter() || 0) | $value : " .
              "(#{self_e}#->$getter() || 0) & ~$value)",
      'attr.write_weak_s' =>
          "#{attr.write_weak_e}#;\n");

  return $self->SUPER::_gh_PrepareCodeGenerator(@_);
}

sub _gh_SerializatorPattern
{
  my $self = shift;
  my @ret = $self->SUPER::_gh_SerializatorPattern(@_);
  $ret[2] = $ret[0];
  return @ret;
}

###### THE END ################################################################

1

#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Defined;

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
  die "TODO: Defined type expects no arguments" if @_;

  my $self = bless({}, $class);
  if (defined($parent_type))
  {
    $self->{'parent'} = $parent_type;
    Scalar::Util::weaken($self->{'parent'})
      if ref($parent_type);
  }

  return $self;
}

# $type->Validate($arg)
sub Validate
{
  my $self = shift;
  if (!$self->{'parent'} || !$self->{'parent'}->isa('GungHo::Type::Optional'))
  {
    die "TODO::TypeError[$TypeName]: Undefined value"
      unless defined($_[0]);
  }
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $self = shift;
  my $ret = '';

  if (!$self->{'parent'} || !$self->{'parent'}->isa('GungHo::Type::Optional'))
  {
    $ret = "die 'TODO::TypeError[$TypeName]: Undefined value'\n" .
           "  unless defined($_[0]);\n";
  }

  return $ret;
}

###### THE END ################################################################

1

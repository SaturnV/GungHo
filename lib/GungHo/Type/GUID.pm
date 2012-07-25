#! /usr/bin/perl
# TODO: License
# TODO: Move to GungHo extensions.
###### NAMESPACE ##############################################################

package GungHo::Type::GUID;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use UUID;

###### INIT ###################################################################

use parent qw( GungHo::Type::String );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $TypeName = $ModName->Name();

my $re_guid = qr/^[0-9a-f]{32}\z/i;

###### METHODS ################################################################

# $type->Validate($arg)
sub Validate
{
  my $self = shift;
  $self->SUPER::Validate(@_);
  die "TODO::TypeError[$TypeName]: Doesn't look good."
    unless ($_[0] =~ $re_guid);
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $self = shift;
  return $self->SUPER::_gh_ValidatorPattern(@_) .
         "die 'TODO::TypeError[$TypeName]: Does not look good.'\n" .
         "  unless  ($_[0] =~ /$re_guid/);\n";
}

sub DefaultValue
{
  my $uuid;
  UUID::generate($uuid);
  return unpack('H32', $uuid);
}

###### THE END ################################################################

1

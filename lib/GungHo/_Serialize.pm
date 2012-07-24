#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Serialize;

###### IMPORTS ################################################################

use Exporter qw( import );

###### INIT ###################################################################

our @EXPORT_OK = qw( _gh_cg_serialize_es _gh_cg_deserialize_es );

###### SUBS ###################################################################

# ==== _gh_cg_serialize_es ====================================================

sub _gh_cg_serialize_es
{
  # my ($attr, $cg, $stash, $context) = @_;
  my $attr = shift;
  my $type = $attr->Type() or
    die "TODO: Can't get type object for '" . $attr->Name() . "'";
  return $type->_gh_SerializatorPattern($attr, @_);
}

# ==== _gh_cg_deserialize_es ==================================================

sub _gh_cg_deserialize_es
{
  # my ($attr, $serial_e, $cg, $stash, $context) = @_;
  my $attr = shift;
  my $type = $attr->Type() or
    die "TODO: Can't get type object for '" . $attr->Name() . "'";
  return $type->_gh_DeserializatorPattern($attr, @_);
}

###### THE END ################################################################

1

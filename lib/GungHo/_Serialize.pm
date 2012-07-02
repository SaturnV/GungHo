#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Serialize;

###### IMPORTS ################################################################

use Exporter qw( import );

###### INIT ###################################################################

our @EXPORT_OK = qw( _gh_cg_serialize_e _gh_cg_deserialize_e );

###### SUBS ###################################################################

# ==== _gh_cg_serialize_e =====================================================

sub _gh_cg_serialize_e
{
  # TODO proper serialization through type
  my ($attr, $cg, $stash) = @_;
  my $ret;

  # TODO error checking
  $attr = $meta_class->GetAttributeByName($attr)
    unless ref($attr);
  die 'TODO' unless $attr;

  $cg->Push();
  $cg->Use($attr);
  $ret = $cg->Generate('serialize', ['attr.get_e'], $stash);
  $cg->Pop();

  return $ret;
}

# ==== _gh_cg_deserialize_e ===================================================

sub _gh_cg_deserialize_e
{
  # TODO proper deserialization through type
  # my ($attr, $serial_e, $cg, $stash) = @_;
  return $_[1];
}

###### THE END ################################################################

1

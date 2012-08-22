#! /usr/bin/perl
# TODO: License
# Do nothing type.
###### NAMESPACE ##############################################################

package GungHo::Type::Any;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );

###### INIT ###################################################################

use parent qw( GungHo::Type::_Base );

###### VARS ###################################################################

our $ModName = __PACKAGE__;
our $TypeName = $ModName->Name();

###### METHODS ################################################################

# ==== Serialization ==========================================================

# TODO
# sub Serialize {}
# sub Deserialize {}

sub _gh_SerializatorPattern
{
  # my ($self, $attr, $cg, $stash, $context) = @_;
  my ($self, $attr, $cg, $stash) = @_;
  my $ret_e;

  my ($rep, $gen) = $attr->_gh_GetMethodNames('get');
  if (!defined($rep) || !defined($gen) || ($rep eq $gen))
  {
    $cg->Push();
    $cg->Use($attr);
    $ret_e = $cg->Generate('serialize', ['attr.get_e'], $stash);
    $cg->Pop();
  }
  else
  {
    die "TODO: No getter" unless $rep;
    $ret_e = "#{self_e}#->$rep()";
  }

  return ($ret_e, '', "defined($ret_e)");
}

sub _gh_DeserializatorPattern
{
  my ($self, $attr, $serial_e, $dest_e, $cg, $stash, $context) = @_;
  my $method = ($context && $context->{'trusted'}) ?
      '_gh_TrustedDeserializatorPattern' :
      '_gh_UntrustedDeserializatorPattern';
  return $self->$method($attr, $serial_e, $dest_e, $cg, $stash, $context);
}

sub _gh_TrustedDeserializatorPattern
{
  # my ($self, $attr, $serial_e, $dest_e, $cg, $stash, $context) = @_;
  return ($_[2], ($_[3] && ($_[3] ne $_[2])) ? "$_[3] = $_[2];\n" : '');
}

sub _gh_UntrustedDeserializatorPattern
{
  # TODO Overridden setter
  # TODO Optimize for in place deserialization
  my ($self, $attr, $serial_e, $dest_e, $cg, $stash, $context) = @_;
  my ($ret_e, $ret_s);

  $cg->Push();
  $cg->Use($attr);

  if ($dest_e)
  {
    $cg->AddNamedPattern('deserialized_e', $dest_e);
    $ret_e = $ret_s = '';
  }
  else
  {
    $cg->CreateScalarVar('deserialized');
    $ret_e = $cg->ExpandPattern('#{deserialized_e}#');
    $ret_s = $cg->ExpandPattern("my \$#{deserialized_sv}#;\n");
  }

  my $set_s = ($context && $context->{'dont_validate_attrs'}) ?
      'attr.set_novalidate_s' :
      'attr.set_s';
  $cg->AddNamedPattern(
      'arg_value_e' => $serial_e,
      'attr.set.write_s' => "#{deserialized_e}# = #{new_value_e}#;\n");
  $ret_s .= $cg->Generate('deserialize', [$set_s], $stash);

  $cg->Pop();

  return ($ret_e, $ret_s);
}

###### THE END ################################################################

1

#! /usr/bin/perl
# TODO: License
# TODO: Remove me
###### NAMESPACE ##############################################################

package GungHo::Type::Boolean;

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

# $type->Validate($arg)
sub Validate
{
  die "TODO::TypeError[$TypeName]: Not a boolean"
    if (defined($_[1]) && ($_[1] !~ /^[01]?\z/));
}

# $type->_gh_ValidatorPattern($arg_pattern)
sub _gh_ValidatorPattern
{
  my $self = shift;
  return "die 'TODO::TypeError[$TypeName]: Not a boolean'\n" .
         "  if (defined($_[0]) && ($_[0] !~ /^[01]?\\z/));\n";
}

# =============================================================================

sub ConvertToType { return !!$_[1] }
sub _gh_ConvertToTypePattern { return "!!$_[1]" }

# sub TransformValueOut { return !!$_[1] }
# sub _gh_TransformValueOutPattern { return "!!$_[1]" }

# TODO Replace this with the right stuff
sub _gh_PrepareCodeGenerator
{
  my $self = shift;
  $self->SUPER::_gh_PrepareCodeGenerator(@_);

  my $cg = $_[3];
  $cg->AddNamedPattern(
      'attr.convert_to_type_s' =>
          '#{define_cond_x(set_value_e,"!!#{arg_value_e}#")}#',
      # 'attr.transform_value_out_s' =>
      #     '#{define_x(return_value_e,"!!#{attr_value_e}#")}#'
      );

  return undef;
}

# =============================================================================

sub _gh_SerializatorPattern
{
  my ($self, $attr, $cg, $stash, $context) = @_;
  my $ret_e;

  $cg->Push();
  $cg->Use($attr);
  $ret_e = ($context && ($context->{'type'} ~~ /\bMySQL\b/)) ?
      $cg->ExpandPattern("#{attr.get_e}# ? 1 : 0") :
      $cg->ExpandPattern('#{attr.get_e}#');
  $cg->Pop();

  return ($ret_e, '', $ret_e);
}

sub _gh_DeserializatorPattern
{
  # my ($self, $attr, $serial_e, $dest_e, $cg, $stash, $context) = @_;
  my $self = shift;
  my @args = @_;
  if ($_[5])
  {
    my $context = { %{$_[5]} };
    $context->{'dont_validate_attrs'} = 1
      if $context->{'trusted'};
    $args[5] = $context;
  }
  return $self->_gh_UntrustedDeserializatorPattern(@args);
}


###### THE END ################################################################

1

#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Type::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our %Inserts =
    (
      'validate' =>
          {
            'can' => 'Validate',
            'patch' => [ 'into' => 'attr.validate_s' ],
            'pattern_generator' => '_gh_ValidatorPattern',
            'direct_call' => 'Validate',
            'args' => [ '#{set_value_e}#' ],
            'important' => 1
          },
      'default' =>
          {
            'can' => 'DefaultValue',
            'patch' => [ 'into' => 'attr.inithook.build_s',
                         'after' => '*' ],
            'pattern_generator' => '_gh_DefaultValuePattern',
            'direct_call' => 'DefaultValue',
            'direct_call_pattern' => '#{attr.rawset_s}#',
            'direct_call_patterns' =>
                {
                  'arg_value_e' => '#{type.default_pattern_e}#'
                },
            'args' => [],
            'important' => 1
          },
    );

###### METHODS ################################################################

# $class->TypeName()
sub TypeName
{
  my $type = ref($_[0]) || $_[0] || '<unknown>';
  $type =~ s/^GungHo::Type:://;
  return $type;
}

# $type_obj->_gh_SetupAttributeHooks($attr, $attr_spec)
sub _gh_SetupAttributeHooks
{
  my $self = $_[0];
  my $attr = $_[1];
  # my $attr_spec = $_[2];

  $attr->_gh_AddHook($H_b_prepare_code_generator,
      $ModName => sub { $self->_gh_PrepareCodeGenerator(@_) });
}

# $self->__hook__($hook_runner, $hook_name, $cg_owner, $cg)
sub _gh_PrepareCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[4];

  my ($insert, $insert_uniq);
  foreach my $insert_name (keys(%Inserts))
  {
    $insert = $Inserts{$insert_name};
    if ($self->can($insert->{'can'}))
    {
      $insert_uniq = $cg->GetUniqueName("$self.${insert_name}_s", '_s');
      $cg->AddNamedPattern($insert_uniq =>
          sub { return $self->_gh_EmitInsert($insert_name, @_) });
      $cg->Patch($insert_uniq, @{$insert->{'patch'}});
    }
  }

  return undef;
}

# ==== _gh_EmitInsert =========================================================

# $self->_gh_EmitInsert($insert_name, $hook_runner, $hook_name, $cg_args)
sub _gh_EmitInsert
{
  my $self = shift;
  my $insert_name = shift;
  my $hook_runner = shift;
  my $cg_args = $_[1];

  # Run the rest of the hooks
  my $ret = '';
  $ret = $hook_runner->Continue(@_) // ''
    if $hook_runner;

  if (my $insert = $Inserts{$insert_name})
  {
    my $cg = $cg_args->{$CGHA_code_generator};
    my $stash = $cg_args->{$CGHA_generate_args}->[0];

    my @args = @{$insert->{'args'}};
    my $pattern_generator = $insert->{'pattern_generator'};
    if ($self->can($pattern_generator))
    {
      # We have a pattern generator
      $ret .= $cg->ExpandPattern($self->$pattern_generator(@args));
    }
    else
    {
      # Direct call
      my $direct_call = $insert->{'direct_call'};

      my $class_name = $stash->{'class_name'};
      my $attr_name = $stash->{'attribute_name'};
      my $enclosed_type_obj = "type object for $class_name.$attr_name";
      $enclosed_type_obj =~ s/\W+/_/g;
      $stash->{'enclose'}->{$enclosed_type_obj} //= $self;

      my $pattern = $insert->{'direct_call_pattern'};
      if (defined($pattern))
      {
        $cg->Push();
        $cg->AddNamedPattern(
            'type.enclosed_obj_sv' => $enclosed_type_obj,
            'type.enclosed_obj_e' => "\$$enclosed_type_obj",
            'type.direct_call_str' => $direct_call,
            'type.args_ex' => join(', ', @args),
            'type.default_pattern_e' =>
                "#{type.enclosed_obj_e}#->#{type.direct_call_str}#" .
                    "(#{type.args_ex}#)",
            'type.default_pattern_s' => "#{type.default_pattern_e}#;\n");
        $cg->AddNamedPattern(%{$insert->{'direct_call_patterns'}})
          if $insert->{'direct_call_patterns'};
        $ret .= $cg->ExpandPattern($pattern);
        $cg->Pop();
      }
      else
      {
        {
          local $" = ', ';
          $pattern = "\$$enclosed_type_obj->$direct_call(@args);\n";
        }
        $ret .= $cg->ExpandPattern($pattern);
      }
    }

    $cg->MakeImportant() if $insert->{'important'};
  }

  return $ret;
}

# ==== Serialization ==========================================================

# TODO
# sub Serialize {}
# sub Deserialize {}

sub _gh_SerializatorPattern
{
  # my ($self, $attr, $cg, $stash, $context) = @_;
  my ($self, $attr, $cg, $stash) = @_;
  my $ret_e;

  $cg->Push();
  $cg->Use($attr);
  $ret_e = $cg->Generate('serialize', ['attr.get_e'], $stash);
  $cg->Pop();

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
  return $_[3] ? ('', "$_[3] = $_[2];\n") : ($_[2], '');
}

sub _gh_UntrustedDeserializatorPattern
{
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

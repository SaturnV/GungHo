#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::JSON;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base GungHo::_Builder );

use JSON qw();
use Scalar::Util;

use GungHo::Names qw( :CG_HOOK_ARGS );
use GungHo::_Serialize qw( _gh_cg_serialize_es _gh_cg_deserialize_es );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

my $json_ctx =
    {
      'name' => $ModName,
      'type' => 'JSON',
      'trusted' => 0
    }

# ==== Hash Keys ==============================================================

our $HK_args = 'args';
our $HK_parent = 'parent';

our $HK_method_specs = 'method_specs';

# ==== Method Types ===========================================================

our @MethodTypes = qw( deserialize serialize import export );

our %MethodNames =
    (
      # 'method_type' => [qw( reported_name generated_name )]
      # 'method_type' => 'name'
      'deserialize' => 'from_json',
      'serialize' => 'ToJson',
      'export' => 'ExportJsonObject',
      'import' => 'json_object_import'
    );

# ==== Code Templates =========================================================

# ==== CodePatterns ===========================================================

# Get trait object from stash
sub _get_trait_obj($)
{
  return $_[0]->{$ModName} ||
    die "TODO: Can't find myself";
}

# my ($hook_runner, $hook_name, $cg, $what, $step, $stash) = @_;
#     $_[0],        $_[1],    $_[2], $_[3], $_[4], $_[5]

our %CodePatterns =
    (
      # ---- import -----------------------------------------------------------

      'json.ct_import_s' => [qw(
          json.import.args_s
          json.import_s
          json.import.return_s )],

      'json.import.args_s' =>
          '#{define_x(class_e,"$_[0]")}#' .
          '#{define_x(class_str,"$_[0]")}#' .
          '#{define_x(json_obj_e,"$_[1]")}#',

      'json.import_s' => [qw(
          json.import.import_s
          json.import.instantiate_s )],

      'json.import.import_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);
            my $method_type = $stash->{'method_type'};

            $cg->CreateScalarVar('new_arg');
            my $code = $cg->ExpandPattern("my \$#{new_arg_sv}# = {};\n");

            # TODO non strict import (missing attrs)
            # TODO non strict import (extra attrs)

            my ($e, $s, $attr_name_e, $value_e);
            my $attrs = $trait_obj->_GetVar($method_type, 'attrs');
            foreach my $attr (@{$attrs})
            {
              $attr_name_e = $cg->QuoteString($attr->Name());
              $value_e = "#{json_obj_e}#->{$attr_name_e}";
              ($e, $s) = _gh_cg_deserialize_es(
                  $attr, $value_e, $cg, $stash, $json_ctx);
              $code .= $s . $cg->ExpandPattern(
                  "#{new_arg_e}#->{$attr_name_e} = $e;\n");
            }

            return $code;
          },

      # TODO Parametric alternative constructor
      'json.import.instantiate_s' =>
          '#{define_x(return_value_e,"#{class_e}#->new(#{new_arg_e}#)")}#',

      'json.import.return_s' => '#{json.return_s}#',

      # ---- deserialize ------------------------------------------------------

      'json.ct_deserialize_s' => [qw(
          json.deserialize.args_s
          json.deserialize_s
          json.deserialize.return_s )],

      'json.deserialize.args_s' =>
          '#{define_x(class_e,"$_[0]")}#' .
          '#{define_x(class_str,"$_[0]")}#' .
          '#{define_x(json_e,"$_[1]")}#',

      'json.deserialize_s' => [qw(
          json.deserialize.decode_s
          json.deserialize.import_s )],

      'json.deserialize.decode_s' =>
          '#{create_sv_x(json_obj)}#' .
          "my \$#{json_obj_sv}# = JSON::decode_json(#{json_e}#);\n",

      'json.deserialize.import_s' => '#{json.import_s}#',

      'json.deserialize.return_s' => '#{json.return_s}#',

      # ---- export -----------------------------------------------------------

      'json.ct_export_s' => [qw(
          json.export.args_s
          json.export_s
          json.export.return_s )],

      'json.export.args_s' =>
          '#{define_x(self_e,"$_[0]")}#' .
          '#{define_x(self_str,"$_[0]")}#',

      'json.export_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);
            my $method_type = $stash->{'method_type'};

            $cg->CreateScalarVar('json_obj');
            $cg->AddNamedPattern('return_value_e' => '#{json_obj_e}#');
            my $code = $cg->ExpandPattern("my \$#{json_obj_sv}# = {};\n");

            my ($e, $s, $attr_name_e);
            my $attrs = $trait_obj->_GetVar($method_type, 'attrs');
            foreach my $attr (@{$attrs})
            {
              $attr_name_e = $cg->QuoteString($attr->Name());
              ($e, $s) = _gh_cg_serialize_es($attr, $cg, $stash, $json_ctx);
              $code .= $s . $cg->ExpandPattern(
                  "#{json_obj_e}#->{$attr_name_e} = $e;\n");
            }

            return $code;
          },

      'json.export.return_s' => '#{json.return_s}#',

      # ---- serialize --------------------------------------------------------

      'json.ct_serialize_s' => [qw(
          json.serialize.args_s
          json.serialize_s
          json.serialize.return_s )],

      'json.serialize.args_s' =>
          '#{define_x(self_e,"$_[0]")}#' .
          '#{define_x(self_str,"$_[0]")}#',

      'json.serialize_s' => [qw(
          json.serialize.export_s
          json.serialize.encode_s )],

      'json.serialize.export_s' => '#{json.export_s}#',

      'json.serialize.encode_s' =>
          '#{define_x(return_value_e,"JSON::encode_json(#{json_obj_e}#)")}#',

      'json.serialize.return_s' => '#{json.return_s}#',

      # -----------------------------------------------------------------------

      'json.return_s' => '#{return_s}#'
    );

###### METHODS ################################################################

# ==== Trait interface ========================================================

sub new
{
  my ($class, $host, $args) = @_;

  my $self = bless(
      {
        $HK_args => $args,
        $HK_parent => $host,
      }, $class);
  Scalar::Util::weaken($self->{$HK_parent});

  return $self;
}

sub _gh_SetupAttributeTrait
{
  my $self = shift;
  my $host = shift;
  my $trait_name = $self->TraitName();
  die "TODO: $trait_name can not be used as an attribute trait";
}

sub _gh_DoSetupClassTrait
{
  my $self = $_[0];
  my $host = $_[1];

  $host->_gh_AddHook('gh_build_methods', $ModName =>
      # __hook__($hook_runner, $hook_name, $class)
      sub
      {
        $self->__PrepareMethods();
        $self->_gh_Build();
        return undef;
      });
}

# ==== _gh_BuildMethods =======================================================

sub _gh_MetaClass { return $_[0]->{$HK_parent} }
sub _gh_TypeToWhat { return "json.ct_$_[1]_s" }

sub _gh_GetMethodTypes
{
  my $self = $_[0];
  my $method_specs = $self->{$HK_method_specs};
  return $method_specs ? keys(%{$method_specs}) : ();
}

sub _gh_GetMethodNames
{
  my $self = $_[0];
  my $method_type = $_[1];

  my $method_name;
  my $method_specs = $self->{$HK_method_specs};
  $method_name = $method_specs->{$method_type}->{'name'}
    if ($method_specs && $method_specs->{$method_type});

  return ref($method_name) ? @{$method_name} : ($method_name, $method_name);
}

# ==== __PrepareMethods =======================================================

sub __PrepareMethods
{
  state $custom_type_seq = 0;
  my $self = $_[0];

  my $method_specs = $self->{$HK_method_specs} //= {};
  my $arg_method_table = $self->{$HK_args}->{'methods'};

  # TODO: Check arg_method_table type
  my %todo;
  %todo = map { ( $_ => 1 ) } keys(%{$arg_method_table})
    if $arg_method_table;

  # Built in methods
  my $method_arg;
  foreach my $method_type (@MethodTypes)
  {
    my $method_name = $MethodNames{$method_type} or
      next;

    if (exists($arg_method_table->{$method_name}))
    {
      $method_arg = $arg_method_table->{$method_name};

      # undef / false => don't build
      # str / arrayref => rename
      # anything else => custom (keep in todo)
      if (!$method_arg || !ref($method_arg) || (ref($method_arg) eq 'ARRAY'))
      {
        $method_specs->{$method_type} =
            {
              'name' => $method_arg,
              'type' => $method_type
            }
          if $method_arg;
        delete($todo{$method_name});
      }
    }
    else
    {
      # No mention => build default implementation
      $method_specs->{$method_type} =
          {
            'name' => $method_name,
            'type' => $method_type
          };
    }
  }

  # Custom methods
  my $method_type;
  foreach my $method_name (keys(%todo))
  {
    $method_type = 'custom_method_' . $custom_type_seq++;
    $method_arg = $arg_method_table->{$method_name};
    $method_specs->{$method_type} =
        $self->__MethodArg2Spec($method_arg, $method_name, $method_type);
  }

  $self->__CreateVars($self->{'vars'} = {}, $self->{$HK_args}, 1);
}

# ---- __MethodArg2Spec -------------------------------------------------------

sub __MethodArg2Spec
{
  my ($self, $method_arg, $method_name, $method_type) = @_;
  my $method_spec =
      {
        'orig_name' => $method_name,
        'name' => [$method_name, $method_name],
        'type' => $method_type
      };

  die "TODO: $ModName bad custom method '$method_name'"
    unless (ref($method_arg) eq 'HASH');

  my $parser_method;
  foreach my $k (keys(%{$method_arg}))
  {
    $parser_method = "_gh_ParseArgMethod_$k";
    die "TODO $ModName bad keyword '$k' in custom method '$method_name'"
      unless ($parser_method = $self->can($parser_method));
    $self->$parser_method($method_name, $method_spec, $method_arg, $k);
  }
  $self->__CreateCustomTemplate($method_name, $method_spec);

  return $method_spec;
}

# ---- __CreateCustomTemplate -------------------------------------------------

sub __CreateCustomTemplate
{
  my ($self, $method_name, $method_spec) = @_;
  my $method_type = $method_spec->{'type'};

  my $model = $method_spec->{'model'} // 'serialize';

  my %vars =
      (
        'model_str' => $model,
        'reported_name_str' => $method_spec->{'name'}->[0],
        'generated_name_str' => $method_spec->{'name'}->[1],
        'method_name_str' => $method_spec->{'orig_name'},
        'type_str' => $method_type
      );

  my @template;
  given ($model)
  {
    when (\@MethodTypes)
    {
      @template = @{$CodePatterns{$self->_gh_TypeToWhat($model)}};
    }
    default
    {
      die "TODO: Can't generate $model method.\n";
    }
  }

  $method_spec->{'template'} = \@template;
  $method_spec->{'vars'} = \%vars;
  $self->__CreateVars($method_spec->{'vars'}, $method_spec);
}

# ---- _gh_ParseArgMethod_xxx -------------------------------------------------
# $self->$parser_method($method_name, $method_spec, $method_args, $kw);

sub _gh_ParseArgMethod_reported_name
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  $method_spec->{'name'}->[0] = $method_args->{$kw};
}

sub _gh_ParseArgMethod_generated_name
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  $method_spec->{'name'}->[1] = $method_args->{$kw};
}

sub _gh_ParseArgMethod_flag
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  $method_spec->{'flag'} = $method_args->{$kw};
}

# ---- __CreateVars -----------------------------------------------------------

sub __CreateVars
{
  my ($self, $vars, $spec, $defaults) = @_;
  my $host = $self->{$HK_parent};

  my $flag = $spec->{'flag'};
  if ($flag || $defaults)
  {
    $flag ||= 'json';
    $vars->{'flag'} = $flag;
    $vars->{'attrs'} = [ $host->GetAttributesWithFlag($flag) ];
  }
}

# ---- _GetVar ----------------------------------------------------------------

# $v = $trait->_GetVar('method_type', 'var_name')
sub _GetVar
{
  my $self = $_[0];
  my $method_type = $_[1];
  my $var_name = $_[2];

  my $method_spec;
  my $method_specs = $self->{$HK_method_specs};
  $method_spec = $method_specs->{$method_type}
    if $method_specs;

  return ($method_spec && exists($method_spec->{'vars'}->{$var_name})) ?
      $method_spec->{'vars'}->{$var_name} :
      $self->{'vars'}->{$var_name};
}

# ==== Code Generator =========================================================

sub _gh_SetupCodeGenerator
{
  # my ($self, $cg) = @_;
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});
  $cg->AddNamedPattern(\%CodePatterns);

  return $self->SUPER::_gh_SetupCodeGenerator(@_);
}

sub _gh_PrepareStash
{
  my $self = $_[0];
  my $stash = $_[1];

  my %defaults =
      (
        $ModName => $self
      );
  foreach my $k (keys(%defaults))
  {
    $stash->{$k} = $defaults{$k}
      unless exists($stash->{$k});
  }
}

###### THE END ################################################################

1

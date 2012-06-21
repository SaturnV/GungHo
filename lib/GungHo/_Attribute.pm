#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Attribute;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Scalar::Util;

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );
use GungHo::Utils qw( _ProcessParameters );
use GungHo::CodeGenerator;

use parent qw( GungHo::_Hookable
               GungHo::_HasProperties
               GungHo::_HasTraits
               GungHo::_Builder );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# Hash keys
our $HK_name = 'name';
our $HK_spec = 'spec';
our $HK_orig_spec = 'orig_spec';
our $HK_super_attrs = 'super_attrs';
our $HK_type = 'type';
our $HK_method_types = 'method_types';
our $HK_methods_reported = 'methods_reported';
our $HK_methods_generated = 'methods_generated';
our $HK_code_generator = 'code_generator';
our $HK_parent = 'parent';
our $HK_finalized = 'finalized';

our @MethodTypes = qw( rawget get rawset set );

our %DontMergeSuper =
    (
      $GungHo::_HasProperties::HK_properties => 1,
      $GungHo::_HasTraits::HK_traits => 1
    );

# ==== Default Code ===========================================================

our %CodePatterns =
    (
      # ---- Getters ----------------------------------------------------------

      # normal
      'attr.ct_get_s' => [qw(
          attr.get.process_arguments_s
          attr.get_s
          return_s )],
      'attr.get_s' => [qw(
          attr.get.read_s
          attr.get.transform_value_out_s )],

      # internal representation
      'attr.ct_rawget_s' => [qw(
          attr.rawget.process_arguments_s
          attr.rawget_s
          return_s )],
      'attr.rawget_s' => [qw(
          attr.rawget.read_s
          attr.rawget.transform_value_out_s )],

      # input: [attribute, method]
      # output: self_e
      'attr.get.process_arguments_s' => '#{define_x(self_e,"$_[0]")}#',
      'attr.rawget.process_arguments_s' => '#{define_x(self_e,"$_[0]")}#',

      # input: [attribute, method] self_e
      # output: attr_value_e
      'attr.get.read_s' => '#{attr.read_s}#',
      'attr.rawget.read_s' => '#{attr.read_s}#',
      'attr.read_s' => '#{define_x(attr_value_e,' .
          '#{obj.read_attribute_e(#{self_e}#,#{attr.name_e}#)}#)}#',

      # input: [attribute, method] self_e, (TODO?)
      # output: return_value_e
      'attr.get.transform_value_out_s' => '#{attr.transform_value_out_s}#',
      'attr.rawget.transform_value_out_s' => '#{attr.transform_value_out_s}#',
      'attr.transform_value_out_s' =>
          '#{define_x(return_value_e,#{attr_value_e}#)}#',

      # TODO
      'attr.get_e' =>
          '#{obj.read_attribute_e(#{self_e}#,#{attr.name_e}#)}#',
      'attr.rawget_e' =>
          '#{obj.read_attribute_e(#{self_e}#,#{attr.name_e}#)}#',

      # ---- Setters ----------------------------------------------------------

      # normal
      'attr.ct_set_s' => [qw(
          attr.set.process_arguments_s
          attr.set_s
          return_s )],
      'attr.set_s' => [qw(
          attr.set.convert_to_type_s
          attr.set.validate_s
          attr.set.transform_value_in_s
          attr.set.write_s
          attr.set.transform_value_out_s )],
      'attr.set_novalidate_s' => [qw(
          attr.set.convert_to_type_s
          attr.set.transform_value_in_s
          attr.set.write_s
          attr.set.transform_value_out_s )],

      # unchecked internal representation
      'attr.ct_rawset_s' => [qw(
          attr.rawset.process_arguments_s
          attr.rawset_s
          return_s )],
      'attr.rawset_s' => [qw(
          attr.rawset.convert_to_type_s
          attr.rawset.validate_s
          attr.rawset.transform_value_in_s
          attr.rawset.write_s
          attr.rawset.transform_value_out_s )],

      # input: [attribute, method]
      # output: self_e, arg_value_e
      'attr.set.process_arguments_s' =>
          '#{define_x(self_e,"$_[0]")}#' .
          '#{define_x(arg_value_e,"$_[1]")}#',
      'attr.rawset.process_arguments_s' =>
          '#{define_x(self_e,"$_[0]")}#' .
          '#{define_x(arg_value_e,"$_[1]")}#',

      # input: [attribute, method] arg_value_e
      # output: set_value_e
      'attr.set.convert_to_type_s' => '#{attr.convert_to_type_s}#',
      'attr.rawset.convert_to_type_s' => '#{attr.convert_to_type_s}#',
      'attr.convert_to_type_s' =>
          '#{define_cond_x(set_value_e,#{arg_value_e}#)}#',

      # input: [attribute, method] arg_value_e
      'attr.set.validate_s' => '#{attr.validate_s}#',

      # input: [attribute, method] self_e, set_value_a
      # output: new_value_e
      'attr.set.transform_value_in_s' => '#{attr.transform_value_in_s}#',
      'attr.rawset.transform_value_in_s' => '#{attr.transform_value_in_s}#',
      'attr.transform_value_in_s' =>
          '#{define_cond_x(new_value_e,#{set_value_e}#)}#',

      # input: [attribute] self_e, new_value_e
      # output: none
      'attr.set.write_s' => '#{attr.write_s}#',
      'attr.rawset.write_s' => '#{attr.write_s}#',
      'attr.write_weak_e' =>
          '#{obj.write_attribute_e(' .
              '#{self_e}#,#{attr.name_e}#,#{new_value_e}#)}#',
      'attr.write_e' => '#{important_x}##{attr.write_weak_e}#',
      'attr.write_weak_s' =>
          '#{obj.write_attribute_s(' .
              '#{self_e}#,#{attr.name_e}#,#{new_value_e}#)}#',
      'attr.write_s' => '#{important_x}##{attr.write_weak_s}#',

      # ---- Hooks ------------------------------------------------------------

      # hnpacahook
      "attr.ct_${H_hnpa_consume_args}_s" => [qw(
          attr.hnpacahook.process_arguments_s
          attr.hnpacahook.body_s
          return_undef_s )],

      # input: [attribute, hook]
      # output: class_e, stash_e, image_e, args_e, arg_value_e
      # __hook__($hook_runner, $hook_name, $class, $stash)
      'attr.hnpacahook.process_arguments_s' =>
          sub
          {
            # TODO define_x can't do #{a}#->{#{b}#}
            my $cg = $_[2]->{$CGHA_code_generator};
            $cg->AddNamedPattern(
                'class_e' => '$_[2]',
                'stash_e' => '$_[3]',
                'image_e' =>
                    '#{stash_e}#->{$GungHo::Names::S_new_image}',
                'args_e' =>
                    '#{stash_e}#->{$GungHo::Names::S_new_arguments}',
                'arg_value_e' =>
                    '#{args_e}#->{#{attr.name_e}#}');
            return undef;
          },

      # input: [attribute, hook] arg_value_e, image_e
      # output: none
      # TODO: This is ugly as hell
      'attr.hnpacahook.body_s' =>
          sub
          {
            my $cg = $_[2]->{$CGHA_code_generator};
            $cg->MakeImportant();
            return $cg->ExpandPattern(
                "if (exists(#{arg_value_e}#))\n" .
                "{\n" .
                '  #{attr.hnpacahook.set_s}#' .
                "}\n",
                { 'del_arg_value_e' => 'delete(#{arg_value_e}#)' });
          },
      'attr.hnpacahook.set_s' =>
          '  #{obj.write_attribute_s(' .
              '#{image_e}#,#{attr.name_e}#,#{del_arg_value_e}#)}#',

      # Build
      "attr.ct_${H_init_Build}_s" => [qw(
          attr.inithook.process_args_s
          attr.inithook.build_s
          return_undef_s )],

      # input: [attribute, hook]
      # output: self_e, stash_e, arg_value_e
      # __hook__($hook_runner, $hook_name, $self, $stash)
      'attr.inithook.process_args_s' =>
          # sub
          # {
          #   my $cg = $_[2]->{$CGHA_code_generator};
          #   $cg->AddNamedPattern(
          #       'self_e' => '$_[2]',
          #       'stash_e' => '$_[3]',
          #       'arg_value_e' => '#{attr.rawget_e}#');
          #   return undef;
          # },
          '#{define_x(self_e,"$_[2]")}#' .
          '#{define_x(stash_e,"$_[3]")}#' .
          '#{define_x(arg_value_e,#{attr.rawget_e}#)}#',

      # input: [attribute, hook] self_e, stash_e, arg_value_e
      # output: none
      'attr.inithook.build_s' => [qw(
          attr.inithook.build_builder_s
          attr.inithook.build_default_s )],

      'attr.inithook.build_builder_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $code;

            if (exists($stash->{'attribute'}->{$HK_spec}->{'builder'}))
            {
              my ($pattern, $v);
              my $builder =
                  $stash->{'attribute'}->{$HK_spec}->{'builder'};
              if (ref($builder))
              {
                $v = 'attribute_builder';
                $stash->{'enclose'}->{$v} = $builder
                  unless exists($stash->{'enclose'}->{$v});
                $builder = "\$$v";
              }

              $cg->Push();
              $cg->CreateArrayVar('builder_ret');
              $code = $cg->ExpandPattern(
                  "if (!#{attr.exists_e}#)\n" .
                  "{\n" .
                  "  my \@#{builder_ret_av}# =\n" .
                  "      #{self_e}#->$builder(#{stash_e}#);\n" .
                  "  if (\@#{builder_ret_av}#)\n" .
                  "  {\n" .
                  "    #{attr.inithook.set_s}#" .
                  "  }\n" .
                  "}\n",
                  { 'arg_value_e' => "\$#{builder_ret_av}#[0]" });
              $cg->Pop();
              $cg->MakeImportant();
            }

            return $code;
          },

      'attr.inithook.set_s' => '#{attr.set_novalidate_s}#',

      'attr.inithook.build_default_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $code;

            if (exists($stash->{'attribute'}->{$HK_spec}->{'default'}))
            {
              my $default =
                  $stash->{'attribute'}->{$HK_spec}->{'default'};
              if (defined($default))
              {
                if (ref($default))
                {
                  my $v = 'attribute_default_value';
                  $stash->{'enclose'}->{$v} = $default
                    unless exists($stash->{'enclose'}->{$v});
                  $default = "\$$v";
                }
                else
                {
                  $default = $cg->QuoteString($default);
                }
              }
              else
              {
                $default = 'undef';
              }

              $code = $cg->ExpandPattern(
                  "if (!#{attr.exists_e}#)\n" .
                  "{\n" .
                  "  #{attr.set_s}#" .
                  "}\n",
                  { 'arg_value_e' => $default });
            }
            
            return $code;
          },

      # Validate
      "attr.ct_${H_init_Validate}_s" => [qw(
          attr.inithook.process_args_s
          attr.inithook.validate_s
          return_undef_s )],

      'attr.inithook.validate_s' => '#{attr.validate_s}#',

      # ---- TODO -------------------------------------------------------------

      'attr.exists_e' =>
          '#{obj.attribute_exists_e(#{self_e}#,#{attr.name_e}#)}#',
      'attr.delete_e' =>
          '#{obj.delete_attribute_e(#{self_e}#,#{attr.name_e}#)}#',
      'attr.delete_s' =>
          '#{obj.delete_attribute_s(#{self_e}#,#{attr.name_e}#)}#',
    );

###### METHODS ################################################################

# ==== Constructor ============================================================

# ---- new --------------------------------------------------------------------

sub new
{
  my ($class, $meta_class, $attr_name, $attr_spec, $super_attrs) = @_;

  # Self + Name
  my $self = bless(
      {
        $HK_name => $attr_name,
        $HK_orig_spec => $attr_spec,
        $HK_spec => { %{$attr_spec} },
        $HK_parent => $meta_class
      }, $class);
  $self->{$HK_super_attrs} = $super_attrs
    if ($super_attrs && @{$super_attrs});
  Scalar::Util::weaken($self->{$HK_parent});

  $attr_spec = { %{$attr_spec} };

  # Merge super
  $self->_gh_MergeSuper($attr_spec);

  # Pre trait stuff
  $self->_gh_ProcessPropertyParameters($attr_spec);

  # Hook up stuff that can mess with spec
  #   Traits -- traits come first so they can provide type
  $self->_gh_ProcessTraitParameters($attr_spec, $meta_class);
  #   Type
  $self->_gh_ProcessTypeParameters($attr_spec, $meta_class);

  # Check / eat up rest
  # __hook__($hook_runner, $hook_name, $attr, $attr_spec, $meta_class)
  $self->_gh_RunHooksAugmented(
      'gh_attr_process_arguments',
      sub
      {
        shift; shift;
        my $self = shift;
        $self->_gh_ProcessMethodNameParameters(@_);
        $self->_ProcessParameters($_[0], '__ProcessNewParam_');
      },
      $self, $attr_spec, $meta_class);

  # Post arguments hook
  # __hook__($hook_runner, $hook_name, $attr)
  $self->_gh_RunHooks('gh_attr_post_arguments', $self);

  return $self;
}

# ---- __ProcessNewParam_* ----------------------------------------------------

sub __ProcessNewParam_default {}
sub __ProcessNewParam_builder {}

# ==== Properties =============================================================

sub Name { return $_[0]->{$HK_name} }
sub _gh_GetSpec { return $_[0]->{$HK_spec} }

# ==== Inheritance ============================================================

sub _gh_MergeSuper
{
  my $self = $_[0];
  my $super_attrs = $self->{$HK_super_attrs};

  if ($super_attrs)
  {
    my $attr_spec = $self->{$HK_spec};
    foreach my $super_spec (map { $_->_gh_GetSpec() } @{$super_attrs})
    {
      foreach my $k (keys(%{$super_spec}))
      {
        $attr_spec->{$k} = $super_spec->{$k}
          unless (exists($attr_spec->{$k}) || $DontMergeSuper{$k});
      }
    }

    $self->_gh_MergeSuperProperties(@{$super_attrs});
    $self->_gh_MergeSuperTraits(@{$super_attrs});
  }
}

# Attribute A is compatible with attribute B if A implements all of
# B's methods.
sub _gh_IsCompatibleWith
{
  my $self = shift;
  my $ret = 1;

  my $other_methods;
  my $my_methods = $self->_gh_GetMethodHashRef();
  ATTRIBUTE: foreach my $other (@_)
  {
    $other_methods = $other->_gh_GetMethodHashRef();
    foreach my $type (keys(%{$other_methods}))
    {
      if (($my_methods->{$type} // '::invalid-method-name::') ne
              $other_methods->{$type})
      {
        $ret = 0;
        last ATTRIBUTE;
      }
    }
  }

  return $ret;
}

# ==== Code Generator =========================================================

sub _gh_MetaClass { return $_[0]->{$HK_parent} }
sub _gh_TypeToWhat { return "attr.ct_$_[1]_s" }

sub _gh_SetupCodeGenerator
{
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});

  $cg->AddNamedPattern(\%CodePatterns);
  $cg->AddNamedPattern(
      'attr.name_e' => $cg->QuoteString($self->{$HK_name}));

  return $self->SUPER::_gh_SetupCodeGenerator(@_);
}

sub _gh_PrepareStash
{
  my $self = $_[0];
  my $stash = $_[1];

  my %defaults =
      (
        'attribute' => $self,
        'attribute_name' => $self->{$HK_name},
        'attribute_type' => $self->{$HK_type},
      );
  foreach my $k (keys(%defaults))
  {
    $stash->{$k} = $defaults{$k}
      unless exists($stash->{$k});
  }
}

# ==== Type ===================================================================

sub _gh_DefaultType { return 'Any' }

sub _gh_SplitRequestedType
{
  # TODO
  # return $requested_type unless wantarray;
  # return ($requested_type, @args);
  return $_[1];
}

sub _gh_ProcessTypeParameters
{
  my $self = $_[0];
  my $attr_spec = $_[1];
  my $requested_type = delete($attr_spec->{'type'}) ||
      $self->_gh_DefaultType();

  # Parse type argument into type and parameters
  my ($requested_type_name, @requested_type_args) =
      $self->_gh_SplitRequestedType($requested_type);

  # Load and instantiate type
  my $type_class = GungHo::Registry::get_or_load_type($requested_type_name);
  my $type_obj = $self->{$HK_type} = $type_class->can('new') ?
      $type_class->new(@requested_type_args) : $type_class;
  # warn "*** type r: $requested_type_name, c: $type_class, o: $type_obj";

  # Let type hook into code generation
  $type_obj->_gh_SetupAttributeHooks($self, $attr_spec)
    if $type_obj->can('_gh_SetupAttributeHooks');
}

# ==== Methods ================================================================

sub GetMethodName
{
  # my ($self, $method_type) = @_;
  return $_[0]->{$HK_methods_reported}->{$_[1]};
}

sub _gh_GetMethodTypes
{
  return $_[0]->{$HK_method_types} ?
      keys(%{$_[0]->{$HK_method_types}}) :
      @MethodTypes;
}

sub _gh_ProcessMethodNameParameters
{
  my $self = $_[0];
  my $attr_spec = $_[1];

  my $v;
  foreach my $n ($self->_gh_GetMethodTypes())
  {
    if (defined($v = delete($attr_spec->{$n})))
    {
      if (ref($v) eq 'ARRAY')
      {
        $self->{$HK_methods_reported}->{$n} = $v->[0];
        $self->{$HK_methods_generated}->{$n} = $v->[1];
      }
      else
      {
        $self->{$HK_methods_generated}->{$n} =
            $self->{$HK_methods_reported}->{$n} = $v;
      }
    }
  }
}

sub _gh_GetMethodHashRef { return $_[0]->{$HK_methods_reported} }

sub _gh_GetMethodNames
{
  return ($_[0]->{$HK_methods_reported}->{$_[1]},
          $_[0]->{$HK_methods_generated}->{$_[1]});
}

# ==== Construction ===========================================================

sub _gh_GetConstructorHooks { return @H_constructor }

# ==== Build ==================================================================

sub _gh_GetHookNames
{
  return ( $_[0]->_gh_GetConstructorHooks() );
}

###### THE END ################################################################

1

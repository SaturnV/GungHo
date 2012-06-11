#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Attribute;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Scalar::Util;

use GungHo::Names qw( :HOOK_NAMES );
use GungHo::Utils qw( _ProcessParameters );
use GungHo::CodeGenerator;

use parent qw( GungHo::_Hookable GungHo::_HasProperties GungHo::_HasTraits );

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

our @DefaultMethodTypes = qw( rawgetter getter rawsetter setter );

our %DontMergeSuper =
    (
      $GungHo::_HasProperties::HK_properties => 1,
      $GungHo::_HasTraits::HK_traits => 1
    );

# ==== Default Code ===========================================================

our %DefaultCodePatterns =
    (
      # ---- Templates --------------------------------------------------------

      # Methods

      # Getters
      #   normal
      'attribute_getter_s' => [qw(
          process_getter_arguments_s transform_value_out_s return_s )],
      #   internal representation
      'attribute_rawgetter_s' => [qw( attribute_getter_s )],

      # Setters
      #   normal
      'attribute_setter_s' => [qw(
          process_setter_arguments_s
          convert_to_type_s validate_s
          transform_value_in_s store_s
          transform_value_out_s return_s )],
      #   unchecked internal representation
      'attribute_rawsetter_s' => [qw( attribute_setter_s )],

      # Hooks

      "attribute_${H_hnpa_consume_args}_s" => [qw(
          process_hnpacahook_args_s hnpacahook_s return_undef_s )],
      "attribute_${H_init_Build}_s" => [qw(
          process_inithook_args_s build_s return_undef_s )],
      "attribute_${H_init_Validate}_s" => [qw(
          process_inithook_args_s validate_s return_undef_s )],

      # ---- Generators -------------------------------------------------------
      # my ($hook_runner, $hook_name, $cg, $what, $step, $stash) = @_;
      #     $_[0],        $_[1],    $_[2], $_[3], $_[4], $_[5]

      # get/set

      # set_e. delete_e optional
      'get_e' => '#{read_attribute_e}#',
      'exists_e' => '#{exists_attribute_e}#',
      'set_s' => '#{important_x}##{write_attribute_s}#',
      'delete_s' => '#{delete_attribute_s}#',

      # process_argument

      # input: [attribute, method]
      # output: self_e
      'process_getter_arguments_s' => sub
          {
            $_[2]->AddNamedPattern('self_e', '$_[0]');
            return undef;
          },
      # input: [attribute, method]
      # output: self_e, arg_value_a
      'process_setter_arguments_s' => sub
          {
            $_[2]->AddNamedPattern('self_e', '$_[0]');
            $_[2]->AddNamedPattern('arg_value_e', '$_[1]');
            return undef;
          },
      # input: [attribute, hook]
      # output: class_e, stash_e, image_e, args_e, arg_value_e
      'process_hnpacahook_args_s' => sub
          {
            # __hook__($hook_runner, $hook_name, $class, $stash)
            $_[2]->AddNamedPattern('class_e', '$_[2]');
            $_[2]->AddNamedPattern('stash_e', '$_[3]');
            $_[2]->AddNamedPattern('image_e',
                '#{stash_e}#->{$GungHo::Names::S_new_image}');
            $_[2]->AddNamedPattern('args_e',
                '#{stash_e}#->{$GungHo::Names::S_new_arguments}');
            $_[2]->AddNamedPattern('arg_value_e',
                "#{args_e}#->{#{attribute_name_e}#}");
          },
      # input: [attribute, hook]
      # output: self_e, stash_e, arg_value_e
      'process_inithook_args_s' => sub
          {
            # __hook__($hook_runner, $hook_name, $self, $stash)
            $_[2]->AddNamedPattern('self_e', '$_[2]');
            $_[2]->AddNamedPattern('stash_e', '$_[3]');
            $_[2]->AddNamedPattern('arg_value_e', '#{get_e}#');
            return undef;
          },

      # getter / setter

      # input: [attribute] self_e, arg_value_e
      # output: new_value_e
      'transform_value_in_s' => sub
          {
            $_[2]->AddNamedPattern('new_value_e', '#{arg_value_e}#');
            return undef;
          },

      # input: [attribute] self_e, new_value_e
      # output: return_value_e
      'transform_value_out_s' => sub
          {
            $_[2]->AddNamedPattern('return_value_e', '#{get_e}#')
              if $_[2]->IsIn('attribute_getter_s');
            return undef;
          },

      # input: [attribute] self_e, new_value_e
      # output: none
      # Using store could lead to circular recursion
      'store_weak_s' => '#{write_attribute_s}#',
      'store_s' => [qw( important_x store_weak_s )],

      # hnpacahook

      # input: [attribute, hook] arg_value_e, image_e
      # output: none
      'hnpacahook_s' => sub
          {
            $_[2]->MakeImportant();
            return $_[2]->ExpandPattern(
                       "if (exists(#{arg_value_e}#))\n" .
                           "{\n  #{set_s}#}\n",
                       {
                         'self_e' => '#{image_e}#',
                         'new_value_e' => 'delete(#{arg_value_e}#)'
                       });
          },

      # Build

      # input: [attribute, hook] self_e, stash_e, arg_value_e
      # output: none
      'build_s' => [qw( build_builder_s build_default_s )],

      'build_builder_s' => sub
          {
            my $cg = $_[2];
            my $stash = $_[5];
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

              $v = $cg->GetMyVariable('');
              $pattern =
                  "if (!#{exists_e}#)\n" .
                  "{\n" .
                  "  my \@$v = #{self_e}#->$builder(#{stash_e}#);\n" .
                  "  if (\@$v)\n" .
                  "  {\n" .
                  "    #{set_s}#" .
                  "  }\n" .
                  "}\n";
              $code = $cg->ExpandPattern(
                  $pattern, { 'new_value_e' => "\$${v}[0]" });
            }

            return $code;
          },

      'build_default_s' => sub
          {
            my $cg = $_[2];
            my $stash = $_[5];
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
                  "if (!#{exists_e}#)\n{\n  #{set_s}#}\n",
                  { 'new_value_e' => $default });
            }
            
            return $code;
          }
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

sub _gh_HookUpCodeGenerator
{
  my $self = $_[0];
  my $cg = $_[1];
  my $cg_owner = $_[2];

  my $attr_name = $self->{$HK_name};

  my $patterns = { %DefaultCodePatterns };
  $patterns->{'attribute_name_e'} = $cg->QuoteString($attr_name);
  $cg->AddNamedPattern($patterns);

  $self->{$HK_parent}->_gh_HookUpCodeGenerator($cg, $cg_owner)
    if ($self eq $cg_owner);

  $cg->_gh_AddHook('new_stash', $self =>
      # __hook__($hook_runner, $hook_name, $cg, $stash)
      sub
      {
        $self->__PrepareStash($_[3], $_[2]);
        return undef;
      });

  # __hook__($hook_runner, $hook_name, $cg)
  $self->_gh_RunHooks($H_cg_prepare_code_generator, $self, $cg);

  # TODO This is ugly here
  $cg->AddNamedPattern('set_e', '#{important_x}##{write_attribute_e}#')
      if (!$cg->GetNamedPattern('set_e') &&
          $cg->GetNamedPattern('write_attribute_e'));
  $cg->AddNamedPattern('delete_e', '#{delete_attribute_e}#')
      if (!$cg->GetNamedPattern('delete_e') &&
          $cg->GetNamedPattern('delete_attribute_e'));
}

sub __PrepareStash
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

sub _DefaultCodeTemplate
{
  my $t = $DefaultCodePatterns{$_[1]};
  return (ref($t) eq 'ARRAY') ? $t : [ $_[1] ];
}

# ---- _gh_Assemble -----------------------------------------------------------

sub _gh_Assemble
{
  # my ($self, $what, $stash) = @_;
  my $self = shift;
  my $what = shift; $what = "attribute_${what}_s";
  my $template = $self->_DefaultCodeTemplate($what, @_) or
    die "TODO::No code template for '$what'";
  return $self->{$HK_code_generator}->Assemble($what, $template, @_);
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

sub _gh_GetMethodTypes
{
  return $_[0]->{$HK_method_types} ?
      keys(%{$_[0]->{$HK_method_types}}) :
      @DefaultMethodTypes;
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

sub GetMethodName
{
  # my ($self, $method_type) = @_;
  return $_[0]->{$HK_methods_reported}->{$_[1]};
}

sub _gh_GetMethodNames
{
  return ($_[0]->{$HK_methods_reported}->{$_[1]},
          $_[0]->{$HK_methods_generated}->{$_[1]});
}

sub _gh_GetGeneratedMethodName
{
  # my ($self, $method_type) = @_;
  return $_[0]->{$HK_methods_generated}->{$_[1]};
}

sub _gh_BuildMethod
{
  my ($self, $method_type, $method_name) = @_;
  my $stash = $self->{$HK_code_generator}->NewStash(
      {
        'cg_owner' => $self,
        'method_name' => $method_name,
        'method_type' => $method_type,
        'code_type' => 'method'
      });
  return $self->_gh_Assemble($method_type, $stash) ||
      sub {};
}

# ==== Construction ===========================================================

# $self->_gh_BuildConstructorHooks()
sub _gh_BuildConstructorHooks
{
  my $self = $_[0];
  my $attr_name = $self->{$HK_name};
  my $meta_class = $self->{$HK_parent};

  my ($hook_code, $stash);
  foreach my $hook_name (
      $H_new_prepare_environment, $H_new_create_image,
          $H_new_process_arguments,
      $H_instantiate,
      $H_hnpa_consume_args, $H_hnpa_expand_macros,
      $H_init_Build, $H_init_Validate, $H_init_InitParts, $H_init_InitWhole )
  {
    $stash = $self->{$HK_code_generator}->NewStash(
      { 
        'cg_owner' => $self,
        'hook_name' => $hook_name,
        'hook_type' => $hook_name,
        'code_type' => 'hook'
      });
    $hook_code = $self->_gh_Assemble($hook_name, $stash);
    $meta_class->_gh_AddHook($hook_name,
        "${ModName}[$attr_name]" => $hook_code)
      if $hook_code;
    # warn "*** Adding hook $hook_name" if $hook_code;
  }
}

# ==== Build ==================================================================

# $self->_gh_Build($meta_class)
sub _gh_Build
{
  my $self = $_[0];
  my $meta_class = $self->{$HK_parent};

  # Code Generator
  {
    my $cg = $self->{$HK_code_generator} = GungHo::CodeGenerator->new();
    $self->_gh_HookUpCodeGenerator($cg, $self);
  }

  # Methods
  my ($method_name_gen, $method_name_rep, $method_ref);
  foreach my $method_type ($self->_gh_GetMethodTypes())
  {
    ($method_name_rep, $method_name_gen) =
        $self->_gh_GetMethodNames($method_type);

    $method_ref = ($method_name_gen &&
                   $meta_class->_gh_ShouldProvideMethod($method_name_gen)) ?
        $self->_gh_BuildMethod($method_type, $method_name_gen) :
        undef;
    $meta_class->_gh_AddMethodImplementation(
        $method_name_gen, $method_ref, $self, $method_type)
      if $method_ref;
    # $meta_class->_gh_AddMetaMethod('TODO')
  }

  # Constructor
  $self->_gh_BuildConstructorHooks();

  # Cleanup
  delete($self->{$HK_code_generator})->Destroy();
  $self->{$HK_finalized} = 1;
}

###### THE END ################################################################

1

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

our @MethodTypes = qw( rawgetter getter rawsetter setter );

our %DontMergeSuper =
    (
      $GungHo::_HasProperties::HK_properties => 1,
      $GungHo::_HasTraits::HK_traits => 1
    );

# ==== Default Code ===========================================================

our %CodePatterns =
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

              $cg->CreateArrayVar('builder_ret');
              $pattern =
                  "if (!#{exists_e}#)\n" .
                  "{\n" .
                  "  my \@#{builder_ret_av}# =\n" .
                  "      #{self_e}#->$builder(#{stash_e}#);\n" .
                  "  if (\@#{builder_ret_av}#)\n" .
                  "  {\n" .
                  "    #{set_s}#" .
                  "  }\n" .
                  "}\n";
              $code = $cg->ExpandPattern($pattern,
                  { 'new_value_e' => "\$#{builder_ret_av}#[0]" });
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

sub _gh_MetaClass { return $_[0]->{$HK_parent} }
sub _gh_TypeToWhat { return "attribute_$_[1]_s" }

sub _gh_SetupCodeGenerator
{
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});

  $cg->AddNamedPattern(\%CodePatterns);
  $cg->AddNamedPattern(
      'attribute_name_e' => $cg->QuoteString($self->{$HK_name}));

  $self->SUPER::_gh_SetupCodeGenerator(@_);

  # TODO This is ugly here
  $cg->AddNamedPattern('set_e', '#{important_x}##{write_attribute_e}#')
      if (!$cg->GetNamedPattern('set_e') &&
          $cg->GetNamedPattern('write_attribute_e'));
  $cg->AddNamedPattern('delete_e', '#{delete_attribute_e}#')
      if (!$cg->GetNamedPattern('delete_e') &&
          $cg->GetNamedPattern('delete_attribute_e'));
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

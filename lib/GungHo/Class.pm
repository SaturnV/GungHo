#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Class;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Tie::IxHash;

use GungHo::Names qw( :HOOK_NAMES );
use GungHo::Utils qw( _ProcessParameters );
use GungHo::Registry;
use GungHo::_Attribute;
use GungHo::_Base;

###### INIT ###################################################################

use parent qw( GungHo::_Hookable GungHo::_HasProperties GungHo::_HasTraits );

###### DOCS ###################################################################

# $self =
#     {
#       $HK_name => 'Class::Name',
#       $HK_orig_spec => { spec passed to new (ro) },
#       $HK_spec => { spec merged with superclasses and stuff },
#       $HK_isa => [ 'Super::Classes', .. ],
#       $HK_attributes =>
#           Tie::IxHash->new( 'attr_name' => $attr_obj ),
#       $HK_finalized => 1 # if built
#     }

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# Precompiled regexps
our $RE_NamePart = qr/[a-z_][0-9_a-z]*/i;

our $RE_ClassName = qr/$RE_NamePart(?:::$RE_NamePart)*/;
our $RE_AnchoredClassName = qr/^$RE_ClassName\z/;

our $RE_MethodName = $RE_NamePart;
our $RE_AnchoredMethodName = qr/^$RE_MethodName\z/;

# Hash keys
our $HK_name = 'name';
our $HK_spec = 'spec';
our $HK_orig_spec = 'orig_spec';
our $HK_isa = 'isa';
our $HK_attributes = 'attributes';
our $HK_finalized = 'finalized';

our %DontMergeSuper =
    (
      $GungHo::_HasProperties::HK_properties => 1,
      $GungHo::_HasTraits::HK_traits => 1,
      $HK_attributes => 1
    );

###### SUBS ###################################################################

###### METHODS ################################################################

# Naming conventions:
#   method_name : class method
#   MethodName  : object method
#   _xxx        : protected method
#                 May be called on self in subclasses.
#   __xxx       : private method
#                 Should not be called from outside of this package.
#   _gh_xxx     : protected method, part of gungho api
#                 GungHo extension may call it anywhere.
#                 Code just using GungHo should not call these.

# ==== Constructor ============================================================

# ---- build ------------------------------------------------------------------

sub build
{
  my $class = shift;
  $class = $class->new(@_);
  $class->Build();
  return $class;
}

# ---- new --------------------------------------------------------------------

sub new
{
  my $class = shift;
  my $class_spec = GungHo::Utils::make_hashref(@_);

  # Self
  my $self = bless(
      {
        $HK_orig_spec => $class_spec,
        $HK_spec => { %{$class_spec} },
      }, $class);
  $class_spec = { %{$class_spec} };

  # Name
  {
    my $name = delete($class_spec->{'name'}) // caller() // '<none>';
    die "TODO::ParameterError::BadValue[$name]"
      unless ($name =~ $RE_AnchoredClassName);
    $self->{$HK_name} = $name;
  }

  # Merge super
  $self->_gh_MergeSuper($class_spec);

  # Pre trait stuff
  $self->_gh_ProcessPropertyParameters($class_spec);

  # Hook up stuff that can mess with spec
  $self->_gh_ProcessTraitParameters($class_spec);

  # Check / eat up rest
  # TODO This is should be hookified
  $self->_ProcessParameters($class_spec, '__ProcessNewParam_');

  return $self;
}

# ---- _gh_MergeSuper ---------------------------------------------------------

sub _gh_MergeSuper
{
  my $self = $_[0];
  # my $class_spec = $_[1];

  if (my $isa = delete($_[1]->{'isa'}))
  {
    $isa = GungHo::Utils::make_arrayref($isa);
    die "TODO::ParameterError::BadValue[isa]"
      if (grep { $_ !~ $RE_AnchoredClassName } @{$isa});
    $self->{$HK_spec}->{'isa'} = $isa;

    my $class_spec = $self->{$HK_spec};
    my @super_metas = map { GungHo::Registry::get_meta_class($_) } @{$isa};
    foreach my $super_spec (map { $_->_gh_GetSpec() } @super_metas)
    {
      foreach my $k (keys(%{$super_spec}))
      {
        $class_spec->{$k} = $super_spec->{$k}
          unless (exists($class_spec->{$k}) || $DontMergeSuper{$k});
      }
    }

    $self->_gh_MergeSuperProperties(@super_metas);
    $self->_gh_MergeSuperTraits(@super_metas);
  }
}

# ---- __ProcessNewParam_ -----------------------------------------------------

sub __ProcessNewParam_attributes
{
  my $self = $_[0];
  my $n = $_[1];
  my $v = $_[2];

  delete($self->{$HK_spec}->{$n});
  $self->AddAttribute((ref($v) eq 'ARRAY') ? @{$v} : %{$v})
    if defined($v);
}

# ==== Properties =============================================================

sub Name { return $_[0]->{$HK_name} }
sub _gh_GetSpec { return $_[0]->{$HK_spec} }

# ==== CodeGenerator ==========================================================

sub _gh_HookUpCodeGenerator
{
  # my ($self, $cg, $cg_owner) = @_;
  my $self = $_[0];
  my $cg = $_[1];

  $cg->AddNamedPattern(
      'read_attribute_e'  => '#{self_e}#->{#{attribute_name_e}#}',
      'write_attribute_e' =>
          '#{self_e}#->{#{attribute_name_e}#} = #{new_value_e}#',
      'write_attribute_s' => "#{write_attribute_e}#;\n",
      'delete_attribute_e' => 'delete(#{read_attribute_e}#)',
      'delete_attribute_s' => "#{delete_attribute_e}#;\n",
      'exists_attribute_e' => 'exists(#{read_attribute_e}#)');
  $cg->_gh_AddHook('new_stash', $self =>
      # __hook__($hook_runner, $hook_name, $cg, $stash)
      sub
      {
        $self->__PrepareStash($_[3], $_[2]);
        return undef;
      });
}

sub __PrepareStash
{
  my $self = $_[0];
  my $stash = $_[1];

  my %defaults =
      (
        'meta_class' => $self,
        'class_name' => $self->{$HK_name},
      );
  foreach my $k (keys(%defaults))
  {
    $stash->{$k} = $defaults{$k}
      unless exists($stash->{$k});
  }
}

# ==== SuperClasses ===========================================================

# ---- Reflection -------------------------------------------------------------

sub GetSuperClasses
{
  return @{$_[0]->{$HK_isa}} if $_[0]->{$HK_isa};
  die 'TODO::Unbuilt';
}

sub GetSuperMetaClasses
{
  my @ret;
  my $m;
  foreach my $super_class ($_[0]->GetSuperClasses())
  {
    push(@ret, $m)
      if ($super_class->can('get_meta_class') &&
          ($m = $super_class->get_meta_class()));
  }
  return @ret;
}

# ---- _gh_GetExplicitSuperClasses --------------------------------------------

# Return superclasses supplied by user
sub _gh_GetExplicitSuperClasses
{
  my $isa_requested = $_[0]->{$HK_spec}->{'isa'};
  return $isa_requested ? @{$isa_requested} : ();
}

# ---- _gh_GetImplicitSuperClasses --------------------------------------------

# Return superclasses we want to add behind the scenes
sub _gh_GetImplicitSuperClasses { return ('GungHo::_Base') }

# ---- _gh_BuildISA -----------------------------------------------------------

sub _gh_BuildISA
{
  my $self = $_[0];
  die 'TODO::InternalError' if $self->{$HK_finalized};
  die 'TODO::InternalError' if $self->{$HK_isa};
  my $class_name = $self->Name();

  my $isa_ref;
  {
    no strict 'refs';
    $isa_ref = \@{"${class_name}::ISA"};
  }

  foreach my $c ($self->_gh_GetExplicitSuperClasses(),
                 $self->_gh_GetImplicitSuperClasses())
  {
    push(@{$isa_ref}, $c) unless $class_name->isa($c);
  }

  $self->{$HK_isa} = $isa_ref;
}

# ---- _gh_BuildSuperMeta -----------------------------------------------------

sub _gh_BuildSuperMeta
{
  my $self = $_[0];
  die 'TODO::InternalError' if $self->{$HK_finalized};
  $self->_gh_MergeSuperProperties($self->GetSuperMetaClasses());
}

# ---- _gh_BuildSuperHooks ----------------------------------------------------

sub _gh_BuildSuperHooks
{
  my $self = $_[0];
  die 'TODO::InternalError' if $self->{$HK_finalized};
  $self->_gh_MergeHooksBeforeWeak($self->GetSuperMetaClasses());
}

# ---- _gh_BuildSuperClasses --------------------------------------------------

sub _gh_BuildSuperClasses
{
  my $self = $_[0];
  die 'TODO::InternalError' if $self->{$HK_finalized};

  $self->_gh_BuildISA();
  $self->_gh_BuildSuperMeta();
  $self->_gh_BuildSuperHooks();
}

# ==== Attributes =============================================================

sub _gh_GetAttributeClass { return 'GungHo::_Attribute' }

# ---- Reflection -------------------------------------------------------------

sub GetAttributes
{
  return $_[0]->{$HK_attributes} ? $_[0]->{$HK_attributes}->Values() : ()
}

sub GetAttributeNames
{
  return $_[0]->{$HK_attributes} ? $_[0]->{$HK_attributes}->Keys() : ()
}

sub GetAttributeByName
{
  return $_[0]->{$HK_attributes} ?
      $_[0]->{$HK_attributes}->FETCH($_[1]) :
      undef;
}

sub GetAttributesWithFlag
{
  return grep { $_->HasFlag($_[1]) } $_[0]->GetAttributes();
}

# ---- AddAttribute -----------------------------------------------------------

sub AddAttribute
{
  my $self = shift;
  die 'TODO::InternalError' if $self->{$HK_finalized};
  die 'TODO::InternalError' if $self->{$HK_attributes};

  return unless @_;

  if (!$#_)
  {
    return $self->AddAttribute(@{$_[0]}) if (ref($_[0]) eq 'ARRAY');
    return $self->_gh_AddAttribute($_[0])
      if (Scalar::Util::Blessed($_[0]) && $_[0]->isa('Tie::IxHash'));
  }

  # $c->AddAttribute($attr1_spec, ...)
  return $self->_gh_AddAttribute(
      Tie::IxHash->new(map { $_->{'name'} => $_ } @_))
    unless (grep { (ref($_) ne 'HASH') || !defined($_->{'name'}) } @_);

  die 'TODO::BadArgs' unless ($#_ & 1);

  my $name;
  my $single = 0; # $c->AddAttribute('name' => 'alma', 'type' => 'x', ...)
  my $multiple = 1; # $c->AddAttribute('attr1' => {}, ...)
  for (my $i = 0 ; $i <= $#_ ; $i += 2)
  {
    die 'TODO::BadArgs' if (!defined($_[$i]) || ref($_[$i]));
    if (($_[$i] eq 'name') && defined($_[$i+1]) && !ref($_[$i+1]))
    {
      $name = $_[$i+1];
      $single = 1;
    }
    $multiple = 0 unless (ref($_[$i+1]) eq 'HASH');
  }
  die 'TODO::BadArgs' unless ($single || $multiple);

  return $self->_gh_AddAttribute(Tie::IxHash->new( $name => { @_ } ))
    if $single;
  return $self->_gh_AddAttribute(Tie::IxHash->new(@_));
}

sub _gh_AddAttribute
{
  my $self = $_[0];
  my $attrs = $_[1];

  my $attributes_requested =
      $self->{$HK_spec}->{'attributes'} //= Tie::IxHash->new();

  my $attr_spec;
  foreach my $attr_name ($attrs->Keys())
  {
    warn "TODO: Redefine $attr_name"
      if $attributes_requested->EXISTS($attr_name);

    # $attr_spec_out =
    #     __hook__($hook_runner, $hook_name, $class, $attr_name, $attr_spec_in)
    $attr_spec = $self->_gh_RunHooksAugmented(
        'gh_class_add_attribute',
        sub { return $_[4] },
        $self, $attr_name, $attrs->FETCH($attr_name));
    $attributes_requested->Push( $attr_name => $attr_spec )
      if $attr_spec;
  }
}

# ---- _gh_BuildAttributes ----------------------------------------------------

sub _gh_BuildAttributes
{
  my $self = $_[0];
  die 'TODO::InternalError' if $self->{$HK_finalized};
  die 'TODO::InternalError' if $self->{$HK_attributes};
  my $attr;

  # Consolidate superclass attributes
  my %super_attrs;
  my $attributes = $self->{$HK_attributes} = Tie::IxHash->new();
  foreach my $super_meta ($self->GetSuperMetaClasses())
  {
    foreach my $attr_name ($super_meta->GetAttributeNames())
    {
      $attr = $super_meta->GetAttributeByName($attr_name);

      if ($super_attrs{$attr_name})
      {
        push(@{$super_attrs{$attr_name}}, $attr);
      }
      else
      {
        $attributes->Push($attr_name => $attr);
        $super_attrs{$attr_name} = [ $attr ];
      }
    }
  }

  # Process new attributes
  if (my $attributes_requested = $self->{$HK_spec}->{'attributes'})
  {
    my $attr_spec;
    my $attr_class = $self->_gh_GetAttributeClass();
    foreach my $attr_name ($attributes_requested->Keys())
    {
      $attr_spec = $attributes_requested->FETCH($attr_name);
      $attr = $attr_class->new($self, $attr_name, $attr_spec,
          delete($super_attrs{$attr_name}));

      $attr->_gh_Build($self);

      # Push replaces key if it is already present without
      # reordering elements.
      $attributes->Push( $attr_name => $attr );
    }
  }

  # Check incompatible multiple inheritance
  if (%super_attrs)
  {
    foreach my $attr_name (keys(%super_attrs))
    {
      $attr = $attributes->FETCH($attr_name);
      warn 'TODO[' . $self->Name() . ']: ' .
          "Multiply inherited attribute $attr_name"
        unless $attr->_gh_IsCompatibleWith(@{$super_attrs{$attr_name}});
    }
  }
}

# ==== Methods ================================================================

## TODO

sub _gh_SyntaxCheckMethodName
{
  # my ($self, $method_name, $attr, $method_type) = @_;
  die 'TODO::ParameterError::BadValue'
    unless (defined($_[1]) && ($_[1] =~ $RE_AnchoredMethodName));
  return 1;
}

sub _gh_ShouldProvideMethod
{
  my ($self, $method_name) = @_;
  my $class_name = $self->Name();
  return !GungHo::Utils::get_symbol("${class_name}::$method_name", 'CODE');
}

sub _gh_AddMethodImplementation
{
  my ($self, $method_name, $method_ref, $attr, $method_type) = @_;
  my $class_name = $self->Name();

  $self->_gh_SyntaxCheckMethodName($method_name);
  GungHo::Utils::set_symbol("${class_name}::$method_name", $method_ref)
    if $method_ref;
}

sub _gh_BuildMethods
{
  my $self = $_[0];
  $self->_gh_RunHooks('gh_build_methods', $self);
}

# ==== Build ==================================================================

sub Build
{
  my $self = shift;
  die 'TODO::ParameterError' if @_;

  $self->_gh_BuildSuperClasses();
  $self->_gh_BuildAttributes();
  $self->_gh_BuildMethods();
  #$self->_BuildMixins();

  $self->{$HK_finalized} = 1;

  GungHo::Registry::register_meta_class($self);
}

###### THE END ################################################################

1

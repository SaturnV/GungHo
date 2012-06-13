#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::CodeGenerator;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES );
use GungHo::Utils;

use parent 'GungHo::_Hookable';

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $HK_depth = 'depth';
our $HK_state = 'state';
our $HK_important = 'important';
our $HK_next_my_variable_seq = 'next_my_variable_seq';

our $HKS_what = 'what';
our $HKS_step = 'step';
our $HKS_args = 'args';
our $HKS_used = 'used';
our $HKS_hooks = 'hooks';
our $HKS_patterns = 'patterns';

our %DefaultPatterns =
    (
      # input: return_value_e, return_value_opt_e
      'return_s' => sub
          {
            my $ret;
            if (defined($_[2]->GetNamedPattern('return_value_e')))
            {
              $ret = $_[2]->ExpandPattern("return #{return_value_e}#;\n");
              $_[2]->MakeImportant();
            }
            elsif (defined($_[2]->GetNamedPattern('return_value_opt_e')))
            {
              $ret = $_[2]->ExpandPattern("return #{return_value_opt_e}#;\n");
            }
            return $ret;
          },
      'return_undef_s' => "return undef;\n",

      'important_x' => sub
          {
            $_[2]->MakeImportant();
            return undef;
          }
    );

###### SUBS ###################################################################

###### METHODS ################################################################

# ==== Constructor ============================================================

sub new
{
  my $class = shift;

  my $self = GungHo::Utils::make_hashref(@_);
  $self->{$HK_state} = [ { $HKS_patterns => {} } ];
  $self->{$HK_next_my_variable_seq} = 0;
  $self->{$HK_depth} = 0;
  bless($self, $class);

  $self->AddNamedPattern(\%DefaultPatterns);

  return $self;
}

sub new_prepared
{
  my $class = shift;
  my $owner = shift;
  my $self = $class->new(@_);
  $self->Use($owner);
  return $self;
}

# ==== Destructor =============================================================

sub Destroy { %{$_[0]} = () }

# ==== Misc ===================================================================

sub MakeImportant { $_[0]->{$HK_important} = 1 }

sub IsIn
{
  return grep { defined($_) && ($_ eq $_[1]) }
             map { $_->{$HKS_what} } @{$_[0]->{$HK_state}};
}

sub IsInLike
{
  return grep { defined($_) && /$_[1]/ }
             map { $_->{$HKS_what} } @{$_[0]->{$HK_state}};
}

sub WhatChain
{
  return join($_[1] // '>',
      reverse(
          grep { defined($_) }
              map { $_->{$HKS_what} } @{$_[0]->{$HK_state}}));
}

# ==== Push/Pop ===============================================================

sub Push
{
  my $self = shift;
  my $what = shift || $self->{$HK_state}->[0]->{$HKS_what};
  my $args = shift || $self->{$HK_state}->[0]->{$HKS_args};
  my $patterns = shift || {};

  my $state =
      {
        $HKS_patterns => $patterns,
        $HKS_hooks => $self->_gh_CloneHooks(),
        $HKS_what => $what,
        $HKS_args => $args,
      };
  unshift(@{$self->{$HK_state}}, $state);
  return $state;
}

sub Pop
{
  $_[0]->_gh_ReplaceHooks(shift(@{$_[0]->{$HK_state}})->{$HKS_hooks});
}

# ==== Use ====================================================================

sub IsUsed
{
  # my $self = $_[0];
  # my $obj = $_[1];
  my $ret;

  foreach my $s (@{$_[0]->{$HK_state}})
  {
    if ($s->{$HKS_used} && $s->{$HKS_used}->{$_[1]})
    {
      $ret = 1;
      last;
    }
  }

  return $ret;
}

sub Use
{
  my $self = shift;

  foreach my $obj (@_)
  {
    next if $self->IsUsed($obj);

    $obj->_gh_SetupCodeGenerator($self);
    $self->{$HK_state}->[0]->{$HKS_used}->{$obj} = 1; # autoviv FTW
  }
}

# ==== Generate ===============================================================

sub Generate
{
  my $self = shift;
  my $what = shift;
  my $template = shift;
  my $code;

  my $top_level = !($self->{$HK_depth}++);

  $self->{$HK_important} = undef if $top_level;
  $code = $self->_Generate($what, $template, undef, @_);
  undef($code) if ($top_level && !$self->{$HK_important});

  --$self->{$HK_depth};

  return $code;
}

sub _Generate
{
  my $self = shift;
  my $what = shift;
  my $template = shift;
  my $patterns = shift;
  my $code = '';

  my $state = $self->Push($what, \@_, $patterns);

  # __hook__($hook_runner, $hook_name, $cg, $what, $template, @args)
  $self->_gh_RunHooks($H_cg_tweak_params, $self, $what, $template, @_);
  $self->_gh_RunHooks($H_cg_tweak_template, $self, $what, $template, @_);

  my $tmp;
  my @template = @{$template};
  my $what_chain = $self->WhatChain();
  foreach my $step (@template)
  {
    $state->{$HKS_step} = $step;
    $code .= "## $what_chain.$step\n";

    # __hook__($hook_runner, $hook_name, $cg, $what, $step, @args)
    $tmp = $self->_gh_RunHooksAugmented(
        'gh_cg_do_step',
         sub
         {
           shift; shift;
           return $_[0]->_gh_RunHooksAugmented(
               "gh_cgs_$_[2]",
               sub { return $_[2]->ExpandNamedPattern($_[4]) },
               @_);
         },
         $self, $what, $step, @_);
    $code .= $tmp if defined($tmp);
  }

  $self->Pop();

  return $code;
}

# ==== Assemble ===============================================================

# $self->Assemble($what, $template, $stash, ...)
sub Assemble
{
  my $self = shift;
  my $code;

  if (defined($code = $self->Generate(@_)) &&
      (ref($code) ne 'CODE'))
  {
    if ($code eq '')
    {
      undef($code);
    }
    else
    {
      $code = "sub { $code }";

      my $stash = $_[2];
      if ((ref($stash) eq 'HASH') &&
          (ref($stash->{'enclose'}) eq 'HASH'))
      {
        my $enclose = '';
        foreach my $name (keys(%{$stash->{'enclose'}}))
        {
          $enclose .= "my \$$name = \$stash->{'enclose'}->{'$name'};\n"
        }
        $code = $enclose . $code;
      }

      # warn "## GENERATED CODE [$_[0]] BEGIN\n"
      #    . "$code\n"
      #    . "## GENERATED CODE [$_[0]] END";

      $code = eval $code or
        die "TODO::InternalError >>$@<<";
    }
  }

  # warn "Assemble $_[0] -> >" . ref($code) . "<";
  return $code;
}

# ==== Patterns ===============================================================

# ---- GetNamedPattern --------------------------------------------------------

sub GetNamedPattern
{
  # my $self = $_[0];
  # my $pname = $_[1];
  # my $params = $_[2];

  return $_[2]->{$_[1]} if ($_[2] && exists($_[2]->{$_[1]}));

  foreach (@{$_[0]->{$HK_state}})
  {
    return $_->{$HKS_patterns}->{$_[1]}
      if exists($_->{$HKS_patterns}->{$_[1]});
  }

  return undef;
}

# ---- CheckNamedPattern ------------------------------------------------------

sub CheckNamedPattern
{
  my ($self, $pattern_name, $pattern_body) = @_;
  die "TODO::BadPatternName[$pattern_name]"
    unless (defined($pattern_name) && ($pattern_name =~ /^\w+\z/));
  die "TODO::BadPattern[$pattern_name]"
      unless defined($pattern_body);
}

# ---- AddNamedPattern --------------------------------------------------------

sub AddNamedPattern
{
  my $self = shift;
  my $patterns = GungHo::Utils::make_hashref(@_);
  my $ps = $self->{$HK_state}->[0]->{$HKS_patterns};

  my $pattern_body;
  foreach my $pattern_name (keys(%{$patterns}))
  {
    $pattern_body = $patterns->{$pattern_name};
    $self->CheckNamedPattern($pattern_name, $pattern_body);
    $ps->{$pattern_name} = $pattern_body;
  }
}

# ---- AddWeakNamedPattern ----------------------------------------------------

sub AddWeakNamedPattern
{
  my $self = shift;
  my $patterns = GungHo::Utils::make_hashref(@_);
  my $ps = $self->{$HK_state}->[0]->{$HKS_patterns};

  my $pattern_body;
  foreach my $pattern_name (keys(%{$patterns}))
  {
    $pattern_body = $patterns->{$pattern_name};
    $self->CheckNamedPattern($pattern_name, $pattern_body);
    $ps->{$pattern_name} = $pattern_body
      unless $self->GetNamedPattern($pattern_name);
  }
}

# ---- Expand(Named)Pattern ---------------------------------------------------

# $cg->ExpandPattern(
#     'pattern', { 'param_name' => 'param_value' }, 'pattern_name')
sub ExpandPattern
{
  my $self = $_[0];
  my $pattern = $_[1] // '';
  my $params = $_[2];
  my $pattern_name = $_[3];

  if (ref($pattern) eq 'CODE')
  {
    my $s = $params ?
        $self->Push($pattern_name, undef, $params) :
        $self->{$HK_state}->[0];
    $pattern = $pattern->(undef, undef,
        $self, $s->{$HKS_what}, $s->{$HKS_step}, @{$s->{$HKS_args}});
    $self->Pop() if $params;
  }
  elsif (ref($pattern) eq 'ARRAY')
  {
    my $s = $self->{$HK_state}->[0];
    $pattern = $self->_Generate(
        $s->{$HKS_step}, $pattern, $params, @{$s->{$HKS_args}});
  }
  else
  {
    $pattern =~ s/#\{(\w+)\}#/$self->ExpandNamedPattern($1, $params)/eg;
  }

  return $pattern;
}

# $cg->ExpandNamedPattern('pattern_name', { 'param_name' => 'param_value' })
sub ExpandNamedPattern
{
  # my ($self, $pattern_name, $params) = @_;
  return $_[0]->ExpandPattern(
      $_[0]->GetNamedPattern($_[1], $_[2]), $_[2], $_[1]) // '';
}

# ---- Patch ------------------------------------------------------------------

sub __index
{
  my $aref = $_[0];
  my $pattern = $_[1];
  my $not_found = $_[2];

  foreach my $i ( 0 .. $#{$aref} )
  {
    return $i if ($aref->[$i] ~~ $pattern);
  }

  return $not_found;
}

sub Patch
{
  state $tmp_seq = 0;
  my $self = shift;
  my $insert = shift;
  my %where = @_;

  foreach my $arg (keys(%where))
  {
    die "TODO::BadArg[$arg]"
      unless ($arg ~~ [ qw( into before after ) ])
  }

  die "TODO::MissingRequired[into]"
    unless defined($where{'into'});
  die "TODO::Can't have before and after"
    if (defined($where{'before'}) && defined($where{'after'}));

  my $orig_pattern = $self->GetNamedPattern($where{'into'});
  if (defined($orig_pattern))
  {
    if (ref($orig_pattern) eq 'ARRAY')
    {
      my $idx = exists($where{'before'}) ?
          __index($orig_pattern, $where{'before'}, 0) :
          __index($orig_pattern, $where{'after'}, $#{$orig_pattern}) + 1;
      splice(@{$orig_pattern}, $idx, 0, $insert);
    }
    else
    {
      my $tmp = "tmp${tmp_seq}_$insert";
      $tmp_seq++;
      $self->AddNamedPattern($tmp, $orig_pattern);
      $self->AddNamedPattern($where{'into'},
            exists($where{'before'}) ? [ $insert, $tmp ] : [ $tmp, $insert ]);
    }
  }
  else
  {
    # Original pattern does not exist
    $self->AddNamedPattern($where{'into'}, [ $insert ]);
  }
}

# ==== Misc ===================================================================

sub GetMyVariable
{
  # my $self = $_[0];
  # my $sigil = $_[1] || '$';
  return (defined($_[1]) ? ($_[1] ne '' ? "$_[1]" : '') : "\$") .
      'v' . $_[0]->{$HK_next_my_variable_seq}++;
}

sub QuoteString
{
  return '"' . quotemeta($_[1]) . '"';
}

# ==== Stash ==================================================================

sub NewStash
{
  my $self = shift;
  my $stash = GungHo::Utils::make_hashref(@_);
  # __hook__($hook_runner, $hook_name, $cg, $stash)
  return $self->_gh_RunHooksWithDefault('new_stash', $stash, $self, $stash);
}

###### THE END ################################################################

1

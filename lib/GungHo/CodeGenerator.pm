#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::CodeGenerator;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::Names qw( :HOOK_NAMES :CG_HOOK_ARGS );
use GungHo::Utils;

use Data::Dumper;

use parent 'GungHo::_Hookable';

###### VARS ###################################################################

our $ModName = __PACKAGE__;

our $HK_depth = 'depth';
our $HK_state = 'state';
our $HK_important = 'important';
our $HK_unique_map = 'unique_map';

our $HKS_what = 'what';
our $HKS_step = 'step';
our $HKS_args = 'args';
our $HKS_used = 'used';
our $HKS_hooks = 'hooks';
our $HKS_patterns = 'patterns';

our $SubPatternClass = "${ModName}::SubPattern";

our %DefaultPatterns =
    (
      # __hook__($hook_runner, $hook_name, $hook_args)

      'create_sv_x' =>
          sub
          {
            my $cg = $_[2]->{$CGHA_code_generator};

            if (my $pn = $cg->ExpandNamedPattern('##'))
            {
              my @vars = grep { $_ }
                  map { $cg->ExpandNamedPattern("#$_") } (1 .. $pn);
              $cg->CreateScalarVar(@vars) if @vars;
            }

            return undef;
          },
      'create_av_x' =>
          sub
          {
            my $cg = $_[2]->{$CGHA_code_generator};

            if (my $pn = $cg->ExpandNamedPattern('##'))
            {
              my @vars = grep { $_ }
                  map { $cg->ExpandNamedPattern("#$_") } (1 .. $pn);
              $cg->CreateArrayVar(@vars) if @vars;
            }

            return undef;
          },

      'define_x' =>
          sub
          {
            my $cg = $_[2]->{$CGHA_code_generator};
            my ($p1, $p2);
            $cg->AddNamedPattern($p1, $p2)
              if (($p1 = $cg->ExpandNamedPattern('#1')) &&
                  ($p2 = $cg->ExpandNamedPattern('#2')));
            return undef;
          },

      'define_cond_x' =>
          sub
          {
            my $cg = $_[2]->{$CGHA_code_generator};
            my ($p1, $p2);
            $cg->AddWeakNamedPattern($p1, $p2)
              if (($p1 = $cg->ExpandNamedPattern('#1')) &&
                  ($p2 = $cg->ExpandNamedPattern('#2')));
            return undef;
          },

      # input: return_value_e, return_value_opt_e
      'return_s' =>
          sub
          {
            my $ret;
            my $cg = $_[2]->{$CGHA_code_generator};
            if (defined($cg->GetNamedPattern('return_value_e')))
            {
              $ret = $cg->ExpandPattern("return #{return_value_e}#;\n");
              $cg->MakeImportant();
            }
            elsif (defined($cg->GetNamedPattern('return_value_opt_e')))
            {
              $ret = $cg->ExpandPattern("return #{return_value_opt_e}#;\n");
            }
            return $ret;
          },
      'return_undef_s' => "return undef;\n",

      'important_x' =>
          sub
          {
            $_[2]->{$CGHA_code_generator}->MakeImportant();
            return undef;
          }
    );

# -----------------------------------------------------------------------------

my $re_name = qr/#?\w+(?:\.\w+)*/;

###### SUBS ###################################################################

sub _parse_expr
{
  my @expr;

  if (@expr = /\G($re_name)/cg)
  {
    if (/\G\(\s*/cg)
    {
      do { push(@expr, _parse_expr()) } while (/\G\s*,\s*/cg);
      die 'TODO::BadPattern1' unless /\G\s*\)/cg;
    }
  }
  elsif (/\G#\{\s*/cg)
  {
    push(@expr, [_parse_expr()]);
    die 'TODO::BadPattern2' unless /\G\s*\}#/cg;
  }
  elsif (/\G'([^']*?)'/cg || /\G"([^"]*?)"/cg)
  {
    push(@expr, $1);
  }

  return @expr ? @expr : '';
}

sub _parse_pattern
{
  my @p;

  while (/\G(.*?)#\{\s*/cgs)
  {
    push(@p, $1) if length($1);
    push(@p, [_parse_expr()]);
    die 'TODO::BadPattern3' unless /\G\s*\}#/cg;
  }

  my $p = pos($_) // 0;
  push(@p, substr($_, $p))
    if ($p < length($_));

  return @p;
}

sub parse_pattern
{
  local $_ = $_[0] // '';
  return _parse_pattern();
}

###### METHODS ################################################################

# ==== Constructor ============================================================

sub new
{
  my $class = shift;

  my $self = GungHo::Utils::make_hashref(@_);
  $self->{$HK_state} = [ { $HKS_patterns => {} } ];
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

# ==== Push/Pop ===============================================================

sub _Push
{
  my $self = shift;
  my $what = shift;
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

sub Push
{
  my $s = shift->_Push(@_);
  $s->{$HKS_patterns}->{'#explicite_push'} = 1;
  return $s;
}

sub Pop
{
  $_[0]->_gh_ReplaceHooks(shift(@{$_[0]->{$HK_state}})->{$HKS_hooks});
}

sub IsIn
{
  return grep { $_ && ($_ ~~ $_[1]) }
             map { $_->{$HKS_what} } @{$_[0]->{$HK_state}};
}

sub What
{
  foreach (@{$_[0]->{$HK_state}})
  {
    return $_->{$HKS_what} if $_->{$HKS_what};
  }
  return undef;
}

sub WhatChain
{
  return join($_[1] // '>',
      reverse(
          grep { $_ }
              map { $_->{$HKS_what} } @{$_[0]->{$HK_state}}));
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

  $self->Push();
  $self->{$HK_important} = undef if $top_level;
  $code = $self->_Generate($what, $template, undef, @_);
  undef($code) if ($top_level && !$self->{$HK_important});
  $self->Pop();

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

  my $state = $self->_Push($what, \@_, $patterns);

  $template = [ $template ] unless ref($template);
  die 'TODO:BadTemplate'
    unless (ref($template) eq 'ARRAY');

  my $tmp;
  my $hook_args;
  my @template = @{$template};
  my $what_chain = $self->WhatChain() || 'code';
  foreach my $step (@template)
  {
    $state->{$HKS_step} = $step;
    # $code .= "## $what_chain.$step\n";

    # __hook__($hook_runner, $hook_name, $hook_args)
    $hook_args =
        {
          $CGHA_code_generator => $self,
          $CGHA_generate_args => [ @_ ],
          $CGHA_what_chain => $what_chain,
          $CGHA_what => $what,
          $CGHA_step => $step
        };
    $tmp = $self->_gh_RunHooksAugmented(
         $H_cg_do_step,
         sub
         {
           return $_[2]->{$CGHA_code_generator}->ExpandNamedPattern(
               $_[2]->{$CGHA_step});
         },
         $hook_args);
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

      if ($ENV{'GUNGHO_DEBUG'})
      {
        warn "## GENERATED CODE [$_[0]] BEGIN\n"
           . "$code\n"
           . "## GENERATED CODE [$_[0]] END";
      }

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

  my $arg_pattern = $_[1] =~ /^#/;
  foreach (@{$_[0]->{$HK_state}})
  {
    return $_->{$HKS_patterns}->{$_[1]}
      if exists($_->{$HKS_patterns}->{$_[1]});
    last if ($arg_pattern && exists($_->{$HKS_patterns}->{'##'}));
  }

  return undef;
}

# ---- CheckNamedPattern ------------------------------------------------------

sub CheckNamedPattern
{
  my ($self, $pattern_name, $pattern_body) = @_;
  die "TODO::BadPatternName[$pattern_name]"
    unless (defined($pattern_name) && ($pattern_name =~ $re_name));
  die "TODO::BadPattern[$pattern_name]"
      unless defined($pattern_body);
}

# ---- AddNamedPattern --------------------------------------------------------

sub AddNamedPattern
{
  my $self = shift;
  my $patterns = GungHo::Utils::make_hashref(@_);

  my $ps = $self->{$HK_state}->[0]->{$HKS_patterns};
  foreach my $s (@{$self->{$HK_state}})
  {
    if ($s->{$HKS_patterns}->{'#explicite_push'})
    {
      $ps = $s->{$HKS_patterns};
      last;
    }
  }

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

  # Pop off implicite pushes
  my $ps;
  my @popped;
  while (@{$self->{$HK_state}})
  {
    if ($self->{$HK_state}->[0]->{$HKS_patterns}->{'#explicite_push'})
    {
      $ps = $self->{$HK_state}->[0]->{$HKS_patterns};
      last;
    }
    else
    {
      push(@popped, shift(@{$self->{$HK_state}}));
    }
  }
  if (!$ps)
  {
    push(@{$self->{$HK_state}}, @popped);
    $ps = $popped[0]->{$HKS_patterns};
    @popped = ();
  }

  # Add patterns
  my $pattern_body;
  foreach my $pattern_name (keys(%{$patterns}))
  {
    $pattern_body = $patterns->{$pattern_name};
    $self->CheckNamedPattern($pattern_name, $pattern_body);
    $ps->{$pattern_name} = $pattern_body
      unless $self->GetNamedPattern($pattern_name);
  }

  # Re-push popped stuff
  unshift(@{$self->{$HK_state}}, @popped)
    if @popped;
}

# ---- ExpandPatternElement ---------------------------------------------------

sub __p
{
  my $i = 0;
  return map { ('#' . ++$i => $_ ) } @_;
#      map { ref($_) ? bless($_, $SubPatternClass) : $_ } @_;
}

sub __q
{
  my $ctx = shift;
  my $i = 0;
  return map { ('#' . ++$i => $_ ) }
      map { ref($_) ? bless({ 'ctx' => $ctx, 'expr' => $_ }, $SubPatternClass) : $_ } @_;
}

sub _GetArgContext
{
  foreach (@{$_[0]->{$HK_state}})
  {
    return $_->{$HKS_patterns} if $_->{$HKS_patterns}->{'##'};
  }
  return $_[0]->{$HK_state}->[0]->{$HKS_patterns};
}

sub ExpandPatternElement
{
  my $self = shift;
  my $p0 = shift;

  $p0 = $self->ExpandPatternElement(@{$p0}) if ref($p0);

  return $self->ExpandNamedPattern($p0,
      @_ ?
          {
            '##' => scalar(@_),
            '#0' => $p0,
            __q($self->_GetArgContext(), @_)
          } :
          undef);
}

# ---- Expand(Named)Pattern ---------------------------------------------------

# $cg->ExpandPattern(
#     'pattern', { 'param_name' => 'param_value' }, 'pattern_name')
sub ExpandPattern
{
  my ($self, $pattern, $params, $pattern_name) = @_;
  my $ret;

  undef($params) unless ($params && %{$params});

  if (!ref($pattern))
  {
    $ret = '';
    $self->_Push($pattern_name, undef, $params)
      if $params;
    $ret .= ref($_) ? $self->ExpandPatternElement(@{$_}) : $_
      foreach (parse_pattern($pattern));
    $self->Pop() if $params;
  }
  elsif (ref($pattern) eq $SubPatternClass)
  {
    $self->_Push(undef, undef, $pattern->{'ctx'});
    $ret = $self->ExpandPatternElement(@{$pattern->{'expr'}});
    $self->Pop();
  }
  elsif (ref($pattern) eq 'ARRAY')
  {
    my $s = $self->{$HK_state}->[0];
    $ret = $self->_Generate(
        $pattern_name // $s->{$HKS_step},
        $pattern,
        $params,
        @{$s->{$HKS_args}});
  }
  elsif (ref($pattern) eq 'CODE')
  {
    my $s = $params ?
        $self->_Push(undef, undef, $params) :
        $self->{$HK_state}->[0];
    my $hook_args =
        {
            $CGHA_code_generator => $self,
            $CGHA_generate_args => $s->{$HKS_args},
            $CGHA_what_chain => $self->WhatChain(),
            $CGHA_what => $self->What(),
            $CGHA_step => $s->{$HKS_step}
        };
    $ret = $pattern->(undef, undef, $hook_args);
    $self->Pop() if $params;
  }
  elsif (defined($pattern))
  {
    my $ref = ref($pattern);
    die "TODO::BadPatternRef[$ref]";
  }

  return $ret // '';
}

# $cg->ExpandNamedPattern('pattern_name', { 'param_name' => 'param_value' })
sub ExpandNamedPattern
{
  # my ($self, $pattern_name, $params) = @_;
  return $_[0]->ExpandPattern(
      $_[0]->GetNamedPattern($_[1], $_[2]), $_[2], $_[1]);
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

sub MakeImportant { $_[0]->{$HK_important} = 1 }
sub QuoteString { return '"' . quotemeta($_[1]) . '"' }

sub GetUniqueName
{
  state $next_unique_seq = 0;
  my $self = $_[0];
  my $id = $_[1];
  my $postfix = $_[2] // '';
  my $ret;

  $ret = $self->{$HK_unique_map}->{$id}
    if defined($id);
  if (!$ret)
  {
    $ret = 'u' . $next_unique_seq++ . $postfix;
    $self->{$HK_unique_map}->{$id} = $ret
      if defined($id);
  }

  return $ret;
}

sub GetMyVariable
{
  # my $self = $_[0];
  # my $sigil = $_[1] // '';
  state $next_my_variable_seq = 0;
  return (defined($_[1]) ? "$_[1]" : '') . 'v' . $next_my_variable_seq++;
}

sub CreateScalarVar
{
  my $self = shift;
  my @v = map { $self->GetMyVariable() } @_;
  $self->AddNamedPattern(
      map { ("$_[$_]_sv" => $v[$_], "$_[$_]_e" => "\$$v[$_]") } (0 .. $#_));
  return @v if wantarray;
  return $v[0];
}

sub CreateArrayVar
{
  my $self = shift;
  my @v = map { $self->GetMyVariable() } @_;
  $self->AddNamedPattern( map { ("$_[$_]_av" => $v[$_]) } (0 .. $#_) );
  return @v if wantarray;
  return $v[0];
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

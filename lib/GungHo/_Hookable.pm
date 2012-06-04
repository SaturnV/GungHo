#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::_Hookable;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Tie::IxHash;

use GungHo::_HookRunner;

###### DOCS ###################################################################

# $self =
#     {
#       $HK_hooks =>
#           {
#             'chain_name' => Tie::IxHash->new(
#                 'sub_name' => sub { ... }, ... )
#           }
#     }

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# Hash keys
our $HK_hooks = 'hooks';

###### SUBS ###################################################################

sub __clone_hook_chain
{
  return Tie::IxHash->new(map { $_ => $_[0]->FETCH($_) } $_[0]->Keys());
}

###### METHODS ################################################################

# ==== Adders =================================================================

# ---- _gh_AddHook ------------------------------------------------------------

sub _gh_AddHook
{
  # my ($self, $chain_name, $sub_name1, $sub_ref1, ...) = @_;
  my $self = shift;
  my $chain_name = shift;
  die 'TODO::ParameterError'
    if ((scalar(@_) < 2) || (scalar(@_) & 1));

  if (my $subs = $self->{$HK_hooks}->{$chain_name})
  {
    $subs->Unshift(@_);
  }
  else
  {
    $self->{$HK_hooks}->{$chain_name} = Tie::IxHash->new(@_);
  }
}

# ==== Getters ================================================================

sub _gh_GetHookChains
{
  return $_[0]->{$HK_hooks} ? keys(%{$_[0]->{$HK_hooks}}) : ();
}

sub _gh_GetHook
{
  my $self = shift;
  my $chain = shift;
  my @ret = defined($chain) ?
      ( ($chain = $self->{$HK_hooks}->{$chain}) ?
          ( @_ ? map { $chain->FETCH($_) } @_ :
                 $chain->Keys() ) :
          ()) :
      keys(%{$self->{$HK_hooks}});
  return $ret[0] unless wantarray;
  return @ret;
}

# ==== Removers ===============================================================

# ---- _gh_RemoveHook ---------------------------------------------------------

sub _gh_RemoveHook
{
  # my ($self, $hook_name, $sub_name1, ...) = @_;
  my $self = shift;
  my $chain = shift;
  if (@_)
  {
    $chain->Delete(@_)
      if ($chain = $self->{$HK_hooks}->{$chain});
  }
  else
  {
    delete($self->{$HK_hooks}->{$chain});
  }
}

# ---- _gh_RemoveAllHooks -----------------------------------------------------

sub _gh_RemoveAllHooks
{
  my $self = $_[0];
  my $chain_name = $_[1];

  if (defined($chain_name))
  {
    delete($self->{$HK_hooks}->{$chain_name});
  }
  else
  {
    delete($self->{$HK_hooks});
  }
}

# ==== Runners ================================================================

# ---- _gh_RunHooks -----------------------------------------------------------

sub _gh_RunHooks
{
  # my ($self, $chain_name, @params) = @_;
  my $self = shift;
  my $chain_name = shift;

  my $chain = $self->{$HK_hooks}->{$chain_name};
  GungHo::_HookRunner::run_hooks(
      [$chain->Values()], $chain_name, @_)
    if $chain;
}

# ---- _gh_RunHooksReversed ---------------------------------------------------

sub _gh_RunHooksReversed
{
  # my ($self, $chain_name, @params) = @_;
  my $self = shift;
  my $chain_name = shift;

  my $chain = $self->{$HK_hooks}->{$chain_name};
  GungHo::_HookRunner::run_hooks(
      [reverse($chain->Values())], $chain_name, @_)
    if $chain;
}

# ---- _gh_RunHooksWithDefault ------------------------------------------------

sub _gh_RunHooksWithDefault
{
  # my ($self, $chain_name, $default, @params) = @_;
  my $self = shift;
  my $chain_name = shift;
  my $default = shift;

  my @subs;
  @subs = $self->{$HK_hooks}->{$chain_name}->Values()
    if $self->{$HK_hooks}->{$chain_name};
  push(@subs, sub { return $default });

  return GungHo::_HookRunner::run_hooks(\@subs, $chain_name, @_);
}

# ---- _gh_RunHooksAugmented ---------------------------------------------------

sub _gh_RunHooksAugmented
{
  # my ($self, $chain_name, $tail, @params) = @_;
  my $self = shift;
  my $chain_name = shift;
  my $tail = shift;

  my @subs;
  @subs = $self->{$HK_hooks}->{$chain_name}->Values()
    if $self->{$HK_hooks}->{$chain_name};

  if ((ref($tail) eq 'CODE') || !ref($tail))
  {
    push(@subs, $tail);
  }
  elsif (ref($tail) eq 'ARRAY')
  {
    push(@subs, @{$tail});
  }
  else
  {
    die 'TODO::ParameterError';
  }

  return GungHo::_HookRunner::run_hooks(\@subs, $chain_name, @_);
}

# ==== State manipulation =====================================================

sub _gh_CloneHooks
{
  my $chain = $_[0]->{$HK_hooks};
  return $chain ?
      { map { $_ => __clone_hook_chain($chain->{$_}) } keys(%{$chain}) } :
      undef;
}

sub _gh_ReplaceHooks
{
  my $clone = $_[1];
  $_[0]->{$HK_hooks} =
      { map { $_ => __clone_hook_chain($clone->{$_}) } keys(%{$clone}) };
}

sub _gh_ReplaceHooksDirect { $_[0]->{$HK_hooks} = $_[1] }

# ==== Merging ================================================================

sub __MergeHooks
{
  my $self = shift;
  my $adder_method = shift;
  my $override = shift;

  my $my_chains = $self->{$HK_hooks} //= {};

  my @sub_names;
  my ($my_chain, $other_chains, $other_chain);
  foreach my $other (@_)
  {
    next unless $other->isa($ModName);

    $other_chains = $other->{$HK_hooks};
    foreach my $chain_name (keys(%{$other_chains}))
    {
      $other_chain = $other_chains->{$chain_name};

      if ($my_chain = $my_chains->{$chain_name})
      {
        @sub_names = $override ? $other_chain->Keys() :
            grep { !$my_chain->EXISTS($_) } $other_chain->Keys();
        $my_chain->$adder_method(
            map { $_ => $other_chain->FETCH($_) } @sub_names)
          if @sub_names;
      }
      else
      {
        $my_chains->{$chain_name} = Tie::IxHash->new(
            map { $_ => $other_chain->FETCH($_) } $other_chain->Keys());
      }
    }
  }
}

sub _gh_MergeHooksBeforeWeak { return shift->__MergeHooks('Unshift', 0, @_) }
sub _gh_MergeHooksBeforeOverride { return shift->__MergeHooks('Unshift', 1, @_) }
sub _gh_MergeHooksAfterWeak { return shift->__MergeHooks('Push', 0, @_) }
sub _gh_MergeHooksAfterOverride { return shift->__MergeHooks('Push', 1, @_) }

###### THE END ################################################################

1

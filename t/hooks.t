#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::_Hookable') }

###### HookTest ###############################################################

{
  package HookTest;
  use parent 'GungHo::_Hookable';
  sub new { return bless({}, $_[0]) }
}

###### VARS ###################################################################

my $class = 'HookTest';

###### SUBS ###################################################################

sub dump_hooks($)
{
  my $obj = $_[0];
  return join(',', sort
      map { "${_}[" . join(',', $obj->_gh_GetHook($_)) . ']' }
          $obj->_gh_GetHookChains());
}

###### CODE ###################################################################

# API methods
can_ok($class, qw(
    _gh_GetHook _gh_GetHookChains
    _gh_AddHook _gh_RemoveHook _gh_RemoveAllHooks
    _gh_RunHooks _gh_RunHooksReversed
    _gh_RunHooksWithDefault _gh_RunHooksAugmented
    _gh_CloneHooks _gh_ReplaceHooks _gh_ReplaceHooksDirect
    _gh_MergeHooksBeforeWeak _gh_MergeHooksBeforeOverride
    _gh_MergeHooksAfterWeak _gh_MergeHooksAfterOverride ));

# ==== Add / Get / Remove / Run / Ordering ====================================

{
  my $str;

  my $obj1 = $class->new();
  isa_ok($obj1, $class);
  isa_ok($obj1, 'GungHo::_Hookable');

  my $obj2 = $class->new();

  # Add some hooks
  foreach my $chain (qw( a b c d e ))
  {
    my @chain = ();
    foreach my $sub (1 .. 5)
    {
      my $id = $chain . $sub;
      push(@chain, $id => sub { $str .= $id; return undef });
    }
    $obj1->_gh_AddHook($chain, @chain);
  }

  # Read back
  # The chains are not ordered only the subs in the individual chains
  my @expected = qw( a b c d e );
  my @got = sort $obj1->_gh_GetHook();
  is_deeply(\@got, \@expected, 'get_chains_all+');
  @got = sort $obj1->_gh_GetHookChains();
  is_deeply(\@got, \@expected, 'get_hook_chains_all+');

  @expected = ();
  @got = $obj2->_gh_GetHook();
  is_deeply(\@got, \@expected, 'get_chains_all-');
  @got = $obj2->_gh_GetHookChains();
  is_deeply(\@got, \@expected, 'get_hook_chains_all-');

  foreach my $chain (qw( a c q ))
  {
    @expected = ($chain le 'e' ) ? map { $chain . $_ } (1 .. 5) : ();
    @got = $obj1->_gh_GetHook($chain);
    is_deeply(\@got, \@expected, "get_subs_all_$chain+");

    @expected = ();
    @got = $obj2->_gh_GetHook($chain);
    is_deeply(\@got, \@expected, "get_subs_all_$chain-");
  }

  @got = $obj1->_gh_GetHook('b', 'b3', 'c4');
  is(scalar(@got), 2, 'get_subs_selected');
  like($got[0], qr/CODE/, 'get_subs_selected+');
  is($got[1], undef, 'get_subs_selected-');

  my $x = $obj1->_gh_GetHook('e', "e2") // '';
  like("$x", qr/CODE/, 'get_sub_selected+');
  $x = $obj1->_gh_GetHook('e', "e7");
  is($x, undef, 'get_sub_selected-');

  # Remove chain
  $obj1->_gh_RemoveHook('d');
  $obj2->_gh_RemoveHook('d');

  @expected = qw( a b c e );
  @got = sort $obj1->_gh_GetHook();
  is_deeply(\@got, \@expected, 'get_chains_removed+');
  @got = sort $obj1->_gh_GetHookChains();
  is_deeply(\@got, \@expected, 'get_hook_chains_removed+');

  @expected = ();
  @got = sort $obj2->_gh_GetHook();
  is_deeply(\@got, \@expected, 'get_chains_removed-');
  @got = sort $obj2->_gh_GetHookChains();
  is_deeply(\@got, \@expected, 'get_hook_chains_removed-');

  # Remove sub
  $obj1->_gh_RemoveHook('e', 'e1', 'e3', 'e5');
  $obj2->_gh_RemoveHook('e', 'e1', 'e3', 'e5');

  @expected = qw( e2 e4 );
  @got = sort $obj1->_gh_GetHook('e');
  is_deeply(\@got, \@expected, 'get_subs_removed+');

  @expected = ();
  @got = sort $obj2->_gh_GetHook('e');
  is_deeply(\@got, \@expected, 'get_subs_removed-');

  # Run
  $obj1->_gh_RunHooks('a');
  is($str, 'a1a2a3a4a5', 'run_all');

  $str = '';
  $obj1->_gh_RunHooksReversed('c');
  is($str, 'c5c4c3c2c1', 'run_reverse');

  # Remove all
  $str = '';
  $obj1->_gh_RemoveAllHooks();
  $obj1->_gh_RunHooks('b');
  is($str, '', 'run_none');
}

# ==== Parameters =============================================================

{
  my $str = '';

  my $obj = $class->new();
  $obj->_gh_AddHook('chain',
      'sub' => sub
               {
                 isa_ok($_[0], 'GungHo::_HookRunner', 'params0');
                 is($_[1], 'chain', 'params1');
                 is($_[2], 'alma', 'params2');
                 is(scalar(@_), 3, 'params_num');
                 $str .= 'a';
               });
  $obj->_gh_RunHooks('chain', 'alma');
  is($str, 'a', 'params_run');
}

# ==== Stop / Continue ========================================================

# Stop on defined
{
  my $str = '';
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { $str .= 'a'; return undef },
      'sub2' => sub { $str .= 'b' },
      'sub3' => sub { $str .= 'c' });
  $obj->_gh_RunHooks('chain');
  is($str, 'ab', 'stop_defined');
}

# Stop the chain
{
  my $str = '';
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { $str .= 'a'; return undef },
      'sub2' => sub { $str .= 'b'; $_[0]->Last(); return undef },
      'sub3' => sub { $str .= 'c' });
  my $ret = $obj->_gh_RunHooks('chain');
  is($str, 'ab', 'last_run');
  is($ret, undef, 'last_ret');
}

# Continue
{
  my $str = '';
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { $str .= 'a'; return undef },
      'sub2' => sub { $_[0]->Continue() ; $str .= 'b'; return undef },
      'sub3' => sub { $str .= 'c' });
  my $ret = $obj->_gh_RunHooks('chain');
  is($str, 'acb', 'continue_run');
  is($ret, undef, 'continue_ret');
}

# ==== Default / Augmented ====================================================

# Default
{
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { return undef },
      'sub2' => sub { return undef });
  my $ret = $obj->_gh_RunHooksWithDefault('chain', 'q');
  is($ret, 'q', 'default');
}

# Augmented
{
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { return undef },
      'sub2' => sub { return undef });
  my $ret = $obj->_gh_RunHooksAugmented('chain',
      sub { return 'a' });
  is($ret, 'a', 'augmented');
}

# ==== Replace ================================================================

{
  my $str = '';
  my $obj = $class->new();

  $obj->_gh_AddHook('chain',
      'sub1' => sub { $str .= 'a'; return undef },
      'sub2' => sub { $str .= 'b'; return undef },
      'sub3' => sub { $str .= 'c' });
  $obj->_gh_AddHook('chain', 'sub2' => sub { $str .= 'B'; return undef });
  $obj->_gh_RunHooks('chain');
  is($str, 'aBc', 'replace');
}

# ==== Clone ==================================================================

{
  my $obj1 = $class->new();
  my $obj2 = $class->new();

  $obj1->_gh_AddHook('chain_a',
      'sub1a' => sub { return undef },
      'sub2a' => sub { return undef });
  $obj1->_gh_AddHook('chain_b',
      'sub1b' => sub { return undef },
      'sub2b' => sub { return undef });

  my $expected = 'chain_a[sub1a,sub2a],chain_b[sub1b,sub2b]';
  my $cloned = $obj1->_gh_CloneHooks();

  $obj2->_gh_ReplaceHooks($cloned);
  $obj1->_gh_RemoveHook('chain_a', 'sub1a');
  $obj1->_gh_RemoveHook('chain_b');
  is(dump_hooks($obj2), $expected, 'clone to other');

  $obj2->_gh_RemoveAllHooks();
  $obj1->_gh_ReplaceHooks($cloned);
  is(dump_hooks($obj1), $expected, 'clone to self');

  $obj1->_gh_RemoveHook('chain_b');
  $obj1->_gh_ReplaceHooks($cloned);
  is(dump_hooks($obj1), $expected, 'clone to self mod');

  $obj1->_gh_RemoveHook('chain_b');
  $obj1->_gh_ReplaceHooksDirect($cloned);
  is(dump_hooks($obj1), $expected, 'clone to self direct');
}

# ==== Merge ==================================================================

{
  my $obj1 = $class->new();
  my $obj2 = $class->new();

  $obj1->_gh_AddHook('chain_a',
      'sub1a' => sub { return '1.1a' },
      'sub2a' => sub { return '1.2a' });
  $obj1->_gh_AddHook('chain_b',
      'sub1b' => sub { return '1.1b' },
      'sub2b' => sub { return '1.2b' });

  $obj2->_gh_AddHook('chain_a',
      'sub1a' => sub { return '2.1a' },
      'sub3a' => sub { return '2.3a' });
  $obj2->_gh_AddHook('chain_b',
      'sub2b' => sub { return '2.2b' },
      'sub3b' => sub { return '2.3b' });

  my $orig = $obj1->_gh_CloneHooks();

  $obj1->_gh_MergeHooksBeforeWeak($obj2);
  is(dump_hooks($obj1),
      'chain_a[sub3a,sub1a,sub2a],chain_b[sub3b,sub1b,sub2b]',
      'MergeHooksBeforeWeak');
  is($obj1->_gh_GetHook('chain_a', 'sub1a')->(),
      '1.1a',
      'MergeHooksBeforeWeak sub');

  $obj1->_gh_ReplaceHooks($orig);
  $obj1->_gh_MergeHooksBeforeOverride($obj2);
  is(dump_hooks($obj1),
      'chain_a[sub3a,sub1a,sub2a],chain_b[sub3b,sub1b,sub2b]',
      'MergeHooksBeforeOverride');
  is($obj1->_gh_GetHook('chain_a', 'sub1a')->(),
      '2.1a',
      'MergeHooksBeforeOverride sub');

  $obj1->_gh_ReplaceHooks($orig);
  $obj1->_gh_MergeHooksAfterWeak($obj2);
  is(dump_hooks($obj1),
      'chain_a[sub1a,sub2a,sub3a],chain_b[sub1b,sub2b,sub3b]',
      'MergeHooksAfterWeak');
  is($obj1->_gh_GetHook('chain_a', 'sub1a')->(),
      '1.1a',
      'MergeHooksAfterWeak sub');

  $obj1->_gh_ReplaceHooks($orig);
  $obj1->_gh_MergeHooksAfterOverride($obj2);
  is(dump_hooks($obj1),
      'chain_a[sub1a,sub2a,sub3a],chain_b[sub1b,sub2b,sub3b]',
      'MergeHooksAfterOverride');
  is($obj1->_gh_GetHook('chain_a', 'sub1a')->(),
      '2.1a',
      'MergeHooksAfterOverride sub');
}

# ==== Done ===================================================================

done_testing();

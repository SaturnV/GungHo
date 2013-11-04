#! /usr/bin/perl
###### NAMESPACE ##############################################################

package GungHo::Verify;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw( import );

###### EXPORTS ################################################################

our @EXPORT = qw( v_ignore v_ign v_optional v_opt v_defined v_def
                  v_string v_str v_boolean v_bool
                  v_number v_num v_integer v_int
                  v_array v_hash
                  verify verify_die );

# ==== Error handling =========================================================

my $but = 'but got #{got}# at #{path}#';

sub make_printable
{
  my $obj = $_[0];

  if (ref($obj))
  {
    $obj = ref($obj);
  }
  elsif (defined($obj))
  {
    $obj = quotemeta($obj);
    if ($obj !~ /^\d{1,15}\z/)
    {
      substr($obj, 6, -6, '...')
        if (length($obj) > 15);
      $obj = "'$obj'";
    }
  }
  else
  {
    $obj = 'undef';
  }

  return $obj;
}

# $human_readable_path = make_printable_path($path_arrayref);
sub make_printable_path
{
  my @path;
  @path = map { ($_->[1] eq '@') ?
                    '[' . make_printable($_->[0]) . ']' :
                    '{' . make_printable($_->[0]) . '}' } @{$_[0]}
    if $_[0];
  return join('->', '$got', @path);
}

sub v_format
{
  my ($got, $expected, $stash, $what, $msg) = @_;

  $msg //= "Expected #{expected}# $but";

  my $t;
  $msg =~ s!#\{got\}#!$t ||= make_printable($got)!eg;

  undef($t);
  $msg =~ s!#\{expected\}#!$t ||= $what // make_printable($expected)!eg;

  undef($t);
  $msg =~ s!#\{path\}#!$t ||= make_printable_path($stash->{':path'})!eg;

  return $msg;
}

sub v_fail
{
  # my ($got, $expected, $stash, $what, $msg) = @_;
  if (!$_[2]->{':ignore_errors'})
  {
    my $msg = v_format(@_);
    die "$msg\n" if $_[2]->{':die_on_error'};
    push(@{$_[2]->{':errors'}}, $msg);
    die ':stop_on_error' if $_[2]->{':stop_on_error'};
  }
  return 0; 
}

sub v_die
{
  # my ($got, $expected, $stash, $what, $msg) = @_;
  die v_format(@_) . "\n";
}

# ==== Deep comparators =======================================================

# $ok = verify_array($got, $expected, \%stash)
sub verify_array
{
  my ($got, $expected, $stash) = @_;
  my $ok = 1;

  my $got_length = @{$got};
  my $expected_length = @{$expected};
  v_fail($got_length, $expected_length, $stash, 'arrayref of length')
    unless ($got_length == $expected_length);

  my $path = $stash->{':path'};

  my $to_idx =
      ($got_length < $expected_length ? $got_length : $expected_length) - 1;
  foreach (0 .. $to_idx)
  {
    $stash->{':path'} = [@{$path}, [$_, '@']];
    $ok = 0
      unless verify_scalar($got->[$_], $expected->[$_], $stash, @_);
  }

  $stash->{':path'} = $path;

  return $ok;
}

# $ok = verify_hash($got, $expected, \%stash)
sub verify_hash
{
  my $got = shift;
  my $expected = shift;
  my $stash = shift;
  my $ok = 1;

  my $path = $stash->{':path'};

  foreach (keys(%{$got}))
  {
    # TODO make_printable
    v_fail($got, $expected, $stash, undef,
        "Got unexpected key '$_' in hashref at #{path}#")
      unless exists($expected->{$_});
  }

  foreach (keys(%{$expected}))
  {
    $stash->{':path'} = [@{$path}, [$_, '%']];

    # TODO exists? (How to ignore non-existing elements?)
    $ok = 0
      unless verify_scalar($got->{$_}, $expected->{$_}, $stash, @_);
  }

  $stash->{':path'} = $path;

  return $ok;
}

# $ok = verify_scalar($got, $expected, \%stash)
sub verify_scalar
{
  if (ref($_[1]))
  {
    if (ref($_[1]) eq 'ARRAY')
    {
      return ((ref($_[0]) eq 'ARRAY') && verify_array(@_));
    }
    elsif (ref($_[1]) eq 'CODE')
    {
      return $_[1]->(@_);
    }
    elsif (ref($_[1]) eq 'HASH')
    {
      return ((ref($_[0]) eq 'HASH') && verify_hash(@_));
    }
    elsif (ref($_[1]) eq 'Regexp')
    {
      return ((defined($_[0]) && ($_[0] =~ $_[1])) || v_fail(@_));
    }
    else
    {
      my $r = ref($_[1]);
      v_die(@_, undef,
          "You expexted a '$r' refence at #{path}#, ".
          "but I don't know what to do with it.");
    }
  }
  elsif (defined($_[1]))
  {
    return ((defined($_[0]) && ($_[0] eq $_[1])) || v_fail(@_));
  }
  else
  {
    return (!defined($_[0]) || v_fail(@_));
  }
}

# ==== Entry points ===========================================================

sub verify_
{
  my ($got, $expected, $stash) = @_;

  $stash //= {};
  $stash->{':path'} //= [];
  $stash->{':errors'} //= [];
  $stash->{':stop_on_error'} = 1 unless wantarray;

  eval { verify_scalar($got, $expected, $stash) };
  die $@ if ($@ && ($@ !~ /:stop_on_error/));

  return @{$stash->{':errors'}} if wantarray;
  return !@{$stash->{':errors'}};
}

sub verify
{
  return verify_($_[0], $_[1]);
}

sub verify_die
{
  return verify_($_[0], $_[1], { ':die_on_error' => 1 });
}

# ==== Comparators ============================================================
# my ($got, $expected, \%stash) = @_;

sub _v_defined
{
  my $what = shift;
  return defined($_[0]) || v_fail(@_, $what);
}

sub _v_nonref
{
  my $what = shift;
  return (!ref($_[0]) ||
          v_fail(@_, undef,
              "Expected a $what but got a reference instead at #{path}#"));
}

sub _v_min_max_obj
{
  my $min = shift;
  my $max = shift;
  my $what = shift;

  # Expected a number, minimum 17 but...
  return ((!defined($min) ||
           ($min <= $_[0]) ||
           v_fail(@_, undef, "Expected $what, minimum $min $but")) &&
          (!defined($max) ||
           ($max >= $_[0]) ||
           v_fail(@_, undef, "Expected $what, maximum $max $but")));
}

sub _v_min_max_num
{
  my $min = shift;
  my $max = shift;
  my $what = shift;

  # Expected minimum value 9 for length but...
  $what = $what ? "for $what" : '';
  return ((!defined($min) ||
           ($min <= $_[0]) ||
           v_fail(@_, undef, "Expected minimum value $min $what $but")) &&
          (!defined($max) ||
           ($max >= $_[0]) ||
           v_fail(@_, undef, "Expected maximum value $max $what $but")));
}

# ---- Ignore -----------------------------------------------------------------

sub v_ignore { return sub { return 1 } }
sub v_ign { return v_ignore(@_) }

# ---- Optional ---------------------------------------------------------------

sub v_optional
{
  my $v = $_[0];
  return
      sub
      {
        my $got = shift;
        my $expected = shift;
        return !defined($got) || verify_scalar($got, $v, @_);
      };
}
sub v_opt { return v_optional(@_) }

# ---- Defined ----------------------------------------------------------------

sub v_defined { return sub { return _v_defined('a defined value', @_) } }
sub v_def { return v_defined(@_) }

# ---- String -----------------------------------------------------------------

sub v_string
{
  state $what = 'a string';
  my ($min_length, $max_length) = @_;
  return
      sub
      {
        return (_v_defined($what, @_) &&
                _v_nonref($what, @_) &&
                _v_min_max_num(
                    $min_length, $max_length, "$what of length",
                    length($_[0]), undef, $_[2]));
      };
}
sub v_str { return v_string(@_) }

# ---- Boolean ----------------------------------------------------------------

sub v_boolean
{
  state $what = 'a boolean';
  return
      sub
      {
        return ((defined($_[0]) && ($_[0] =~ /^[01]?\z/)) ||
                v_fail(@_, $what));
      };
}
sub v_bool { return v_boolean(@_) }

# ---- Number / Integer -------------------------------------------------------

sub v_number
{
  state $what = 'a number';
  my ($min, $max) = @_;
  return
      sub
      {
        return (_v_defined($what, @_) &&
                _v_nonref($what, @_) &&
                (Scalar::Util::looks_like_number($_[0]) ||
                 v_fail(@_, $what)) &&
                _v_min_max_obj($min, $max, $what, @_));
      };
}
sub v_num { return v_number(@_) }

sub v_integer
{
  state $what = 'an integer';
  my ($min, $max) = @_;
  return
      sub
      {
        return (_v_defined($what, @_) &&
                _v_nonref($what, @_) &&
                (($_[0] =~ /^(?:0|(?:-?[1-9][0-9]*))\z/) ||
                 v_fail(@_, $what)) &&
                _v_min_max_obj($min, $max, $what, @_));
      };
}
sub v_int { return v_integer(@_) }

# ---- Array ------------------------------------------------------------------

sub v_array
{
  my ($min_elems, $max_elems, @elem_cmps) = @_;

  return
      sub
      {
        my $ok = 0;

        if (ref($_[0]) eq 'ARRAY')
        {
          my ($got, undef, $stash) = @_;

          my $got_elems = @{$got};
          $ok = _v_min_max_num(
              $min_elems, $max_elems, 'array length',
              $got_elems, undef, $stash);

          my $path = $stash->{':path'};
          my $elem_cmp_mod = @elem_cmps;
          my $elem_cmp_i = 0;
          foreach (0 .. $#{$got})
          {
            $stash->{':path'} = [@{$path}, [$_, '@']];

            $ok = 0
              unless verify_scalar(
                  $got->[$_], $elem_cmps[$elem_cmp_i], $stash);

            $elem_cmp_i = ($elem_cmp_i + 1) % scalar(@elem_cmps);
          }
          $stash->{':path'} = $path;
        }
        else
        {
          v_fail(@_, 'ARRAY');
        }

        return $ok;
      };
}

# ==== Hash ===================================================================

sub v_hash
{
  my ($min_elems, $max_elems, $required_keys, @elem_cmps) = @_;

  my @required_keys;
  @required_keys = ref($required_keys) ?
      @{$required_keys} :
      ($required_keys)
    if defined($required_keys);

  my @key_cmps;
  my @value_cmps;
  for ( my $i = 0 ; $i <= $#elem_cmps ; $i += 2 )
  {
    push(@key_cmps, $elem_cmps[$i]);
    push(@value_cmps, $elem_cmps[$i + 1]);
  }

  return
      sub
      {
        my $ok = 0;

        if (ref($_[0]) eq 'HASH')
        {
          my ($got, undef, $stash) = @_;

          my $got_elems = keys(%{$got});
          $ok = _v_min_max_num(
              $min_elems, $max_elems, 'hash length',
              $got_elems, undef, $stash);

          foreach (@required_keys)
          {
            if (!exists($got->{$_}))
            {
              v_fail(@_, undef,
                  "Required element '$_' missing at #{path}#");
              $ok = 0;
            }
          }

          my ($elem_ok, $key_ok);
          my $ignore_errors = $stash->{':ignore_errors'};
          my $path = $stash->{':path'};
          foreach my $k (keys(%{$got}))
          {
            $stash->{':path'} = [@{$path}, [$k, '%']];

            $elem_ok = 0;
            foreach my $i (0 .. $#key_cmps)
            {
              # local?
              $stash->{':ignore_errors'} = 1;
              $key_ok = !defined($key_cmps[$i]) ||
                  eval { verify_scalar($k, $key_cmps[$i], $stash) };
              $stash->{':ignore_errors'} = $ignore_errors;
              die $@ if $@;

              if ($key_ok)
              {
                $elem_ok = !defined($value_cmps[$i]) ||
                    verify_scalar($got->{$k}, $value_cmps[$i], $stash);
                last;
              }
            }
            $ok = 0 unless $elem_ok;

            v_fail($k, undef, $stash, undef, 'Invalid hash key at #{path}#')
              unless $key_ok;
          }
          $stash->{':path'} = $path;
        }
        else
        {
          v_fail(@_, 'HASH');
        }

        return $ok;
      };
}

###############################################################################

1

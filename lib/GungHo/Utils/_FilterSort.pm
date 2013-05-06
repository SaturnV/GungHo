#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# TODO: Docs, examples
# TODO json flag should be api_???
# TODO better customization
##### NAMESPACE ###############################################################

package GungHo::Utils::_FilterSort;

##### IMPORTS #################################################################

use strict;
use warnings;
use feature ':5.10';

# TODO This class doesn't depend on any of these.
#   But subclassing multiple classes breaks (*) $class->SUPER
#   if more than one subclass implements it.
#   *: In the sense that is does not call all applicable ones or
#   the one that the programmer intended to call. :)
use parent 'GungHo::Utils::_Relationships';
use parent 'GungHo::Utils::_AccessControl';

use GungHo::SQL::Utils qw( get_col_for_attr );

###### VARS ###################################################################

# TODO c (LIKE) operator
# TODO: SQL abstraction is leaking here
my %ops =
    (
      'eq' => '=',  'lt' => '<',  'gt' => '>',
      'ne' => '<>', 'ge' => '>=', 'le' => '<='
    );

##### SUBS ####################################################################

# ==== filtering ==============================================================

sub _map_to_filter_op { return $ops{$_[1]} }

sub _map_to_custom_filter
{
  my ($class, $n, $v, $die) = @_;
  die ($die // "TODO Bad filter '$n'");
}

sub _map_to_attr_filter
{
  my ($class, $n, $v, $attr) = @_;
  my @ret;

  die "TODO: Bad filter attribute '$n'"
    unless $attr->HasFlag('json');

  if ($attr->GetProperty('relationship'))
  {
    my $t = $class->can('_map_to_rel_filter');
    die "TODO: $class can't filter on relationships"
      unless $t;
    @ret = $class->$t($n, $v, $attr);
  }
  else
  {
    my ($op, $op_, $arg);

    die "TODO: Bad filter value for '$n'"
      unless (($op, $arg) = ($v =~ /^([^:]+):(.*)\z/s));
    die "TODO: Bad operator '$op'"
      unless ($op_ = $class->_map_to_filter_op($op));

    @ret = ($n => { $op_ => $arg });
  }

  return @ret;
}

# TODO This looks like $hit.
sub map_to_filters
{
  my $class = $_[0];
  my $args = $_[1];
  my @filters;

  if ($args)
  {
    # warn 'map_to_filters ' . Data::Dumper::Dumper($args);
    my $meta_class = $class->get_meta_class();

    my ($attr, $op, $op_, $arg);
    foreach my $n (keys(%{$args}))
    {
      if ($n !~ /^:/)
      {
        push(@filters,
            defined($attr = $meta_class->GetAttributeByName($n)) ?
                $class->_map_to_attr_filter($n, $args->{$n}, $attr) :
                $class->_map_to_custom_filter($n, $args->{$n}, $@));
      }
      elsif ($n eq ':sort')
      {
        push(@filters, $n => $args->{$n});
      }
      else
      {
        push(@filters, $class->_map_to_custom_filter($n, $args->{$n}));
      }
    }
  }

  return @filters;
}

# ==== SQL stuff ==============================================================

# ---- _load_sql_builder_param ------------------------------------------------

sub _load_sql_builder_param
{
  my $class = shift;
  my ($select, $table_alias, $class_db_descr, $dumpster, $n, $v) = @_;
  my $ret = 1;

  if ($n eq ':sort')
  {
    my $meta_class = $class->get_meta_class();

    my @fs = grep { $_ ne '' } split(',', $v // '');

    my @order_by;
    my $order_by = 1;
    my ($attr, $d, $f);
    foreach my $f_ (@fs)
    {
      $d = ($f = $f_) =~ s/^-//;

      if ($f !~ /^:/)
      {
        die "TODO: No attribute named '$f' in '$class'"
          unless ($attr = $meta_class->GetAttributeByName($f));
        die "TODO: Trying to access invisible field"
          unless $attr->HasFlag('json');
        if ($attr->HasFlag('persistent'))
        {
          $f = get_col_for_attr($class_db_descr, $f, $table_alias);
          $f .= ' DESC' if $d;
          push(@order_by, $f);
        }
        else
        {
          undef($order_by);
        }
      }
      else
      {
        undef($order_by);
      }

      if ($order_by)
      {
        $select->AddOrderBy(@order_by) if @order_by;
      }
      else
      {
        $dumpster->{'sort'} = \@fs;
      }
    }

    $ret = 1;
  }
  else
  {
    $ret = $class->SUPER::_load_sql_builder_param(@_);
  }

  return $ret;
}

# ---- _load_by_sql_return ----------------------------------------------------

sub _build_custom_sort
{
  my ($class, $f, $params) = @_;
  die "TODO Can't build comparator for '$f'";
}

sub __sqli_cmp_num
{
  return (defined($_[0]) ?
              (defined($_[1]) ? $_[0] <=> $_[1] : 1) :
              (defined($_[1]) ? -1 : 0));
}

sub __sqli_cmp_str
{
  return (defined($_[0]) ?
              (defined($_[1]) ? $_[0] cmp $_[1] : 1) :
              (defined($_[1]) ? -1 : 0));
}

sub _load_by_sql_return
{
  my $class = shift;
  my @ret = $class->SUPER::_load_by_sql_return(@_);
  my $params = $_[0];

  if ($params->{'sort'} && (scalar(@ret) > 1))
  {
    my $meta_class = $class->get_meta_class();

    my @cmps;
    my ($d, $f);
    foreach my $f_ (@{$params->{'sort'}})
    {
      $d = ($f = $f_) =~ s/^-//;

      my ($cmp, $get_a, $get_b);
      if ($f !~ /^:/)
      {
        my $attr = $meta_class->GetAttributeByName($f);
        # die "TODO: Trying to access invisible field"
        #   unless $attr->HasFlag('json');

        my $get = $attr->GetMethodName('get');
        $get_a = "\$a->$get()";
        $get_b = "\$b->$get()";
        
        my $type = $attr->Type();
        $cmp = $type && $type->isa('GungHo::Type::Number') ?
            '__sqli_cmp_num' :
            '__sqli_cmp_str';
      }
      else
      {
        # TODO better interface
        ($cmp, $get_a, $get_b) = $class->_build_custom_sort($f, '$params');
        $cmp = '__sqli_cmp_num' if ($cmp && ($cmp eq '<=>'));
        $cmp = '__sqli_cmp_str' if ($cmp && ($cmp eq 'cmp'));
      }

      if (defined($cmp) && defined($get_a) && defined($get_b))
      {
        ($get_a, $get_b) = ($get_b, $get_a) if $d;
        push(@cmps, "$cmp($get_a, $get_b)")
      }
    }

    if (@cmps)
    {
      my $sub = $#cmps ? join(' || ', map { "($_)" } @cmps) : $cmps[0];
      # warn "cmp: $sub";
      $sub = eval "sub { $sub }";
      @ret = sort { $sub->() } @ret;
    }
  }

  return @ret if wantarray;
  return $ret[0];
}

##### SUCCESS #################################################################

1;

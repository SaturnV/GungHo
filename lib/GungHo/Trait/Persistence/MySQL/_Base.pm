#! /usr/bin/perl
# TODO: License
# TODO: There is not much (':lock') MySQL specific in this module
#       and that would be very easy to factor out.
# TODO; JOIN
###### NAMESPACE ##############################################################

package GungHo::Trait::Persistence::MySQL::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::SQL::Query;
use GungHo::SQL::Utils qw( get_col_for_attr build_where_clause );
use GungHo::Utils qw( make_hashref );

use List::MoreUtils qw( any );

###### METHODS ################################################################

# ==== common =================================================================

sub _sql_name
{
  my $class = ref($_[0]) || $_[0];
  # my $params = $_[1];
  return "$class/" . ($_[1]->{'name'} // 'anon_sql');
}

sub _sql_make_dumpster
{
  my $class = shift;
  my $op = shift;
  my $params = make_hashref(@_);

  my $table_info = $class->get_sql_table_info();
  # {
  #   'table' => 'alma',
  #   'attributes' => [qw( id alma atom )],
  #   'columns' => [qw( id name atom )],
  #   ? 'attr_column_map' => { 'attr' => 'col' },
  #   'key' => [qw( id )],
  # }

  return
      {
        'name' => "anon_$op",
        'op' => $op,
        'params' => $params,
        'table_info' => $table_info
      };
}

# ---- DBI --------------------------------------------------------------------

# my ($params, $sth, @sql_params) = $class->_prepare_sql(@_);
sub _prepare_sql
{
  my ($class, $params, $sql, @sql_params) = @_;
  my $sth;

  ($sql, @sql_params) = $sql->Build()
    if (Scalar::Util::blessed($sql) && $sql->can('Build'));

  # TODO dbh
  my $dbh = $main::DBH;
  if (!($sth = $dbh->prepare($sql)))
  {
    my $sql_name = $class->_sql_name($params);
    die "TODO: Prepare ($sql_name) failed";
  }

  return ($params, $sth, @sql_params);
}

sub _execute_nonselect_sth
{
  my $class = shift;
  my $params = shift;
  my $sth = shift;
  my $ret;

  if (!($ret = $sth->execute(@_)))
  {
    my $sql_name = $class->_sql_name($params);
    die "TODO: Execute ($sql_name) failed";
  }

  return $ret;
}

# ---- SQL building -----------------------------------------------------------

sub _sql_builder_param
{
  my ($class, $sql, $table_alias, $table_info, $dumpster, $n, $v) = @_;
  my $ret;

  my $meta_class = $class->get_meta_class() or
    die 'TODO';
  if ($meta_class->GetAttributeByName($n))
  {
    my @where = build_where_clause(
        get_col_for_attr($table_info, $n, $table_alias), $v);
    $sql->AddWhere(@where) if @where;
    $ret = 1;
  }

  return $ret;
}

sub _sql_builder
{
  my ($class, $sql, $table_alias, $table_info, $dumpster) = @_;

  my $param_handler = $dumpster->{'op'};
  $param_handler = $class->can("_${param_handler}_sql_builder_param")
    if $param_handler;
  $param_handler //= $class->can('_sql_builder_param');

  my $params = $dumpster->{'params'};
  foreach (keys(%{$params}))
  {
    $dumpster->{$_} = $params->{$_}
      unless $class->$param_handler(
                 $sql, $table_alias, $table_info, $dumpster,
                 $_, $params->{$_});
  }

  return 1;
}

# ==== load ===================================================================

# ---- Sorting ----------------------------------------------------------------

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

sub _build_custom_sort
{
  my ($class, $f, $params, $params_q) = @_;

  my $meta_class = $class->get_meta_class();
  my $attr = $meta_class && $meta_class->GetAttributeByName($f);
  my $get = $attr && $attr->GetMethodName('get');
  die "TODO Can't build comparator for '$f'"
    unless $get;

  my $type = $attr->Type();
  my $cmp = $type && $type->isa('GungHo::Type::Number') ?
      '__sqli_cmp_num' :
      '__sqli_cmp_str';

  return ($cmp, "\$a->$get()", "\$b->$get()");
}

sub _build_custom_sort_
{
  my $class = shift;
  my $f = shift;

  my $d = $f =~ s/^-//;
  my ($cmp, $get_a, $get_b) =
      $class->_build_custom_sort($f, @_);

  return $d ?
      ($cmp, $get_b, $get_a) :
      ($cmp, $get_a, $get_b);
}

sub _build_custom_sort__
{
  my $class = shift;

  my ($cmp, $get_a, $get_b) =
      $class->_build_custom_sort_(@_);
  if ($cmp)
  {
    $cmp = '__sqli_cmp_num' if ($cmp eq '<=>');
    $cmp = '__sqli_cmp_str' if ($cmp eq 'cmp');
  }

  return $cmp ? ("$cmp($get_a, $get_b)") : ();
}

sub _sort_objects
{
  my $class = shift;
  my $params = shift;

  my @cmps =
      map { $class->_build_custom_sort__($_, $params, '$params') }
          @{$params->{'sort'}};
  if (@cmps)
  {
    my $sub = $#cmps ? join(' || ', map { "($_)" } @cmps) : $cmps[0];
    # warn "cmp: $sub";
    $sub = eval "sub { $sub }";
    return sort { $sub->() } @_;
  }
  else
  {
    return @_;
  }
}

# TODO Better DESC handling
sub _sql_sort_builder_field
{
  my $class = shift;
  my ($sql, $table_alias, $table_info, $dumpster, $f) = @_;
  my $ret;

  my $d = $f =~ s/^-//;

  if ($f !~ /^:/)
  {
    my $attr;
    my $meta_class = $class->get_meta_class();
    die "TODO: No attribute named '$f' in '$class'"
      unless ($attr = $meta_class->GetAttributeByName($f));
    die "TODO: Trying to access invisible field"
      unless $attr->HasFlag('json');
    die "TODO: Trying to sort on non-persistent attribute '$class.$f'"
      unless $attr->HasFlag('persistent');

    $ret = get_col_for_attr($table_info, $f, $table_alias);
    $ret .= ' DESC' if $d;
  }

  return $ret;
}

sub _sql_sort_builder
{
  my $class = shift;
  my ($sql, $table_alias, $table_info, $dumpster, $n, $v) = @_;

  my @fs;
  @fs = grep { $_ ne '' } split(',', $v)
    if defined($v);

  if (@fs)
  {
    my $t;
    my @order_by;
    my $sql_sort = 1;
    foreach (@fs)
    {
      $t = $class->_sql_sort_builder_field(
          $sql, $table_alias, $table_info, $dumpster, $_);
      if (!defined($t))
      {
        $sql_sort = 0;
        last;
      }

      push(@order_by, $t) if ($t ne '');
    }

    if ($sql_sort)
    {
      $sql->AddOrderBy(@order_by);
    }
    else
    {
      $dumpster->{'sort'} = \@fs;
    }
  }

  return 1;
}

# ---- SQL building -----------------------------------------------------------

sub _load_sql_builder_param
{
  my $class = shift;
  my ($sql, $table_alias, $table_info, $dumpster, $n, $v) = @_;
  my $ret;

  given ($n)
  {
    when (':lock')
    {
      given ($v)
      {
        when ('read')
        {
          $sql->ReadLock();
        }
        when ('write')
        {
          $sql->WriteLock();
        }
        when ('none')
        {
          # Nop
        }
        default
        {
          die 'TODO' if defined($v);
        }
      }

      $ret = 1;
    }
    when (':sort')
    {
      $ret = $class->_sql_sort_builder(@_);
    }
    default
    {
      $ret = $class->_sql_builder_param(@_);
    }
  }

  return $ret;
}

sub _load_sql_builder
{
  # my ($class, $sql, $table_alias, $table_info, $dumpster) =
  #     splice(@_, 0, 5);
  # my $params = make_hashref(@_);
  return shift->_sql_builder(@_);
}

sub load_sql
{
  my $class = shift;
  my $dumpster = $class->_sql_make_dumpster('load', @_);

  my $sql = GungHo::SQL::Query->new('SELECT');
  my $table_info = $dumpster->{'table_info'};
  my $table_alias = $dumpster->{'table_aliases'}->{'root'} =
      $sql->AddFrom($table_info->{'table'});
  $sql->AddSelect(
      map { "$table_alias.$_" } @{$table_info->{'columns'}});
  $class->_load_sql_builder(
      $sql, $table_alias, $table_info, $dumpster);

  return ($dumpster, $sql);
}

# ---- transform --------------------------------------------------------------

sub _load_by_sql_transform
{
  my $class = shift;
  my $params = shift;
  my @ret;
  my $t;

  if ($t = $params->{'&map_to_hash'})
  {
    @ret = $class->$t($params, @_);
  }
  else
  {
    my @attributes = @{$params->{'table_info'}->{'attributes'}};
    @ret = map { my $h = {} ; @{$h}{@attributes} = @{$_} ; $h } @_;
  }

  @ret = $class->$t($params, @ret)
    if ($t = $params->{'&pre_deserialize_map'});

  @ret = $class->_load_by_sql_deserialize($params, @ret);

  @ret = $class->$t($params, @ret)
    if ($t = $params->{'&post_deserialize_map'});

  return @ret;
}


# ---- instantiate ------------------------------------------------------------

sub _load_by_sql_instantiate
{
  my $class = shift;
  my $params = shift;
  return map { $class->_fast_new($_) } @_;
}

# ---- return -----------------------------------------------------------------

sub _load_by_sql_return
{
  my $class = shift;
  my $params = shift;

  if ($params->{'sort'} && (scalar(@_) > 1))
  {
    my @objs = $class->_sort_objects($params, @_);
    return @objs if wantarray;
    return $objs[0];
  }
  else
  {
    return @_ if wantarray;
    return $_[0];
  }
}

# ---- execute / fetch --------------------------------------------------------

sub _load_by_sql_sth
{
  my $class = shift;
  my $params = shift;
  my $sth = shift;

  my $sql_name = $class->_sql_name($params);

  $sth->execute(@_) or
    die "TODO: Execute ($sql_name) failed";
  my $rows = $sth->fetchall_arrayref() or
    die "TODO: Fetch ($sql_name) failed";
  die "TODO: Database error ($sql_name)"
    if $sth->err();

  die "TODO: Empty set ($sql_name)"
    if ($params->{'die_on_empty'} && !@{$rows});
  die "TODO: Multiple rows ($sql_name)"
    if ($params->{'single_row'} && (scalar(@{$rows}) > 1));
  die "TODO: Object not found ($sql_name)"
    if (!wantarray && !scalar(@{$rows}) &&
        !$params->{'return_undef'});
  warn "TODO: Discarding loaded objects ($sql_name)"
    if (!wantarray && (scalar(@{$rows}) > 1));

  return $class->_load_by_sql_return($params,
      $class->_load_by_sql_instantiate($params,
          $class->_load_by_sql_transform($params, @{$rows})));
}

# -----------------------------------------------------------------------------

sub load_by_sql
{
  # my ($class, $params, $sql_str, @sql_params) = @_;
  # my ($class, $params, $sql_obj) = @_;
  my $class = shift;

  # my ($params, $sth, @sql_params) = $class->_prepare_sql(@_);
  # return $class->_load_by_sql_sth($params, $sth, @sql_params);
  return $class->_load_by_sql_sth($class->_prepare_sql(@_));
}

sub load
{
  my $class = shift;
  # my ($params, $sql, @sql_params) = $class->load_sql(@_);
  # return $class->load_by_sql($params, $sql, @sql_params);
  return $class->load_by_sql($class->load_sql(@_));
}

# ==== destroy ================================================================

sub _destroy_by_sql_sth { return shift->_execute_nonselect_sth(@_) }

sub _destroy_sql_builder
{
  # my ($class, $sql, $table_alias, $table_info, $dumpster) =
  #     splice(@_, 0, 5);
  # my $params = make_hashref(@_);
  return shift->_sql_builder(@_);
}

sub destroy_sql
{
  my $class = shift;
  my $dumpster = $class->_sql_make_dumpster('destroy', @_);

  my $sql = GungHo::SQL::Query->new('delete');
  my $table_info = $dumpster->{'table_info'};
  my $table_alias = $dumpster->{'table_aliases'}->{'root'} =
      $sql->AddFrom($table_info->{'table'});

  $class->_destroy_sql_builder(
      $sql, $table_alias, $table_info, $dumpster);

  return ($dumpster, $sql);
}

sub destroy_by_sql
{
  # my ($class, $params, $sql_str, @sql_params) = @_;
  # my ($class, $params, $sql_obj) = @_;
  my $class = shift;

  # my ($params, $sth, @sql_params) = $class->_prepare_sql(@_);
  # return $class->_destroy_by_sql_sth($params, $sth, @sql_params);
  return $class->_destroy_by_sql_sth($class->_prepare_sql(@_));
}

sub destroy
{
  my $class = shift;
  # my ($params, $sql, @sql_params) = $class->destroy_sql(@_);
  # return $class->destroy_by_sql($params, $sql, @sql_params);
  return $class->destroy_by_sql($class->destroy_sql(@_));
}

###### THE END ################################################################

1

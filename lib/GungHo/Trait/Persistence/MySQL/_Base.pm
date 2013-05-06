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

###### METHODS ################################################################

# ==== common =================================================================

sub _sql_name
{
  my $class = ref($_[0]) || $_[0];
  # my $params = $_[1];
  return "$class/" . ($_[1]->{'name'} // 'anon_sql');
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
  warn "$class SQL $sql";
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

  warn "$class SQL (non-select) PARAMS " . Data::Dumper::Dumper(\@_);
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
  my ($class, $sql, $table_alias, $table_info, $dumpster) =
      splice(@_, 0, 5);
  my $params = make_hashref(@_);

  my $param_handler = $dumpster->{'op'};
  $param_handler = $class->can("_${param_handler}_sql_builder_param")
    if $param_handler;
  $param_handler //= $class->can('_sql_builder_param');

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
        default
        {
          die 'TODO';
        }
      }

      $ret = 1;
    }
    when (':sort')
    {
      $sql->AddOrderBy(
          map { get_col_for_attr($table_info, $_, $table_alias) }
              (ref($v) ? @{$v} : ($v)));
      $ret = 1;
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
  my $dumpster = { 'name' => 'anon_load', 'op' => 'load' };

  my $table_info = $dumpster->{'table_info'} =
      $class->get_sql_table_info();
  # {
  #   'table' => 'alma',
  #   'attributes' => [qw( id alma atom )],
  #   'columns' => [qw( id name atom )],
  #   ? 'attr_column_map' => { 'attr' => 'col' },
  #   'key' => [qw( id )],
  # }

  my $sql = GungHo::SQL::Query->new('SELECT');
  my $table_alias = $dumpster->{'table_aliases'}->{'root'} =
      $sql->AddFrom($table_info->{'table'});
  $sql->AddSelect(
      map { "$table_alias.$_" } @{$table_info->{'columns'}});
  $class->_load_sql_builder(
      $sql, $table_alias, $table_info,
      $dumpster, @_);

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

  warn "$class SQL OBJS " . Data::Dumper::Dumper(\@ret);
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
  return @_ if wantarray;
  return $_[0];
}

# ---- execute / fetch --------------------------------------------------------

sub _load_by_sql_sth
{
  my $class = shift;
  my $params = shift;
  my $sth = shift;

  my $sql_name = $class->_sql_name($params);

  warn "$class SQL (select) PARAMS " . Data::Dumper::Dumper(\@_);
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
  my $dumpster = { 'name' => 'anon_destroy', 'op' => 'destroy' };

  my $table_info = $dumpster->{'table_info'} =
      $class->get_sql_table_info();

  my $sql = GungHo::SQL::Query->new('delete');
  my $table_alias = $dumpster->{'table_aliases'}->{'root'} =
      $sql->AddFrom($table_info->{'table'});

  $class->_destroy_sql_builder(
      $sql, $table_alias, $table_info,
      $dumpster, @_);

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

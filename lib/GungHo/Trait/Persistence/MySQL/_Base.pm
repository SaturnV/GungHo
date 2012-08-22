#! /usr/bin/perl
# TODO: License
# TODO: There is nothing MySQL specific in this module
###### NAMESPACE ##############################################################

package GungHo::Trait::Persistence::MySQL::_Base;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use GungHo::SQL::Query;
use GungHo::Utils qw( make_hashref );

###### METHODS ################################################################

sub _load_sql_builder_param
{
  my ($class, $select, $table_alias, $class_db_descr, $dumpster, $n, $v) = @_;
  my $ret;

  my $meta_class = $class->get_meta_class() or
    die 'TODO';
  if (my $attr = $meta_class->GetAttributeByName($n))
  {
    my $col = $class_db_descr->{'attr_column_map'}->{$n} || $n;
    $col = "$table_alias.$col";

    if (!ref($v))
    {
      $select->AddWhere("$col = ?", $v);
    }
    elsif (ref($v) eq 'ARRAY')
    {
      die "TODO: No values in array" unless @{$v};
      if ($#{$v})
      {
        my $qs = join(', ', ('?') x scalar(@{$v}));
        $select->AddWhere("$col IN ($qs)", @{$v});
      }
      else
      {
        $select->AddWhere("$col = ?", $v->[0]);
      }
    }
    elsif (ref($v) eq 'HASH')
    {
      $select->AddWhere("$col $_ ?", $v->{$_})
        foreach (keys(%{$v}));
    }
    elsif ($v->isa('GungHo::SQL::Query::Literal'))
    {
      $select->AddWhere("$col = " . $v->Sql(), $v->SqlParameters());
    }
    else
    {
      die 'TODO';
    }

    $ret = 1;
  }

  return $ret;
}

sub _load_sql_builder
{
  my ($class, $select, $table_alias, $class_db_descr, $dumpster) =
      splice(@_, 0, 5);
  my $params = make_hashref(@_);

  foreach (keys(%{$params}))
  {
    $dumpster->{$_} = $params->{$_}
      unless $class->_load_sql_builder_param(
                 $select, $table_alias, $class_db_descr, $dumpster,
                 $_, $params->{$_});
  }

  return 1;
}

sub _load_sql
{
  my $class = shift;
  my $dumpster = {};

  my $class_db_descr = $class->get_sql_select_info();
  # {
  #   'table' => 'alma',
  #   'attributes' => [qw( id alma atom )],
  #   'columns' => [qw( id name atom )],
  #   ? 'attr_column_map' => { 'attr' => 'col' },
  #   'key' => [qw( id )],
  # }

  my $select = GungHo::SQL::Query->new();
  my $table_alias = $select->AddFrom($class_db_descr->{'table'});
  $select->AddSelect(
      map { "$table_alias.$_" } @{$class_db_descr->{'columns'}});
  $dumpster->{'select_info'} = $class_db_descr;
  $class->_load_sql_builder(
      $select, $table_alias, $class_db_descr,
      $dumpster, @_);

  return ($dumpster, $select->Build());
}

sub _load_by_sql_instantiate
{
  my $class = shift;
  my $params = shift;
  my @attributes = @{$params->{'select_info'}->{'attributes'}};
  my @ret = map { $class->_fast_new($_) }
      $class->_load_by_sql_deserialize($params,
          map { my $h = {} ; @{$h}{@attributes} = @{$_} ; $h } @_);
  return @ret if wantarray;
  return $ret[0];
}

sub _load_by_sql_sth
{
  my $class = shift;
  my $params = shift;
  my $sth = shift;

  my $sql_name = "$class/" . ($params->{'name'} // 'anon_load');

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

  return $class->_load_by_sql_instantiate($params, @{$rows});
}

sub _load_by_sql
{
  my $class = shift;
  my $params = shift;
  my $sql = shift;

  my $sql_name = "$class/" . ($params->{'name'} // 'anon_load');

  # TODO
  my $dbh = $main::DBH;

  my $sth = $dbh->prepare($sql) or
    die "TODO: Prepare ($sql_name) failed";

  return $class->_load_by_sql_sth($params, $sth, @_);
}

sub load
{
  my $class = shift;
  # my ($params, $sql, @sql_params) = $class->_load_sql(@_);
  # return $class->load_by_sql($params, $sql, @sql_params);
  return $class->_load_by_sql($class->_load_sql(@_));
}

###### THE END ################################################################

1

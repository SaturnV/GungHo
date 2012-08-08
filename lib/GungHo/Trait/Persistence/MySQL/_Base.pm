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
      $select->AddWhere($v->Sql(), $v->SqlParameters());
    }
    else
    {
      die 'TODO';
    }
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
  #   'columns' => [qw( id name atom )],
  #   ? 'attr_column_map' => { 'attr' => 'col' },
  #   'key' => [qw( id )],
  # }
  my $select = GungHo::SQL::Query->new();
  my $table_alias = $select->AddFrom($class_db_descr->{'table'});
  $select->AddSelect(
      map { "$table_alias.$_" } @{$class_db_descr->{'columns'}});
  $class->_load_sql_builder(
      $select, $table_alias, $class_db_descr,
      $dumpster, @_);

  return ($dumpster, $select->Build());
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

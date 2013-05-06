#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Utils;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw( import );

use GungHo::SQL::Query;

###### EXPORTS ################################################################

our @EXPORT_OK = qw(
    $SQL_NULL $SQL_NOT_NULL
    get_col_for_attr build_where_clause );

###### VARS ###################################################################

our $SQL_NULL = { 'IS' => GungHo::SQL::Query->literal('NULL') };
our $SQL_NOT_NULL = { 'IS' => GungHo::SQL::Query->literal('NOT NULL') };

###### SUBS ###################################################################

sub get_col_for_attr
{
  my ($table_info, $attr_name, $table_alias) = @_;
  my $col =
      $table_info->{'attr_column_map'} &&
          $table_info->{'attr_column_map'}->{$attr_name} ||
      $attr_name;
  $col = "$table_alias.$col" if defined($table_alias);
  return $col;
}

sub build_where_clause
{
  my ($col, $v) = @_;
  my ($where, @where_params);

  if (!ref($v))
  {
    $where = "$col = ?";
    @where_params = ($v);
  }
  elsif (ref($v) eq 'ARRAY')
  {
    die "TODO: No values in array" unless @{$v};
    if ($#{$v})
    {
      my $qs = join(', ', ('?') x scalar(@{$v}));
      $where = "$col IN ($qs)";
    }
    else
    {
      $where = "$col = ?";
    }
    @where_params = @{$v};
  }
  elsif (ref($v) eq 'HASH')
  {
    my @where;
    my $vv;
    foreach (keys(%{$v}))
    {
      if (Scalar::Util::blessed($vv = $v->{$_}) &&
          $vv->isa('GungHo::SQL::Query::Literal'))
      {
        push(@where, "$col $_ " . $vv->Sql());
        push(@where_params, $vv->SqlParameters());
      }
      else
      {
        push(@where, "$col $_ ?");
        push(@where_params, $vv);
      }
    }

    $where = $#where ?
        join(' AND ', map { "($_)" } @where) :
        $where[0]
      if @where;
  }
  elsif ($v->isa('GungHo::SQL::Query::Literal'))
  {
    $where = "$col = " . $v->Sql();
    @where_params = $v->SqlParameters();
  }
  else
  {
    die 'TODO';
  }

  return () unless defined($where);
  return ($where, @where_params);
}

###### THE END ################################################################

1

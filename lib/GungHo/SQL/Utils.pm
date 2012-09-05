#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Utils;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw( import );

use GungHo::SQL::Query::Literal;

###### EXPORTS ################################################################

our @EXPORT_OK = qw( get_col_for_attr $SQL_NULL $SQL_NOT_NULL );

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

###### THE END ################################################################

1

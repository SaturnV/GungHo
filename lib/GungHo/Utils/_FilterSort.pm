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

##### SUCCESS #################################################################

1;

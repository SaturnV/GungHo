#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# TODO Better interface instead of $x_class
#
# @objs = $class->load(':access' => { ... }, ...);
#   Load objects that satisfy filter parameters AND access control parameters.
#   Doesn't die if there are objects that satisfy filter parameters but are
#   not accessible or no objects are loaded. Access control and filtering is
#   done in the DB if possible (efficient).
# @objs = $class->load(...);
# $class->check_access($acc_user, 'x', @objs);
#   Load objects that satisfy filter parameters then check access. Dies if
#   there is an object that doesn't satisfy access control parameters.
#   May be less efficient then previous method.
# $obj = $class->load(':access' => { ... }, ...);
#   Load object satisfying filter parameters AND access control parameters,
#   Dies if no such object exist.
##### NAMESPACE ###############################################################

package GungHo::Utils::_AccessControl;

##### IMPORTS #################################################################

use strict;
use warnings;
use feature ':5.10';

# TODO Invent something that call all overridden methods instead of
#      SUPER call in _load_sql_builder_param.
use parent 'GungHo::Trait::Persistence::MySQL::_Base';

##### SUBS ####################################################################

# ==== access control =========================================================

sub _check_user_access
{
  my $class = $_[0];
  my $user = $_[1];
  my $access_granted;

  if (!ref($user))
  {
    die "TODO" if (!defined($user) || ($user eq '-'));
    $access_granted = 1 if ($user eq '+');
  }

  return ($access_granted, $user);
}

sub _check_class_access
{
  # my ($class, $user, $mode, @objects) = @_;
  # my @x_classes = ...;
  # my $x_classes = @x_classes ? \@x_classes : undef;
  # return ($access_granted, $x_classes);
  return (undef);
}

sub _check_object_access
{
  my ($class, $x_classes, $user, $mode);
  $class = shift;
  $x_classes = shift;
  $user = shift;
  $mode = shift;

  if (($mode ne 'create') && $x_classes && @_)
  {
    my @ids = map { ref($_) ? $_->GetId() : $_ } @_;

    my %allowed;
    my ($x_class, $x_attr, $x_getter, @filters);
    foreach my $x_class_info (@{$x_classes})
    {
      $x_class = $x_class_info->{'x_class'};
      $x_attr = $x_class_info->{'x_attr'};
      $x_getter = $x_class_info->{'x_getter'};

      @filters = $x_class_info->{'x_filter'} ?
            ( %{$x_class_info->{'x_filter'}} ) :
            ();

      # TODO GetId, user_id
      $allowed{$_->$x_getter()} = 1
        foreach ($x_class->load(
                     'user_id' => $user->GetId(),
                     $x_attr => \@ids,
                     @filters));
    }

    $allowed{$_} or die "TODO" foreach (@ids);
  }

  return 1;
}

# Class->check_access($user, $mode, @objects);
sub check_access
{
  my $class = shift;
  my ($access_granted, $user, $x_classes);

  ($access_granted, $user) = $class->_check_user_access(@_);
  if (!$access_granted)
  {
    # User. Was loaded / replaced by _check_user_access
    shift;

    ($access_granted, $x_classes) =
        $class->_check_class_access($user, @_);

    $class->_check_object_access($x_classes, $user, @_) or
      die "TODO"
      unless $access_granted;
  }

  return 1;
}

# ==== SQL stuff ==============================================================

sub _load_sql_builder_param
{
  my $class = shift;
  my ($select, $table_alias, $class_db_descr, $dumpster, $n, $v) = @_;
  my $ret = 1;

  if ($n eq ':access')
  {
    my ($access_granted, $user, $x_classes);

    ($access_granted, $user) =
        $class->_check_user_access($v->{'user'}, $v->{'mode'});
    ($access_granted, $x_classes) =
        $class->_check_class_access($user, $v->{'mode'})
      unless $access_granted;

    if (!$access_granted)
    {
      # TODO deleted?

      my ($x_class, $x_attr, $my_attr, $sub_sql, @sub_params, @filters);
      foreach my $x_class_info (@{$x_classes})
      {
        # TODO attr->col mapping
        $my_attr = $x_class_info->{'my_attr'};
        $x_class = $x_class_info->{'x_class'};
        $x_attr = $x_class_info->{'x_attr'};

        # TODO GetId, user_id
        @filters = $x_class_info->{'x_filter'} ?
            ( %{$x_class_info->{'x_filter'}} ) :
            ();
        (undef, $sub_sql) = $x_class->load_sql(
            $x_attr =>
                GungHo::SQL::Query->literal("$table_alias.$my_attr"),
            'user_id' => $user->GetId(),
            @filters);
        ($sub_sql, @sub_params) = $sub_sql->Build();
        $select->AddWhere("EXISTS ($sub_sql)", @sub_params);
      }
    }
  }
  else
  {
    $ret = $class->SUPER::_load_sql_builder_param(@_);
  }

  return $ret;
}

##### SUCCESS #################################################################

1;

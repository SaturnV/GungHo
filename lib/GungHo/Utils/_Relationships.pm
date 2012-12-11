#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# Should play together nicely with access control.
# TODO: Many to many relationships
# TODO: Docs, examples
##### NAMESPACE ###############################################################

package GungHo::Utils::_Relationships;

##### IMPORTS #################################################################

use strict;
use warnings;
use feature ':5.10';

# use parent 'GungHo::Trait::Persistence::MySQL::_Base';

##### VARS ####################################################################

my %reltype =
    (
      'has_many' => ':children',
      'belongs_to' => ':parents'
    );

##### SUBS ####################################################################

# ---- get_rel_info -----------------------------------------------------------

sub get_rel_info
{
  my ($class, $rel_name) = @_;

  my %r = (
    'obj_class_name' => $class,
    'obj_meta_class' => $class->get_meta_class(),
    'rel_name'       => $rel_name
  );

  my $attr = $r{'obj_meta_class'}->GetAttributeByName($rel_name);

  $r{'type'} = $attr->GetProperty('relationship');

  ($r{'obj_relid_name'}, $r{'rel_class_name'}, $r{'rel_relid_name'}) =
      $attr->GetProperty('related') =~ /^(\w+)\s+=>\s+([^.]+)\.(\w+)\z/ or
    die "TODO Can't parse relationship for $class.$rel_name";

  $r{'rel_meta_class'} = $r{'rel_class_name'}->get_meta_class() or
    die "TODO: Can't find metadata for related " . $r{'rel_class_name'};

  foreach my $type ('obj', 'rel')
  {
    my $name = $r{"${type}_relid_name"};
    $r{"${type}_relid_attr"} =
        $r{"${type}_meta_class"}->GetAttributeByName($name) or
      die "TODO: Can't find $type relid attribute";
    $r{"${type}_table_info"} = $r{"${type}_class_name"}->get_sql_table_info();

    foreach my $method ('get', 'set')
    {
      $r{"${type}_relid_${method}"} =
          $r{"${type}_relid_attr"}->GetMethodName($method) //
          sub { die "TODO: No ${method}er for $type relid attribute" };
    }
  }

  $r{'access_control'} = $attr->HasFlag('propagate_access') ? 'obj' : 'rel';

  return \%r;
}

# ---- load_relationships -----------------------------------------------------

# Access control:
#   base object(s) should be checked beforehand
#   read: implied (base), trough relation / delegated (related)
#   write: n/a
#   create: n/a
sub load_relationships
{
  my $class = shift;
  my $ac = shift;
  my $rels = shift;
  my @objs = @_;

  if ($rels && %{$rels} && @objs)
  {
    my $meta_class = $class->get_meta_class() or
      die "TODO: Can't find metadata for '$class'";

    foreach my $obj_rel_attr
        ($meta_class->GetAttributesWithFlag('relationship'))
    {
      my $obj_rel_name = $obj_rel_attr->Name();

      # TODO better get_rel_info integration
      my $ri = $class->get_rel_info($obj_rel_name);
      my ($obj_relid_get, $rel_relid_get,
          $rel_class_name, $rel_relid_name) =
         ($ri->{'obj_relid_get'}, $ri->{'rel_relid_get'},
          $ri->{'rel_class_name'}, $ri->{'rel_relid_name'});

      my $relationship = $obj_rel_attr->GetProperty('relationship') or
        die 'TODO: Not a relationship.';

      my $rel_info;
      my $rel = $rels->{$obj_rel_name} ||
          $rels->{$reltype{$relationship} || ':others'} ||
          $rels->{'*'};
      if (ref($rel))
      {
        $rel_info = $rel;
        $rel = $rel_info->{'return'};
      }
      next if (!$rel || ($rel eq 'none'));

      my $obj_rel_set = $obj_rel_attr->GetMethodName('set') or
        die 'TODO: No setter for relationship';

      my $related_objs = {};
      {
        my $relid;
        foreach (@objs)
        {
          $related_objs->{$relid} = []
            if defined($relid = $_->$obj_relid_get());
        }
      }

      if (my $load = $obj_rel_attr->GetProperty('load'))
      {
        # TODO: Better parameters incl. AC stuff
        $related_objs = $load->(
            'class' => $rel_class_name,
            'attr' => $rel_relid_name,
            'attr_getter' => $rel_relid_get,
            'values' => [keys(%{$related_objs})],
            'args' => ($rel_info ? $rel_info->{'args'} : undef)) || {};
      }
      else
      {
        my @related_objs;
        {
          my @load_filters;
          push(@load_filters,
              $rel_class_name->map_to_filters($rel_info->{'args'}))
            if ($rel_info && $rel_info->{'args'});
          push(@load_filters, ':access' => $ac)
            if (($ri->{'type'} ne 'belongs_to') &&
                ($ri->{'access_control'} ~~ 'rel'));
          @related_objs = $rel_class_name->load(
              $rel_relid_name => [keys(%{$related_objs})],
              @load_filters)
            if %{$related_objs};
        }

        if (my $load_map = $obj_rel_attr->GetProperty('load_map'))
        {
          my @mapped_objs = $load_map->(@related_objs);
          foreach my $i (0 .. $#related_objs)
          {
            push(@{$related_objs->{$related_objs[$i]->$rel_relid_get()}},
                $mapped_objs[$i])
              if $mapped_objs[$i];
          }
        }
        else
        {
          push(@{$related_objs->{$_->$rel_relid_get()}}, $_)
            foreach (@related_objs);
        }
      }

      if ($rel ne 'raw')
      {
        my $ac_user = $ac->{'user'};
        my $exporter = ($rel eq 'id') ? 'GetId' : 'ExportJsonObject';
        $related_objs->{$_} =
            [ map { $_->$exporter($ac_user) } @{$related_objs->{$_}} ]
          foreach (keys(%{$related_objs}));
      }

      given ($relationship)
      {
        when ('has_many')
        {
          my $relid;
          foreach (@objs)
          {
            $_->$obj_rel_set([@{$related_objs->{$relid}}])
              if (defined($relid = $_->$obj_relid_get()) &&
                  $related_objs->{$relid} &&
                  @{$related_objs->{$relid}});
          }
        }
        when ('belongs_to')
        {
          my $relid;
          foreach (@objs)
          {
            die "TODO: Belongs to none"
              if (!defined($relid = $_->$obj_relid_get()) ||
                  !$related_objs->{$relid} ||
                  !@{$related_objs->{$relid}});
            die "TODO: Belongs to many"
              if $#{$related_objs->{$relid}};
            $_->$obj_rel_set($related_objs->{$relid}->[0]);
          }
        }
        default
        {
          die "TODO: Unknown relationship";
        }
      } # given ($relationship)
    } # foreach my $obj_rel_attr (...)
  } # if ($rels && %{$rels} && @objs)

  return @objs;
}

# ---- SaveRelationships ------------------------------------------------------

# Access control:
#   base object should be checked beforehand
#   read: n/a
#   write: implied (base), delegated (related)
#   create: n/a (base), delegated (related)
sub SaveRelationships
{
  my ($obj, $acc_user, $rels) = @_;
  my $ret = {};
  $obj->_UpdateParents($ret, $acc_user, $rels);
  $obj->Save();
  $obj->_SaveChildren($ret, $acc_user, $rels);
  return $ret;
}

# Access control:
#   base object should be checked beforehand
#   read: n/a
#   write: implied (base) / checked (related)
#   create: n/a
sub _UpdateParents
{
  my ($obj, $ret, $acc_user, $rels) = @_;
  my $class = ref($obj);
  my $meta_class = $class->get_meta_class();

  foreach my $obj_rel_name (keys(%{$rels}))
  {
    # TODO better get_rel_info integration
    my $obj_rel_attr = $meta_class->GetAttributeByName($obj_rel_name) or
      die "TODO: Can't find my related attribute '$obj_rel_name'";
    my $relationship = $obj_rel_attr->GetProperty('relationship') or
      die 'TODO: Not a relationship.';
    next unless ($relationship ~~ 'belongs_to');

    die "TODO: Trying to remove parent, use delete instead"
      if ($rels->{$obj_rel_name}->{'mode'} ~~ 'remove');

    my $ri = $class->get_rel_info($obj_rel_name);
    my ($obj_relid_set, $rel_class_name) =
        ($ri->{'obj_relid_set'}, $ri->{'rel_class_name'});

    my $related_objs = $rels->{$obj_rel_name}->{'objs'};
    die "TODO: No parent"
      unless (@{$related_objs} && defined($related_objs->[0]));
    die "TODO: Multiple parents"
      if $#{$related_objs};
    die "TODO: Embedded parent"
      if ref($related_objs->[0]);

    my $old_rel_id = $obj->id_getter();
    my $new_rel_id = $related_objs->[0];
    if (!defined($old_rel_id) || ($old_rel_id ne $new_rel_id))
    {
      my $check_access = $rel_class_name->can('check_access');
      $rel_class_name->$check_access($acc_user, 'w', $new_rel_id)
        if $check_access;
      $obj->$obj_relid_set($new_rel_id);
    }

    $ret->{$obj_rel_name} = [ $new_rel_id ];
  }

  return $ret;
}

# Access control:
#   base object should be checked beforehand
#   read: n/a
#   write: n/a (base) / see comments (related)
#   create: n/a (base) / checked (related)
sub _SaveChildren
{
  my ($obj, $ret, $acc_user, $rels) = @_;
  my $class = ref($obj);
  my $meta_class = $class->get_meta_class();

  foreach my $obj_rel_name (keys(%{$rels}))
  {
    # TODO better get_rel_info integration
    my $obj_rel_attr = $meta_class->GetAttributeByName($obj_rel_name) or
      die "TODO: Can't find my related attribute '$obj_rel_name'";
    my $relationship = $obj_rel_attr->GetProperty('relationship') or
      die 'TODO: Not a relationship.';
    next unless ($relationship ~~ 'has_many');

    my $ri = $class->get_rel_info($obj_rel_name);
    my ($obj_relid_get, $rel_class_name,
        $rel_relid_name, $rel_relid_set) =
        ($ri->{'obj_relid_get'}, $ri->{'rel_class_name'},
         $ri->{'rel_relid_name'}, $ri->{'rel_relid_set'});

    my @ret_objs;
    my @ret_ids;
    my $ret_ids;

    my $inverted_delete;
    my $dont_delete;
    my %child_ids;

    my $obj_relid = $obj->$obj_relid_get();

    if (my $save = $obj_rel_attr->GetProperty('save'))
    {
      # Access control delegated to save
      my $s = $save->($obj, $obj_rel_name, $rels->{$obj_rel_name}, $acc_user);

      my $id;
      my $s_id_getter = $s->{'id_getter'} || 'GetId';
      foreach my $r (@{$s->{'return'}})
      {
        if (ref($r))
        {
          $id = $r->$s_id_getter();
          push(@ret_objs, $r);
          push(@ret_ids, $id);
        }
        else
        {
          push(@ret_ids, $r);
          $ret_ids = 1;
        }
      }

      if ($s->{'ids'})
      {
        $child_ids{$_} = 1 foreach (@{$s->{'ids'}})
      }

      $inverted_delete = $s->{'inverted_delete'};
      $dont_delete = $s->{'dont_delete'};
    }
    elsif ($rels->{$obj_rel_name}->{'mode'} ~~ 'remove')
    {
      # Access granted trough relationship with base
      foreach (@{$rels->{$obj_rel_name}->{'objs'}})
      {
        die "TODO: Embedded object in remove" if ref;
        push(@ret_ids, $_);
        $child_ids{$_} = 1;
        $ret_ids = 1;
      }
      $inverted_delete = 1;
    }
    else
    {
      my %update_ids;
      my ($child, $child_id);
      foreach my $r (@{$rels->{$obj_rel_name}->{'objs'}})
      {
        if (ref($r))
        {
          # Access control delegated to api_create_
          $r->{$rel_relid_name} = $obj_relid;
          $child = $rel_class_name->api_create_(
              { 'user' => $acc_user }, $r);

          # TODO id discovery
          $child_id = $child->GetId();
          $child_ids{$child_id} = 1;
          push(@ret_ids, $child_id);
          push(@ret_objs, $child);
        }
        else
        {
          # Access control delayed
          $update_ids{$r} = 1;
          push(@ret_ids, $r);
          $ret_ids = 1;
        }
      }

      if (%update_ids)
      {
        # Access checked
        my @children = $rel_class_name->load(
            $rel_relid_name => [keys(%update_ids)]);
        # TODO can
        $rel_class_name->check_access($acc_user, 'w', @children);

        foreach (@children)
        {
          $_->$rel_relid_set($obj_relid);
          $_->Save();

          # TODO id discovery
          $child_id = $_->GetId();
          delete($update_ids{$child_id});
          $child_ids{$child_id} = 1;
        }

        die "TODO: Can't update " . join(', ', keys(%update_ids))
          if %update_ids;
      }
    }

    if (($rels->{$obj_rel_name}->{'mode'} ~~ ['replace', 'remove']) &&
        !$dont_delete)
    {
      # Access already checked
      my $child_id;
      my @delete_ids;
      foreach ($rel_class_name->load($rel_relid_name => $obj_relid))
      {
        # TODO id discovery
        $child_id = $_->GetId();
        push(@delete_ids, $child_id)
          unless ($inverted_delete xor $child_ids{$child_id});
      }

      # TODO: Performance
      $rel_class_name->api_delete({ 'user' => '+' }, $_)
        foreach (@delete_ids);
    }

    $ret->{$obj_rel_name} = $ret_ids ? \@ret_ids : \@ret_objs;
  }

  return $ret;
}

# ---- split_relationships ----------------------------------------------------

# Access control: n/a
sub split_relationships
{
  my ($class, $json) = @_;
  my %rels;

  my ($attr_name, $rel);
  my $meta_class = $class->get_meta_class();
  foreach my $attr ($meta_class->GetAttributesWithFlag('relationship'))
  {
    $attr_name = $attr->Name();
    next unless exists($json->{$attr_name});

    $rel = delete($json->{$attr_name});
    $rels{$attr_name} = { 'mode' => 'add', 'objs' => $rel }
      if (defined($rel) && ((ref($rel) ne 'ARRAY') || @{$rel}));
  }

  return %rels ? \%rels : undef;
}

##### SUCCESS #################################################################

1;

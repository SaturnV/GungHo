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

sub _sclone_list { return $_[0] ? [@{$_[0]}] : undef }

# ---- get_rel_info -----------------------------------------------------------

sub _get_rel_info_simple
{
  my ($class, $rel_name, $related, $meta_class, $attr) = @_;

  my %r =
      (
        'name'           => $rel_name,
        'type'           => $attr->GetProperty('relationship'),
        'obj_class_name' => $class,
        'obj_meta_class' => $meta_class,
      );

  @r{'obj_relid_name', 'rel_class_name', 'rel_relid_name'} =
      $related =~ /^(\w+)\s+=>\s+([^.]+)\.(\w+)\z/ or
    die "TODO Can't parse relationship for $class.$rel_name";

  $r{'rel_meta_class'} = $r{'rel_class_name'}->get_meta_class() or
    die "TODO: Can't find metadata for related $r{'rel_class_name'}";

  foreach my $type ('obj', 'rel')
  {
    my $name = $r{"${type}_relid_name"};
    $r{"${type}_relid_attr"} =
        $r{"${type}_meta_class"}->GetAttributeByName($name) or
      die "TODO: Can't find $type relid attribute";
    $r{"${type}_table_info"} = $r{"${type}_class_name"}->get_sql_table_info();

    foreach ('get', 'set')
    {
      $r{"${type}_relid_$_"} =
          $r{"${type}_relid_attr"}->GetMethodName($_) //
          sub { die "TODO: No $_ method for $type relid attribute " .
                    "in $class.$rel_name" };
    }
  }

  $r{'access_control'} = $attr->HasFlag('propagate_access') ? 'obj' : 'rel';

  foreach (qw( get set ))
  {
    $r{$_} = $attr->GetMethodName($_) //
        sub { die "TODO: No $_ method for relationship $class.$rel_name" };
  }

  my $t;
  foreach (qw( load save ))
  {
    $r{"rel_$_"} = $t if defined($t = $attr->GetProperty($_));
  }

  return \%r;
}

sub _merge_relationships
{
  my ($obj_x, $x_rel) = @_;
  my $ret = { 'obj_x_relinfo' => $obj_x, 'x_rel_relinfo' => $x_rel };

  my $rel = $obj_x->{'name'};
  my $class = $obj_x->{'obj_class_name'};
  die "TODO Something is not good around $class.$rel (type)"
    unless (($obj_x->{'type'} ~~ 'many_to_many') &&
            ($x_rel->{'type'} ~~ 'belongs_to'));

  my $new_key;
  foreach my $orig_key (keys(%{$obj_x}))
  {
    $new_key = $orig_key;
    $new_key =~ s/^obj_relid/obj_xobjid/ ||
        $new_key =~ s/^rel_relid/x_xobjid/ || 
        $new_key =~ s/^rel_/x_/;
    $ret->{$new_key} = $obj_x->{$orig_key};
  }

  foreach my $orig_key (keys(%{$x_rel}))
  {
    next if ($orig_key ~~ [qw( obj_table_info )]);

    $new_key = $orig_key;
    $new_key =~ s/^obj_relid/x_xrelid/ ||
        $new_key =~ s/^rel_relid/rel_xrelid/ ||
        $new_key =~ s/^obj_/x_/ ||
        $new_key =~ s/^/xr_/;

    if (defined($ret->{$new_key}))
    {
      die "TODO Something is not good around $class.$rel ($orig_key/$new_key)"
        if ($ret->{$new_key} ne $x_rel->{$orig_key});
    }
    else
    {
      $ret->{$new_key} = $x_rel->{$orig_key};
    }
  }

  return $ret;
}

sub get_rel_info
{
  my ($class, $rel_name) = @_;
  my $ret;

  my $meta_class = $class->get_meta_class();
  my $attr = $meta_class->GetAttributeByName($rel_name);
  my $related = $attr->GetProperty('related');
  if ($related =~ s/\s*>>\s*(\w+)\z//)
  {
    my $final_rel = $1;
    my $rel_obj = $class->_get_rel_info_simple(
        $rel_name, $related, $meta_class, $attr);
    my $rel_rel = $rel_obj->{'rel_class_name'}->get_rel_info($final_rel);
    $ret = _merge_relationships($rel_obj, $rel_rel);
  }
  else
  {
    $ret = $class->_get_rel_info_simple(
        $rel_name, $related, $meta_class, $attr);
  }

  return $ret;
}

# ---- load_relationships -----------------------------------------------------

sub _relationships_to_load
{
  my ($class, $load_relationships_spec) = @_;
  my %relationships_to_load;

  my $meta_class = $class->get_meta_class() or
    die "TODO: Can't find metadata for '$class'";

  my ($rel_name, $relationship, $rel);
  foreach my $rel_attr
      ($meta_class->GetAttributesWithFlag('relationship'))
  {
    $rel_name = $rel_attr->Name();
    $relationship = $rel_attr->GetProperty('relationship') or
      die "TODO: $class.$rel_name is not a relationship.";

    $rel = $load_relationships_spec->{$rel_name} ||
        $load_relationships_spec->{$reltype{$relationship} || ':others'} ||
        $load_relationships_spec->{'*'};
    if ($rel)
    {
      $rel = { 'return' => $rel } unless ref($rel);
      $relationships_to_load{$rel_name} = $rel
        if (($rel->{'return'} // 'none') ne 'none');
    }
  }

  return \%relationships_to_load;
}

sub _loadrel_output_mapper
{
  # my ($class, $ri, $load_spec, $ac) = @_;
  my $map_out;

  my $output = $_[2]->{'return'};
  if ($output eq 'id')
  {
    $map_out = sub { return $_[0]->GetId() };
  }
  elsif ($output eq 'full')
  {
    my $ac_user = $_[3]->{'user'};
    $map_out = sub { return $_[0]->ExportJsonObject($ac_user) };
  }
  elsif ($output eq 'raw')
  {
    # nop
  }
  else
  {
    die "TODO Unknown output transformation '$output'";
  }

  return $map_out;
}

sub _loadrel_load_rels
{
  my ($class, $ri, $load_spec, $ac, $rel_ids) = @_;

  my @filters = ( $ri->{'rel_relid_name'} => $rel_ids );
  push(@filters, ':access' => $ac)
    if ($ri->{'access_control'} eq 'rel');
  push(@filters, @{$load_spec->{'filter'}})
    if $load_spec->{'filter'};

  return $ri->{'rel_class_name'}->load(@filters);
}

# Technically this implements may_belong_to
sub _load_relationship_belongs_to
{
  my $class = shift;
  my $ri = shift;
  my $load_spec = shift;
  my $ac = shift;

  my $set = $ri->{'set'};
  my $obj_relid_get = $ri->{'obj_relid_get'};

  if (($load_spec->{'return'} eq 'id') && !$load_spec->{'filter'} &&
      ($ri->{'access_control'} eq 'obj'))
  {
    $_->$set($_->$obj_relid_get()) foreach (@_);
  }
  else
  {
    my $relid;

    my %relids;
    foreach (@_)
    {
      $relids{$relid} = 1
        if defined($relid = $_->$obj_relid_get());
    }

    my %rels;
    if (%relids)
    {
      my $rel_relid_get = $ri->{'rel_relid_get'};
      my $map_out = $class->_loadrel_output_mapper($ri, $load_spec, $ac);
      my @rels = $class->_loadrel_load_rels(
          $ri, $load_spec, $ac, [keys(%relids)]);
      %rels = $map_out ?
          map { ( $_->$rel_relid_get() => $map_out->($_) ) } @rels :
          map { ( $_->$rel_relid_get() => $_ ) } @rels;
    }

    foreach (@_)
    {
      $_->$set($rels{$relid})
        if defined($relid = $_->$obj_relid_get());
    }
  }

  return @_;
}

# TODO More efficient id only loading
sub _load_relationship_has_many
{
  my $class = shift;
  my $ri = shift;
  my $load_spec = shift;
  my $ac = shift;

  my $set = $ri->{'set'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  my $rel_relid_get = $ri->{'rel_relid_get'};
  my $relid;

  my %rels;
  foreach (@_)
  {
    $rels{$relid} = []
      if defined($relid = $_->$obj_relid_get());
  }

  if (%rels)
  {
    my @rels = $class->_loadrel_load_rels(
        $ri, $load_spec, $ac, [keys(%rels)]);
    my $map_out = $class->_loadrel_output_mapper($ri, $load_spec, $ac);
    if ($map_out)
    {
      push(@{$rels{$_->$rel_relid_get()}}, $map_out->($_))
        foreach (@rels);
    }
    else
    {
      push(@{$rels{$_->$rel_relid_get()}}, $_)
        foreach (@rels);
    }
  }

  foreach (@_)
  {
    $_->$set(_sclone_list($rels{$relid}))
      if defined($relid = $_->$obj_relid_get());
  }

  return @_;
}

sub _load_relationship_many_to_many
{
  my $class = shift;
  my $ri = shift;
  my $load_spec = shift;
  my $ac = shift;

  my $set = $ri->{'set'};
  my $obj_xobjid_get = $ri->{'obj_xobjid_get'};
  my $relid;

  my %rels;
  foreach (@_)
  {
    $rels{$relid} = []
      if defined($relid = $_->$obj_xobjid_get());
  }

  if (%rels)
  {
    my $x_spec = {};
    $x_spec->{'filter'} = $load_spec->{'x_filter'}
      if $load_spec->{'x_filter'};
    my @xs = $class->_loadrel_load_rels(
        $ri->{'obj_x_relinfo'}, $x_spec, $ac, [keys(%rels)]);
    @xs = $ri->{'x_class_name'}->_load_relationship(
        $ri->{'x_rel_relinfo'}, $load_spec, $ac, @xs);

    my $t;
    my $x_xobjid_get = $ri->{'x_xobjid_get'};
    my $x_get = $ri->{'x_rel_relinfo'}->{'get'};
    foreach (@xs)
    {
      push(@{$rels{$_->$x_xobjid_get()}}, $t)
        if ($t = $_->$x_get());
    }
  }

  foreach (@_)
  {
    $_->$set(_sclone_list($rels{$relid}))
      if defined($relid = $_->$obj_xobjid_get());
  }

  return @_;
}

sub _load_relationship
{
  my $class = shift;
  my $rel_name = shift;
  # my $load_spec = shift;
  # my $ac = shift;

  my $ri;
  if (ref($rel_name))
  {
    $ri = $rel_name;
    $rel_name = $ri->{'name'};
  }
  else
  {
    $ri = $class->get_rel_info($rel_name);
  }

  my $method = $ri->{'rel_load'} ||
      $class->can("_load_relationship_$ri->{'type'}") or
    die "TODO $class can't load $ri->{'type'} relationship ($rel_name)";

  # return $class->$method($ri, $load_spec, $ac, @_);
  return $class->$method($ri, @_);
}

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
  # my @objs = @_;

  if ($rels && %{$rels} && @_)
  {
    my $load_rels = $class->_relationships_to_load($rels);
    $class->_load_relationship($_, $load_rels->{$_}, $ac, @_)
      foreach (keys(%{$load_rels}));
  }

  return @_;
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

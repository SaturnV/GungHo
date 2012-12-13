#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# TODO: Docs, examples
##### NAMESPACE ###############################################################

package GungHo::Utils::_RestApi;

##### IMPORTS #################################################################

use strict;
use warnings;
use feature ':5.10';

use parent 'GungHo::Utils::_FilterSort';

use GungHo::SQL::Utils qw( get_col_for_attr );

##### SUBS ####################################################################

# ==== random ramblings =======================================================

sub tweak_new_json {}
sub tweak_duplicate_json {}

# ==== api ====================================================================

# Access control:
#   read: checked (filter)
#   write: n/a
#   create: n/a
sub api_list
{
  my ($class, $params) = @_;
  my @objs = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'r' },
      $class->map_to_filters($params->{'args'}));
  @objs = $class->load_relationships(
      { 'user' => $params->{'user'}, 'mode' => 'r' },
      $params->{'rel'}, @objs)
    if (@objs && $params && $params->{'rel'} && %{$params->{'rel'}});
  return [ map { $_->ExportJsonObject($params->{'user'}) } @objs ];
}

# Access control:
#   read: checked (die)
#   write: n/a
#   create: n/a
sub api_read_
{
  my ($class, $params, $id) = @_;
  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'r' },
      'id' => $id) or
    die "TODO: Can't load ${class}[$id]";
  ($obj) = $class->load_relationships(
      { 'user' => $params->{'user'}, 'mode' => 'r' },
      $params->{'rel'}, $obj)
    if ($params && $params->{'rel'} && %{$params->{'rel'}});
  return $obj;
}
sub api_read
{
  return shift->api_read_(@_)->ExportJsonObject($_[0]->{'user'});
}

sub api_read_multiple_
{
  my $class = shift;
  my $params = shift;
  my @objs;

  if (@_)
  {
    @objs = $class->load(
        ':access' => { 'user' => $params->{'user'}, 'mode' => 'r' },
        'id' => \@_) or
      die "TODO: Can't load ${class}[" . join(', ', @_) .']';
    @objs = $class->load_relationships(
        { 'user' => $params->{'user'}, 'mode' => 'r' },
        $params->{'rel'}, @objs)
      if ($params && $params->{'rel'} && %{$params->{'rel'}});
  }

  return @objs;
}
sub api_read_multiple
{
  return
      map { $_->ExportJsonObject($_[0]->{'user'}) }
          shift->api_read_multiple_(@_);
}

# Access control:
#   read: n/a
#   write: n/a (base) / delegated (related)
#   create: checked (die)
sub api_create_
{
  my ($class, $params, $json) = @_;
  $class->check_access($params->{'user'}, 'c', $json);
  $class->tweak_new_json($params->{'user'}, $json);
  my $rels = $class->split_relationships($json);
  my $obj = $class->new($json);
  $rels ? $obj->SaveRelationships($params->{'user'}, $rels) : $obj->Save();
  return $obj;
}
sub api_create
{
  return shift->api_create_(@_)->ExportJsonObject($_[0]->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die)
#   create: n/a
sub api_update
{
  my ($class, $params, $id, $json) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'w' },
      'id' => $id);

  if (keys(%{$json}))
  {
    die "id_mismatch\n"
      if (defined($json->{'id'}) && ($json->{'id'} ne $id));

    my $meta_class = $class->get_meta_class() or
      die "meta_class missing.\n";
    my ($attr, $obj_rel_set);
    my %rels;
    foreach my $k (keys(%{$json}))
    {
      $attr = $meta_class->GetAttributeByName($k);
      die "attr_missing: '$k'.\n" unless ref($attr);
      die "!attr_api_writable: '$k'\n" unless $attr->HasFlag('api_writable');

      if ($attr->GetProperty('relationship'))
      {
        $rels{$k} = { 'objs' => $json->{$k}, 'mode' => 'replace' };
      }
      else
      {
        $obj_rel_set = $attr->GetMethodName('set');
        die "readonly_attr: '$k'.\n" unless $obj_rel_set;
        $obj->$obj_rel_set($json->{$k});
      }
    }

    %rels ? $obj->SaveRelationships($params->{'user'}, \%rels) : $obj->Save();
  }

  return $obj->ExportJsonObject($params->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die)
#   create: n/a
sub api_delete
{
  my ($class, $params, $id) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'w' },
      'id' => $id);
  if ($obj->can('SetDeleted'))
  {
    $obj->SetDeleted(1);
    $obj->Save();
  }
  else
  {
    $obj->Destroy();
  }

  return undef;
}

# Access control:
#   read: delegated
#   write: n/a
#   create: n/a
sub api_list_rel
{
  my ($class, $params, $id, $rel_name, $id_or_full) = @_;
  my $objs;

  $id_or_full = 'raw' if ($id_or_full eq 'full');
  my $obj = $class->api_read_(
      {
        'user' => $params->{'user'},
        'rel' =>
            {
              $rel_name =>
                  {
                    'return' => $id_or_full,
                    'args' => $params->{'args'}
                  }
            }
      }, $id);
  if ($obj)
  {
    my $getter = $class->get_meta_class()->
        GetAttributeByName($rel_name)->
        GetMethodName('get');
    if ($objs = $obj->$getter())
    {
      # Access control: related objects are readable
      my $related_class = ref($objs->[0]);
      $objs =
          [ map { $_->ExportJsonObject($params->{'user'}) }
                $related_class->load_relationships(
                    { 'user' => $params->{'user'}, 'mode' => 'r' },
                    $params->{'rel'}, @{$objs}) ]
        if $related_class;
    }
  }

  return $objs || [];
}

# Access control:
#   read: delegated
#   write: n/a
#   create: n/a
# TODO: More efficient implementation
sub api_read_rel_
{
  my ($class, $params, $id, $rel_name, $rel_id) = @_;

  my $obj = $class->api_read_(
      {
        'user' => $params->{'user'},
        'rel' => { $rel_name => 'raw' }
      }, $id) or
    die "TODO: Can't load parent (${class}[$id])";
  my $getter = $class->get_meta_class()->
        GetAttributeByName($rel_name)->
        GetMethodName('get');
  my $rel_objs = $obj->$getter() or
    die "TODO: No related objects";
  my @ros = grep { $_->GetId() eq $rel_id } @{$rel_objs};
  die "TODO: $rel_id not related to $id"
    unless @ros;
  die "TODO: Non-unique id $rel_id" if $#ros;
  my $related_class = ref($ros[0]);
  @ros = $related_class->load_relationships(
      { 'user' => $params->{'user'}, 'mode' => 'r' },
      $params->{'rel'}, @ros);

  return $ros[0];
}
sub api_read_rel
{
  return shift->api_read_rel_(@_)->ExportJsonObject($_[0]->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die, base), delegated (related)
#   create: n/a (base), delegated (related)
sub api_add_replace_rel
{
  my ($class, $mode, $params, $id, $rel_name, $data) = @_;
  my $ret;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'w' },
      'id' => $id) or
    die "TODO: Can't load ${class}[$id]";

  if ($data)
  {
    my $r;
    my $data_list = (ref($data) ne 'ARRAY') ? [ $data ] : $data;
    $r = $obj->SaveRelationships(
        $params->{'user'},
        { $rel_name => { 'mode' => $mode, 'objs' => $data_list } })
      if (@{$data_list} || ($mode eq 'replace'));
    if ($r)
    {
      my @r =
          map { ref($_) ? $_->ExportJsonObject($params->{'user'}) : $_ }
              @{$r->{$rel_name}};
      $ret = (ref($data) eq 'ARRAY') ? \@r : $r[0];
    }
  }

  return $ret;
}
sub api_replace_rel { return shift->api_add_replace_rel('replace', @_) }
sub api_add_rel { return shift->api_add_replace_rel('add', @_) }

# Access control:
#   read: n/a
#   write: delegated
#   create: n/a (base), delegated (related)
sub api_edit_rel
{
  my ($class, $params, $id, $rel_name, $rel_id, $data) = @_;
  my $rel_obj = $class->api_read_rel_(
      { 'user' => $params->{'user'} }, $id, $rel_name, $rel_id, $data) or
    die "TODO: Not related";
  my $related_class = ref($rel_obj) or
    die "TODO: Not object";
  return $related_class->api_update(
      { 'user' => $params->{'user'} }, $rel_id, $data);
}

# Access control:
#   read: n/a
#   write: checked (die, base), delegated (related)
#   create: n/a
sub api_remove_rel
{
  my ($class, $params, $id, $rel_name, $data) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'w' },
      'id' => $id) or
    die "TODO: Can't load ${class}[$id]";

  if ($data)
  {
    my $data_list = (ref($data) ne 'ARRAY') ? [ $data ] : $data;
    $obj->SaveRelationships($params->{'user'},
        {
          $rel_name => { 'mode' => 'remove', 'objs' => $data_list }
        })
      if @{$data_list};
  }

  return {};
}

# ---- Duplicate --------------------------------------------------------------

sub _duplicate
{
  my $class = shift;
  my $user = shift;
  my @objs;

  if (@_)
  {
    my @clear_ids;
    my @recursive;

    my $rels = {};
    my $dup_type;
    my $attr_name;
    my $meta_class = $class->get_meta_class();
    foreach my $attr ($meta_class->GetAttributesWithFlag('duplicate'))
    {
      $attr_name = $attr->Name();
      $dup_type = $attr->GetProperty('duplicate');
      if ($dup_type ne 'recursive')
      {
        $rels->{$attr_name} = $dup_type;
        push(@clear_ids, $attr_name) if ($dup_type eq 'full');
      }
      else
      {
        $rels->{$attr_name} = 'raw';
        push(@recursive, $attr_name);
      }
    }
    @objs = $class->load_relationships(
        { 'user' => $user, 'mode' => 'r' },
        $rels, @_);

    delete($_->{'id'}) foreach (@objs);

    foreach my $rel_name (@clear_ids)
    {
      foreach my $obj (@objs)
      {
        delete($_->{'id'}) foreach (@{$obj->{$rel_name}});
      }
    }

    my $rel_class;
    foreach my $rel_name (@recursive)
    {
      $rel_class = $class->get_rel_info($rel_name)->{'rel_class_name'};

      foreach (@objs)
      {
        $_->{$rel_name} = $rel_class->_duplicate($user, @{$_->{$rel_name}})
          if ($_->{$rel_name} && @{$_->{$rel_name}});
      }
    }
  }

  return @objs ? [ map { $_->ExportJsonObject($user) } @objs ] : undef;
}

sub api_duplicate
{
  my ($class, $params, $id, $post_json) = @_;

  my $obj = $class->_duplicate(
      $params->{'user'},
      $class->api_read_(
          { 'user' => $params->{'user'} }, $id))->[0];
  $class->tweak_duplicate_json($params->{'user'}, $obj);
  warn "Duplicated object looks like this: " . Data::Dumper::Dumper($obj);
  $obj = $class->api_create(
      { 'user' => $params->{'user'} }, $obj);

  $obj = $class->api_update(
      { 'user' => $params->{'user'} }, $obj->{'id'}, $post_json)
    if ($post_json && %{$post_json});

  return $obj;
}

# ==== testing ================================================================

sub create_objs_api
{
  my $class = shift;
  my $params = { 'user' => '+' };
  my @ret = map { $class->api_create_($params, $_)->GetId() } @_;
  return @ret if wantarray;
  return $ret[0];
}

sub create_objs_raw
{
  my $class = shift;

  my @ret = map {
                  my ($obj, $rels);
                  $rels = $class->split_relationships($_);
                  $obj = $class->new($_);
                  $rels ? $obj->SaveRelationships('+', $rels) : $obj->Save();
                  $obj->GetId()
                } @_;

  return @ret if wantarray;
  return $ret[0];
}

sub create_objs_tweaked
{
  my $class = shift;

  my @ret = map {
                  my ($obj, $rels);
                  $class->tweak_new_json('+', $_);
                  $rels = $class->split_relationships($_);
                  $obj = $class->new($_);
                  $rels ? $obj->SaveRelationships('+', $rels) : $obj->Save();
                  $obj->GetId()
                } @_;

  return @ret if wantarray;
  return $ret[0];
}

##### SUCCESS #################################################################

1;

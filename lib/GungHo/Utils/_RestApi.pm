#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# TODO: Docs, examples
# TODO: Check ids before passing them to load
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

sub ApiVerifyObject {}

# ==== api ====================================================================

# Access control:
#   read: checked (filter)
#   write: n/a
#   create: n/a
sub api_list
{
  my ($class, $params) = @_;

  my @objs = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' },
      $class->map_to_filters($params->{'args'}));

  @objs = $class->load_relationships(
      $params->{'rel'},
      { ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' } },
      @objs)
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

  my @filters;
  @filters = @{$params->{'filter'}}
    if $params->{'filter'};

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' },
      'id' => $id,
      @filters) or
    die "TODO: Can't load ${class}[$id]";

  ($obj) = $class->load_relationships(
      $params->{'rel'},
      { ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' } },
      $obj)
    if ($params && $params->{'rel'} && %{$params->{'rel'}});

  return $obj;
}
sub api_read
{
  my $class = shift;
  my $params = $_[0];
  return $class->api_read_(@_)->ExportJsonObject($params->{'user'});
}

sub api_read_multiple_
{
  my $class = shift;
  my $params = shift;
  my @objs;

  if (@_)
  {
    my @filters;
    @filters = @{$params->{'filter'}}
      if $params->{'filter'};

    @objs = $class->load(
        ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' },
        'id' => \@_,
        @filters) or
      die "TODO: Can't load ${class}[" . join(', ', @_) .']';

    @objs = $class->load_relationships(
        $params->{'rel'},
        { ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' } },
        @objs)
      if ($params && $params->{'rel'} && %{$params->{'rel'}});
  }

  return @objs;
}
sub api_read_multiple
{
  my $class = shift;
  my $params = $_[0];
  return
      map { $_->ExportJsonObject($params->{'user'}) }
          $class->api_read_multiple_(@_);
}

# Access control:
#   read: n/a
#   write: n/a (base) / delegated (related)
#   create: checked (die)
sub _api_create_
{
  my ($class, $params, $json) = @_;

  $class->check_access($params->{'user'}, 'create', $json);
  $class->tweak_new_json($params, $json);

  my $rels = $class->split_relationships($json);

  my $obj = $class->new($json);
  $obj->ApiVerifyObject();

  $rels ?
      # TODO mode?
      $obj->SaveRelationships($rels,
          { ':access' =>
                { 'user' => $params->{'user'}, 'mode' => 'write' } }) :
      $obj->Save();

  return $obj;
}
sub api_create_ { return shift->_api_create_(@_) }
sub api_import_ { return shift->_api_create_(@_) }
sub api_create
{
  my $class = shift;
  my $params = $_[0];
  return $class->api_create_(@_)->ExportJsonObject($params->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die)
#   create: n/a
sub ApiUpdate
{
  my ($self, $params, $json) = @_;

  if (keys(%{$json}))
  {
    if (exists($json->{'id'}))
    {
      die "TODO: Can't delete id"
        unless defined($json->{'id'});
      die "TODO: Can't change id"
        unless ($json->{'id'} eq $self->GetId());
    }

    my $meta_class = $self->get_meta_class() or
      die "meta_class missing.\n";

    my %rels;
    my ($attr, $obj_rel_set);
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
        $self->$obj_rel_set($json->{$k});
      }
    }

    $self->ApiVerifyObject();

    %rels ?
        # TODO mode?
        $self->SaveRelationships(\%rels,
            { ':access' =>
                  { 'user' => $params->{'user'}, 'mode' => 'write' } }) :
        $self->Save();
  }

  return $self;
}

sub api_update
{
  my ($class, $params, $id, $json) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' },
      'id' => $id);
  $obj = $obj->ApiUpdate($params, $json);

  return $obj->ExportJsonObject($params->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die)
#   create: n/a
sub ApiDelete
{
  # my ($obj, $params) = @_;
  my $obj = $_[0];

  if ($obj->can('SetDeleted'))
  {
    $obj->SetDeleted(1);
    $obj->ApiVerifyObject();
    $obj->Save();
  }
  else
  {
    $obj->Destroy();
  }

  return undef;
}

sub api_delete
{
  my ($class, $params, $id) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' },
      'id' => $id);

  return $obj->ApiDelete($params);
}

# Access control:
#   read: delegated
#   write: n/a
#   create: n/a
# TODO Don't check :access twice when not needed
sub api_list_rel
{
  my ($class, $params, $id, $rel_name, $id_or_json) = @_;
  my $objs;

  my $user = $params->{'user'};

  my $ri = $class->get_rel_info($rel_name);
  my ($obj) = $class->load_relationship(
      $ri,
      { ':access' => { 'user' => $user, 'mode' => 'read' } },
      {
        'return' => ($id_or_json eq 'json') ? 'raw' : 'id',
        'filter' =>
            [$ri->{'rel_class_name'}->map_to_filters($params->{'args'})]
      },
      scalar($class->load(
          ':access' => { 'user' => $user, 'mode' => 'read' },
          'id' => $id)));

  my $get = $ri->{'get'};
  my $rels = $obj->$get();
  if ($rels && ($id_or_json eq 'json'))
  {
    my $rel_class = $ri->{'rel_class_name'};
    $rels = [map { $_->ExportJsonObject($user) }
        $rel_class->load_relationships(
            $params->{'rel'},
            { ':access' => { 'user' => $user, 'mode' => 'read' } },
            @{$rels})];
  }

  return $rels || [];
}

# Access control:
#   read: delegated
#   write: n/a
#   create: n/a
sub api_read_rel_w_parent
{
  my ($class, $params, $id, $rel_name, $rel_id) = @_;
  my @rels;

  my $obj = $class->api_read_(
      {
        'user' => $params->{'user'},
        'rel' =>
            {
              $rel_name =>
                  {
                    'filter' => [ 'id' => $rel_id ],
                    'return' => 'raw'
                  }
            },
      }, $id) or
    die "TODO: Can't load parent (${class}[$id])";

  my $getter = $class->get_meta_class()->
        GetAttributeByName($rel_name)->
        GetMethodName('get');
  my $rel_objs = $obj->$getter() or
    die "TODO: No related objects";

  @rels = @{$rel_objs};

  die "TODO: $rel_id not related to $id" unless @rels;
  die "TODO: Non-unique id $rel_id" if $#rels;

  my $related_class = ref($rels[0]);
  @rels = $related_class->load_relationships(
      $params->{'rel'},
      { ':access' => { 'user' => $params->{'user'}, 'mode' => 'read' } },
      @rels)
    if $params->{'rel'};

  return ($rels[0], $obj);
}
sub api_read_rel_
{
  my ($rel) = shift->api_read_rel_w_parent(@_);
  return $rel;
}
sub api_read_rel
{
  my $class = shift;
  my $params = $_[0];
  return $class->api_read_rel_(@_)->ExportJsonObject($params->{'user'});
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
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' },
      'id' => $id) or
    die "TODO: Can't load ${class}[$id]";

  if ($data)
  {
    my $r;
    my $data_list = (ref($data) ne 'ARRAY') ? [ $data ] : $data;
    # TODO mode?
    $r = $obj->SaveRelationships(
        { $rel_name => { 'mode' => $mode, 'objs' => $data_list } },
        { ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' } })
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

  my ($rel_obj, $obj) = $class->api_read_rel_w_parent(
      { 'user' => $params->{'user'} }, $id, $rel_name, $rel_id) or
    die "TODO: Not related";

  $rel_obj = $rel_obj->ApiUpdate(
      {
        'user' => $params->{'user'},
        'parent' => $obj
      },
      $data);

  return $rel_obj->ExportJsonObject($params->{'user'});
}

# Access control:
#   read: n/a
#   write: checked (die, base), delegated (related)
#   create: n/a
sub api_remove_rel
{
  my ($class, $params, $id, $rel_name, $data) = @_;

  my $obj = $class->load(
      ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' },
      'id' => $id) or
    die "TODO: Can't load ${class}[$id]";

  if ($data)
  {
    my $data_list = (ref($data) ne 'ARRAY') ? [ $data ] : $data;
    # TODO mode?
    $obj->SaveRelationships(
        { $rel_name => { 'mode' => 'remove', 'objs' => $data_list } },
        { ':access' => { 'user' => $params->{'user'}, 'mode' => 'write' } })
      if @{$data_list};
  }

  return {};
}

# ---- Duplicate --------------------------------------------------------------

sub _duplicate
{
  my $class = shift;
  my $params = shift;
  my @objs;

  my $user = $params->{'user'};

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
      if ($dup_type eq 'recursive')
      {
        $rels->{$attr_name} = 'raw';
        push(@recursive, $attr_name);
      }
      elsif ($dup_type eq 'full')
      {
        $rels->{$attr_name} = 'json';
        push(@clear_ids, $attr_name);
      }
      else
      {
        $rels->{$attr_name} = $dup_type;
      }
    }
    @objs = $class->load_relationships(
        $rels, { ':access' => { 'user' => $user, 'mode' => 'read' } }, @_);

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
        $_->{$rel_name} = $rel_class->_duplicate($params, @{$_->{$rel_name}})
          if ($_->{$rel_name} && @{$_->{$rel_name}});
      }
    }
  }

  @objs = map { $_->ExportJsonObject($user) } @objs;
  $class->tweak_duplicate_json($params, $_)
    foreach (@objs);

  return @objs ? \@objs : undef;
}

sub api_duplicate_
{
  my ($class, $params, $id, $post_json) = @_;
  my $obj;

  my $copy = $class->_duplicate(
      $params,
      $class->api_read_(
          { 'user' => $params->{'user'} },
          $id))->[0];
  # warn "Duplicated object looks like this: " . Data::Dumper::Dumper($copy);

  $obj = $class->api_create_(
      { 'user' => $params->{'user'} },
      $copy);
  $obj->ApiUpdate(
      { 'user' => $params->{'user'} },
      $post_json)
    if ($post_json && %{$post_json});

  return $obj;
}

sub api_duplicate
{
  # my $class = shift;
  # my $obj = $class->api_duplicate_(@_);
  # return $obj->ExportJsonObject($_[0]->{'user'});
  return shift->api_duplicate_(@_)->ExportJsonObject($_[0]->{'user'});
}

# ==== testing ================================================================

sub _create_objs_helper
{
  my $class = shift;
  my $method = shift;
  my $params = shift;

  $params->{'user'} //= '+';

  my @ret = map { $class->$method($params, $_) } @_;
  return @ret if wantarray;
  return $ret[0];
}

sub create_objs_api_
{
  return shift->_create_objs_helper('api_create_', {}, @_);
}
sub create_objs_api { return map { $_->GetId() } shift->create_objs_api_(@_) }

sub import_objs_api_
{
  return shift->_create_objs_helper('api_import_', { 'import' => 1 }, @_);
}
sub import_objs_api { return map { $_->GetId() } shift->import_objs_api_(@_) }

sub create_objs_raw_
{
  my $class = shift;

  my @ret = map {
                  my ($obj, $rels);
                  $rels = $class->split_relationships($_);
                  $obj = $class->new($_);
                  $rels ?
                      $obj->SaveRelationships($rels) :
                      $obj->Save();
                  $obj
                } @_;

  return @ret if wantarray;
  return $ret[0];
}
sub create_objs_raw { return map { $_->GetId() } shift->create_objs_raw_(@_) }

sub create_objs_tweaked_
{
  my $class = shift;

  my @ret = map {
                  my ($obj, $rels);
                  $class->tweak_new_json({ 'user' => '+' }, $_);
                  $rels = $class->split_relationships($_);
                  $obj = $class->new($_);
                  $rels ?
                      $obj->SaveRelationships($rels) :
                      $obj->Save();
                  $obj
                } @_;

  return @ret if wantarray;
  return $ret[0];
}
sub create_objs_tweaked
{
  return map { $_->GetId() } shift->create_objs_tweaked_(@_);
}

# ==== Relationship + API =====================================================

sub _saverel_create
{
  my ($rel_class, $obj, $save_info, $save_rels) = @_;
  my $u = $save_info->{':access'}->{'user'} // '+';
  return map { $rel_class->api_create_({ 'user' => $u }, $_) } @{$save_rels};
}

sub _SaveHasMany_remove
{
  my ($obj, $save_info, $save_rels) = @_;

  my $u = $save_info->{':access'}->{'user'} // '+';
  my $ri = $save_info->{'rel_info'};
  my $rel_class = $ri->{'rel_class_name'};

  $rel_class->api_delete({ 'user' => $u }, ref($_) ? $_->GetId() : $_)
    foreach (@{$save_rels});

  return @{$save_rels};
}

##### SUCCESS #################################################################

1;

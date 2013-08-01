#! /usr/bin/perl
# This class is experimental. Work in progress. Hard hat area.
# Should play together nicely with access control.
# TODO: Docs, examples
##### NAMESPACE ###############################################################

package GungHo::Utils::_Relationships;

##### IMPORTS #################################################################

use strict;
use warnings;
use feature ':5.10';
# use mro;

# use parent 'GungHo::Trait::Persistence::MySQL::_Base';

use Scalar::Util qw( blessed );
use List::MoreUtils qw( all );

use GungHo::SQL::Utils qw( get_col_for_attr );

##### VARS ####################################################################

my %reltype =
    (
      'has_many' => [':children', ':all'],
      'belongs_to' => [':parents'],
      'many_to_many' => [':all']
    );

##### SUBS ####################################################################

sub _sclone_list { return $_[0] ? [@{$_[0]}] : undef }
sub _sclone_hash { return $_[0] ? {%{$_[0]}} : undef }

# delme
sub _dri
{
  my $x = {};
  foreach (keys(%{$_[0]}))
  {
    $x->{$_} = /rel(?:_?)info/ ? _dri($_[0]->{$_}) : $_[0]->{$_}
      unless (/meta/ || /attr/);
  }
  return $x;
}

# local $Data::Dumper::Sortkeys = 1;
# warn Data::Dumper::Dumper(_dri($_[1]->{'rel_info'}));

# ==== get_rel_info ===========================================================

# ---- _get_rel_info_simple ---------------------------------------------------

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

  my ($t, $ra);
  foreach my $type ('obj', 'rel')
  {
    $ra = $r{"${type}_relid_attr"} =
        $r{"${type}_meta_class"}->GetAttributeByName(
            $r{"${type}_relid_name"}) or
      die "TODO: Can't find $type relid attribute in $class.$rel_name";

    $t = $r{"${type}_class_name"};
    $r{"${type}_table_info"} = $t->get_sql_table_info()
      if $t->can('get_sql_table_info');

    foreach my $m ('get', 'set')
    {
      $r{"${type}_relid_$m"} =
          $ra->GetMethodName($m) //
          sub { die "TODO: No $m method for $type relid attribute " .
                    "in $class.$rel_name" };
    }
  }

  foreach my $m (qw( get set ))
  {
    $r{$m} = $attr->GetMethodName($m) //
        sub { die "TODO: No $m method for relationship $class.$rel_name" };
  }

  foreach my $type (qw( obj rel ))
  {
    $r{$ra} = $t
      if ($t = $attr->GetProperty($ra = "${type}_notify"));
  }

  foreach (qw( load save ))
  {
    $r{"rel_$_"} = $t if defined($t = $attr->GetProperty($_));
  }

  $r{'access_control'} = $attr->HasFlag('propagate_access') ? 'obj' : 'rel';

  return \%r;
}

# ---- _merge_relationships ---------------------------------------------------

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
        $new_key =~ s/^(?!rel_)/x_/;

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

# ---- get_rel_info -----------------------------------------------------------

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

# ==== load_relationships =====================================================

# ---- _relationships_to_load -------------------------------------------------

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

    $rel = $load_relationships_spec->{$rel_name};
    if (!$rel)
    {
      if ($reltype{$relationship})
      {
        foreach (@{$reltype{$relationship}})
        {
          last if ($rel = $load_relationships_spec->{$_});
        }
      }
      $rel //= $load_relationships_spec->{'*'};
    }

    if ($rel)
    {
      # load_relationship is going to sclone $rel
      $rel = { 'return' => $rel } unless ref($rel);
      $rel->{'load_relationships'} //=
          $load_relationships_spec->{"$rel_name:rel"};
      $relationships_to_load{$rel_name} = $rel
        if (($rel->{'return'} // 'none') ne 'none');
    }
  }

  return \%relationships_to_load;
}

# ---- _loadrel_output_mapper -------------------------------------------------

sub _loadrel_output_mapper
{
  my ($class, $load_spec) = @_;
  my $map_out;

  my $output = $load_spec->{'return'};
  if ($output eq 'id')
  {
    $map_out = sub { return $_[0]->GetId() };
  }
  elsif ($output eq 'json')
  {
    my $ac = $load_spec->{':access'};
    my $ac_user = defined($ac) ? (ref($ac) ? $ac->{'user'} : $ac) : undef;
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

# ---- _loadrel_load_rels -----------------------------------------------------

sub _loadrel_load_rels
{
  my ($class, $load_spec, $rel_class, $rel_ids) = @_;
  my @ret;

  my $ri = $load_spec->{'rel_info'};
  my @filters = ( $ri->{'rel_relid_name'} => $rel_ids );
  $rel_class //= $ri->{'rel_class_name'};

  push(@filters, ':access' => $load_spec->{':access'})
    if ($load_spec->{':access'} &&
        ($ri->{'access_control'} eq 'rel'));

  push(@filters, @{$load_spec->{'filter'}})
    if $load_spec->{'filter'};

  @ret = $rel_class->load(@filters);

  if (@ret && $load_spec->{'load_relationships'})
  {
    my $common_key =
        exists($load_spec->{'recursive_spec'}) ?
            'recursive_spec' :
            'common_spec';
    @ret = $rel_class->load_relationships(
        $load_spec->{'load_relationships'}, $load_spec->{$common_key}, @ret);
  }

  return @ret;
}

# ---- _load_relationship_belongs_to ------------------------------------------

# Technically this implements may_belong_to
sub _load_relationship_belongs_to
{
  my ($class, $load_spec, $obj_objs) = @_;

  my $ri = $load_spec->{'rel_info'};
  my $set = $ri->{'set'};
  my $obj_relid_get = $ri->{'obj_relid_get'};

  if (($load_spec->{'return'} eq 'id') && !$load_spec->{'filter'} &&
      ($ri->{'access_control'} eq 'obj'))
  {
    $_->$set($_->$obj_relid_get()) foreach (@{$obj_objs});
  }
  else
  {
    my $relid;

    my %relids;
    foreach (@{$obj_objs})
    {
      $relids{$relid} = 1
        if defined($relid = $_->$obj_relid_get());
    }

    my %rels;
    if (%relids)
    {
      my $rel_relid_get = $ri->{'rel_relid_get'};
      my $map_out = $class->_loadrel_output_mapper($load_spec);
      my @rels = $class->_loadrel_load_rels(
          $load_spec, undef, [keys(%relids)]);
      %rels = $map_out ?
          map { ( $_->$rel_relid_get() => $map_out->($_) ) } @rels :
          map { ( $_->$rel_relid_get() => $_ ) } @rels;
    }

    foreach (@{$obj_objs})
    {
      $_->$set($rels{$relid})
        if defined($relid = $_->$obj_relid_get());
    }
  }

  return @{$obj_objs};
}

# ---- _load_relationship_has_many --------------------------------------------

# TODO More efficient id only loading
sub _load_relationship_has_many
{
  my ($class, $load_spec, $obj_objs) = @_;

  my $ri = $load_spec->{'rel_info'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  my $rel_relid_get = $ri->{'rel_relid_get'};
  my $set = $ri->{'set'};
  my $relid;

  my %rels;
  foreach (@{$obj_objs})
  {
    $rels{$relid} = []
      if defined($relid = $_->$obj_relid_get());
  }

  if (%rels)
  {
    my @rels = $class->_loadrel_load_rels($load_spec, undef, [keys(%rels)]);
    my $map_out = $class->_loadrel_output_mapper($load_spec);
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

  foreach (@{$obj_objs})
  {
    $_->$set(_sclone_list($rels{$relid}))
      if defined($relid = $_->$obj_relid_get());
  }

  return @{$obj_objs};
}

# ---- _load_relationship_many_to_many ----------------------------------------

sub _load_relationship_many_to_many
{
  my ($class, $load_spec, $obj_objs) = @_;

  my $ri = $load_spec->{'rel_info'};
  my $obj_xobjid_get = $ri->{'obj_xobjid_get'};
  my $set = $ri->{'set'};
  my $relid;

  my %rels;
  foreach (@{$obj_objs})
  {
    $rels{$relid} = []
      if defined($relid = $_->$obj_xobjid_get());
  }

  if (%rels)
  {
    my $x_spec = { 'return' => 'raw', 'rel_info' => $ri->{'obj_x_relinfo'} };
    $x_spec->{'filter'} = $load_spec->{'x_filter'}
      if $load_spec->{'x_filter'};
    my @xs = $class->_loadrel_load_rels($x_spec, undef, [keys(%rels)]);

    $x_spec = _sclone_hash($load_spec);
    $x_spec->{'rel_info'} = $ri->{'x_rel_relinfo'};
    @xs = $ri->{'x_class_name'}->_load_relationship($x_spec, \@xs);

    my $t;
    my $x_xobjid_get = $ri->{'x_xobjid_get'};
    my $x_get = $ri->{'x_rel_relinfo'}->{'get'};
    foreach (@xs)
    {
      push(@{$rels{$_->$x_xobjid_get()}}, $t)
        if ($t = $_->$x_get());
    }
  }

  foreach (@{$obj_objs})
  {
    $_->$set(_sclone_list($rels{$relid}))
      if defined($relid = $_->$obj_xobjid_get());
  }

  return @{$obj_objs};
}

# ---- _load_relationship -----------------------------------------------------

sub _load_relationship
{
  my ($class, $load_spec, $obj_objs) = @_;

  my $ri = $load_spec->{'rel_info'};
  my $method = $ri->{'rel_load'} ||
      $class->can("_load_relationship_$ri->{'type'}") or
    die "TODO $class can't load $ri->{'type'} relationship ($ri->{'name'})";

  return $class->$method($load_spec, $obj_objs);
}

# ---- load_relationship ------------------------------------------------------

sub load_relationship
{
  my $class = shift;
  my $rel = shift;
  my $spec1 = shift;
  my $spec2 = shift;

  $rel = $class->get_rel_info($rel) unless ref($rel);
  $spec1 = { 'return' => $spec1 } unless ref($spec1);

  my $load_spec = _sclone_hash($spec1);
  $load_spec->{'rel_info'} = $rel;

  if (ref($spec2))
  {
    $load_spec->{$_} = $spec2->{$_}
      foreach (grep { !exists($load_spec->{$_}) } keys(%{$spec2}));
  }
  else
  {
    $load_spec->{'return'} //= $spec2 // 'raw';
  }
  $load_spec->{'common_spec'} //= $spec2 if $spec2;

  return $class->_load_relationship($load_spec, \@_);
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
  my $rels = shift;
  my $common = shift;
  # my @objs = @_;

  if ($rels && %{$rels} && @_)
  {
    my $load_rels = $class->_relationships_to_load($rels);
    $class->load_relationship($_, $load_rels->{$_}, $common, @_)
      foreach (keys(%{$load_rels}));
  }

  return @_;
}

# ==== SaveRelationships ======================================================

sub _saverel_remap_changed
{
  my ($class, $save_info, $objs, $remap) = @_;
  my $rel_name = $save_info->{'rel_info'}->{'name'};
  my @remapped;

  foreach (@{$objs})
  {
    if (ref($_))
    {
      push(@remapped, $_);
    }
    elsif (defined($_))
    {
      die "TODO Object appeared from thin air at $class.$rel_name"
        unless defined($remap->{$_});
      push(@remapped, $remap->{$_});
    }
    else
    {
      die "TODO Something is wrong";
    }
  }

  return \@remapped;
}

sub _saverel_changed
{
  my ($class, $save_info, $op, $objs, $remap) = @_;

  my $rel_name = $save_info->{'rel_info'}->{'name'};
  my $chg = $save_info->{'ret'}->{':changed'}->{$rel_name} //= {};

  $objs = $class->_saverel_remap_changed(
      $save_info, $objs, $remap)
    if $remap;

  if ($chg->{$op})
  {
    push(@{$chg->{$op}}, @{$objs});
  }
  else
  {
    $chg->{$op} = [@{$objs}];
  }

  return $chg;
}

sub _saverel_create
{
  my ($rel_class, $obj, $save_info, $save_rels) = @_;
  my @new;

  my $ri = $save_info->{'rel_info'};
  $rel_class->check_access(
      $save_info->{':access'}->{'user'}, 'c', @{$save_rels})
    if (defined($save_info->{':access'}) &&
        ($ri->{'access_control'} eq 'rel') &&
        $rel_class->can('check_access'));

  my $t;
  foreach (@{$save_rels})
  {
    push(@new, $t = $rel_class->new($_));
    $t->Save();
  }

  return @new;
}

# ==== _SaveRelationship_belongs_to -------------------------------------------

# TODO: AC check?
sub _SaveRelationship_belongs_to
{
  my ($obj, $save_info, $save_rels) = @_;
  return 0 unless $save_info->{'pre'};

  my $class = ref($obj);
  my $ri = $save_info->{'rel_info'};
  my $rel_name = $ri->{'name'};

  my ($new_ret, $new_relid, $new_obj);
  my $old_relid = $obj->($ri->{'obj_relid_get'})();
  {
    $new_ret = $save_rels;
    if (ref($new_ret) eq 'ARRAY')
    {
      die "TODO Too many objects in $class.$rel_name"
        if (scalar(@{$new_ret}) > 1);
      $new_ret = $new_ret->[0];
    }

    if (ref($new_ret))
    {
      die "TODO Trying to create parent through $class.$rel_name"
        unless blessed($new_ret);
      $new_relid = $new_ret->($ri->{'rel_relid_get'})();
      $new_obj = $new_ret;
    }
    else
    {
      $new_relid = $new_ret;
    }
  }

  my $nop;
  given ($save_info->{'mode'})
  {
    when ('add')
    {
      die "TODO Trying to add second parent in $class.$rel_name"
        if (defined($old_relid) && defined($new_relid) &&
            ($old_relid ne $new_relid));
      $nop = 1 unless defined($new_relid);
    }
    when ('replace')
    {
      # TODO Optional parent
      die "TODO Trying to remove parent in $class.$rel_name with replace"
        unless defined($new_relid);
      $nop = 1 if (defined($old_relid) && ($new_relid eq $old_relid));
    }
    when ('remove')
    {
      # TODO Optional parent
      # TODO Remove from unrelated parent?
      die "TODO Trying to remove parent in $class.$rel_name";
    }
    default
    {
      die "TODO Unknown save mode '$save_info->{'mode'}'"
    }
  }

  if (!$nop)
  {
    my $get = $ri->{'get'};
    my $set = $ri->{'set'};
    my $obj_relid_set = $ri->{'obj_relid_set'};

    my $old_obj = $obj->$get();

    $obj->$obj_relid_set($new_relid);
    # $obj->$set($new_obj);
    $obj->$set(undef);

    my $chg = $save_info->{'ret'}->{':changed'}->{$rel_name} = {};

    $chg->{':added'} = [ $new_ret ]
      if defined($new_relid);

    if (defined($old_relid))
    {
      $chg->{':removed_from'} = { $old_relid => $obj };
      $chg->{':removed'} = [ $old_obj // $old_relid ];
    }

    $chg->{':current'} = defined($new_relid) ? [ $new_ret ] : [];

    $save_info->{'ret'}->{$rel_name} = [ @{$chg->{':current'}} ];
  }

  return 1;
}

# ==== _SaveRelationship_has_many ---------------------------------------------

# ---- _SaveHasMany_create ----------------------------------------------------

sub _SaveHasMany_create
{
  my ($obj, $save_info, $save_rels) = @_;

  my $ri = $save_info->{'rel_info'};
  my $rel_class = $ri->{'rel_class_name'};
  my $rel_relid_name = $ri->{'rel_relid_name'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  my $obj_relid = $obj->$obj_relid_get();

  $_->{$rel_relid_name} = $obj_relid
    foreach (@{$save_rels});

  return $rel_class->_saverel_create(@_);
}

# ---- _SaveHasMany_update ----------------------------------------------------

sub _SaveHasMany_update
{
  my ($obj, $save_info, $save_rels) = @_;

  my $ri = $save_info->{'rel_info'};
  my $rel_class = $ri->{'rel_class_name'};
  my $rel_relid_set = $ri->{'rel_relid_set'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  my $obj_relid = $obj->$obj_relid_get();

  $rel_class->check_access(
      $save_info->{':access'}->{'user'}, 'w', @{$save_rels})
    if (defined($save_info->{':access'}) &&
        ($ri->{'access_control'} eq 'rel') &&
        $rel_class->can('check_access'));

  foreach (@{$save_rels})
  {
    $_->$rel_relid_set($obj_relid);
    $_->Save();
  }

  return @{$save_rels};
}

sub _SaveHasMany_update_
{
  my ($obj, $save_info, $to_update, @_rest) = @_;
  my $class = ref($obj);
  my @updated;

  my @ids;
  my @objs;
  ref($_) ? push(@objs, $_) : push(@ids, $_)
    foreach (@{$to_update});

  my $ri = $save_info->{'rel_info'};
  my $rel_name = $ri->{'name'};

  my $rel_class = $ri->{'rel_class_name'};
  my $rel_relid_name = $ri->{'rel_relid_name'};
  push(@objs, $rel_class->load($rel_relid_name => \@ids))
    if @ids;

  my $rel_relid_get = $ri->{'rel_relid_get'};
  my %removed_from =
      map { ($_->GetId() => $_->$rel_relid_get()) }
          @objs;

  @updated = $obj->_SaveHasMany_update_($save_info, \@objs, @_rest);

  my $chg = $obj->_saverel_changed($save_info, ':added', \@updated);

  my $rel_id;
  my $removed_from = $chg->{':removed_from'} //= {};
  foreach (@updated)
  {
    $rel_id = ref($_) ? $_->$rel_relid_get() : $_;
    die "TODO A rel object appeared from thin air at $class.$rel_name"
      unless defined($removed_from{$rel_id});
    $removed_from->{$rel_id} = $removed_from{$rel_id};
  }

  return @updated;
}

# ---- _SaveHasMany_remove ----------------------------------------------------

# TODO Optional parents
sub _SaveHasMany_remove
{
  my ($obj, $save_info, $save_rels) = @_;

  my $ri = $save_info->{'rel_info'};
  my $rel_class = $ri->{'rel_class_name'};
  $rel_class->check_access(
      $save_info->{':access'}->{'user'}, 'w', @_)
    if (defined($save_info->{':access'}) &&
        ($ri->{'access_control'} eq 'rel') &&
        $rel_class->can('check_access'));

  my $rel_relid = $ri->{'rel_relid_name'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  $rel_class->destroy(
      'id' => [ map { ref($_) ? $_->GetId() : $_ } @{$save_rels} ],
      $rel_relid => $obj->$obj_relid_get());

  # BUG: This may list items, that never were part of this relationship.
  return @{$save_rels};
}

# ---- _SaveRelationship_has_many ---------------------------------------------

sub _SaveRelationship_has_many
{
  my ($obj, $save_info, $save_rels) = @_;
  return 0 unless $save_info->{'post'};

  my $ri = $save_info->{'rel_info'};
  my $rel_name = $ri->{'name'};
  my $class = ref($obj);

  # NOP check
  my $mode = $save_info->{'mode'};
  return 0 if (($mode ~~ ['add', 'remove']) && !@{$save_rels});

  my @arg_rel_ids;
  my @arg_rel_objs;
  my @create_rel_objs;
  foreach (@{$save_rels})
  {
    if (ref($_))
    {
      if (blessed($_))
      {
        push(@arg_rel_objs, $_);
      }
      else
      {
        push(@create_rel_objs, $_);
      }
    }
    elsif (defined($_))
    {
      push(@arg_rel_ids, $_)
    }
    else
    {
      die "Undefined value in relationship $class.$rel_name";
    }
  }

  my $current;
  if ($mode eq 'remove')
  {
    die "TODO Object create in remove in $class.$rel_name"
      if @create_rel_objs;

    $obj->_saverel_changed(
        $save_info, ':removed',
        [$obj->_SaveHasMany_remove(
            $save_info, [@arg_rel_ids, @arg_rel_objs])]);
  }
  else
  {
    my $rel_class = $ri->{'rel_class_name'};
    my $rel_relid_name = $ri->{'rel_relid_name'};
    my $rel_relid_get = $ri->{'rel_relid_get'};
    my $obj_relid_get = $ri->{'obj_relid_get'};
    my $obj_relid = $obj->$obj_relid_get();

    # TODO load_relationship?
    # No access control here. Access is controlled where writing.
    # TODO This may lead to some leak by not dying on nop
    my %old_rels_by_id;
    %old_rels_by_id =
        map { ($_->GetId() => $_) }
            $rel_class->load($rel_relid_name => $obj_relid)
      if (($mode eq 'replace') || @arg_rel_ids);

    my %new_rels_by_id;
    $new_rels_by_id{$_} = $_ foreach (@arg_rel_ids);
    $new_rels_by_id{$_->GetId()} = $_ foreach (@arg_rel_objs);

    my %cur_rels_by_id = %old_rels_by_id;

    if ($mode eq 'replace')
    {
      my @remove_rels =
          grep { !exists($new_rels_by_id{$_}) } keys(%old_rels_by_id);
      if (@remove_rels)
      {
        my @removed = $obj->_SaveHasMany_remove(
            $save_info, [@old_rels_by_id{@remove_rels}]);

        $obj->_saverel_changed($save_info, ':removed', \@removed);

        delete($cur_rels_by_id{ref($_) ? $_->GetId() : $_})
          foreach (@removed);
      }
    }

    my $t;
    my $not_obj_relid = "!$obj_relid";
    my @update_ids =
        grep { !$old_rels_by_id{$_} ||
               (ref($t = $new_rels_by_id{$_}) &&
                (($t->$rel_relid_get() // $not_obj_relid) eq $obj_relid)) }
            keys(%new_rels_by_id);
    if (@update_ids)
    {
      # \@hash{@keys} === map { \$hash{$_} } @keys
      my @to_update = @new_rels_by_id{@update_ids};
      $cur_rels_by_id{ref($_) ? $_->GetId() : $_} = $_
        foreach ($obj->_SaveHasMany_update_($save_info, \@to_update));
    }

    if (@create_rel_objs)
    {
      my @new_rels = $obj->_SaveHasMany_create(
          $save_info, \@create_rel_objs);
      $obj->_saverel_changed($save_info, ':added', \@new_rels);

      my $id;
      foreach (@new_rels)
      {
        $id = ref($_) ? $_->GetId() : $_;
        $new_rels_by_id{$id} = $_;
        $cur_rels_by_id{$id} = $_
      }
    }

    my $chg = $save_info->{'ret'}->{':changed'}->{$rel_name} //= {};
    $current = $chg->{':current'} = [values(%cur_rels_by_id)];

    $save_info->{'ret'}->{$rel_name} = @arg_rel_ids ?
        [ keys(%new_rels_by_id) ] :
        [ values(%new_rels_by_id) ];
  }

  my $set = $ri->{'set'};
  # $obj->$set(
  #     ($current && ((all { !ref } @{$current}) ||
  #                   (all { ref } @{$current}))) ?
  #         [@{$current}] :
  #         undef);
  $obj->$set(undef);

  return 1;
}

# ==== _SaveRelationship_many_to_many -----------------------------------------

# ---- _saverel_x_create ------------------------------------------------------

sub _saverel_x_create
{
  # my ($x_class, $save_obj, $save_info, $save_rels) = @_;
  shift;
  return $_[1]->{'rel_info'}->{'rel_class_name'}->_saverel_create(@_);
}

# ---- _saverel_x_newrel ------------------------------------------------------

# TODO Access control?
sub _saverel_x_newrel
{
  my ($x_class, $save_obj, $save_info, $save_rels) = @_;
  my @new_xs;

  my $t;
  my $ri = $save_info->{'rel_info'};
  my $x_xrelid = $ri->{'x_xrelid_name'};
  my $x_xobjid = $ri->{'x_xobjid_name'};
  my $obj_xobjid_get = $ri->{'obj_xobjid_get'};
  my $obj_xobjid = $save_obj->$obj_xobjid_get();
  foreach (@{$save_rels})
  {
    push(@new_xs,
        $t = $x_class->new($x_xobjid => $obj_xobjid, $x_xrelid => $_));
    $t->Save();
  }

  return @new_xs;
}

# ---- _saverel_x_removerel ---------------------------------------------------

# TODO Access control
sub _saverel_x_removerel
{
  my ($x_class, $save_obj, $save_info, $save_rels) = @_;

  my $ri = $save_info->{'rel_info'};
  my $x_xrelid = $ri->{'x_xrelid_name'};
  my $x_xobjid = $ri->{'x_xobjid_name'};
  my $obj_xobjid_get = $ri->{'obj_xobjid_get'};

  my $obj_xobjid = $save_obj->$obj_xobjid_get();
  $x_class->destroy(
      $x_xobjid => $save_obj->$obj_xobjid_get(),
      $x_xrelid => $save_rels);

  # BUG: This may list items, that never were part of this relationship.
  return @{$save_rels};
}

# ---- _saverel_x -------------------------------------------------------------

sub _saverel_x
{
  my ($x_class, $save_obj, $save_info, $save_rels) = @_;
  return 0 unless $save_info->{'post'};

  # NOP check
  my $mode = $save_info->{'mode'};
  return 0 if (($mode ~~ ['add', 'remove']) && !@{$save_rels});

  # TODO relid vs rel_id
  my $ri = $save_info->{'rel_info'};
  my $obj_class = $ri->{'obj_class_name'};
  my $rel_name = $ri->{'name'};
  my $rel_xrelid_get = $ri->{'rel_xrelid_get'};
  die "TODO relid != rel_id in $obj_class.$rel_name"
    unless ($ri->{'rel_xrelid_name'} eq 'id');

  my $return_ids;
  my @create_rel_objs;
  my %new_rels_by_xrelid;
  foreach (@{$save_rels})
  {
    if (ref($_))
    {
      if (blessed($_))
      {
        $new_rels_by_xrelid{$_->$rel_xrelid_get()} = $_;
      }
      else
      {
        push(@create_rel_objs, $_);
      }
    }
    elsif (defined($_))
    {
      $new_rels_by_xrelid{$_} = $_;
      $return_ids = 1;
    }
    else
    {
      die "Undefined value in relationship $obj_class.$rel_name";
    }
  }

  my $current;
  if ($mode eq 'remove')
  {
    die "TODO Object create in remove in $obj_class.$rel_name"
      if @create_rel_objs;

    my @removed = $x_class->_saverel_x_removerel(
        $save_obj, $save_info, [keys(%new_rels_by_xrelid)]);
    $x_class->_saverel_changed(
        $save_info, ':removed', \@removed, \%new_rels_by_xrelid);
  }
  else
  {
    my $x_xobjid_name = $ri->{'x_xobjid_name'};
    my $x_xrelid_get = $ri->{'x_xrelid_get'};
    my $obj_xobjid_get = $ri->{'obj_xobjid_get'};
    my $obj_xobjid = $save_obj->$obj_xobjid_get();

    # TODO load_relationship?
    # No access control here. Access is controlled where writing.
    # TODO This may lead to some leak by not dying on nop
    my %old_xrelids;
    %old_xrelids =
        map { ($_->$x_xrelid_get() => $_->GetId()) }
            $x_class->load($x_xobjid_name => $obj_xobjid)
      if (($mode eq 'replace') || %new_rels_by_xrelid);

    my %cur_xrelids = %old_xrelids;

    if (@create_rel_objs)
    {
      $new_rels_by_xrelid{$_->$rel_xrelid_get()} = $_
        foreach ($x_class->_saverel_x_create(
                     $save_obj, $save_info, \@create_rel_objs));
    }

    if ($mode eq 'replace')
    {
      my @remove_xrelids =
          grep { !exists($new_rels_by_xrelid{$_}) } keys(%old_xrelids);
      if (@remove_xrelids)
      {
        my @removed = $x_class->_saverel_x_removerel(
            $save_obj, $save_info, \@remove_xrelids);
        $x_class->_saverel_changed(
            $save_info, ':removed', \@removed);
        # TODO Returned rels, xs
        delete($cur_xrelids{$_}) foreach (@removed);
      }
    }

    my @new_xrelids =
        grep { !exists($old_xrelids{$_}) } keys(%new_rels_by_xrelid);
    if (@new_xrelids)
    {
      my @new_xs = $x_class->_saverel_x_newrel(
          $save_obj, $save_info, \@new_xrelids);
      $x_class->_saverel_changed(
          $save_info, ':added',
          [ map { $_->$x_xrelid_get() } @new_xs ],
          \%new_rels_by_xrelid);
      $cur_xrelids{$_->$x_xrelid_get()} = 1 foreach (@new_xs);
    }

    $current =
        [ map { $new_rels_by_xrelid{$_} // $_ } keys(%cur_xrelids) ];
    my $chg = $save_info->{'ret'}->{':changed'}->{$rel_name} //= {};
    $chg->{':current'} = [@{$current}];

    $save_info->{'ret'}->{$rel_name} = $return_ids ?
       [ keys(%new_rels_by_xrelid) ] :
       [ values(%new_rels_by_xrelid) ];
  }

  my $set = $ri->{'set'};
  # $save_obj->$set(
  #     ($current && ((all { !ref } @{$current}) ||
  #                   (all { ref } @{$current}))) ?
  #         [@{$current}] :
  #         undef);
  $save_obj->$set(undef);

  return 1;
}

# ---- _SaveRelationship_many_to_many -----------------------------------------

sub _SaveRelationship_many_to_many
{
  # my ($obj, $save_info, $save_rels) = @_;
  return $_[1]->{'rel_info'}->{'x_class_name'}->_saverel_x(@_);
}

# ==== SaveRelationships ------------------------------------------------------

# ---- _SaveRelationship ------------------------------------------------------

sub _SaveRelationship
{
  my ($obj, $ri, $pre_post, $save, $common, $ret) = @_;
  my $class = ref($obj);

  my $method = $ri->{'rel_save'} ||
      $obj->can("_SaveRelationship_$ri->{'type'}") or
    die "TODO $class can't save $ri->{'type'} relationship ($ri->{'name'})";

  my $args =
      {
        'rel_info' => $ri,
        'ret' => $ret,
        'mode' => $save->{'mode'},
        'pp' => $pre_post,
        $pre_post => 1
      };
  if ($common)
  {
    $args->{$_} = $common->{$_}
      foreach (grep { !exists($args->{$_}) } keys(%{$common}));
  }

  return $obj->$method($args, $save->{'objs'});
}

# ---- SaveRelationships ------------------------------------------------------

# Access control:
#   base object should be checked beforehand
#   read: n/a
#   write: implied (base), delegated (related)
#   create: n/a (base), delegated (related)
sub SaveRelationships
{
  my ($obj, $rels, $common) = @_;
  my $ret = {};

  if ($rels && %{$rels})
  {
    my $class = ref($obj);
    my %ri = map { ($_ => $class->get_rel_info($_)) } keys(%{$rels});

    # ($obj, $ri, $pre_post, $ret, $ac_user, $save)
    $obj->_SaveRelationship($ri{$_}, 'pre', $rels->{$_}, $common, $ret)
      foreach (keys(%ri));
    $obj->Save() unless ($common && $common->{'dont_save_base'});
    $obj->_SaveRelationship($ri{$_}, 'post', $rels->{$_}, $common, $ret)
      foreach (keys(%ri));

    my ($ri, $chg, $m, $rel_class);
    foreach (keys(%ri))
    {
      $ri = $ri{$_};
      $chg = $ret->{':changed'}->{$_};

      $obj->$m($chg->{'obj'})
        if ($chg->{'obj'} &&
            ($m = $ri->{'obj_notify'}) &&
            ($m = $obj->can($m)));

      $rel_class = $ri->{'rel_class_name'};
      $rel_class->$m($chg->{'rel'})
        if ($chg->{'rel'} &&
            ($m = $ri->{'rel_notify'}) &&
            ($m = $rel_class->can($m)));
    }
  }

  return $ret;
}

# ==== split_relationships ====================================================

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

# ==== load extensions ========================================================
# TODO This is not very efficient. Neither at the Perl nor at the SQL level.

sub __where_helper
{
  my ($sql,
      $obj_relid_col,
      $rel_class_name, $rel_relid_name,
      $rel_id_name, $rel_ids) = @_;

  my ($sub_load, $sub_sql, @sub_params);
  foreach my $rel_id (@{$rel_ids})
  {
    $sub_load = $rel_class_name->load_sql(
        $rel_relid_name => GungHo::SQL::Query->literal($obj_relid_col),
        $rel_id_name => $rel_id);
    ($sub_sql, @sub_params) = $sub_load->Build();
    $sql->AddWhere("EXISTS ($sub_sql)", @sub_params);
  }
}

# TODO This depends on __PACKAGE__ being ahead of MySQL::_Base (or whatever)
#      in the linearized ISA path of the class using next::method, which is
#      just one step short of using SUPER that would depend on being a
#      subclass of MySQL::_Base. Not very elegant.
sub _load_sql_builder_param
{
  my $class = shift;
  my ($sql, $table_alias, $table_info, $dumpster, $n, $v) = @_;
  my $ret;

  my $meta_class = $class->get_meta_class();
  my $attr = $meta_class && $meta_class->GetAttributeByName($n);
  my $rel = $attr && $attr->GetProperty('relationship');

  if ($rel)
  {
    my @rels;
    if (!ref($v))
    {
      @rels = ($v);
    }
    elsif (ref($v) eq 'ARRAY')
    {
      @rels = @{$v};
    }
    else
    {
      die 'TODO';
    }

    if (@rels)
    {
      # TODO AC?
      my $ri = $class->get_rel_info($n);
      if ($rel eq 'belongs_to')
      {
        die "TODO More than one relid in belongs_to filter $class.$n"
          if $#rels;
        my @where = build_where_clause(
            get_col_for_attr(
                $table_info, $ri->{'obj_relid_name'}, $table_alias),
            \@rels);
        $sql->AddWhere(@where) if @where;
      }
      elsif ($rel eq 'has_many')
      {
        __where_helper(
            $sql,
            get_col_for_attr(
                $table_info, $ri->{'obj_relid_name'}, $table_alias),
            $ri->{'rel_class_name'}, $ri->{'rel_relid_name'},
            'id', \@rels);
      }
      elsif ($rel eq 'many_to_many')
      {
        __where_helper(
            $sql,
            get_col_for_attr(
                $table_info, $ri->{'obj_xobjid_name'}, $table_alias),
            $ri->{'x_class_name'}, $ri->{'x_xobjid_name'},
            $ri->{'x_xrelid_name'}, \@rels);
      }
      else
      {
        die 'TODO';
      }
    }

    $ret = 1;
  }

  $ret = $class->next::method(@_)
    unless $ret;

  return $ret;
}

# ==== _FilterSort extensions =================================================

# No error checking here. Load will complain.
sub _map_to_rel_filter
{
  my ($class, $n, $v, $attr) = @_;
  my @ret;

  if ($v =~ /^rel:/)
  {
    my @rels = split(',', substr($v, 4));
    @ret = ( $n => \@rels ) if @rels;
  }
  else
  {
    die "TODO Can't parse filter spec '$v' for $class.$n";
  }

  return @ret;
}

##### SUCCESS #################################################################

1;

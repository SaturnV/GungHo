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

# use parent 'GungHo::Trait::Persistence::MySQL::_Base';

use Scalar::Util qw( blessed );

##### VARS ####################################################################

my %reltype =
    (
      'has_many' => ':children',
      'belongs_to' => ':parents'
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
    $x->{$_} = /relinfo/ ? _dri($_[0]->{$_}) : $_[0]->{$_}
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

  my $t;
  foreach my $type ('obj', 'rel')
  {
    $r{"${type}_relid_attr"} =
        $r{"${type}_meta_class"}->GetAttributeByName(
            $r{"${type}_relid_name"}) or
      die "TODO: Can't find $type relid attribute in $class.$rel_name";

    $t = $r{"${type}_class_name"};
    $r{"${type}_table_info"} = $t->get_sql_table_info()
      if $t->can('get_sql_table_info');

    foreach ('get', 'set')
    {
      $r{"${type}_relid_$_"} =
          $r{"${type}_relid_attr"}->GetMethodName($_) //
          sub { die "TODO: No $_ method for $type relid attribute " .
                    "in $class.$rel_name" };
    }
  }

  foreach (qw( get set ))
  {
    $r{$_} = $attr->GetMethodName($_) //
        sub { die "TODO: No $_ method for relationship $class.$rel_name" };
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

    $rel = $load_relationships_spec->{$rel_name} ||
        $load_relationships_spec->{$reltype{$relationship} || ':others'} ||
        $load_relationships_spec->{'*'};
    if ($rel)
    {
      # load_relationship is going to sclone $rel
      $rel = { 'return' => $rel } unless ref($rel);
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
  my ($class, $load_spec, $rel_ids) = @_;

  my $ri = $load_spec->{'rel_info'};
  my @filters = ( $ri->{'rel_relid_name'} => $rel_ids );

  push(@filters, ':access' => $load_spec->{':access'})
    if ($load_spec->{':access'} &&
        ($ri->{'access_control'} eq 'rel'));

  push(@filters, @{$load_spec->{'filter'}})
    if $load_spec->{'filter'};

  return $ri->{'rel_class_name'}->load(@filters);
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
      my @rels = $class->_loadrel_load_rels($load_spec, [keys(%relids)]);
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
    my @rels = $class->_loadrel_load_rels($load_spec, [keys(%rels)]);
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
    my @xs = $class->_loadrel_load_rels($x_spec, [keys(%rels)]);

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

  # return $class->$method($load_spec, $obj_objs);
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
  my $rel_name = $ri->{'rel_name'};

  my $get = $ri->{'get'};
  my $old = $obj->$get();
  my $new = $save_rels;
  if (ref($new) eq 'ARRAY')
  {
    die "TODO Too many objects in $class.$rel_name"
      if (scalar(@{$new}) > 1);
    $new = $new->[0];
  }
  if (ref($new))
  {
    my $rel_relid_get = $ri->{'rel_relid_get'};
    $new = $new->$rel_relid_get();
  }

  given ($save_info->{'mode'})
  {
    when ('add')
    {
      die "TODO Trying to add second parent in $class.$rel_name"
        if (defined($old) && defined($new) &&
            ($old ne $new));
    }
    when ('replace')
    {
      die "TODO Trying to remove parent in $class.$rel_name with replace"
        unless defined($new);
    }
    when ('remove')
    {
      die "TODO Trying to remove parent in $class.$rel_name";
    }
    default
    {
      die "TODO Unknown save mode '$save_info->{'mode'}'"
    }
  }

  if (defined($new))
  {
    if (!defined($old) || ($old ne $new))
    {
      # TODO change notify
      my $obj_relid_set = $ri->{'obj_relid_set'};
      $obj->$obj_relid_set($new);
    }
  }

  return 1;
}

# ==== _SaveRelationship_has_many ---------------------------------------------

# ---- _SaveHasMany_create ----------------------------------------------------

# TODO change notify
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

# TODO change notify
sub _SaveHasMany_update
{
  my ($obj, $save_info, $save_rels) = @_;

  my @ids;
  my @objs;
  ref($_) ? push(@objs, $_) : push(@ids, $_)
    foreach (@{$save_rels});

  my $ri = $save_info->{'rel_info'};
  my $rel_class = $ri->{'rel_class_name'};
  my $rel_relid_name = $ri->{'rel_relid_name'};
  push(@objs, $rel_class->load($rel_relid_name => \@ids))
    if @ids;

  $rel_class->check_access(
      $save_info->{':access'}->{'user'}, 'w', @objs)
    if (defined($save_info->{':access'}) &&
        ($ri->{'access_control'} eq 'rel') &&
        $rel_class->can('check_access'));

  my $rel_relid_set = $ri->{'rel_relid_set'};
  my $obj_relid_get = $ri->{'obj_relid_get'};
  my $obj_relid = $obj->$obj_relid_get();
  foreach (@objs)
  {
    $_->$rel_relid_set($obj_relid);
    $_->Save();
  }
}

# ---- _SaveHasMany_remove ----------------------------------------------------

# TODO change notify
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

  $rel_class->destroy(
      'id' => [ map { ref($_) ? $_->GetId() : $_ } @{$save_rels} ] );
}

# ---- _SaveRelationship_has_many ---------------------------------------------

sub _SaveRelationship_has_many
{
  my ($obj, $save_info, $save_rels) = @_;
  return 0 unless $save_info->{'post'};

  # NOP check
  my $mode = $save_info->{'mode'};
  return 0 if (($mode ~~ ['add', 'remove']) && !@{$save_rels});

  my @arg_rel_ids;
  my @arg_rel_objs;
  my @create_rel_objs;
  ref($_) ?
      (blessed($_) ? push(@arg_rel_objs, $_) : push(@create_rel_objs, $_)) :
      push(@arg_rel_ids, $_)
    foreach (@{$save_rels});

  my $ri = $save_info->{'rel_info'};
  if ($mode eq 'remove')
  {
    if (@create_rel_objs)
    {
      my $class = ref($obj);
      my $rel_name = $ri->{'name'};
      die "TODO Object create in remove in $class.$rel_name";
    }

    $obj->_SaveHasMany_remove($save_info, [@arg_rel_ids, @arg_rel_objs]);
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

    if ($mode eq 'replace')
    {
      my @remove_rels =
          grep { !exists($new_rels_by_id{$_}) } keys(%old_rels_by_id);
      $obj->_SaveHasMany_remove($save_info, \@remove_rels)
        if @remove_rels;
    }

    my $t;
    my $not_obj_relid = "!$obj_relid";
    my @update_ids =
        grep { !$old_rels_by_id{$_} ||
               (ref($t = $new_rels_by_id{$_}) &&
                (($t->$rel_relid_get() // $not_obj_relid) eq $obj_relid)) }
            keys(%new_rels_by_id);
    # \@hash{@keys} === map { \$hash{$_} } @keys
    $obj->_SaveHasMany_update(
        $save_info, [@new_rels_by_id{@update_ids}])
      if @update_ids;

    $obj->_SaveHasMany_create($save_info, \@create_rel_objs)
      if @create_rel_objs;
  }

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

  my @arg_rel_ids;
  my @create_rel_objs;
  ref($_) ?
      (blessed($_) ?
          push(@arg_rel_ids, $_->$rel_xrelid_get()) :
          push(@create_rel_objs, $_)) :
      push(@arg_rel_ids, $_)
    foreach (@{$save_rels});

  if ($mode eq 'remove')
  {
    die "TODO Object create in remove in $obj_class.$rel_name"
      if @create_rel_objs;
    $x_class->_saverel_x_removerel($save_obj, $save_info, \@arg_rel_ids);
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
      if (($mode eq 'replace') || @arg_rel_ids);

    push(@arg_rel_ids,
        map { $_->$rel_xrelid_get() }
            $x_class->_saverel_x_create(
                $save_obj, $save_info, \@create_rel_objs))
      if @create_rel_objs;

    my %new_xrelids = map { ($_ => 1) } @arg_rel_ids;

    if ($mode eq 'replace')
    {
      my @remove_xrelids = grep { !$new_xrelids{$_} } keys(%old_xrelids);
      # \@hash{@keys} === map { \$hash{$_} } @keys
      $x_class->_saverel_x_removerel(
          $save_obj, $save_info, [@old_xrelids{@remove_xrelids}])
        if @remove_xrelids;
    }

    my @new_xrelids = grep { !$old_xrelids{$_} } keys(%new_xrelids);
    $x_class->_saverel_x_newrel(
        $save_obj, $save_info, \@new_xrelids)
      if @new_xrelids;
  }

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

##### SUCCESS #################################################################

1;

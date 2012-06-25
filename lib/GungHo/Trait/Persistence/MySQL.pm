#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Trait::Persistence::MySQL;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base GungHo::_Builder );

use Scalar::Util;

use GungHo::Trait::Persistence::MySQL::GrepParser qw( parse_grep );
use GungHo::Names qw( :CG_HOOK_ARGS );

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# ==== Hash Keys ==============================================================

our $HK_args = 'args';
our $HK_parent = 'parent';
our $HK_sql_vars = 'sql_vars';
our $HK_method_specs = 'method_specs';

# ==== Method Types ===========================================================

our @MethodTypes =
    qw( load_by_id load_all save destroy_by_id destroy_object );

our %MethodNames =
    (
      # 'method_type' => [qw( reported_name generated_name )]
      # 'method_type' => 'name'
      'load_by_id' => 'load',
      'load_all' => 'load_all',
      'save' => 'Save',
      'destroy_by_id' => 'destroy',
      'destroy_object' => 'Destroy'
    );

# ==== Code Templates =========================================================

my $ctpl_return_s = <<__END__;
  return #{return_e}#;
__END__

# ---- load -------------------------------------------------------------------

my $ctpl_load_by_id_args = <<__END__;
  #{create_sv_x(class)}#
  #{define_x(ids_av,_)}#
  my \$#{class_sv}# = shift;

  die "TODO: load what?" unless \@#{ids_av}#;
  die "TODO: something is wrong" if (\$##{ids_av}# && !wantarray);
__END__

my $ctpl_load_custom_args = <<__END__;
  #{create_sv_x(class)}#
  #{define_x(args_av,_)}#
  my \$#{class_sv}# = shift;
__END__

my $ctpl_load_by_id_execute = <<__END__;
  #{create_sv_x(sth)}#
  my \$#{sth_sv}#;
  if (\$##{ids_av}#)
  {
    my \$qms = join(', ', ('?') x scalar(\@#{ids_av}#));
    \$#{sth_sv}# = #{persistence.dbh_e}#->prepare(
        "#{sql.select_header_str}# WHERE #{sql.id_col_str}# IN (\$qms)") or
      die "TODO: Prepare (\$#{class_sv}#/load_by_id/multiple) failed";
  }
  else
  {
    state \$sth_single = #{persistence.dbh_e}#->prepare(
        "#{sql.select_header_str}# WHERE #{sql.id_col_str}# = ?") or
      die "TODO: Prepare (\$#{class_sv}#/load_by_id/single) failed";
    \$#{sth_sv}# = \$sth_single;
  }

  #{sth_e}#->execute(\@#{ids_av}#) or
    die "TODO: Execute (\$#{class_sv}#/load_by_id) failed";
__END__

my $ctpl_load_all_execute = <<__END__;
  #{create_sv_x(sth)}#
  state \$#{sth_sv}# = #{persistence.dbh_e}#->prepare(
      "#{sql.select_header_str}#") or
    die "TODO: Prepare (\$#{class_sv}#/load_all) failed";
  #{sth_e}#->execute() or
    die "TODO: Execute (\$#{class_sv}#/load_all) failed";
__END__

# TODO Proper loader name
my $ctpl_load_custom_fixsql_execute = <<__END__;
  #{create_sv_x(sth)}#
  state \$#{sth_sv}# = #{persistence.dbh_e}#->prepare(
      "#{sql.select_header_str}#" .
      "#{mysql.cv(where_str)}#" .
      "#{mysql.cv(order_str)}#") or
    die "TODO: Prepare (\$#{class_sv}#/#{mysql.cv(method_name_str)}#) failed";
  #{sth_e}#->execute(#{mysql.cv(execute_e)}#) or
    die "TODO: Execute (\$#{class_sv}#/#{mysql.cv(method_name_str)}#) failed";
__END__

my $ctpl_load_fetch = <<__END__;
  #{create_sv_x(rows)}#
  my \$#{rows_sv}# = #{sth_e}#->fetchall_arrayref() or
    die "TODO: Fetch (\$#{class_sv}#/load) failed";
  die "TODO: Database error (\$#{class_sv}#/load)"
    if #{sth_e}#->err();
__END__

my $ctpl_load_instantiate = <<__END__;
  #{create_av_x(return)}#
  my \@#{return_av}# =
      map { #{class_e}#->_fast_new( { #{persistence._deserialize_z}# } ) }
          \@{#{rows_e}#};
__END__

my $ctpl_load_return_die = <<__END__;
  return \@#{return_av}# if wantarray;
  return \$#{return_av}#[0] || die "TODO: Object not found.\n";
__END__

my $ctpl_load_return = <<__END__;
  return \@#{return_av}# if wantarray;
  return \$#{return_av}#[0];
__END__

# ---- replace ----------------------------------------------------------------

my $ctpl_replace_args = <<__END__;
  #{create_sv_x(self,class)}#
  my \$#{self_sv}# = \$_[0];
  my \$#{class_sv}# = ref(#{self_e}#) || #{self_e}#;
__END__

my $ctpl_replace_execute = <<__END__;
  my \$#{return_sv}#;
  {
    state \$sth = #{persistence.dbh_e}#->prepare(
        #{sql.replace_e}#) or
      die "TODO: Prepare (\$#{class_sv}#/replace) failed";
    \$#{return_sv}# = \$sth->execute(#{persistence._serialize_z}#) or
      die "TODO: Execute (\$#{class_sv}#/replace) failed";
  }
__END__

# ---- destroy ----------------------------------------------------------------

my $ctpl_destroy_by_id_args = <<__END__;
  #{create_sv_x(class)}#
  #{define_x(ids_av,_)}#
  my \$#{class_sv}# = shift;
__END__

my $ctpl_destroy_by_id_execute = <<__END__;
  #{create_sv_x(return)}#
  my \$#{return_sv}#;
  if (\@#{ids_av}#)
  {
    my \$sth;

    if (\$##{ids_av}#)
    {
      my \$qms = join(', ', ('?') x scalar(\@#{ids_av}#));
      \$sth = #{persistence.dbh_e}#->prepare(
          "DELETE FROM #{sql.table_str}# " . 
          "WHERE #{sql.id_col_str}# IN (\$qms)") or
        die "TODO: Prepare (\$#{class_sv}#/destroy_by_id/multiple) failed";
    }
    else
    {
      state \$sth_single = #{persistence.dbh_e}#->prepare(
          "DELETE FROM #{sql.table_str}# WHERE #{sql.id_col_str}# = ?") or
        die "TODO: Prepare (\$#{class_sv}#/destroy_by_id/single) failed";
      \$sth = \$sth_single;
    }

    \$#{return_sv}# = \$sth->execute(\@#{ids_av}#) or
      die "TODO: Execute (\$#{class_sv}#/destroy_by_id) failed";
  }
__END__

# ==== CodePatterns ===========================================================

# Get trait object from stash
sub _get_trait_obj($)
{
  return $_[0]->{$ModName} ||
    die "TODO: Can't find myself";
}

# my ($hook_runner, $hook_name, $cg, $what, $step, $stash) = @_;
#     $_[0],        $_[1],    $_[2], $_[3], $_[4], $_[5]

our %CodePatterns =
    (
      'persistence.dbh_e' => '$main::DBH',

      # ---- load_by_id -------------------------------------------------------
      # $obj = Class->load($id) ==> load $id or die
      # @objs = Class->load($id1, ...) ==> map { load $id } ($id1, ...)

      'persistence.load_by_id_s' => [qw(
          persistence.load_by_id.args_s
          persistence.load_by_id.execute_s
          persistence.load.fetch_s
          persistence.load.instantiate_s
          persistence.load.return_die_s
          important_x )],

      # output: class_sv, ids_av
      'persistence.load_by_id.args_s' => $ctpl_load_by_id_args,

      # output: sth_sv
      'persistence.load_by_id.execute_s' => $ctpl_load_by_id_execute,

      # ---- load_all ---------------------------------------------------------

      'persistence.load_all_s' => [qw(
          persistence.load_all.args_s
          persistence.load_all.execute_s
          persistence.load.fetch_s
          persistence.load.instantiate_s
          persistence.load.return_s
          important_x )],

      # output: class_sv
      'persistence.load_all.args_s' =>
          '#{define_x(class_sv,"_[0]")}#' .
          '#{define_x(class_e,"$_[0]")}#',

      # output: sth_sv
      'persistence.load_all.execute_s' => $ctpl_load_all_execute,

      # ---- custom load ------------------------------------------------------

      'persistence.load_custom.args_s' => $ctpl_load_custom_args,
      'persistence.load_custom_fixsql.execute_s' =>
          $ctpl_load_custom_fixsql_execute,

      # ---- generic load -----------------------------------------------------

      # output: rows_sv
      'persistence.load.fetch_s' => $ctpl_load_fetch,

      # output: return_av
      'persistence.load.instantiate_s' => $ctpl_load_instantiate,

      'persistence.load.return_die_s' => $ctpl_load_return_die,
      'persistence.load.return_s' => $ctpl_load_return,

      # ---- replace ----------------------------------------------------------

      'persistence.save_s' => [ 'persistence.replace_s' ],

      'persistence.replace_s' => [qw(
          persistence.replace.args_s
          persistence.replace.execute_s
          persistence.reload_id_s
          persistence.replace.return_s
          important_x )],

      'persistence.replace.args_s' => $ctpl_replace_args,

      'persistence.replace.execute_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $sql_replace_e;
            {
              local $" = ', ';
              my $sql_table = $trait_obj->GetSqlVar('table');
              my @sql_cols = @{$trait_obj->GetSqlVar('columns')};
              my @qms = ('?') x scalar(@sql_cols);
              $sql_replace_e =
                  "REPLACE INTO $sql_table (@sql_cols) VALUES (@qms)";
            }

            $cg->CreateScalarVar('return');
            $cg->AddNamedPattern(
                'sql.replace_e' => $cg->QuoteString($sql_replace_e));

            return $cg->ExpandPattern($ctpl_replace_execute);
          },

      'persistence.reload_id_s' =>
          sub
          {
            # TODO destroy_by_id method name
            # TODO proper id attr lookup?
            # TODO something more prudent instead of attr.write_e
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->GetSqlVar('id_attribute_name'));

            $cg->Push();
            $id_attr->_gh_SetupCodeGenerator($cg);
            my $code = $cg->ExpandPattern(
                "#{attr.write_e}# unless #{attr.exists_e}#;\n",
                {
                  'new_value_e' =>
                      '#{persistence.dbh_e}#->' .
                          'last_insert_id(undef, undef, undef, undef)'
                });
            $cg->Pop();

            return $code;
          },

      'persistence.replace.return_s' => $ctpl_return_s,

      # ---- destroy_by_id ----------------------------------------------------

      'persistence.destroy_by_id_s' => [qw(
          persistence.destroy_by_id.args_s
          persistence.destroy_by_id.execute_s
          persistence.destroy_by_id.return_s
          important_x )],

      # output: class_sv, ids_av
      'persistence.destroy_by_id.args_s' => $ctpl_destroy_by_id_args,

      # output: sth_sv
      'persistence.destroy_by_id.execute_s' => $ctpl_destroy_by_id_execute,

      'persistence.destroy_by_id.return_s' => $ctpl_return_s,

      # ---- destroy_object ---------------------------------------------------

      'persistence.destroy_object_s' => [qw(
          persistence.destroy_object.args_s
          persistence.destroy_object.execute_s
          important_x )],

      'persistence.destroy_object.args_s' => '#{define_x(self_e,"$_[0]")}#',

      'persistence.destroy_object.execute_s' =>
          sub
          {
            # TODO destroy_by_id method name
            # TODO proper id attr lookup?
            # TODO proper serialization of id
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->GetSqlVar('id_attribute_name'));

            $cg->Push();
            $id_attr->_gh_SetupCodeGenerator($cg);
            my $code = $cg->ExpandPattern(
                "#{self_e}#->destroy(#{attr.get_e}#) " .
                    "if #{attr.exists_e}#;\n");
            $cg->Pop();

            return $code;
          },

      # ---- (De)Serialize ----------------------------------------------------

      'persistence._serialize_z' =>
          sub
          {
            # TODO proper serialization through type
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my @attrs;
            foreach my $attr (@{$trait_obj->GetSqlVar('p_attributes')})
            {
              $cg->Push();
              $attr->_gh_SetupCodeGenerator($cg);
              push(@attrs, $cg->Generate('serialize', ['attr.get_e'], $stash));
              $cg->Pop();
            }

            return join(', ', @attrs);
          },

      'persistence._deserialize_z' =>
          sub
          {
            # TODO proper deserialization through type
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $idx = 0;
            return join(', ',
                map { "$_ => \$_->[" . $idx++ . ']' }
                    map { $cg->QuoteString($_) }
                        @{$trait_obj->GetSqlVar('p_attribute_names')});
          },

      # ---- custom variables ------------------------------------------------

      'mysql.cv' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $ret;

            if (my $p1 = $cg->ExpandNamedPattern('#1'))
            {
              my $stash = $cg_args->{$CGHA_generate_args}->[0];
              my $trait_obj = _get_trait_obj($stash);
              my $custom_type = $stash->{'method_type'};
              die "TODO: Not in a custom method"
                unless ($custom_type =~ /^custom_method_(\d+)\z/);
              $ret = $trait_obj->GetCustomVar($custom_type, $p1);
              $ret = $cg->ExpandPattern($ret) if defined($ret);
            }

            return $ret;
          },

      # TODO
      'persistence.sql_col_str' => '#{#1}#'
    );

###### METHODS ################################################################

# ==== Trait interface ========================================================

sub new
{
  my ($class, $host, $args) = @_;

  my $self = bless(
      {
        $HK_args => $args,
        $HK_parent => $host,
      }, $class);
  Scalar::Util::weaken($self->{$HK_parent});
  
  return $self;
}

sub _gh_SetupAttributeTrait
{
  my $self = shift;
  my $host = shift;
  my $trait_name = $self->TraitName();
  die "TODO: $trait_name can not be used as an attribute trait";
}

sub _gh_DoSetupClassTrait
{
  my $self = $_[0];
  my $host = $_[1];

  $host->_gh_AddHook('gh_build_methods', $ModName =>
      # __hook__($hook_runner, $hook_name, $class)
      sub
      {
        $self->__PrepareSqlStuff();
        $self->__PrepareMethods();
        $self->_gh_Build();
        return undef;
      });
}

# ==== _gh_BuildMethods =======================================================

sub _gh_MetaClass { return $_[0]->{$HK_parent} }
sub _gh_TypeToWhat { return "persistence.$_[1]_s" }

sub _gh_GetMethodTypes
{
  my $self = $_[0];
  my $method_specs = $self->{$HK_method_specs};
  return $method_specs ? keys(%{$method_specs}) : ();
}

sub _gh_GetMethodNames
{
  my $self = $_[0];
  my $method_type = $_[1];

  my $method_name;
  my $method_specs = $self->{$HK_method_specs};
  $method_name = $method_specs->{$method_type}->{'name'}
    if ($method_specs && $method_specs->{$method_type});

  return ref($method_name) ? @{$method_name} : ($method_name, $method_name);
}

# ==== __PrepareSqlStuff ======================================================

sub __PrepareSqlStuff
{
  my $self = $_[0];

  my $meta_class = $self->_gh_MetaClass();
  my $class_name = $meta_class->Name();

  my $sql_vars = $self->{$HK_sql_vars} = {};

  # Table
  {
    my $table = $self->{$HK_args}->{'table'} //
        $meta_class->GetProperty('table') //
        lc("${class_name}s"); # TODO
    $sql_vars->{'table'} = $table;
  }

  # Columns
  {
    my $persistent_flag =
        $self->{$HK_args}->{'persistent_flag'} // 'persistent';
    my @attrs = $meta_class->GetAttributesWithFlag($persistent_flag) or
      die "TODO: No persistent attributes in $class_name.\n";
    my @attr_names = map { $_->Name() } @attrs;
    my @sql_cols = @attr_names; # TODO

    $sql_vars->{'columns'} = \@sql_cols;
    $sql_vars->{'p_attributes'} = \@attrs;
    $sql_vars->{'p_attribute_names'} = \@attr_names;

    $sql_vars->{'p_attribute_name_to_column_map'} =
        { map { $attr_names[$_] => $sql_cols[$_] } (0 .. $#attr_names) };
  }

  # Id
  {
    my $id_flag = $self->{$HK_args}->{'id_flag'} // 'id';
    my @id_attrs = $meta_class->GetAttributesWithFlag($id_flag);
    if (!@id_attrs)
    {
      my $id_attr = $self->{$HK_args}->{'id_attr'} // 'id';
      $id_attr = $meta_class->GetAttributeByName($id_attr);
      push(@id_attrs, $id_attr) if $id_attr;
    }
    die "TODO: No id in $class_name.\n" unless @id_attrs;
    die "TODO: Multiple ids in $class_name.\n" if $#id_attrs;

    $sql_vars->{'id_attribute_name'} = $id_attrs[0]->Name();
    $sql_vars->{'id_column'} =
        $sql_vars->{'p_attribute_name_to_column_map'}->
            {$sql_vars->{'id_attribute_name'}} //
        die "TODO: Id not persistent in $class_name.\n";
  }

  # Select header
  {
    local $" = ', ';
    my @sql_cols = @{$sql_vars->{'columns'}};
    my $table = $sql_vars->{'table'};
    $sql_vars->{'select_header'} = "SELECT @sql_cols FROM $table";
  }

  return $sql_vars;
}

# ---- GetSqlVar --------------------------------------------------------------

sub GetSqlVar { return $_[0]->{$HK_sql_vars}->{$_[1]} }

# ==== __PrepareMethods =======================================================

sub __PrepareMethods
{
  state $custom_type_seq = 0;
  my $self = $_[0];

  my $method_specs = $self->{$HK_method_specs} //= {};
  my $arg_method_table = $self->{$HK_args}->{'methods'};

  # TODO: Check arg_method_table type
  my %todo;
  %todo = map { ( $_ => 1 ) } keys(%{$arg_method_table})
    if $arg_method_table;

  # Built in methods
  my $method_arg;
  foreach my $method_type (@MethodTypes)
  {
    my $method_name = $MethodNames{$method_type} or
      next;

    if (exists($arg_method_table->{$method_name}))
    {
      $method_arg = $arg_method_table->{$method_name};

      # undef / false => don't build
      # str / arrayref => rename
      # anything else => custom (keep in todo)
      if (!$method_arg || !ref($method_arg) || (ref($method_arg) eq 'ARRAY'))
      {
        $method_specs->{$method_type} =
            {
              'name' => $method_arg,
              'type' => $method_type
            }
          if $method_arg;
        delete($todo{$method_name});
      }
    }
    else
    {
      # No mention => build default implementation
      $method_specs->{$method_type} =
          {
            'name' => $method_name,
            'type' => $method_type
          };
    }
  }

  # Custom methods
  my $method_type;
  foreach my $method_name (keys(%todo))
  {
    $method_type = 'custom_method_' . $custom_type_seq++;
    $method_arg = $arg_method_table->{$method_name};
    $method_specs->{$method_type} =
        $self->__MethodArg2Spec($method_arg, $method_name, $method_type);
  }
}

# ---- __MethodArg2Spec -------------------------------------------------------

sub __MethodArg2Spec
{
  my ($self, $method_arg, $method_name, $method_type) = @_;
  my $method_spec =
      {
        'orig_name' => $method_name,
        'name' => [$method_name, $method_name],
        'type' => $method_type
      };

  die "TODO: $ModName bad custom method '$method_name'"
    unless (ref($method_arg) eq 'HASH');

  my $parser_method;
  foreach my $k (keys(%{$method_arg}))
  {
    $parser_method = "_gh_ParseArgMethod_$k";
    die "TODO $ModName bad keyword '$k' in custom method '$method_name'"
      unless ($parser_method = $self->can($parser_method));
    $self->$parser_method($method_name, $method_spec, $method_arg, $k);
  }
  $self->__CreateCustomTemplate($method_name, $method_spec);

  return $method_spec;
}

# ---- __CreateCustomTemplate -------------------------------------------------

sub __CreateCustomTemplate
{
  my ($self, $method_name, $method_spec) = @_;
  my $method_type = $method_spec->{'type'};

  my $model = $method_spec->{'model'} // 'load';

  my %vars =
      (
        'model_str' => $model,
        'reported_name_str' => $method_spec->{'name'}->[0],
        'generated_name_str' => $method_spec->{'name'}->[1],
        'method_name_str' => $method_spec->{'orig_name'},
        'type_str' => $method_type
      );

  my @template;
  given ($model)
  {
    when ('load')
    {
      @template = ('persistence.load_custom.args_s');

      # TODO fix/gen sql
      push(@template, 'persistence.load_custom_fixsql.execute_s');
      if ($method_spec->{'where'})
      {
        $vars{'where_str'} = ' WHERE ' . $method_spec->{'where'}->{'sql'};
        $vars{'execute_e'} =
            join(', ', @{$method_spec->{'where'}->{'execute'}});
      }
      $vars{'order_str'} = ' ORDER BY ' .
          join(', ', @{$method_spec->{'order_by'}})
        if defined($method_spec->{'order_by'});

      push(@template,
          'persistence.load.fetch_s',
          'persistence.load.instantiate_s');

      # TODO single/multi obj, die/nodie
      push(@template, 'persistence.load.return_s');

      push(@template, 'important_x');
    }
    default
    {
      die "TODO: Can't generate $model method.\n";
    }
  }

  $method_spec->{'template'} = \@template;
  $method_spec->{'vars'} = \%vars;
}

# ---- _gh_ParseArgMethod_xxx -------------------------------------------------
# $self->$parser_method($method_name, $method_spec, $method_args, $kw);

sub _gh_ParseArgMethod_reported_name
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  $method_spec->{'name'}->[0] = $method_args->{$kw};
}

sub _gh_ParseArgMethod_generated_name
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  $method_spec->{'name'}->[1] = $method_args->{$kw};
}

sub _gh_ParseArgMethod_type
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  my $model = $method_args->[$kw];
  die "TODO $ModName can't use ref as $kw for $method_name"
    if ref($model);
  die "TODO $ModName bad method type '$model'"
    unless ($model ~~ [qw( load )]);
  $method_spec->{'model'} = $model;
}

sub _gh_ParseArgMethod_grep
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;

  my $model = $method_spec->{'model'} // $method_args->{'model'} // 'load';
  die "TODO $ModName can't use $kw in $model for $method_name"
    unless ($model eq 'load');

  eval { $method_spec->{'where'} = parse_grep($method_args->{$kw}) };
  die "TODO $ModName $@ in $kw for $method_name" if $@;
}

sub _gh_ParseArgMethod_sort
{
  my ($self, $method_name, $method_spec, $method_args, $kw) = @_;
  if (my @fields = grep { $_ } split(/(?:\s*,\s*|\s+)/, $method_args->{$kw}))
  {
    # TODO check field names
    foreach (@fields)
    {
      $_ = s/^-// ?
          "#{persistence.sql_col_str($_)}# DESC" :
          "#{persistence.sql_col_str($_)}#";
    }
    $method_spec->{'order_by'} = \@fields;
  }
}

sub _gh_ParseArgMethod_single_object
{
  # TODO
}

# ---- GetCustomVar -----------------------------------------------------------

sub GetCustomVar
{
  my ($self, $custom_type, $var) = @_;
  my $ret;

  $ret = $self->{$HK_method_specs}->{$custom_type}->{'vars'}->{$var}
    if ($self->{$HK_method_specs} &&
        $self->{$HK_method_specs}->{$custom_type});

  return $ret;
}

# ==== Code Generator =========================================================

sub _gh_SetupCodeGenerator
{
  # my ($self, $cg) = @_;
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});

  # SQL vars
  {
    my $sql_vars = $self->{$HK_sql_vars};
    $cg->AddNamedPattern(\%CodePatterns);
    $cg->AddNamedPattern(
        # '' => quotemeta($self->{''}),
        'sql.table_str' => quotemeta($sql_vars->{'table'}),
        'sql.id_col_str' => quotemeta($sql_vars->{'id_column'}),
        'sql.select_header_str' => quotemeta($sql_vars->{'select_header'}));
  }

  # Method templates
  if (my $method_specs = $self->{$HK_method_specs})
  {
    my $template;
    my $method_spec;
    foreach my $method_type (keys(%{$method_specs}))
    {
      $method_spec = $method_specs->{$method_type};
      $template = $method_spec->{'template'};
      $cg->AddNamedPattern(
          $self->_gh_TypeToWhat($method_type) => $template)
        if $template;
    }
  }

  return $self->SUPER::_gh_SetupCodeGenerator(@_);
}

sub _gh_PrepareStash
{
  my $self = $_[0];
  my $stash = $_[1];

  my %defaults =
      (
        $ModName => $self
      );
  foreach my $k (keys(%defaults))
  {
    $stash->{$k} = $defaults{$k}
      unless exists($stash->{$k});
  }
}

###### THE END ################################################################

1

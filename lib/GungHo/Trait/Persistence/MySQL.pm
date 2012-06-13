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

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# ==== Hash Keys ==============================================================

our $HK_args = 'args';
our $HK_parent = 'parent';
our $HK_sql_vars = 'sql_vars';

# ==== Method Types ===========================================================

our @MethodTypes = qw( load_by_id save destroy_by_id destroy_object );

our %MethodNames =
    (
      # 'method_type' => [qw( reported_name generated_name )]
      # 'method_type' => 'name'
      'load_by_id' => 'load',
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
  my \$#{class_sv}# = shift;

  die "TODO: load what?" unless \@#{ids_av}#;
  die "TODO: something is wrong" if (\$##{ids_av}# && !wantarray);
__END__

my $ctpl_load_by_id_execute = <<__END__;
  my \$#{sth_sv}#;
  if (\$##{ids_av}#)
  {
    my \$qms = join(', ', ('?') x scalar(\@#{ids_av}#));
    \$#{sth_sv}# = #{dbh_e}#->prepare(
        "#{sql_select_header_str}# WHERE #{sql_id_col_str}# IN (\$qms)") or
      die "TODO: Prepare (\$#{class_sv}#/load_by_id/multiple) failed";
  }
  else
  {
    state \$sth_single;
    \$sth_single = #{dbh_e}#->prepare(
          "#{sql_select_header_str}# WHERE #{sql_id_col_str}# = ?") or
      die "TODO: Prepare (\$#{class_sv}#/load_by_id/single) failed"
      unless \$sth_single;
    \$#{sth_sv}# = \$sth_single;
  }

  #{sth_e}#->execute(\@#{ids_av}#) or
    die "TODO: Execute (\$#{class_sv}#/load_by_id) failed";
__END__

my $ctpl_load_fetch = <<__END__;
  my \$#{rows_sv}# = #{sth_e}#->fetchall_arrayref() or
    die "TODO: Fetch (\$#{class_sv}#/load) failed";
  die "TODO: Database error (\$#{class_sv}#/load)"
    if #{sth_e}#->err();
__END__

my $ctpl_load_instantiate = <<__END__;
  my \@#{return_av}# =
      map { #{class_e}#->_fast_new( { #{_deserialize_z}# } ) }
          \@{#{rows_e}#};
__END__

my $ctpl_load_return = <<__END__;
  return \@#{return_av}# if wantarray;
  return \$#{return_av}#[0] || die "TODO: Object not found.\n";
__END__

# ---- replace ----------------------------------------------------------------

my $ctpl_replace_args = <<__END__;
  my \$#{self_sv}# = \$_[0];
  my \$#{class_sv}# = ref(#{self_e}#) || #{self_e}#;
__END__

my $ctpl_replace_execute = <<__END__;
  my \$#{return_sv}#;
  {
    state \$sth;
    \$sth = #{dbh_e}#->prepare(
        #{sql_replace_e}#) or
      die "TODO: Prepare (\$#{class_sv}#/replace) failed"
      unless \$sth;
    \$#{return_sv}# = \$sth->execute(#{_serialiaze_z}#) or
      die "TODO: Execute (\$#{class_sv}#/replace) failed";
  }
__END__

# ---- destroy ----------------------------------------------------------------

my $ctpl_destroy_by_id_args = <<__END__;
  my \$#{class_sv}# = shift;
__END__

my $ctpl_destroy_by_id_execute = <<__END__;
  my \$#{return_sv}#;
  if (\@#{ids_av}#)
  {
    my \$sth;

    if (\$##{ids_av}#)
    {
      my \$qms = join(', ', ('?') x scalar(\@#{ids_av}#));
      \$sth = #{dbh_e}#->prepare(
          "DELETE FROM #{sql_table_str}# " . 
          "WHERE #{sql_id_col_str}# IN (\$qms)") or
        die "TODO: Prepare (\$#{class_sv}#/destroy_by_id/multiple) failed";
    }
    else
    {
      state \$sth_single;
      \$sth_single = #{dbh_e}#->prepare(
            "DELETE FROM #{sql_table_str}# WHERE #{sql_id_col_str}# = ?") or
        die "TODO: Prepare (\$#{class_sv}#/destroy_by_id/single) failed"
        unless \$sth_single;
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
      'dbh_e' => '$main::DBH',

      # ---- load_by_id -------------------------------------------------------
      # $obj = Class->load($id) ==> load $id or die
      # @objs = Class->load($id1, ...) ==> map { load $id } ($id1, ...)

      'persistence_load_by_id_s' => [qw(
          load_by_id_args_s
          load_by_id_execute_s
          load_fetch_s
          load_instantiate_s
          load_return_s
          important_x )],

      # output: class_sv, ids_av
      'load_by_id_args_s' =>
          sub
          {
            my $cg = $_[2];
            my $class_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'class_sv' => $class_sv,
                'class_e' => "\$$class_sv",
                'ids_av' => '_');
            return $cg->ExpandPattern($ctpl_load_by_id_args);
         },

      # output: sth_sv
      'load_by_id_execute_s' =>
          sub
          {
            my $cg = $_[2];
            my $sth_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'sth_sv' => $sth_sv,
                'sth_e' => "\$$sth_sv");
            return $cg->ExpandPattern($ctpl_load_by_id_execute);
          },

      # ---- generic load -----------------------------------------------------

      # output: rows_sv
      'load_fetch_s' =>
          sub
          {
            my $cg = $_[2];
            my $rows_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'rows_sv' => $rows_sv,
                'rows_e' => "\$$rows_sv");
            return $cg->ExpandPattern($ctpl_load_fetch);
          },

      # output: return_av
      'load_instantiate_s' =>
          sub
          {
            my $cg = $_[2];
            $cg->AddNamedPattern(
                'return_av' => $cg->GetMyVariable(''));
            return $cg->ExpandPattern($ctpl_load_instantiate);
          },

      'load_return_s' => $ctpl_load_return,

      # ---- replace ----------------------------------------------------------

      'persistence_save_s' => [ 'replace_s' ],

      'replace_s' => [qw(
          replace_args_s
          replace_execute_s
          reload_id_s
          replace_return_s
          important_x )],

      'replace_args_s' =>
          sub
          {
            my $cg = $_[2];

            my $self_sv = $cg->GetMyVariable('');
            my $class_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'class_sv' => $class_sv,
                'class_e' => "\$$class_sv",
                'self_sv' => $self_sv,
                'self_e' => "\$$self_sv");

            return $cg->ExpandPattern($ctpl_replace_args);
          },

      'replace_execute_s' =>
          sub
          {
            my $cg = $_[2];
            my $trait_obj = _get_trait_obj($_[5]);

            my $sql_replace_e;
            {
              local $" = ', ';
              my $sql_table = $trait_obj->GetSqlVar('table');
              my @sql_cols = @{$trait_obj->GetSqlVar('columns')};
              my @qms = ('?') x scalar(@sql_cols);
              $sql_replace_e =
                  "REPLACE INTO $sql_table (@sql_cols) VALUES (@qms)";
            }

            my $return_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'return_sv' => $return_sv,
                'return_e' => "\$$return_sv",
                'sql_replace_e' => $cg->QuoteString($sql_replace_e));

            return $cg->ExpandPattern($ctpl_replace_execute);
          },

      'reload_id_s' =>
          sub
          {
            # TODO destroy_by_id method name
            # TODO proper id attr lookup?
            my $cg = $_[2];
            my $stash = $_[5];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->GetSqlVar('id_attribute_name'));

            $cg->Push();
            $id_attr->_gh_SetupCodeGenerator($cg);
            my $code = $cg->ExpandPattern(
                "#{set_e}# unless #{exists_e}#;\n",
                {
                  'new_value_e' =>
                      '#{dbh_e}#->last_insert_id(undef, undef, undef, undef)'
                });
            $cg->Pop();

            return $code;
          },

      'replace_return_s' => $ctpl_return_s,

      # ---- destroy_by_id ----------------------------------------------------

      'persistence_destroy_by_id_s' => [qw(
          destroy_by_id_args_s
          destroy_by_id_execute_s
          destroy_return_s
          important_x )],

      # output: class_sv, ids_av
      'destroy_by_id_args_s' =>
          sub
          {
            my $cg = $_[2];
            my $class_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'class_sv' => $class_sv,
                'class_e' => "\$$class_sv",
                'ids_av' => '_');
            return $cg->ExpandPattern($ctpl_destroy_by_id_args);
         },

      # output: sth_sv
      'destroy_by_id_execute_s' =>
          sub
          {
            my $cg = $_[2];
            my $return_sv = $cg->GetMyVariable('');
            $cg->AddNamedPattern(
                'return_sv' => $return_sv,
                'return_e' => "\$$return_sv");
            return $cg->ExpandPattern($ctpl_destroy_by_id_execute);
          },

      'destroy_return_s' => $ctpl_return_s,

      # ---- destroy_object ---------------------------------------------------

      'persistence_destroy_object_s' => [qw(
          destroy_object_args_s
          destroy_object_execute_s
          important_x )],

      'destroy_object_args_s' =>
          sub
          {
            $_[2]->AddNamedPattern('self_e', '$_[0]');
            return undef;
          },

      'destroy_object_execute_s' =>
          sub
          {
            # TODO destroy_by_id method name
            # TODO proper id attr lookup?
            my $cg = $_[2];
            my $stash = $_[5];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->GetSqlVar('id_attribute_name'));

            $cg->Push();
            $id_attr->_gh_SetupCodeGenerator($cg);
            my $code = $cg->ExpandPattern(
                "#{self_e}#->destroy(#{get_e}#) if #{exists_e}#;\n");
            $cg->Pop();

            return $code;
          },

      # ---- (De)Serialize ----------------------------------------------------

      '_serialiaze_z' =>
          sub
          {
            # TODO proper serialization through type
            my $cg = $_[2];
            my $stash = $_[5];
            my $trait_obj = _get_trait_obj($stash);

            my @attrs;
            foreach my $attr (@{$trait_obj->GetSqlVar('p_attributes')})
            {
              $cg->Push();
              $attr->_gh_SetupCodeGenerator($cg);
              push(@attrs, $cg->Generate('serialize', ['get_e'], $stash));
              $cg->Pop();
            }

            return join(', ', @attrs);
          },

      '_deserialize_z' =>
          sub
          {
            # TODO proper deserialization through type
            my $cg = $_[2];
            my $trait_obj = _get_trait_obj($_[5]);

            my $idx = 0;
            return join(', ',
                map { "$_ => \$_->[" . $idx++ . ']' }
                    map { $cg->QuoteString($_) }
                        @{$trait_obj->GetSqlVar('p_attribute_names')});
          }
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
        $self->_gh_Build();
        return undef;
      });
}

# ==== _gh_BuildMethods =======================================================

sub _gh_MetaClass { return $_[0]->{$HK_parent} }
sub _gh_GetMethodTypes { return @MethodTypes }
sub _gh_TypeToWhat { return "persistence_$_[1]_s" }

sub _gh_GetMethodNames
{
  my $self = $_[0];
  my $method_type = $_[1];
  my $arg_method_table = $self->{$HK_args}->{'methods'};

  my $name =
      ($arg_method_table && exists($arg_method_table->{$method_type})) ?
          $arg_method_table->{$method_type} :
          $MethodNames{$method_type};

  return ref($name) ? @{$name} : ($name, $name);
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

sub GetSqlVar { return $_[0]->{$HK_sql_vars}->{$_[1]} }

# ==== Code Generator =========================================================

sub _gh_SetupCodeGenerator
{
  # my ($self, $cg) = @_;
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});

  my $sql_vars = $self->{$HK_sql_vars};
  $cg->AddNamedPattern(\%CodePatterns);
  $cg->AddNamedPattern(
      # '' => quotemeta($self->{''}),
      'sql_table_str' => quotemeta($sql_vars->{'table'}),
      'sql_id_col_str' => quotemeta($sql_vars->{'id_column'}),
      'sql_select_header_str' => quotemeta($sql_vars->{'select_header'}));

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

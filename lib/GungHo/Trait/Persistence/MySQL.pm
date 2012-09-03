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

use GungHo::Names qw( :CG_HOOK_ARGS );
use GungHo::_Serialize qw( _gh_cg_serialize_es _gh_cg_deserialize_es );

use GungHo::Trait::Persistence::MySQL::_Base;

###### VARS ###################################################################

our $ModName = __PACKAGE__;

my $mysql_ctx =
    {
      'name' => $ModName,
      'type' => 'MySQL SQL database storage',
      'trusted' => 1
    };

# ==== Hash Keys ==============================================================

our $HK_args = 'args';
our $HK_parent = 'parent';
our $HK_sql_vars = 'sql_vars';
our $HK_method_specs = 'method_specs';

# ==== Method Types ===========================================================

our @MethodTypes = qw(
    _load_by_sql_deserialize
    get_sql_table_info
    save
    destroy_object );

our %MethodNames =
    (
      # 'method_type' => [qw( reported_name generated_name )]
      # 'method_type' => 'name'
      '_load_by_sql_deserialize' => '_load_by_sql_deserialize',
      'get_sql_table_info' => 'get_sql_table_info',
      'save' => 'Save',
      'destroy_object' => 'Destroy'
    );

# ==== Code Templates =========================================================

my $ctpl_return_s = <<__END__;
  return #{return_e}#;
__END__

# ---- deserialize ------------------------------------------------------------

# ---- replace ----------------------------------------------------------------

my $ctpl_replace_args = <<__END__;
  #{create_sv_x(self,class)}#
  my \$#{self_sv}# = \$_[0];
  my \$#{class_sv}# = ref(#{self_e}#) || #{self_e}#;
__END__

my $ctpl_replace_execute = <<__END__;
  my \$#{return_sv}#;
  {
    my \$sth = #{persistence.dbh_e}#->prepare(
        #{sql.replace_e}#) or
      die "TODO: Prepare (\$#{class_sv}#/replace) failed";
    #{persistence.serialize_s}#
    \$#{return_sv}# = \$sth->execute(#{serialized_e}#) or
      die "TODO: Execute (\$#{class_sv}#/replace) failed";
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

      # ---- _load_by_sql_deserialize -----------------------------------------

      # TODO
      'persistence._load_by_sql_deserialize_s' => [qw(
          persistence.__load_by_sql_deserialize_s )],
      'persistence.__load_by_sql_deserialize_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);
            my $ret = '';

            # args
            $cg->CreateScalarVar('class', 'params');
            $ret .= "my \$#{class_sv}# = shift;\n"
                 .  "my \$#{params_sv}# = shift;\n";

            # deserialize
            my $deser_loop;
            {
              my @ss;
              my ($s, $attr_name_e, $attr_e);
              foreach my $attr (@{$trait_obj->GetSqlVar('p_attributes')})
              {
                $attr_name_e = $cg->QuoteString($attr->Name());
                $attr_e = "\$_->{$attr_name_e}";
                (undef, $s) = _gh_cg_deserialize_es(
                    $attr, $attr_e, $attr_e, $cg, $stash, $mysql_ctx);
                push(@ss, $s);
              }

              $deser_loop = join('', @ss);
            }
            $ret .= "foreach (\@_) { $deser_loop }\n"
              if $deser_loop;

            # return
            $ret .= "return \@_;\n";
            $cg->MakeImportant();

            return $cg->ExpandPattern($ret);
          },

      # ---- get_sql_table_info ----------------------------------------------

      # TODO
      'persistence.get_sql_table_info_s' =>
          ['persistence._get_sql_table_info_s'],
      'persistence._get_sql_table_info_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $t;
            {
              my @attrs = map { $cg->QuoteString($_) }
                  @{$trait_obj->GetSqlVar('p_attribute_names')};
              my @sql_cols = map { $cg->QuoteString($_) }
                  @{$trait_obj->GetSqlVar('columns')};

              local $" = ', ';
              $t = "return {"
                 . " 'table' => \"#{sql.table_str}#\","
                 . " 'attributes' => [@attrs],"
                 . " 'columns' => [@sql_cols],"
                 . " 'key' => \"#{sql.id_col_str}#\""
                 . "};\n";
            }

            $cg->MakeImportant();
            return $cg->ExpandPattern($t);
          },

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
            # TODO proper id attr lookup?
            # TODO something more prudent instead of attr.write_e
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->GetSqlVar('id_attribute_name'));

            $cg->Push();
            $cg->Use($id_attr);
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

      # ---- destroy_object ---------------------------------------------------

      'persistence.destroy_object_s' => [qw(
          persistence.destroy_object.args_s
          persistence.destroy_object.execute_s
          important_x )],

      'persistence.destroy_object.args_s' => '#{define_x(self_e,"$_[0]")}#',

      'persistence.destroy_object.execute_s' =>
          sub
          {
            # TODO proper id attr lookup?
            # TODO proper serialization of id
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my $id_attr_name = $trait_obj->GetSqlVar('id_attribute_name');
            my $id_str = $cg->QuoteString($id_attr_name);
            my $id_attr = $stash->{'meta_class'}->
                GetAttributeByName($id_attr_name);

            $cg->Push();
            $cg->Use($id_attr);
            my $code = $cg->ExpandPattern(
                "#{self_e}#->destroy($id_str => #{attr.get_e}#) " .
                    "if #{attr.exists_e}#;\n");
            $cg->Pop();

            return $code;
          },

      # ---- (De)Serialize ----------------------------------------------------

      'persistence.serialize_s' =>
          sub
          {
            my $cg_args = $_[2];
            my $cg = $cg_args->{$CGHA_code_generator};
            my $stash = $cg_args->{$CGHA_generate_args}->[0];
            my $trait_obj = _get_trait_obj($stash);

            my ($e, $s);
            my (@es, @ss);
            foreach my $attr (@{$trait_obj->GetSqlVar('p_attributes')})
            {
              ($e, $s) = _gh_cg_serialize_es($attr, $cg, $stash, $mysql_ctx);
              $e = 'undef' if (!defined($e) || ($e eq ''));
              push(@es, $e);
              push(@ss, $s);
            }
            $cg->AddNamedPattern('serialized_e', join(', ', @es));

            return join('', @ss);
          },

      # ---- custom variables ------------------------------------------------

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

  $host->_gh_AddHook('gh_class_get_super_classes', $ModName =>
      # __hook__($hook_runner, $hook_name, $class, \@isa)
      sub
      {
        push(@{$_[3]}, 'GungHo::Trait::Persistence::MySQL::_Base');
        return undef;
      });

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
      die "TODO: No persistent attributes in $class_name";
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
    die "TODO: No id in $class_name" unless @id_attrs;
    die "TODO: Multiple ids in $class_name" if $#id_attrs;

    $sql_vars->{'id_attribute_name'} = $id_attrs[0]->Name();
    $sql_vars->{'id_column'} =
        $sql_vars->{'p_attribute_name_to_column_map'}->
            {$sql_vars->{'id_attribute_name'}} //
        die "TODO: Id not persistent in $class_name";
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

  die "TODO: Can't do custom methods"
    if keys(%todo);
}

# ==== Code Generator =========================================================

sub _gh_SetupCodeGenerator
{
  # my ($self, $cg) = @_;
  my $self = shift;
  my $cg = $_[0];

  $cg->Use($self->{$HK_parent});

  $cg->AddNamedPattern(\%CodePatterns);

  # SQL vars
  {
    my $sql_vars = $self->{$HK_sql_vars};
    $cg->AddNamedPattern(
        # '' => quotemeta($self->{''}),
        'sql.table_str' => quotemeta($sql_vars->{'table'}),
        'sql.id_col_str' => quotemeta($sql_vars->{'id_column'}));
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

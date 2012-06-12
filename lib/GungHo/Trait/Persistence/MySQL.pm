#! /usr/bin/perl
# TODO: License
# TODO: Eliminate direct accessess into trait_obj
# $obj = Class->load($id) ==> load $id or die
# @objs = Class->load($id1, ...) ==> map { load $id } ($id1, ...)
###### NAMESPACE ##############################################################

package GungHo::Trait::Persistence::MySQL;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use parent qw( GungHo::Trait::_Base );

use Scalar::Util;

###### VARS ###################################################################

our $ModName = __PACKAGE__;

# ==== Code Templates ========================================================

my $ctpl_return_s = <<__END__;
  return #{return_e}#;
__END__

# ---- load ------------------------------------------------------------------

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
      map { #{class_e}#->_fast_new( { #{deserialize_z}# } ) }
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
    \$#{return_sv}# = \$sth->execute(#{serialiaze_z}#) or
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

# ==== DefaultCodePatterns ====================================================

# my ($hook_runner, $hook_name, $cg, $what, $step, $stash) = @_;
#     $_[0],        $_[1],    $_[2], $_[3], $_[4], $_[5]

our %DefaultCodePatterns =
    (
      'dbh_e' => '$main::DBH',

      # ---- load_by_id -------------------------------------------------------

      'load_by_id_s' => [qw(
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

      'deserialize_z' =>
          sub
          {
            # TODO proper deserialization through type
            my $cg = $_[2];
            my $trait_obj = $_[5]->{$ModName} or
              die "TODO: Can't find myself";

            my $idx = 0;
            return join(', ',
                map { "$_ => \$_->[" . $idx++ . ']' }
                    map { $cg->QuoteString($_) }
                        @{$trait_obj->{'sql_attr_names'}});
          },

      # ---- replace ----------------------------------------------------------

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
            my $trait_obj = $_[5]->{$ModName} or
              die "TODO: Can't find myself";

            my $sql_replace_e;
            {
              local $" = ', ';
              my $sql_table = $trait_obj->{'sql_table'};
              my @sql_cols = @{$trait_obj->{'sql_cols'}};
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
            my $trait_obj = $stash->{$ModName} or
              die "TODO: Can't find myself";

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->{'sql_id_attr_name'});

            $cg->Push();
            $id_attr->_gh_HookUpCodeGenerator($cg, $trait_obj);
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

      'serialiaze_z' =>
          sub
          {
            # TODO proper deserialization through type
            my $cg = $_[2];
            my $stash = $_[5];
            my $trait_obj = $stash->{$ModName} or
              die "TODO: Can't find myself";

            my @attrs;
            foreach my $attr (@{$trait_obj->{'sql_attrs'}})
            {
              $cg->Push();
              $attr->_gh_HookUpCodeGenerator($cg, $trait_obj);
              push(@attrs, $cg->Generate('serialize', ['get_e'], $stash));
              $cg->Pop();
            }

            return join(', ', @attrs);
          },

      # ---- destroy_by_id ----------------------------------------------------

      'destroy_by_id_s' => [qw(
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

      'destroy_object_s' => [qw(
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
            my $trait_obj = $stash->{$ModName} or
              die "TODO: Can't find myself";

            my $id_attr = $stash->{'meta_class'}->GetAttributeByName(
                $trait_obj->{'sql_id_attr_name'});

            $cg->Push();
            $id_attr->_gh_HookUpCodeGenerator($cg, $trait_obj);
            my $code = $cg->ExpandPattern(
                "#{self_e}#->destroy(#{get_e}#) if #{exists_e}#;\n");
            $cg->Pop();

            return $code;
          }
    );

###### METHODS ################################################################

# ==== Trait interface ========================================================

sub new
{
  my ($class, $host, $args) = @_;

  my $self = bless(
      {
        'args' => $args,
        'parent' => $host,
      }, $class);
  Scalar::Util::weaken($self->{'parent'});
  
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
        shift; shift;
        $self->__BuildMethods(@_);
        return undef;
      });
}

# ==== _BuildMethods ==========================================================

sub __BuildMethods
{
  my $self = $_[0];
  my $meta_class = $_[1];
  my $code;

  $self->__PrepareSqlStuff($meta_class);

  my $cg = GungHo::CodeGenerator->new_prepared($self);
  $cg->AddNamedPattern(\%DefaultCodePatterns);

  $code = $cg->Assemble('load_by_id', [ 'load_by_id_s' ], $cg->NewStash());
  $meta_class->_gh_AddMethodImplementation('load', $code)
    if $code;

  $code = $cg->Assemble('save', [ 'replace_s' ], $cg->NewStash());
  $meta_class->_gh_AddMethodImplementation('Save', $code)
    if $code;

  $code = $cg->Assemble(
      'destroy_by_id', [ 'destroy_by_id_s' ], $cg->NewStash());
  $meta_class->_gh_AddMethodImplementation('destroy', $code)
    if $code;

  $code = $cg->Assemble(
      'destroy_object', [ 'destroy_object_s' ], $cg->NewStash());
  $meta_class->_gh_AddMethodImplementation('Destroy', $code)
    if $code;
}

# ==== __PrepareSqlStuff ======================================================

sub __PrepareSqlStuff
{
  my $self = $_[0];
  my $meta_class = $_[1];

  my $class_name = $meta_class->Name();

  # Table
  {
    my $table = $self->{'args'}->{'table'} //
        $meta_class->GetProperty('table') //
        lc("${class_name}s"); # TODO
    $self->{'sql_table'} = $table;
  }

  # Columns
  {
    my $persistent_flag =
        $self->{'args'}->{'persistent_flag'} // 'persistent';
    my @attrs = $meta_class->GetAttributesWithFlag($persistent_flag) or
      die "TODO: No persistent attributes in $class_name.\n";
    my @attr_names = map { $_->Name() } @attrs;
    my @sql_cols = @attr_names; # TODO

    $self->{'sql_attrs'} = \@attrs;
    $self->{'sql_attr_names'} = \@attr_names;
    $self->{'sql_cols'} = \@sql_cols;

    $self->{'sql_attr_col_map'} =
        { map { $attr_names[$_] => $sql_cols[$_] } (0 .. $#attr_names) };
  }

  # Id
  {
    my $id_flag = $self->{'args'}->{'id_flag'} // 'id';
    my @id_attrs = $meta_class->GetAttributesWithFlag($id_flag);
    if (!@id_attrs)
    {
      my $id_attr = $self->{'args'}->{'id_attr'} // 'id';
      $id_attr = $meta_class->GetAttributeByName($id_attr);
      push(@id_attrs, $id_attr) if $id_attr;
    }
    die "TODO: No id in $class_name.\n" unless @id_attrs;
    die "TODO: Multiple ids in $class_name.\n" if $#id_attrs;

    $self->{'sql_id_attr_name'} = $id_attrs[0]->Name();
    $self->{'sql_id_col'} =
        $self->{'sql_attr_col_map'}->{$self->{'sql_id_attr_name'}} //
        die "TODO: Id not persistent in $class_name.\n";
  }

  # Select header
  {
    local $" = ', ';
    my @sql_cols = @{$self->{'sql_cols'}};
    my $table = $self->{'sql_table'};
    $self->{'sql_select_header'} = "SELECT @sql_cols FROM $table";
  }
}

# ==== Code Generator =========================================================

sub _gh_HookUpCodeGenerator
{
  # my ($self, $cg, $cg_owner) = @_;
  my $self = $_[0];
  my $cg = $_[1];
  my $cg_owner = $_[2];

  $self->{'parent'}->_gh_HookUpCodeGenerator($cg, $cg_owner)
    if ($self eq $cg_owner);

  $cg->AddNamedPattern(
      # '' => quotemeta($self->{''}),
      'sql_table_str' => quotemeta($self->{'sql_table'}),
      'sql_id_col_str' => quotemeta($self->{'sql_id_col'}),
      'sql_select_header_str' => quotemeta($self->{'sql_select_header'}));
  $cg->_gh_AddHook('new_stash', $self =>
      # __hook__($hook_runner, $hook_name, $cg, $stash)
      sub
      {
        $self->__PrepareStash($_[3], $_[2]);
        return undef;
      });
}

sub __PrepareStash
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

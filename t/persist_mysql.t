#! /usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use DBI;

use GungHo::Class;

###### CONFIG #################################################################

# TODO: How to do this portably?
our $Database = 'alma';
our $Username = 'alma';
our $Password = 'alma';

###### VARS ###################################################################

our $DBH;

###### SUBS ###################################################################

sub select_all
{
  my $rows = $DBH->selectall_arrayref(
      'SELECT id, attr1, attr2 FROM gungho_test ORDER BY attr1') or
    die "Prepare/execute/fetch failed (select).\n";
  return $rows;
}

sub obj_to_row
{
  return map { [$_->Id(), $_->A1(), $_->A2()] } @_
    if wantarray;
  return [$_[0]->Id(), $_[0]->A1(), $_[0]->A2()];
}

###### CODE ###################################################################

# ==== Connect to DB ==========================================================

$DBH = DBI->connect("DBI:mysql:$Database", $Username, $Password) or
  die "Cannot connect to database ($Database).\n";

# ==== Build table, class =====================================================

$DBH->do('DROP TABLE IF EXISTS gungho_test') or
  die "Database error (drop/1).\n";
$DBH->do(<<__EOF__) or
    CREATE TABLE gungho_test
    (
      id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      attr1 VARCHAR(255),
      attr2 VARCHAR(255)
    )
__EOF__
  die "Database error (create).\n";

GungHo::Class->build(
    'name' => 'MysqlTest',
    'traits' =>
        {
          'Persistence::MySQL' => { 'table' => 'gungho_test' },
          'FlagAttributes' => 'persistent'
        },
    'attributes' =>
        [
          'id' => { 'getter' => 'Id' },
          'attr1' => { 'getter' => 'A1' },
          'attr2' => { 'getter' => 'A2', 'setter' => 'SetA2' }
        ]);

# ==== CRUD ===================================================================

# ---- C ----------------------------------------------------------------------

my $a_obj = MysqlTest->new(
    'attr1' => 'a',
    'attr2' => 'a');
ok($a_obj, 'constructor a');
ok($a_obj->Save(), 'insert a');

my $a_id = $a_obj->Id();
ok(defined($a_id), 'id a');
my $a_row = obj_to_row($a_obj);

my $b_obj = MysqlTest->new(
    'attr1' => 'b',
    'attr2' => 'b');
ok($b_obj, 'constructor b');
ok($b_obj->Save(), 'insert b');

my $b_id = $b_obj->Id();
ok(defined($b_id), 'id b');
my $b_row = obj_to_row($b_obj);;

isnt($a_id, $b_id, 'id different');

is_deeply(
    select_all(),
    [$a_row, $b_row],
    'insert check');

# ---- R ----------------------------------------------------------------------

{
  my $a_loaded = MysqlTest->load($a_id);
  ok($a_loaded, 'load a');

  is_deeply(
      obj_to_row($a_loaded),
      $a_row,
      'load check a');
}

# ---- U ----------------------------------------------------------------------

{
  $a_obj->SetA2('x');
  $a_obj->Save();
  $a_row = obj_to_row($a_obj);

  is_deeply(
      select_all(),
      [$a_row, $b_row],
      'update');
}

# ---- D ----------------------------------------------------------------------

my $c_obj = MysqlTest->new(
  'attr1' => 'c',
  'attr2' => 'c');
$c_obj->Save();

my $c_id = $c_obj->Id();
my $c_row = obj_to_row($c_obj);

{
  MysqlTest->destroy('kjfdsh'); # Destroy bad id
  MysqlTest->destroy($a_id); # Destroy by id
  $b_obj->Destroy(); # Object destroy
  
  is_deeply(select_all(), [$c_row], 'destroy single');
}

# ---- Multiple load / destroy ------------------------------------------------

{
  # Create many
  my @objs =
      map { MysqlTest->new('attr1' => "q$_", 'attr2' => $_) } ('a' .. 'h');
  $_->Save() foreach @objs;
  my @obj_rows = obj_to_row(@objs);
  my @obj_ids = map { $_->Id() } @objs;

  is_deeply(select_all(), [$c_row, @obj_rows], 'insert objs');

  # load multiple
  my @loaded_objs = sort { $a->A1() cmp $b->A1() } MysqlTest->load(@obj_ids);
  my @looded_rows = obj_to_row(@loaded_objs);
  is_deeply(\@looded_rows, \@obj_rows, 'load multiple');

  # delete multiple
  MysqlTest->destroy(@obj_ids);
  is_deeply(select_all(), [$c_row], 'destroy multiple');
}

# =============================================================================

$DBH->do('DROP TABLE gungho_test') or
  die "Database error (drop/2).\n";
$DBH->disconnect() or
  die "Database error (disconnect).\n";

done_testing();

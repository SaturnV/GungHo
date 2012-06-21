#! /usr/bin/perl
###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Test::Exception;

###### INIT ###################################################################

BEGIN { use_ok('GungHo::CodeGenerator') };

###### VARS ###################################################################

###### CODE ###################################################################

# ==== Basic ==================================================================

{
  my $cg = GungHo::CodeGenerator->new();
  isa_ok($cg, 'GungHo::CodeGenerator');

  my $code;

  # basic 1 -- template expansion
  $cg->Push();
  $cg->AddNamedPattern( 'test1' => 'alma' );
  $code = $cg->Generate('basic1', ['test1', 'important_x']);
  like($code, qr/alma/, 'basic 1');
  $cg->Pop();

  # basic 2 -- state isolation (push/pop)
  $cg->Push();
  $cg->AddNamedPattern( 'test2' => 'barac' );
  $code = $cg->Generate('basic2', ['test1', 'test2', 'important_x']);
  like($code, qr/barac/, 'basic 2 positive');
  unlike($code, qr/alma/, 'basic 2 negative');
  $cg->Pop();

  # basic 3 -- pattern expansion #{xxx}#
  $cg->Push();
  $cg->AddNamedPattern( 'test1' => '#{test2}#',
                        'test2' => 'alma' );
  $code = $cg->Generate('basic3', ['test1', 'important_x']);
  like($code, qr/alma/, 'basic 3');
  $cg->Pop();

  # parametric 1 -- parametric pattern expansion
  $cg->Push();
  $cg->AddNamedPattern( 'test1' => '#{test2(#{alma}#,barac)}#',
                        'test2' => 'citrom(#{#1}#,#{#2}#)',
                        'alma' => 'retek' );
  $code = $cg->Generate('parametric1', ['test1', 'important_x']);
  like($code, qr/\Qcitrom(retek,barac)\E/, 'parametric 1');
  $cg->Pop();

  # parametric 2 -- implicite parameter forwarding
  $cg->Push();
  $cg->AddNamedPattern( 'test1' => '#{test2(#{alma}#,barac)}#',
                        'test2' => '#{test3}#',
                        'test3' => 'citrom(#{#1}#,#{#2}#)',
                        'alma' => 'retek' );
  $code = $cg->Generate('parametric2', ['test1', 'important_x']);
  like($code, qr/\Qcitrom(retek,barac)\E/, 'parametric 2');
  $cg->Pop();

  # parametric 3 -- explicite parameter forwarding
  $cg->Push();
  $cg->AddNamedPattern( 'test1' => '#{test2(#{alma}#,barac)}#',
                        'test2' => '#{test3(#{#2}#,#{#1}#)}#',
                        'test3' => 'citrom(#{#1}#,#{#2}#)',
                        'alma' => 'retek' );
  $code = $cg->Generate('parametric3', ['test1', 'important_x']);
  like($code, qr/\Qcitrom(barac,retek)\E/, 'parametric 3');
  $cg->Pop();
}

# ==== Advanced ===============================================================

# ==== Done ===================================================================

done_testing();

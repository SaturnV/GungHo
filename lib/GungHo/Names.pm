#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::Names;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

use Exporter qw( import );

###### INIT ###################################################################

our @EXPORT_OK =
    qw(
      $S_new_image $S_new_arguments $S_new_return $S_new_constructor

      $H_new_prepare_environment $H_new_create_image $H_new_process_arguments
      $H_hnpa_consume_args $H_hnpa_expand_macros
      $H_instantiate
      $H_init_Build $H_init_Validate $H_init_InitParts $H_init_InitWhole
      @H_constructor

      $H_cg_do_step
      $CGHA_code_generator $CGHA_generate_args $CGHA_what_chain $CGHA_what
      $CGHA_step

      $H_b_prepare_code_generator
    );

our %EXPORT_TAGS =
    (
      'ALL' => \@EXPORT_OK,
      'HOOK_NAMES'     => [ grep { /^[\$\@]H_/ } @EXPORT_OK ],
      'STASH_KEYS'     => [ grep { /^\$S_/ } @EXPORT_OK ],
      'STASH_KEYS_NEW' => [ grep { /^\$S_new_/ } @EXPORT_OK ],
      'CG_HOOK_ARGS'   => [ grep { /^\$CGHA_/ } @EXPORT_OK ],
    );

###### VARS ###################################################################

# ==== Stash keys =============================================================

# Object construction (new, init, hnpa)
our $S_new_image = 'image';
our $S_new_arguments = 'arguments';
our $S_new_return = 'return';
our $S_new_constructor = 'constructor';

# Code generator

# ==== Hook names =============================================================

# ---- Object construction ----------------------------------------------------

# Generic
our $H_instantiate = 'gh_instantiate';

# $class->new
our $H_new_prepare_environment = 'gh_new_prepare_environment';
our $H_new_create_image = 'gh_new_create_image';
our $H_new_process_arguments = 'gh_new_process_arguments';

# $class->new process arguments
our $H_hnpa_consume_args = 'gh_hnpa_consume_args';
our $H_hnpa_expand_macros = 'gh_hnpa_expand_macros';

# Object initialization (in $class->new)
our $H_init_Build = 'gh_init_Build';
our $H_init_Validate = 'gh_init_Validate';
our $H_init_InitParts = 'gh_init_InitParts';
our $H_init_InitWhole = 'gh_init_InitWhole';

our @H_constructor =
    (
      $H_new_prepare_environment, $H_new_create_image,
          $H_new_process_arguments,
      $H_hnpa_consume_args, $H_hnpa_expand_macros,
      $H_instantiate,
      $H_init_Build, $H_init_Validate, $H_init_InitParts, $H_init_InitWhole
    );

# ---- Code Generation --------------------------------------------------------

our $H_cg_do_step = 'gh_cg_do_step';

our $CGHA_code_generator = 'code_generator';
our $CGHA_generate_args = 'generate_args';
our $CGHA_what_chain = 'what_chain';
our $CGHA_what = 'what';
our $CGHA_step = 'step';

# ---- _Builder ---------------------------------------------------------------

our $H_b_prepare_code_generator = 'gh_b_prepare_code_generator';

###### THE END ################################################################

1

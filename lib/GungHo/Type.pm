#! /usr/bin/perl
# TODO: License
# This is just an API specification.
# This package should not be used directly. It's only function is that
# other code can test AnyClass->isa('GungHo::Type').
###### NAMESPACE ##############################################################

package GungHo::Type;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

our $ModName = __PACKAGE__;

###### METHODS ################################################################

# new: Create a type object if applicable.
# $type = $class->new(@type_paraeters)
# sub new { return $_[1] }

# _gh_SetupAttributeHooks: Hook into attribute code generation
# $type->_gh_SetupAttributeHooks($attr, $attr_spec)
# sub _gh_SetupAttributeHooks { return undef }

# ==== Parameter processing ===================================================

# TODO: TransformIn, TransformOut

# ==== Validation / Checking ==================================================

# Validate: Check if the object (internal representation) passes
#     internal consistency tests.
#     Return value ignored, should die on failure
# sub Validate { return undef }

# CheckChanges: Check if $old ant $new differ significantly.
#     Eg. the changes justify updating a persistent image.
#     Return true if modified, false otherwise.
# $type->CheckChanges($old, $new)
# sub CheckChanges { return undef }

# GeneratePlaceholder: Generate a valid dummy value (internal representation)
# sub GeneratePlaceholder { return undef }

# ==== Comparison =============================================================
# $type->Xxx($a, $b)
# a and b are 'internal representations'

# IsSameObject: $a and $b is the same object
#     Return true if same, false otherwise
# sub IsSameObject { return undef }

# IsEquivalent: $a and $b behaves identically
#     Return true if equivalent, false otherwise
# sub IsEquivalent { return undef }

# Compare: Determine sort order for $a and $b
#     Return 0/+/- like cmp or <=>
# sub Compare { return undef }

# ==== Modification ===========================================================

# Edit: Gather parameters from a hash and apply changes
# $type->Edit($obj, $param_hashref)
# $type->Edit($obj, $param_hashref, $name_prefix)
# sub Edit { return undef }

###### THE END ################################################################

1

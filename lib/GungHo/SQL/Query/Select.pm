#! /usr/bin/perl
# TODO: License
###### NAMESPACE ##############################################################

package GungHo::SQL::Query::Select;

###### IMPORTS ################################################################

use strict;
use warnings;
use feature ':5.10';

###### VARS ###################################################################

###### METHODS ################################################################

sub new
{
  my $class = $_[0];
  # my $orig_class = $_[1];
  # my $query_type = $_[2];

  my $self =
      {
        'select' => [],
        'from' => [],
        'where' => [],
        'where_params' => [],
        'group_by' => [],
        'having' => [],
        'having_params' => []
      };

  return bless($self, $class);
}

sub AddSelect
{
  my $self = shift;
  push(@{$self->{'select'}}, @_);
  return $self;
}

sub AddFrom
{
  state $next_alias = 'a';
  my $self = shift;
  my @ret;

  die "TODO: Add what?" unless @_;

  my $alias;
  foreach (@_)
  {
    push(@ret, $alias = '__sta_' . $next_alias++);
    push(@{$self->{'from'}}, { 'table' => $_[0], 'alias' => $alias });
  }

  return @ret if wantarray;
  return $ret[0];
}

sub Join
{
  my $self = shift;
  my $params = GungHo::Utils::make_hashref(@_);

  my $t;
  my $alias = $params->{'alias'} or
    die "TODO: Join what?";
  foreach (@{$self->{'from'}})
  {
    if ($_->{'alias'} eq $alias)
    {
      $t = $_;
      last;
    }
  }
  die "TODO: Can't find '$alias'" unless $t;
  
  $t->{'join'} = uc($params->{'type'}) || 'JOIN';

  if ($params->{'on'})
  {
    $t->{'cond'} = 'ON ' . $params->{'on'};

    my $p = $params->{'params'};
    $t->{'params'} = ref($p) ? $p : [ $p ] if $p;
  }
  elsif (my $u = $params->{'using'})
  {
    my @fs = ref($u) ? @{$u} : ($u);
    local $" = ', ';
    $t->{'cond'} = "USING (@fs)";
  }

  return $self;
}

sub AddWhere
{
  my $self = shift;
  die "TODO: Add what?" unless @_;
  push(@{$self->{'where'}}, shift);
  push(@{$self->{'where_params'}}, @_);
  return $self;
}

sub AddGroupBy
{
  my $self = shift;
  push(@{$self->{'group_by'}}, @_);
  return $self;
}

sub AddHaving
{
  my $self = shift;
  die "TODO: Add what?" unless @_;
  push(@{$self->{'having'}}, shift);
  push(@{$self->{'having_params'}}, @_);
  return $self;
}

sub Build
{
  my $self = shift;
  my ($sql, @params);

  {
    my @fs = @{$self->{'select'}};
    die "TODO: No fields SELECTed" unless @fs;

    local $" = ', ';
    $sql = "SELECT @fs";
  }

  {
    my @ts = @{$self->{'from'}};
    die "TODO: No tables SELECTed" unless @ts;
    $sql .= ' FROM';

    my $c = 0;
    foreach (@ts)
    {
      $sql .= ($_->{'join'} ? ' ' . $_->{'join'} : ',') if $c++;
      $sql .= ' ' . $_->{'table'} . ' ' . $_->{'alias'};
      $sql .= ' ' . $_->{'cond'} if $_->{'cond'};

      push(@params, @{$_->{'params'}})
        if $_->{'params'};
    }
  }

  if (my @ws = @{$self->{'where'}})
  {
    @ws = map { "($_)" } @ws if $#ws;
    local $" = ' AND ';
    $sql .= " WHERE @ws";
    push(@params, @{$self->{'where_params'}});
  }

  if (my @gs = @{$self->{'group_by'}})
  {
    local $" = ', ';
    $sql .= " GROUP BY @gs";
  }

  if (my @hs = @{$self->{'having'}})
  {
    @hs = map { "($_)" } @hs if $#hs;
    local $" = ' AND ';
    $sql .= " HAVING @hs";
    push(@params, @{$self->{'having_params'}});
  }

  return ($sql, @params);
}

###### THE END ################################################################

1

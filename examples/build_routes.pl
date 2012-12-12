#! /usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

use Lingua::EN::Inflect qw ( PL );

# Load your classes here

my $class_prefix = 'Common::Prefix::';
sub class_name_to_path
{
  my $path = $_[0];
  $path =~ s/^$class_prefix//;
  $path =~ s{::}{/}g;
  $path =~ s/(?<=[0-9a-z])(?=[A-Z])/_/g;
  $path = '/' . lc(PL($path));
  return $path;
}

sub add_route
{
  my $uri_base = shift;
  say "$_->[0] $uri_base$_->[1] => $_->[2]"
    foreach (@_);
}

sub add_related_routes
{
  # TODO Relationships other than the last one is not enforced.
  #      This is just syntactic sugar for leaving off the leading
  #      </:class/:id>s.
  my ($uri_base, $path, $meta_class, $done) = @_;
  my $class_name = $meta_class->Name();

  $done ||= {};
  $done->{$class_name} = 1;

  foreach my $attr ($meta_class->GetAttributesWithFlag('relationship'))
  {
    my $attr_name = $attr->Name();
    my $attr_path = lc($attr_name);
    $attr_path =~ s/(?<=[0-9a-z])(?=[A-Z])/_/g;

    my $related = $attr->GetProperty('related') or
      die 'TODO: Unrelated relationship';
    my ($id_attr_name, $related_class_name, $related_attr_name) =
        $related =~ /^(\w+)\s*=>\s*([^.]+)\.(\w+)\z/ or
      die "TODO: Can't parse relationship";
    my $related_meta_class = $related_class_name->get_meta_class() or
        die "TODO: Can't find metadata for related '$related_class_name'";

    my $uri_params =
        {
          'class' => $class_name,
          'rel' => $attr_name
        };
    my $rel_uri = "$path/:id/$attr_path";
    my $rel_uri_id = "$rel_uri/:rel_id";

    my @routes = (
        [ 'GET',    $rel_uri,    '_list_rel',      $uri_params ]);
    push(@routes,
        [ 'GET',    $rel_uri_id, '_read_rel',      $uri_params ])
      if $related_meta_class->GetAttributeByName('id');
    push(@routes,
        [ 'POST',   $rel_uri,    '_add_rel',       $uri_params ],
        [ 'PUT',    $rel_uri,    '_replace_rel',   $uri_params ],
        [ 'PUT',    $rel_uri_id, '_edit_rel',      $uri_params ],
        [ 'DELETE', $rel_uri,    '_remove_rel',    $uri_params ],
        [ 'DELETE', $rel_uri_id, '_remove_rel_id', $uri_params ])
      if ($related_meta_class->HasFlag('api') ||
          $related_meta_class->HasFlag('api_follow_rel'));
    add_route($uri_base, @routes);

    add_related_routes(
        $uri_base, $rel_uri, $related_meta_class, $done)
      if (!$done->{$related_class_name} &&
          $related_meta_class->HasFlag('api') &&
          ($attr->GetProperty('relationship') ~~ 'has_many'));
  }
}

sub build_routes
{
  my $uri_base = $_[0] // '/api';

  my @api_classes = grep { $_->HasFlag('api') }
      GungHo::Registry::get_registered_classes();
  foreach my $meta_class (@api_classes)
  {
    my $class_name = $meta_class->Name();
    my $path = class_name_to_path($class_name);
    my $path_id = "$path/:id";

    my $uri_params = { 'class' => $class_name };
    add_route($uri_base,
        [ 'GET',    $path,    '_list',   $uri_params ],
        [ 'POST',   $path,    '_create', $uri_params ],
        [ 'GET',    $path_id, '_read',   $uri_params ],
        [ 'PUT',    $path_id, '_update', $uri_params ],
        [ 'DELETE', $path_id, '_delete', $uri_params ]);

    add_related_routes($uri_base, $path, $meta_class);
  }
}

build_routes();

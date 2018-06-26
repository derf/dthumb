#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Test::More tests => 14;

use_ok('App::Dthumb');

my $dthumb = App::Dthumb->new();

isa_ok($dthumb, 'App::Dthumb');

isa_ok($dthumb->{data}, 'App::Dthumb::Data');

is($dthumb->{config}->{dir_data}, './.dthumb', 'Data directory is .dthumb');
is($dthumb->{config}->{dir_images}, '.', 'Image directory is .');
is($dthumb->{config}->{suffix_thumbs}, '.thumbnails',
	'Thumbnail suffix is .thumbnails');
is($dthumb->{config}->{file_index}, 'index.html', 'index is index.html');

is($dthumb->{config}->{names}   ,   1, 'Show image names');
is($dthumb->{config}->{quality} ,  75, 'Default quality');
is($dthumb->{config}->{recreate},   0, 'Do not recreate');
is($dthumb->{config}->{size}    , 200, 'Default size');
is($dthumb->{config}->{spacing} , 1.1, 'Default spacing');

$dthumb = App::Dthumb->new('no-names' => 1);
is($dthumb->{config}->{names}, 0, 'Image names disabled');

$dthumb = App::Dthumb->new();

@{$dthumb->{files}} = qw(a.png b.png c.png d.jpg);
@{$dthumb->{old_thumbnails}} = 'e.png';

is_deeply($dthumb->{files}, [$dthumb->get_files()], '$dthumb->get_files()');

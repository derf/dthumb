#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Test::More;

eval "use Test::MockObject";
plan skip_all => 'Test::MockObject required' if $@;

plan tests => 14;

my @iml_scale_args;
my $iml_quality;
my $iml_save;
my ($iml_w, $iml_h);

my $mock = Test::MockObject->new();
$mock->fake_module(
	'Image::Imlib2',
	load => sub { return bless({}, $_[0]) },
	create_scaled_image => sub { @iml_scale_args = @_[1,2]; return $_[0] },
	set_quality => sub { $iml_quality = $_[1] },
	save => sub { $iml_save = $_[1] },
	width => sub { return $iml_w },
	height => sub { return $iml_h },
);

sub reset_mock_vars {
	$iml_quality = undef;
	$iml_save = undef;
	@iml_scale_args = ();
}


use_ok('App::Dthumb');

my $dthumb = App::Dthumb->new(
	size => 100,
	quality => 90,
);

isa_ok($dthumb, 'App::Dthumb');

$iml_w = 2;
$iml_h = 2;

$dthumb->create_thumbnail_image('a.png');

is(@iml_scale_args, 0, 'Small image: Do not scale');
is($iml_quality, 90, 'Set quality');
is($iml_save, './.thumbs/a.png', 'Save thumbnail');

reset_mock_vars();
$iml_w = 100;
$iml_h = 100;
$dthumb->create_thumbnail_image('a.png');

is(@iml_scale_args, 0, 'Exact match: Do not scale');
is($iml_quality, 90, 'Set quality');
is($iml_save, './.thumbs/a.png', 'Save thumbnail');

reset_mock_vars();
$iml_w = 200;
$iml_h = 100;
$dthumb->create_thumbnail_image('a.png');

is_deeply([@iml_scale_args], [100, 0], 'W too big: scale to fit X');
is($iml_quality, 90, 'Set quality');
is($iml_save, './.thumbs/a.png', 'Save thumbnail');

reset_mock_vars();
$iml_w = 100;
$iml_h = 200;
$dthumb->create_thumbnail_image('a.png');

is_deeply([@iml_scale_args], [0, 100], 'H too big: scale to fit Y');
is($iml_quality, 90, 'Set quality');
is($iml_save, './.thumbs/a.png', 'Save thumbnail');

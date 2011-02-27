#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
	build_requires => {
		'Test::More' => 0,
		'Test::Compile' => 0,
		'Test::Pod' => 0,
	},
	dist_name => 'dthumb',
	module_name => 'App::Dthumb',
	license => 'unrestricted',
	requires => {
		'perl' => '5.10.0',
		'autodie' => 0,
		'Archive::Tar' => 0,
		'Cwd' => 0,
		'Data::Section' => 0,
		'Getopt::Long' => 0,
		'Image::Imlib2' => 0,
	},
);
$build->create_build_script();

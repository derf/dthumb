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
	dist_name => 'gen-xhtml-thumbnails',
	dist_version_from => 'bin/gen-xhtml-thumbnails',
	license => 'unrestricted',
	requires => {
		'perl' => '5.10.0',
		'Archive::Tar' => 0,
		'Image::Imlib2' => 0,
	},
	script_files => 'bin/',
);
$build->create_build_script();

#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Test::More;

eval "use File::Slurp";
plan skip_all => 'File::Slurp required' if $@;

plan tests => 9;

use_ok('App::Dthumb');

my %conf = (
	file_index => 'index',
	dir_images => 't/out',
);
my @created_files;
my @indep_files = ('main.css');

my $dthumb = App::Dthumb->new(%conf);
isa_ok($dthumb, 'App::Dthumb');

$dthumb->read_directories;

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html("t/out/$file");
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.names'),
	'create_thumbnail_html / write_out_html');

unlink('t/out/index');



$conf{names} = 0;
$dthumb = App::Dthumb->new(%conf);

$dthumb->read_directories;

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html("t/out/$file");
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.no-names'),
	'create_thumbnail_html / write_out_html with names = 0');

unlink('t/out/index');



$dthumb = App::Dthumb->new(dir_images => 't/out');
$dthumb->read_directories;
$dthumb->create_files;

ok(-d 't/out/.thumbnails', 'create_files: Creates thumb dir');
ok(-d 't/out/.dthumb', 'create_files: Creates data dir');

for my $file ($dthumb->{data}->list_archived()) {
	if (-e "t/out/.dthumb/${file}") {
		push(@created_files, $file);
		unlink("t/out/.dthumb/${file}");
	}
}
rmdir('t/out/.dthumb/css');
rmdir('t/out/.dthumb/js');
rmdir('t/out/.dthumb');

is_deeply([sort $dthumb->{data}->list_archived()], [sort @created_files],
	'create_files: All files created');
@created_files = ();

$dthumb = App::Dthumb->new(%conf);

$dthumb->read_directories();

is_deeply($dthumb->{old_thumbnails}, ['t/out/invalid.png'], '{old_thumbnails}');
is_deeply($dthumb->{files}, ['t/out/one.png', 't/out/two.png'], '{files}');

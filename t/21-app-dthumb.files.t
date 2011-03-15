#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Test::More;

eval "use File::Slurp";
plan skip_all => 'File::Slurp required' if $@;

plan tests => 14;

use_ok('App::Dthumb');

my %conf = (
	file_index => 't/out/index',
	dir_images => 't/imgdir',
);
my @created_files;
my @indep_files = ('main.css');

my $dthumb = App::Dthumb->new(%conf);
isa_ok($dthumb, 'App::Dthumb');

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html($file);
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.names'),
	'create_thumbnail_html / write_out_html');

unlink('t/out/index');



$conf{names} = 0;
$dthumb = App::Dthumb->new(%conf);

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html($file);
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.no-names'),
	'create_thumbnail_html / write_out_html with names = 0');

unlink('t/out/index');



$conf{names} = 1;
$conf{lightbox} = 1;
$dthumb = App::Dthumb->new(%conf);

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html($file);
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.lightbox'),
	'create_Thumbnail_html / write_out_html with lightbox = 1');

unlink('t/out/index');



$conf{lightbox} = 0;
$dthumb = App::Dthumb->new(%conf);

for my $file (qw(one.png two.png)) {
	$dthumb->create_thumbnail_html($file);
}
$dthumb->write_out_html();

is(read_file('t/out/index'), read_file('t/cmp/index.no-lightbox'),
	'create_Thumbnail_html / write_out_html with lightbox = 0');

unlink('t/out/index');



$dthumb = App::Dthumb->new(dir_images => 't/out');
$dthumb->create_files();

ok(-d 't/out/.thumbs', 'create_files: Creates thumb dir');
ok(-d 't/out/.dthumb', 'create_files: Creates data dir');

for my $file ($dthumb->{data}->list_archived()) {
	if (-e "t/out/.dthumb/${file}") {
		push(@created_files, $file);
		unlink("t/out/.dthumb/${file}");
	}
}
rmdir('t/out/.thumbs');
rmdir('t/out/.dthumb');

is_deeply([sort $dthumb->{data}->list_archived()], [sort @created_files],
	'create_files: All files created');
@created_files = ();



$dthumb = App::Dthumb->new(dir_images => 't/out', lightbox => 0);
$dthumb->create_files();

ok(-d 't/out/.thumbs', 'create_files: Creates thumb dir (lightbox=0)');
ok(-d 't/out/.dthumb', 'create_files: Creates data dir (lightbox=0)');

for my $file (@indep_files) {
	if (-e "t/out/.dthumb/${file}") {
		push(@created_files, $file);
		unlink("t/out/.dthumb/${file}");
	}
}
rmdir('t/out/.thumbs');
rmdir('t/out/.dthumb');

is_deeply([sort @indep_files], [sort @created_files],
	'create_files: All lightbox-independent files created');
@created_files = ();



$dthumb = App::Dthumb->new(%conf);

$dthumb->read_directories();

is_deeply($dthumb->{old_thumbnails}, ['invalid.png'], '{old_thumbnails}');
is_deeply($dthumb->{files}, ['one.png', 'two.png'], '{files}');

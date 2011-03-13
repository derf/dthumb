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
	file_index => 't/out/index',
	dir_images => 't/imgdir',
);
my @create_failed;

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



$dthumb = App::Dthumb->new(dir_images => 't/out');
$dthumb->create_files();

ok(-d 't/out/.thumbs', '->create_files creates thumb dir');
ok(-d 't/out/.dthumb', '->create_files creates data dir');

for my $file ($dthumb->{data}->list_archived()) {
	if (not -e "t/out/.dthumb/${file}") {
		push(@create_failed, $file);
	}
	else {
		unlink("t/out/.dthumb/${file}");
	}
}
rmdir('t/out/.thumbs');
rmdir('t/out/.dthumb');

if (@create_failed) {
	fail("->create_files missed out " . join(' ', @create_failed));
}
else {
	pass("->create_files all okay");
}



$dthumb = App::Dthumb->new(%conf);

$dthumb->read_directories();

is_deeply($dthumb->{old_thumbnails}, ['invalid.png'], '{old_thumbnails}');
is_deeply($dthumb->{files}, ['one.png', 'two.png'], '{files}');

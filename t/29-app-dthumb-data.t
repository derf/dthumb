#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use App::Dthumb::Data;
use Test::More;

opendir(my $share, 'share');
my @files = grep { /^[^.]/ } readdir($share);
closedir($share);

my @files_archived = sort grep { ! /\.dthumb$/ } @files;

plan(
	tests => 3 + scalar @files,
);

my $dthumb = App::Dthumb::Data->new();

isa_ok($dthumb, 'App::Dthumb::Data', 'App::Dthumb::Data->new()');

for my $file (@files) {
	open(my $fh, '<', "share/${file}");
	my $data = do { local $/ = undef; <$fh> };
	close($fh);

	is($dthumb->get($file), $data, "\$dthumb->get($file)");
}

is($dthumb->get('404notfound'), undef, '$dthumb->get on non-existing file');

is_deeply([@files_archived], [sort $dthumb->list_archived()],
	'$dthumb->list_archived skips .dthumb files');

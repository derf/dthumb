#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;
use MIME::Base64 qw(encode_base64);

local $/ = undef;
my ($out_file) = @ARGV;

open(my $out_fh, '>', $out_file);
opendir(my $share_dh, 'share');

print {$out_fh} <DATA>;

for my $file (readdir($share_dh)) {
	if (substr($file, 0, 1) eq '.') {
		next;
	}

	open(my $fh, '<', "share/${file}");
	my $content = <$fh>;
	close($fh);

	if ($file =~ qr{ \. (png | gif) $ }ox) {
		$content = encode_base64($content);
	}

	printf {$out_fh} (
		"______[ %s ]______\n%s\n",
		$file,
		$content,
	);
}
closedir($share_dh);
close($out_fh);


__DATA__
package App::Dthumb::Data;

use strict;
use warnings;
use base 'Exporter';

use Data::Section -setup;
use MIME::Base64 qw(decode_base64);

our @EXPORT_OK = ();

sub new {
	my ($obj) = @_;
	my $ref = {};
	return bless($ref, $obj);
}

sub get {
	my ($self, $name) = @_;
	my $data = $self->section_data($name);

	if (not $data) {
		die("No such data: ${name}\n");
	}

	if ($name =~ qr{ \. (png | gif) $ }ox) {
		return decode_base64(${$data});
	}
	return ${$data};
}

1;

__DATA__


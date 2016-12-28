#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use File::Slurp qw(read_dir);
use MIME::Base64 qw(encode_base64);

my ($out_file) = @ARGV;

open( my $out_fh, '>', $out_file );

print {$out_fh} <DATA>;

for my $file (
	read_dir( 'share',     prefix => 1 ),
	read_dir( 'share/css', prefix => 1 ),
	read_dir( 'share/js',  prefix => 1 )
  )
{

	if ( -d $file ) {
		next;
	}

	open( my $fh, '<', $file );
	my $content = do { local $/ = undef; <$fh> };
	close($fh);

	if ( $file =~ qr{ [.] (png | gif) $ }ox ) {
		$content = encode_base64($content);
	}

	$file =~ s{ ^ share/ }{}x;

	printf {$out_fh} ( "______[ %s ]______\n%s\n", $file, $content, );
}
close($out_fh);

__DATA__
package App::Dthumb::Data;

use strict;
use warnings;

use Data::Section -setup;
use MIME::Base64 qw(decode_base64);

our $VERSION = '0.2';

sub new {
	my ($obj) = @_;

	my $ref = {};

	return bless($ref, $obj);
}

sub set_vars {
	my ($self, %vars) = @_;

	while (my ($key, $value) = each(%vars)) {
		$self->{replace}->{$key} = $value;
	}

	return;
}

sub list_archived {
	my ($self) = @_;

	return grep { ! m{ [.] dthumb $ }x } $self->section_data_names();
}

sub get {
	my ($self, $name) = @_;
	my $data = $self->section_data($name);

	if (not $data) {
		return;
	}

	$data = ${$data};

	chomp($data);

	if ($name =~ m{ [.] (png | gif) $ }ox) {
		return decode_base64($data);
	}

	while (my ($key, $value) = each %{$self->{replace}}) {
		$data =~ s{
			( \<\!-- | /\* )
				\s+ \$ $key \s+
			( --\> | \*/ )
		}{$value}gx;
	}

	return $data;
}

# * Included files in __DATA__ may use other newlines than we do
# * Since we have __DATA__ below the POD, we cannot put it after __END__
## no critic (RequireConsistentNewlines, RequirePodAtEnd)

1;

=head1 NAME

App::Dthumb::Data - Retrieve installed data (like lightbox images)

=head1 SYNOPSIS

    use App::Dthumb::Data;
    my $data = App::Dthumb::Data->new();
    
    $data->set_vars(
    	title => 'Something funky',
    );
    
    print $data->get('html_start.dthumb');
    
    open(my $fh, '>', 'close.png');
    print {$fh} $data->get('close.png');
    close($fh);

=head1 VERSION

This manual documents B<App::Dthumb::Data> version 0.2

=head1 DESCRIPTION

Since there seems to be no nice way of installing additional data with
Module::Build, this modules uses Data::Section to save all B<dthumb> data
(images, javascript, stylesheets...) in its __DATA__.  It provides methods to
retrieve this data and optionally replace certain variables in it with other
content.

While building B<App::Dthumb>, this module reads all files in the F<share>
directory and saves them in its __DATA__ section.

=head1 METHODS

=over

=item $data = App::Dthumb::Data->new()

Returns a new B<App::Dthumb::Data> object. Does not take any arguments.

=item $data->set_vars(I<%vars>)

Set replacement variables.  For each hash key, when outputting data using the
B<get> function, dthumb will replace occurences of "<!-- $key -->" or "/* $key
*/" (the dollar sign is literal) with its value.

=item $data->list_archived()

Returns an array of all saved data.  That is, all files which do not end in
".dthumb".

=item $data->get($filename)

Returns the exact content of share/$filename (undef if no such file was
saved).

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Data::Section

=back

=head1 BUGS AND LIMITATIONS

So far, none are known.  This module has proved to work fine with both binary
and ASCII files.

However, since it encodes binary files with base64, you shouldn't use it with
too many / too large files, otherwise you'll end up with a rather big module
file.

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@chaosdorf.deE<gt>

=head1 LICENSE

    0. You just DO WHAT THE FUCK YOU WANT TO.

=cut

__DATA__

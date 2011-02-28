package App::Dthumb;


=head1 NAME

App::Dthumb - Generate thumbnail index for a set of images

=head1 SYNOPSIS

    use App::Dthumb;
    use Getopt::Long qw(:config no_ignore_case);
    
    my $opt = {};
    
    GetOptions(
    	$opt,
    	qw{
    		help|h
    		size|d=i
    		spacing|s=f
    		no-lightbox|L
    		no-names|n
    		quality|q=i
    		version|v
    	},
    );
    
    my $dthumb = App::Dthumb->new($opt);
    $dthumb->run();

=head1 VERSION

This manual documents App::Dthumb version 0.1

=cut


use strict;
use warnings;
use autodie;
use 5.010;

use base 'Exporter';

use App::Dthumb::Data;
use Cwd;
use Image::Imlib2;
use IO::Handle;
use Time::Progress;

our @EXPORT_OK = ();
our $VERSION = '0.1';

STDERR->autoflush(1);


=head1 METHODS

=head2 new($conf)

Returns a new B<App::Dthumb> object. As you can see in the SYNOPSIS, $conf is
designed so that it can be directly fed by B<Getopt::Long>.

Valid hash keys are:

=over

=item B<help> => I<bool>

If true, prints a short help message to STDOUT and quits

Default: false

=item B<size> => I<int>

Maximum image size in pixels, either width or height (depending on image
orientation)

Default: 200

=item B<spacing> => I<float>

Spacing between image boxes. 1.0 means each box is exactly as wide as the
maximum image width (see B<size>), 1.1 means slightly larger, et cetera

Default: 1.1

=item B<no-lightbox> => I<bool>

Do not show include javascript lightbox code

Default: false

=item B<no-names> => I<bool>

Do not show image name below thumbnail

Default: false

=item B<quality> => I<0 .. 100>

Thumbnail image quality

Default: 75

=item B<version> => I<bool>

If true, prints version information to STDOUT and quits

Default: false

=back

=cut


sub new {
	my ($obj, $conf) = @_;
	my $ref = {};

	$conf->{size}    //= 200;
	$conf->{spacing} //= 1.1;
	$conf->{quality} //= 75;
	$conf->{lightbox}  = !$conf->{'no-lightbox'};
	$conf->{names}     = !$conf->{'no-names'};

	$ref->{config} = $conf;

	$ref->{data} = App::Dthumb::Data->new();
	$ref->{timer} = Time::Progress->new();

	$ref->{html} = $ref->{data}->get('html_start');

	$ref->{current_file_id} = 0;

	$ref->{config}->{file_index}    = 'index.xhtml';
	$ref->{config}->{dir_thumbs}    = '.thumbs';
	$ref->{config}->{dir_data}      = '.dthumb';

	return bless($ref, $obj);
}


=head2 run

Run dthumb.  Read all files, create thumbnails, write index.xhtml, and so on.

=cut


sub run {
	my ($self) = @_;

	$self->check_cmd_flags();
	$self->read_directories();
	$self->create_files();
	$self->delete_old_thumbnails();
	$self->create_thumbnails();
	$self->write_out_html();
}


=head1 INTERNALS

The following methods are internal only and do not need to be called by
external scripts.  This documentation is only for people working on
B<App::Dthumb> itself.  All of them are object-oriented, so need to be called
as $dthumb->something().

=head2 check_cmd_flags

Check if version/help flags in the config are set.  If so, print the
corresponding text to STDOUT and quit.

=cut


sub check_cmd_flags {
	my ($self) = @_;

	if ($self->{config}->{version}) {
		say "dthumb version ${VERSION}";
		exit 0;
	}
	if ($self->{config}->{help}) {
		say "Please refer to perldoc -F $0 (or man dthumb)";
		exit 0;
	}
}


=head2 read_directories

Store all image files in the current directory in $self->{files} (arrayref),
and all files in F<.thumbs> which do not have a corresponding full-size image
in $self->{old_thumbnails}.  $self->{files} is sorted case-insensitively.

=cut


sub read_directories {
	my ($self) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};
	my $imgdir   = '.';
	my $dh;
	my (@files, @old_thumbs);

	opendir($dh, $imgdir);

	for my $file (readdir($dh)) {
		if (-f $file and $file =~ qr{ \. (png | jp e? g) $ }iox) {
			push(@files, $file);
		}
	}
	closedir($dh);

	if (-d $thumbdir) {
		opendir($dh, $thumbdir);
		for my $file (readdir($dh)) {
			if ($file =~ qr{^ [^.] }ox and not -f $file) {
				push(@old_thumbs, $file);
			}
		}
		closedir($dh);
	}

	@{$self->{files}} = sort { lc($a) cmp lc($b) } @files;
	@{$self->{old_thumbnails}} = @old_thumbs;

	$self->{timer}->attr(
		min => 1,
		max => scalar @files,
	);
}


=head2 create_files

Makes sure the F<.thumbs> directory exists.

If $self->{conf}->{lightbox} is true (which is the default), also creates the
F<.dthumb> directory and fills it with F<lightbox.js>, F<overlay.png>,
F<loading.gif> and F<close.gif>.

=cut


sub create_files {
	my ($self) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};
	my $datadir  = $self->{config}->{dir_data};

	if (not -d $thumbdir) {
		mkdir($thumbdir);
	}

	if ($self->{config}->{lightbox}) {

		if (not -d $datadir) {
			mkdir($datadir);
		}

		for my $file (qw(close.png loading.gif next.png pause.png play.png
				previous.png shadowbox.css shadowbox.js)) {
			open(my $fh, '>', "${datadir}/${file}");
			print {$fh} $self->{data}->get($file);
			close($fh);
		}
	}
}


=head2 delete_old_thumbnails

Unlink all no longer required thumbnails (those saved in
$self->{old_thumbnails}).

=cut


sub delete_old_thumbnails {
	my ($self) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};

	for my $file (@{$self->{old_thumbnails}}) {
		unlink("${thumbdir}/${file}");
	}
}


=head2 create_thumbnails

Iterate over all files in $self->{files}, print a progress bar to STDERR and
call B<create_thumbnail_html> and B<create_thumbnail_image> for each.

=cut


sub create_thumbnails {
	my ($self) = @_;

	for my $file (@{$self->{files}}) {

		print STDERR $self->{timer}->report(
			"\r\e[KCreating Thumbnails: %p done, %L elapsed, %E remaining",
			++$self->{current_file_id},
		);

		$self->create_thumbnail_html($file);
		$self->create_thumbnail_image($file);
	}
	print "\n";
}


=head2 create_thumbnail_html($file)

Append the necessary lines for $file to the HTML.

=cut


sub create_thumbnail_html {
	my ($self, $file) = @_;
	my $div_width = $self->{config}->{size} * $self->{config}->{spacing};
	my $div_height = $div_width + ($self->{config}->{names} ? 10 : 0);

	$self->{html} .= sprintf(
		"<div style=\"%s; %s; %s; width: %dpx; height: %dpx\">\n",
		'text-align: center',
		'font-size: 80%',
		'float: left',
		$div_width,
		$div_height,
	);
	$self->{html} .= sprintf(
		"\t<a rel=\"shadowbox[main]\" href=\"%s\">\n"
		. "\t\t<img src=\"%s/%s\" alt=\"%s\" /></a>\n",
		$file,
		$self->{config}->{dir_thumbs},
		($file) x 2,
	);
	if ($self->{config}->{names}) {
		$self->{html} .= sprintf(
			"\t<br />\n"
			. "\t<a style=\"%s;\" href=\"%s\">%s</a>\n",
			'text-decoration: none',
			($file) x 2,
		);
	}
	$self->{html} .= "</div>\n";
}


=head2 create_thumbnail_image($file)

Load F<$file> and save a resized version in F<.thumbs/$file>.  Returns if the
thumbnail file already exists, so far it doesn't do any further checks.

=cut


sub create_thumbnail_image {
	my ($self, $file) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};
	my $thumb_dim = $self->{config}->{size};

	if (-e "${thumbdir}/${file}") {
		return;
	}

	my $image = Image::Imlib2->load($file);
	my ($dx, $dy) = ($image->width(), $image->height());
	my $thumb = $image;

	if ($dx > $thumb_dim or $dy > $thumb_dim) {
		if ($dx > $dy) {
			$thumb = $image->create_scaled_image($thumb_dim, 0);
		}
		else {
			$thumb = $image->create_scaled_image(0, $thumb_dim);
		}
	}

	$thumb->set_quality($self->{config}->{quality});
	$thumb->save("${thumbdir}/${file}");
}


=head2 write_out_html

Write the cached HTML data to F<index.xhtml>.

=cut


sub write_out_html {
	my ($self) = @_;

	$self->{html} .= $self->{data}->get('html_end');

	open(my $fh, '>', $self->{config}->{file_index});
	print {$fh} $self->{html};
	close($fh);
}

#sub print_progress {
#	my ($self) = @_;
#	my $num  = $self->{current_file_id};
#	my $name = $self->{current_file_name};
#
#	if (($num % 60) == 0) {
#		if ($number) {
#			printf(" %4d/%d\n", $number, scalar(@files));
#		}
#		printf('[%3d%%] ', $number * 100 / @files);
#	} elsif (($number % 10) == 0) {
#		print ' ';
#	}
#	return;
#}

1;

__END__

=head1 DEPENDENCIES

=over

=item * App::Dthumb::Data

=item * Image::Imlib2

=item * Time::Progress

=back

=head1 AUTHOR

Copyright (C) 2009-2011 by Daniel Friesel E<gt>derf@chaosdorf.deE<lt>

=head1 LICENSE

    0. You just DO WHAT THE FUCK YOU WANT TO.

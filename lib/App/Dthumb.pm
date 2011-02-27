package App::Dthumb;

use strict;
use warnings;
use autodie;
use 5.010;

use base 'Exporter';

use App::Dthumb::Data;
use Cwd;
use Image::Imlib2;

our @EXPORT_OK = ();
our $VERSION = '0.1';

local $| = 1;

sub new {
	my ($obj, $conf) = @_;
	my $ref = {};

	$conf->{size}    //= 200;
	$conf->{spacing} //= 1.1;
	$conf->{quality} //= 75;
	$conf->{names}     = !$conf->{'no-names'};

	$ref->{config} = $conf;

	$ref->{data} = App::Dthumb::Data->new();

	$ref->{html} = $ref->{data}->get('html_start');

	$ref->{current_file_id} = 0;

	$ref->{config}->{file_index}    = 'index.xhtml';
	$ref->{config}->{file_lightbox} = 'lightbox.js';
	$ref->{config}->{dir_thumbs}    = '.thumbs';
	$ref->{config}->{dir_data}      = '.dthumb';

	return bless($ref, $obj);
}

sub run {
	my ($self) = @_;

	$self->check_cmd_flags();
	$self->read_directories();
	$self->create_files();
	$self->delete_old_thumbnails();
	$self->create_thumbnails();
	$self->write_out_html();
}

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
}

sub create_files {
	my ($self) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};
	my $datadir  = $self->{config}->{dir_data};

	if (not -d $thumbdir) {
		mkdir($thumbdir);
	}

	if (not -d $datadir) {
		mkdir($datadir);
	}

	for my $file (qw(lightbox.js overlay.png loading.gif close.gif)) {
		open(my $fh, '>', "${datadir}/${file}");
		print {$fh} $self->{data}->get($file);
		close($fh);
	}
}

sub delete_old_thumbnails {
	my ($self) = @_;
	my $thumbdir = $self->{config}->{dir_thumbs};

	for my $file (@{$self->{old_thumbnails}}) {
		unlink("${thumbdir}/${file}");
	}
}

sub create_thumbnails {
	my ($self) = @_;

	for my $file (@{$self->{files}}) {
		$self->create_thumbnail_html($file);
		$self->create_thumbnail_image($file);
	}
}

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
		"\t<a rel=\"lightbox\" href=\"%s\">\n"
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

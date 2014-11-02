package App::Dthumb;

use strict;
use warnings;
use autodie;
use 5.010;

use App::Dthumb::Data;
use Cwd;
use Image::Imlib2;

our $VERSION = '0.2';

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = {};

	$conf{quality}  //= 75;
	$conf{recreate} //= 0;
	$conf{size}     //= 200;
	$conf{spacing}  //= 1.1;
	$conf{title}    //= ( split( qr{/}, cwd() ) )[-1];

	$conf{file_index} //= 'index.xhtml';
	$conf{dir_images} //= q{.};

	$conf{dir_data}   = "$conf{dir_images}/.dthumb";
	$conf{dir_thumbs} = "$conf{dir_images}/.thumbs";

	# helpers to directly pass GetOptions results
	$conf{lightbox} //= (
		(
			     $conf{'no-lightbox'}
			  or $conf{shadowbox}
		) ? 0 : 1
	);
	$conf{names} //= ( $conf{'no-names'} ? 0 : 1 );

	$ref->{config} = \%conf;

	$ref->{data} = App::Dthumb::Data->new();

	$ref->{data}->set_vars(
		title  => $conf{title},
		width  => $conf{size} * $conf{spacing} . 'px',
		height => $conf{size} * $conf{spacing} . 'px',
	);

	if ( $conf{lightbox} ) {
		$ref->{data}->set_vars(
			lightbox => $ref->{data}->get('lightbox/html_load.dthumb'), );
	}
	elsif ( $conf{shadowbox} ) {
		$ref->{data}->set_vars(
			lightbox => $ref->{data}->get('shadowbox/html_load.dthumb'), );
	}

	$ref->{html} = $ref->{data}->get('html_start.dthumb');

	return bless( $ref, $obj );
}

sub read_directories {
	my ($self) = @_;

	my $thumbdir = $self->{config}->{dir_thumbs};
	my $imgdir   = $self->{config}->{dir_images};
	my $dh;
	my ( @files, @old_thumbs );

	opendir( $dh, $imgdir );

	for my $file ( readdir($dh) ) {
		if ( -f "${imgdir}/${file}"
			and $file =~ qr{ [.] (png | jp e? g) $ }iox )
		{
			push( @files, $file );
		}
	}
	closedir($dh);

	if ( -d $thumbdir ) {
		opendir( $dh, $thumbdir );
		for my $file ( readdir($dh) ) {
			if ( $file =~ qr{^ [^.] }ox and not -f "${imgdir}/${file}" ) {
				push( @old_thumbs, $file );
			}
		}
		closedir($dh);
	}

	@{ $self->{files} } = sort { lc($a) cmp lc($b) } @files;
	@{ $self->{old_thumbnails} } = @old_thumbs;

	return;
}

sub create_files {
	my ($self) = @_;

	my $thumbdir = $self->{config}->{dir_thumbs};
	my $datadir  = $self->{config}->{dir_data};
	my @files;

	for my $dir ( $thumbdir, $datadir, "${datadir}/lightbox",
		"${datadir}/shadowbox" )
	{
		if ( not -d $dir ) {
			mkdir($dir);
		}
	}

	if ( $self->{config}->{lightbox} or $self->{config}->{shadowbox} ) {
		@files = $self->{data}->list_archived();
	}
	else {
		@files = ('main.css');
	}

	for my $file (@files) {
		open( my $fh, '>', "${datadir}/${file}" );
		print {$fh} $self->{data}->get($file);
		close($fh);
	}

	return;
}

sub delete_old_thumbnails {
	my ($self) = @_;

	my $thumbdir = $self->{config}->{dir_thumbs};

	for my $file ( @{ $self->{old_thumbnails} } ) {
		unlink("${thumbdir}/${file}");
	}

	return;
}

sub get_files {
	my ($self) = @_;

	return @{ $self->{files} };
}

sub create_thumbnail_html {
	my ( $self, $file ) = @_;

	my $div_width = $self->{config}->{size} * $self->{config}->{spacing};
	my $div_height = $div_width + ( $self->{config}->{names} ? 10 : 0 );

	$self->{html} .= "<div class=\"image-container\">\n";

	$self->{html} .= sprintf(
		"\t<a rel=\"lightbox\" href=\"%s\" title=\"%s\">\n"
		  . "\t\t<img src=\"%s/%s\" alt=\"%s\" /></a>\n",
		($file) x 2,
		$self->{config}->{dir_thumbs},
		($file) x 2,
	);

	if ( $self->{config}->{names} ) {
		$self->{html} .= sprintf(
			"\t<br />\n" . "\t<a style=\"%s;\" href=\"%s\">%s</a>\n",
			'text-decoration: none',
			($file) x 2,
		);
	}

	$self->{html} .= "</div>\n";

	return;
}

sub create_thumbnail_image {
	my ( $self, $file ) = @_;

	my $thumbdir  = $self->{config}->{dir_thumbs};
	my $thumb_dim = $self->{config}->{size};

	if (    -e "${thumbdir}/${file}"
		and not $self->{config}->{recreate}
		and ( stat($file) )[9] <= ( stat("${thumbdir}/${file}") )[9] )
	{
		return;
	}

	my $image = Image::Imlib2->load($file);
	my ( $dx, $dy ) = ( $image->width(), $image->height() );
	my $thumb = $image;

	if ( $dx > $thumb_dim or $dy > $thumb_dim ) {
		if ( $dx > $dy ) {
			$thumb = $image->create_scaled_image( $thumb_dim, 0 );
		}
		else {
			$thumb = $image->create_scaled_image( 0, $thumb_dim );
		}
	}

	$thumb->set_quality( $self->{config}->{quality} );
	$thumb->save("${thumbdir}/${file}");

	return;
}

sub write_out_html {
	my ($self) = @_;

	$self->{html} .= $self->{data}->get('html_end.dthumb');

	open( my $fh, '>', $self->{config}->{file_index} );
	print {$fh} $self->{html};
	close($fh);

	return;
}

1;

__END__

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

This manual documents App::Dthumb version 0.2

=head1 DESCRIPTION

App::Dthumb does all the backend work for dthumb(1).

=head1 METHODS

=over

=item $dthumb = App::Dthumb->new(I<%conf>)

Returns a new B<App::Dthumb> object. As you can see in the SYNOPSIS, I<%conf> is
designed so that it can be directly passed from B<Getopt::Long>.

Valid hash keys are:

=over

=item B<dir_images> => I<directory>

Set base directory for image reading, data creation etc.

Default: F<.> (current working directory)

=item B<file_index> => I<file>

Set name of the html index file

Default: F<index.xhtml>

=item B<lightbox> => I<bool>

Include and use javascript lightbox code

Default: true

=item B<recreate> => I<bool>

If true, unconditionally recreate all thumbnails.

Default: false

=item B<size> => I<int>

Maximum image size in pixels, either width or height (depending on image
orientation)

Default: 200

=item B<spacing> => I<float>

Spacing between image boxes. 1.0 means each box is exactly as wide as the
maximum image width (see B<size>), 1.1 means slightly larger, et cetera

Default: 1.1

=item B<names> => I<bool>

Show image name below thumbnail

Default: true

=item B<quality> => I<0 .. 100>

Thumbnail image quality

Default: 75

=back

=item $dthumb->read_directories()

Read in a list of all image files in the current directory and all files in
F<.thumbs> which do not have a corresponding full-size image.

=item $dthumb->create_files()

Makes sure the F<.thumbs> directory exists.

Also, if lightbox is enabled (which is the default), creates the F<.dthumb>
directory and fills it with all required files.

=item $dthumb->delete_old_thumbnails()

Unlink all no longer required thumbnails (as previously found by
B<read_directories>).

=item $dthumb->get_files()

Returns an array of all image files found by B<read_directories>.

=item $dthumb->create_thumbnail_html($file)

Append the necessary lines for $file to the HTML.

=item $dthumb->create_thumbnail_image($file)

Load F<$file> and save a resized version in F<.thumbs/$file>.  Skips thumbnail
generation if the thumbnail already exists and has a more recent mtime than
the original file.

=item $dthumb->write_out_html()

Write the cached HTML data to F<index.xhtml>.

=back

=head1 DIAGNOSTICS

None yet.

=head1 DEPENDENCIES

=over

=item * App::Dthumb::Data

=item * Image::Imlib2

=back

=head1 BUGS AND LIMITATIONS

So far, this module is pretty focused on working with dthumb(1).  It is
planned to make it somewhat more universal.

=head1 AUTHOR

Copyright (C) 2009-2011 by Daniel Friesel E<lt>derf@chaosdorf.deE<gt>

=head1 LICENSE

    0. You just DO WHAT THE FUCK YOU WANT TO.

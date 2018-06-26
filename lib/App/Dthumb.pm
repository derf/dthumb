package App::Dthumb;

use strict;
use warnings;
use 5.010;

use App::Dthumb::Data;
use Cwd;
use File::Copy qw(copy);
use File::Slurp qw(read_dir write_file);
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

	$conf{file_index} //= 'index.html';
	$conf{dir_images} //= q{.};

	$conf{dir_data}      = "$conf{dir_images}/.dthumb";
	$conf{suffix_thumbs} = '.thumbnails';

	$conf{names} //= ( $conf{'no-names'} ? 0 : 1 );

	$conf{oxygen_base} //= '/usr/share/icons/oxygen/base';

	$ref->{config} = \%conf;

	$ref->{data} = App::Dthumb::Data->new();

	$ref->{data}->set_vars(
		title  => $conf{title},
		width  => $conf{size} * $conf{spacing} . 'px',
		height => $conf{size} * $conf{spacing} . 'px',
	);

	return bless( $ref, $obj );
}

sub read_directories {
	my ($self) = @_;

	my $thumbdir = $self->{config}->{suffix_thumbs};
	my $imgdir   = $self->{config}->{dir_images};
	my ( @files, @old_thumbs );

	my @queue = read_dir( $imgdir, prefix => 1 );
	my @paths = ($imgdir);

	for my $path (@queue) {
		my ( $basedir, $file ) = ( $path =~ m{ ^ (.*) / ([^/]*) $ }x );
		if ( $file =~ m{ ^ [.] }x ) {
			next;
		}
		if ( $file eq 'index.html' ) {
			next;
		}
		if ( -f $path
			and
			( $self->{config}{all} or $file =~ m{ [.] (png | jp e? g) $ }ix ) )
		{
			push( @files, $path );
		}
		elsif ( $self->{config}{recursive} and -d $path ) {
			push( @files, $path );
			push( @queue, read_dir( $path, prefix => 1 ) );
			push( @paths, $path );
		}
	}

	for my $path (@paths) {
		if ( -d "${path}/${thumbdir}" ) {
			for my $file ( read_dir("${path}/${thumbdir}") ) {
				if ( $file =~ m{^ [^.] }ox and not -f "${path}/${file}" ) {
					push( @old_thumbs, "${path}/$file" );
				}
			}
		}
		$self->{html}->{$path} = $self->{data}->get('html_start.dthumb');
	}

	@{ $self->{files} } = sort { lc($a) cmp lc($b) } @files;
	@{ $self->{paths} } = sort { lc($a) cmp lc($b) } @paths;
	@{ $self->{old_thumbnails} } = @old_thumbs;

	return;
}

sub create_files {
	my ($self) = @_;

	my $thumbdir = $self->{config}->{suffix_thumbs};
	my $datadir  = $self->{config}->{dir_data};
	my @files    = $self->{data}->list_archived;
	my @icons;

	if ( $self->{config}{all} ) {
		push( @icons, 'mimetypes/unknown.png' );
	}
	if ( $self->{config}{recursive} ) {
		push( @icons, 'places/folder-blue.png' );
	}

	for my $dir ( $datadir, "${datadir}/css", "${datadir}/js" ) {
		if ( not -d $dir ) {
			mkdir($dir);
		}
	}

	for my $path ( @{ $self->{paths} } ) {
		if ( not -d "${path}/${thumbdir}" ) {
			mkdir("${path}/${thumbdir}");
		}
	}

	for my $file (@files) {
		write_file( "${datadir}/${file}", $self->{data}->get($file) );
	}

	for my $icon (@icons) {
		my ( $dir, $file ) = split( qr{/}, $icon );
		my $base = $self->{config}{oxygen_base};
		copy( "${base}/128x128/${dir}/${file}", "${datadir}/${file}" );
	}

	return;
}

sub delete_old_thumbnails {
	my ($self) = @_;

	for my $file ( @{ $self->{old_thumbnails} } ) {
		unlink($file);
	}

	return;
}

sub get_files {
	my ($self) = @_;

	return @{ $self->{files} };
}

sub create_thumbnail_html {
	my ( $self, $path ) = @_;

	my $div_width = $self->{config}->{size} * $self->{config}->{spacing};
	my $div_height = $div_width + ( $self->{config}->{names} ? 10 : 0 );

	my ( $basedir, $file ) = ( $path =~ m{ ^ (.*) / ([^/]*) $ }x );

	my $html = \$self->{html}->{$basedir};

	$$html .= "<div class=\"image-container\">\n";

	if ( -d $path ) {
		$$html .= sprintf(
			"\t<a href=\"%s\" title=\"%s\">\n"
			  . "\t\t<img src=\"<!--BASE-->.dthumb/folder-blue.png\" alt=\"%s\" /></a>\n",
			($file) x 3,
		);
	}
	elsif ( $file =~ m{ [.] (png | jp e? g) $ }ix ) {
		$$html .= sprintf(
"\t<a class=\"fancybox\" href=\"%s\" title=\"%s\" data-fancybox-group=\"gallery\">\n"
			  . "\t\t<img src=\"%s/%s\" alt=\"%s\" /></a>\n",
			($file) x 2,
			$self->{config}->{suffix_thumbs},
			($file) x 2,
		);
	}
	else {
		$$html .= sprintf(
			"\t<a href=\"%s\" title=\"%s\">\n"
			  . "\t\t<img src=\"<!--BASE-->.dthumb/unknown.png\" alt=\"%s\" /></a>\n",
			($file) x 3,
		);
	}

	if ( $self->{config}->{names} or -d $file ) {
		$$html .= sprintf(
			"\t<br />\n" . "\t<a style=\"%s;\" href=\"%s\">%s</a>\n",
			'text-decoration: none',
			($file) x 2,
		);
	}

	$$html .= "</div>\n";

	return;
}

sub create_thumbnail_image {
	my ( $self, $path ) = @_;

	my $thumbdir  = $self->{config}->{suffix_thumbs};
	my $thumb_dim = $self->{config}->{size};

	my ( $basedir, $file ) = ( $path =~ m{ ^ (.*) / ([^/]*) $ }x );

	if (    -e "${basedir}/${thumbdir}/${file}"
		and not $self->{config}->{recreate}
		and ( stat($path) )[9]
		<= ( stat("${basedir}/${thumbdir}/${file}") )[9] )
	{
		return;
	}
	if ( -d $path
		or $self->{config}{all}
		and not( $file =~ m{ [.] (png | jp e? g) $ }ix ) )
	{
		return;
	}

	my $image = Image::Imlib2->load($path);
	my ( $dx, $dy ) = ( $image->width, $image->height );
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
	$thumb->save("${basedir}/${thumbdir}/${file}");

	return;
}

sub write_out_html {
	my ($self) = @_;

	my $index_name = $self->{config}->{file_index};

	for my $path ( @{ $self->{paths} } ) {
		my $diff = substr( $path, length( $self->{config}->{dir_images} ) );
		my $path_to_base = q{};
		if ( length($diff) ) {
			$path_to_base = '../' x ( scalar split( qr{/}, $diff ) - 1 );
		}
		$self->{html}->{$path} .= $self->{data}->get('html_end.dthumb');
		$self->{html}->{$path} =~ s{<!--BASE-->}{$path_to_base}g;
		write_file( "${path}/${index_name}", $self->{html}->{$path} );
	}

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
    		no-names|n
    		quality|q=i
    		version|v
    	},
    );
    
    my $dthumb = App::Dthumb->new($opt);
    $dthumb->run;

=head1 VERSION

This manual documents App::Dthumb version 0.2

=head1 DESCRIPTION

App::Dthumb does the backend work for dthumb(1).

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

Default: F<index.html>

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

=item $dthumb->read_directories

Read in a list of all image files in the current directory and all files in
F<.thumbs> which do not have a corresponding full-size image.

=item $dthumb->create_files

Makes sure the F<.thumbs> directory exists.

Also, if lightbox is enabled (which is the default), creates the F<.dthumb>
directory and fills it with all required files.

=item $dthumb->delete_old_thumbnails

Unlink all no longer required thumbnails (as previously found by
B<read_directories>).

=item $dthumb->get_files

Returns an array of all image files found by B<read_directories>.

=item $dthumb->create_thumbnail_html($file)

Append the necessary lines for $file to the HTML.

=item $dthumb->create_thumbnail_image($file)

Load F<$file> and save a resized version in F<.thumbs/$file>.  Skips thumbnail
generation if the thumbnail already exists and has a more recent mtime than
the original file.

=item $dthumb->write_out_html

Write the cached HTML data to F<index.html>.

=back

=head1 DIAGNOSTICS

None yet.

=head1 DEPENDENCIES

=over

=item * App::Dthumb::Data

=item * Image::Imlib2

=back

=head1 BUGS AND LIMITATIONS

To be determined.

=head1 AUTHOR

Copyright (C) 2009-2016 by Daniel Friesel E<lt>derf@chaosdorf.deE<gt>

=head1 LICENSE

    0. You just DO WHAT THE FUCK YOU WANT TO.

package Image::EXIF;

use 5.008;
use strict;
use warnings;

our $VERSION = '1.00.3';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub new {
    my ($class, $file_name) = @_;

    my $self = bless {}, $class;

    $self->file_name($file_name) if $file_name && $file_name ne '';
    $self->{errstr} = [];

    return $self;
}

sub file_name {
    my ($self, $file_name) = @_;

    $self->{file_name} = $file_name
        if defined $file_name && $file_name ne '';

    if (defined $self->{file_name} && $self->{file_name} ne '') {
        c_read_file($self->{file_name});
    }
    else {
        push @{ $self->{errstr} }, 'Please set file_name';
    }

    return $self->{file_name};
}

sub error {
    my ($self) = @_;

    return @{ $self->{errstr} };
}

sub errstr {
    my ($self) = @_;

    return shift @{ $self->{errstr} };
}

sub get_camera_info {
    my ($self) = @_;

    if (c_errstr()) {
        push @{ $self->{errstr} }, c_errstr();
        return undef;
    }

    c_get_camera_info();
    return __fetch_data();
}

sub get_image_info {
    my ($self) = @_;

    if (c_errstr()) {
        push @{ $self->{errstr} }, c_errstr();
        return undef;
    }

    c_get_image_info();
    return __fetch_data();
}

sub get_other_info {
    my ($self) = @_;

    if (c_errstr()) {
        push @{ $self->{errstr} }, c_errstr();
        return;
    }

    c_get_other_info();
    return __fetch_data();
}

sub get_unknown_info {
    my ($self) = @_;

    if (c_errstr()) {
        push @{ $self->{errstr} }, c_errstr();
        return;
    }

    c_get_unknown_info();
    return __fetch_data();
}

sub get_all_info {
    my ($self) = @_;

    if (c_errstr()) {
        push @{ $self->{errstr} }, c_errstr();
        return;
    }

    my %hash;
    for my $key (qw<camera image other unknown>) {
        my $method = "get_$key\_info";
        my $data = $self->$method or next;
        $hash{$key} = $data;
    }

    return %hash ? \%hash : undef;
}

sub DESTROY {
    c_close_all();
}

sub __fetch_data {

    my %data;
    while (my ($name, $value) = c_fetch()) {
        next if $name eq '';
        $value =~ s/\s*\z//;
        $data{$name} = $value;
    }

    return %data ? \%data : undef;
}

1;
__END__

=head1 NAME

Image::EXIF - Perl extension for exif library

=head1 SYNOPSIS

  use Image::EXIF;
  use Data::Dumper;

  my $exif = Image::EXIF->new($file_name);

  # or:
  my $exif = Image::EXIF->new;
  $exif->file_name($file_name);

  my $image_info = $exif->get_image_info(); # hash reference
  my $camera_info = $exif->get_camera_info(); # hash reference
  my $other_info = $exif->get_other_info(); # hash reference
  my $point_shoot_info = $exif->get_point_shoot_info(); # hash reference
  my $unknown_info = $exif->get_unknown_info(); # hash reference
  my $all_info = $exif->get_all_info(); # hash reference

  die $exif->errstr if $exif->error;
  print Dumper($all_info);

=head1 DESCRIPTION

Perl Package Image::EXIF based on utility exiftags v0.99.1
by Eric M. Johnston, emj@postal.net, http://johnst.org/sw/exiftags/.
Actually it's just a wrapper. Weak PHP's support of EXIF
made me write it.
If you wanna improve it - go ahead. I did this module only
because nobody did it before.

=head1 AUTHOR

sergey s prozhogin<lt>ccpro@rrelaxo.org.ru<gt>

=head1 SEE ALSO

L<exiftags>.

=cut

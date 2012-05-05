package Image::EXIF;

use 5.008;
use strict;
use warnings;

our $VERSION = '1.00.3';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub new {
    my ($class, $file_name) = @_;

    my $self = {};
    bless $self, $class;

    $self->file_name($file_name) if ($file_name && $file_name ne '');
    $self->{errstr} = [()];

    $self;
}

sub file_name {
    my $self = shift;

    if (@_) {
        my $tmp = shift || '';
        $self->{file_name} = $tmp if ($tmp ne '');
    }

    if ($self->{file_name} && $self->{file_name} ne '') {
        c_read_file($self->{file_name});
    }
    else {
        push @{$self->{errstr}}, 'Please set file_name';
    }

    $self->{file_name};
}

sub error {
    my $self = shift;

    @{$self->{errstr}};
}

sub errstr {
    my $self = shift;

    shift @{$self->{errstr}};
}

sub get_camera_info {
    my $self = shift;

    my $hash;

    if (c_errstr()) {
        push @{$self->{errstr}}, c_errstr();
    }
    else {
        c_get_camera_info();
        while (my ($fld, $val) = c_fetch()) {
            $val =~ s/\s*$//g;
            $fld eq '' && next;
            $hash->{$fld} = $val;
        }
    }
    $hash;
}

sub get_image_info {
    my $self = shift;

    my $hash;

    if (c_errstr()) {
        push @{$self->{errstr}}, c_errstr();
    }
    else {
        c_get_image_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{$fld} = $val;
        }
    }
    $hash;
}

sub get_other_info {
    my $self = shift;

    my $hash;

    if (c_errstr()) {
        push @{$self->{errstr}}, c_errstr();
    }
    else {
        c_get_other_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{$fld} = $val;
        }
    }
    $hash;
}

sub get_unknown_info {
    my $self = shift;

    my $hash;

    if (c_errstr()) {
        push @{$self->{errstr}}, c_errstr();
    }
    else {
        c_get_unknown_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{$fld} = $val;
        }
    }
    $hash;
}

sub get_all_info {
    my $self = shift;

    my $hash;

    if (c_errstr()) {
        push @{$self->{errstr}}, c_errstr();
        return;
    }
    else {
        c_get_camera_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{camera}->{$fld} = $val;
        }

        c_get_image_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{image}->{$fld} = $val;
        }

        c_get_other_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{other}->{$fld} = $val;
        }

        c_get_unknown_info();
        while (my ($fld, $val) = c_fetch()) {
            $fld eq '' && next;
            $val =~ s/\s*$//g;
            $hash->{unknown}->{$fld} = $val;
        }
    }

    $hash;
}

sub DESTROY {
    c_close_all();
}

1;
__END__

=head1 NAME

Image::EXIF - Perl extension for exif library

=head1 SYNOPSIS

  use Image::EXIF;
  use Data::Dumper;

  my $exif = new Image::EXIF ($file_name);

  # or:
  my $exif = new Image::EXIF;
  $exif->file_name($file_name);

  my $image_info = $exif->get_image_info(); # hash reference
  my $camera_info = $exif->get_camera_info(); # hash reference
  my $other_info = $exif->get_other_info(); # hash reference
  my $point_shoot_info = $exif->get_point_shoot_info(); # hash reference
  my $unknown_info = $exif->get_unknown_info(); # hash reference
  my $all_info = $exif->get_all_info(); # hash reference

  print $exif->error ?
      $exif->errstr : Dumper($all_info);

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

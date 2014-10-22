#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib';

use Math::FractalCurve;
use Imager;

unless(@ARGV) {
	die <<HERE;
Koch.pl - generate von Koch fractals as PNG images.
Usage: $0 RecursionDepth

HERE
}

my $depth = shift @ARGV;

# Filename for image.
my $filename = sprintf('Koch-Depth%02i.png', $depth);

# This generates a von Koch-curve.
my $generator = [
	[0,   0,         1/3, 0        ],
	[1/3, 0,         1/2, sqrt(5)/6],
	[1/2, sqrt(5)/6, 2/3, 0        ],
	[2/3, 0,         1,   0        ],
];

# New curve generator
my $curve_gen = Math::FractalCurve->new(generator => $generator);

# New curve
my $curve = $curve_gen->line(
	start => [-2, 0],
	end   => [2, 0],
);


# Image dimensions
my $max_x = 1000;
my $max_y = 400;

my $img = Imager->new(xsize => $max_x, ysize => $max_y);

my $edges = $curve->fractal($depth);

my $color = Imager::Color->new( 0, 0, 255 );

# Scale dimensions by 200.
@$_ = map $_*200, @$_ foreach @$edges;

foreach (@$edges) {
	$img->line(
		color => $color,
		x1 => $max_x/2 + $_->[0],
		y1 => $max_y - 50 - $_->[1],
		x2 => $max_x/2 + $_->[2],
		y2 => $max_y - 50 - $_->[3],
	);
}

$img->write(file=>$filename) or
        die $img->errstr;


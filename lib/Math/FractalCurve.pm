=head1 NAME

Math::FractalCurve - Generate fractal curves 

=head1 SYNOPSIS

  use Math::FractalCurve;

  # This generates a von Koch-curve.
  my $generator = [
      [0,   0,         1/3, 0        ],
      [1/3, 0,         1/2, sqrt(5)/6],
      [1/2, sqrt(5)/6, 2/3, 0        ],
      [2/3, 0,         1,   0        ],
  ];
  # $generator may also be an anonymous subroutine that returns a
  # data structure like the above.
  
  # New curve generator
  my $curve_gen = Math::FractalCurve->new(generator => $generator);
  
  # New curve
  my $curve = $curve_gen->line(
      start => [-2, 1],
      end   => [2, -1],
  );
  
  my $edges = $curve->fractal($depth);
  # (now containing array ref of array refs of x1,y1,x2,y2 coordinates)

=head1 DESCRIPTION

This module is intended to generate 2-dimensional fractal curves such as
the von Koch curve from simple generator functions.

The fractals are generated by recursively replacing a distance with the
generator. Hence, the starting distance and the generator define such a
fractal curve. Generators describe what a given distance is going to be
replaced with in terms of lengths of the distance. For example,
a generator of ([0, 0, 1/3, 0], [2/3, 0, 1, 0]) describes a
Mid-third Cantor Set which means the the middle third of every distance
in the set is deleted. Syntax for generator data structures in the context
of this module is [[x1, y1, x2, y2], [X1, Y1, X2, Y2]] (array ref of array
refs of edge coordinates) where xn,yn are the two coordinate pairs
specifying the first edge a distance is to be replaced with
and Xn,Yn are the second edge. There may be any number of edges.

For more telling examples, please have a thorough look at the examples
subdirectory that came with this distribution or look through the examples
page of this module on
http://steffen-mueller.net/modules/Math-FractalCurve/examples

Furthermore, the generator may be either one of the aformentioned nested
array references, or it may be an anonymous subroutine that returns such
a data structure. This enables you to generate I<probalistic> fractal curves
or generelly fractal curves whose trajectory depends on the distance any
generator is to replace.

While the above feature makes the probablistic / dynamic curves non-fractal,
they preserve some properties real fractals have. Please refer to the
literature mentioned under L<SEE ALSO> for more information. The examples
subdirectory of the distribution also holds an example of a probalistic
von Koch-curve and a Koch curve whose excavation-direction (the direction
the triangle points at) depends on the orientation of the distance the
generator is applied to (spatial.pl).

Generator subroutines are passed the curve object as first argument. They
may access any attributes of the curve segment they are applied to, but
most interestingly, they may access their {start} and {end} attributes that
hold array references [x,y] of the start- and end points of the distance
they are being applied to.

=head2 EXPORT

None.

=head1 METHODS

=cut

package Math::FractalCurve;

use 5.006;
use strict;
use warnings;

use Carp;

# obsolete!
#use constant PI     => 3.1415926535897932384626433832795;
#use constant TWOPI  => 6.283185307179586476925286766559;
#use constant HALFPI => 1.5707963267948966192313216916398;

our $VERSION = '1.00';


=head2 Constructor new

The new() constructor requires one named argument:

  generator => GENERATOR

where GENERATOR may either be a generator-datastructure as described
earlier or a subroutine reference (or closure) that returns such a
data structure.

Furthermore, new accepts any key/value pairs that will be made attributes
of the curve object.

new() is both a class- and an object method and thus can be used to clone
existing curves. (And is internally used to do so.)

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = {};
	if (ref $proto) {
		$self->{generator} = $proto->{generator};
		if (exists $proto->{end} and exists $proto->{start}) {
			$self->{end} = [@{$proto->{end}}];
			$self->{start} = [@{$proto->{start}}];
		}
	}
	for (my $i = 0; $i < @_; $i+=2) {
		$self->{$_[$i]} = $_[$i+1];
	}

	delete $self->{_edges};
	bless $self => $class;

	if (not exists $self->{generator}) {
		croak "You need to supply a generator subroutine.";
	}
	
	return $self;
}



=head2 Method line

The line() method takes two required named arguments:

  start => [START_X, START_Y],
  end   => [END_X,   END_Y  ]

where START_X, START_Y and END_X, END_Y are the coordinates of the
start- and end points of the distance to create the fractal curve from.

line() stores this data in the {start} and {end} attributes of the
curve object.

=cut

sub line {
	my $self = shift;
	my %args = @_;
	my $start = $args{start};
	my $end = $args{end};
	
	if (not defined $start or not defined $end) {
		croak "You need to supply start- and end point.";
	}

	$self = $self->new(start => $start, end => $end);
	return $self;
}



=head2 Method recurse()

The recurse() method applies the generator to the curve's distance
and returns a reference to an array of new curve objects that represent
the newly generated edges.

=cut

sub recurse {
	my $self = shift;
	my $edges = $self->edges();

	my $obj = [];
	foreach my $e (@$edges) {
		push @$obj, $self->new(
			start => [$e->[0], $e->[1]],
			end   => [$e->[2], $e->[3]],
		);
	}
	
	return $obj;
}



=head2 Method fractal()

The fractal() method takes one argument: The recursion depth of the
discrete fractal representation. Obviously, the complexity is
Edges^Depth with Edges equal to the number of edges of the generator.

fractal() returns a reference to an array of array references. These
referenced arrays contain (x1, y1, x2, y2) coordinates of edges.

=cut

sub fractal {
	my $self = shift;
	my $depth = shift;

	croak "First argument must be recursion depth!" unless defined $depth;

	return [[@{$self->{start}}, @{$self->{end}}]] if $depth <= 0;
	
	$depth--;

	my $result = [$self];
	foreach (1..$depth) {
		my $temp = [];
		foreach (@$result) {
			push @$temp, @{$_->recurse()};
		}
		$result = $temp;
	}

	@$result = map {@{$_->edges()}} @$result;
	
	return $result;
}



=head2 Method edges()

The edges() method returns a reference to an array of array references.
These referenced arrays contain (x1, y1, x2, y2) coordinates of the
edges that are generated by the generator from the curve's starting
edge.

=cut

sub edges {
	my $self = shift;

	return $self->{_edges} if exists $self->{_edges};
	my $edges;
	if (ref $self->{generator} eq 'CODE') {
		$edges = $self->{generator}->($self)
	}
	else {
		$edges = $self->{generator};
	}

	my $start = $self->{start};
	my $end   = $self->{end};
	
	my $vec = [
		$end->[0] - $start->[0],
		$end->[1] - $start->[1],
	];
	my $len = sqrt(
		$vec->[0]**2 +
		$vec->[1]**2
	);
	
	my $sin = $vec->[1]/$len;
	my $cos = $vec->[0]/$len;

	my $edges_res = [];
	foreach my $e (@$edges) {
		my ($x1, $y1, $x2, $y2) = map $_*$len, @$e;

		push @$edges_res, [
			$start->[0] + $x1*$cos - $y1*$sin,
			$start->[1] + $x1*$sin + $y1*$cos,
			$start->[0] + $x2*$cos - $y2*$sin,
			$start->[1] + $x2*$sin + $y2*$cos
		];
	}
	$self->{_edges} = $edges_res;
	return $edges_res;
}


1;
__END__

=head1 AUTHOR

Steffen Mueller, E<lt>fractal-module at steffen-mueller dot netE<gt>

=head1 SEE ALSO

New versions of this module can be found on http://steffen-mueller.net or CPAN.

The idea and some background for this module came from:

Kenneth J. Falconer, "Fractal Geometry. Mathematical Foundations and
Applications", (c) 1990 at Jon Wiley & Sons Ltd., Chichester

=cut

package Dig;
use v5.36;

use Exporter 'import';
our @EXPORT_OK = qw(dig maybe);

# Fast traversal. O(n) where n = path length, zero allocations.
# Returns undef if any intermediate step is undefined or the wrong ref type.
#
#   my $val = dig($data, 'a', 'b', 'c');
#   my $val = dig($data, 'users', 0, 'name');  # mixed hash/array
#
sub dig ($data, @path) {
    for my $key (@path) {
        return undef unless defined $data;
        if (ref $data eq 'HASH') {
            $data = $data->{$key};
        }
        elsif (ref $data eq 'ARRAY') {
            return undef unless $key =~ /\A-?[0-9]+\z/;
            $data = $data->[$key];
        }
        else {
            return undef;
        }
    }
    return $data;
}

# Chaining wrapper. Syntactic sugar over dig — prettier, slower.
#
#   my $val = maybe($data)->{'a'}->{'b'}->{'c'}->unfurl;
#   my $val = maybe($data)->{'a'}->{'b'}->{'c'}->unfurl // 'default';
#
sub maybe ($value) {
    return Dig::Maybe->new($value);
}

# ---------------------------------------------------------------------------
# Dig::Maybe — the chaining wrapper
# ---------------------------------------------------------------------------
package Dig::Maybe;
use v5.36;

use overload
    '%{}' => \&_as_hash,
    '@{}' => \&_as_array,
    '""'  => sub ($self, @) { $$self // '' },
    'bool' => sub ($self, @) { defined $$self },
    fallback => 1;

sub new ($class, $value) {
    return bless \$value, $class;
}

# Unwrap the value. Call this at the end of the chain.
sub unfurl ($self) {
    return $$self;
}

sub _as_hash ($self, @) {
    tie my %h, 'Dig::Maybe::Hash', $$self;
    return \%h;
}

sub _as_array ($self, @) {
    tie my @a, 'Dig::Maybe::Array', $$self;
    return \@a;
}

# ---------------------------------------------------------------------------
# Dig::Maybe::Hash — tied hash that returns Maybe on access
# ---------------------------------------------------------------------------
package Dig::Maybe::Hash;
use v5.36;

sub TIEHASH ($class, $value) {
    return bless {'value' => $value}, $class;
}

sub FETCH ($self, $key) {
    my $value = $self->{'value'};
    if (defined $value && ref $value eq 'HASH') {
        return Dig::Maybe->new($value->{$key});
    }
    return Dig::Maybe->new(undef);
}

sub EXISTS ($self, $key) {
    my $value = $self->{'value'};
    return 0 unless defined $value && ref $value eq 'HASH';
    return exists $value->{$key};
}

sub FIRSTKEY ($self) { return undef }
sub NEXTKEY  ($self, $last) { return undef }
sub SCALAR   ($self) { return 0 }

# ---------------------------------------------------------------------------
# Dig::Maybe::Array — tied array that returns Maybe on access
# ---------------------------------------------------------------------------
package Dig::Maybe::Array;
use v5.36;

sub TIEARRAY ($class, $value) {
    return bless {'value' => $value}, $class;
}

sub FETCH ($self, $index) {
    my $value = $self->{'value'};
    if (defined $value && ref $value eq 'ARRAY') {
        return Dig::Maybe->new($value->[$index]);
    }
    return Dig::Maybe->new(undef);
}

sub FETCHSIZE ($self) {
    my $value = $self->{'value'};
    return 0 unless defined $value && ref $value eq 'ARRAY';
    return scalar @{$value};
}

1;

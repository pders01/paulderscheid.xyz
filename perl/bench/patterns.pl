#!/usr/bin/env perl
use v5.36;
use Benchmark qw(cmpthese);

# Adversarial benchmarks for preferred Perl patterns.
# The goal: try to BREAK the patterns I like, not confirm them.
# If they survive, the conclusion is earned.

say "=" x 72;
say "Perl pattern benchmarks — adversarial edition";
say "perl $^V on $^O";
say "=" x 72;

# ---------------------------------------------------------------------------
# 1. Hashrefs vs bare hashes
#    Preferred pattern: always hashrefs.
#    Adversarial angle: tiny fixed-key hashes where dereference is overhead.
# ---------------------------------------------------------------------------

say "\n--- 1a. Hashref vs bare hash: 2-key access (favorable to bare) ---\n";
cmpthese(-3, {
    'bare_hash' => sub {
        my %h = ('name' => 'Paul', 'lang' => 'Perl');
        my $x = $h{'name'};
        my $y = $h{'lang'};
    },
    'hashref' => sub {
        my $h = {'name' => 'Paul', 'lang' => 'Perl'};
        my $x = $h->{'name'};
        my $y = $h->{'lang'};
    },
});

say "\n--- 1b. Hashref vs bare hash: slice extraction ---\n";
cmpthese(-3, {
    'bare_slice' => sub {
        my %h = ('a' => 1, 'b' => 2, 'c' => 3, 'd' => 4);
        my @vals = @h{'a', 'b', 'c', 'd'};
    },
    'hashref_slice' => sub {
        my $h = {'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4};
        my @vals = @{$h}{'a', 'b', 'c', 'd'};
    },
});

say "\n--- 1c. Hashref vs bare hash: pass to sub (where refs shine) ---\n";

sub _takes_hash (%h)   { return $h{'name'} }
sub _takes_ref  ($h)    { return $h->{'name'} }

cmpthese(-3, {
    'pass_hash' => sub {
        my %h = ('name' => 'Paul', 'lang' => 'Perl');
        _takes_hash(%h);
    },
    'pass_ref' => sub {
        my $h = {'name' => 'Paul', 'lang' => 'Perl'};
        _takes_ref($h);
    },
});

# ---------------------------------------------------------------------------
# 2. map/grep vs loops
#    Preferred pattern: map/grep for transforms and filters.
#    Adversarial angle: void context (side effects), large lists.
# ---------------------------------------------------------------------------

say "\n--- 2a. map vs foreach: void context (side effects only) ---\n";

my @source_100 = (1..100);

cmpthese(-3, {
    'map_void' => sub {
        my $sink;
        map { $sink = $_ * 2 } @source_100;
    },
    'foreach_void' => sub {
        my $sink;
        foreach my $x (@source_100) { $sink = $x * 2 }
    },
    'for_void' => sub {
        my $sink;
        for my $i (0..$#source_100) { $sink = $source_100[$i] * 2 }
    },
});

say "\n--- 2b. grep vs foreach: filter with low hit rate (1%) ---\n";

my @source_10k = (1..10_000);

cmpthese(-3, {
    'grep_filter' => sub {
        my @out = grep { $_ % 100 == 0 } @source_10k;
    },
    'foreach_filter' => sub {
        my @out;
        foreach my $x (@source_10k) {
            push @out, $x if $x % 100 == 0;
        }
    },
});

say "\n--- 2c. map vs foreach: building a new list (where map belongs) ---\n";

cmpthese(-3, {
    'map_transform' => sub {
        my @out = map { $_ * 2 } @source_100;
    },
    'foreach_push' => sub {
        my @out;
        foreach my $x (@source_100) { push @out, $x * 2 }
    },
});

# ---------------------------------------------------------------------------
# 3. Preventive checks vs exceptions
#    Preferred pattern: check before you leap.
#    Adversarial angle: unhappy path at various error rates.
# ---------------------------------------------------------------------------

say "\n--- 3a. Error handling: happy path (0% errors) ---\n";

my @inputs_ok = map { {value => $_} } 1..100;

cmpthese(-3, {
    'check_first' => sub {
        foreach my $input (@inputs_ok) {
            if (exists $input->{'value'}) {
                my $x = $input->{'value'} + 1;
            }
        }
    },
    'eval_catch' => sub {
        foreach my $input (@inputs_ok) {
            eval {
                my $x = $input->{'value'} + 1;
            };
        }
    },
});

say "\n--- 3b. Error handling: 10% error rate ---\n";

my @inputs_10pct = map { $_ % 10 == 0 ? undef : {'value' => $_} } 1..100;

cmpthese(-3, {
    'check_first' => sub {
        foreach my $input (@inputs_10pct) {
            if (defined $input && exists $input->{'value'}) {
                my $x = $input->{'value'} + 1;
            }
        }
    },
    'eval_catch' => sub {
        foreach my $input (@inputs_10pct) {
            eval {
                die "bad input" unless defined $input;
                my $x = $input->{'value'} + 1;
            };
            if ($@) {
                # handle error
            }
        }
    },
});

say "\n--- 3c. Error handling: 50% error rate ---\n";

my @inputs_50pct = map { $_ % 2 == 0 ? undef : {'value' => $_} } 1..100;

cmpthese(-3, {
    'check_first' => sub {
        foreach my $input (@inputs_50pct) {
            if (defined $input && exists $input->{'value'}) {
                my $x = $input->{'value'} + 1;
            }
        }
    },
    'eval_catch' => sub {
        foreach my $input (@inputs_50pct) {
            eval {
                die "bad input" unless defined $input;
                my $x = $input->{'value'} + 1;
            };
            if ($@) {
                # handle error
            }
        }
    },
});

# ---------------------------------------------------------------------------
# 4. Dispatch tables vs if/else
#    Preferred pattern: hash-based dispatch.
#    Adversarial angle: tiny branch counts where hash lookup overhead matters.
# ---------------------------------------------------------------------------

say "\n--- 4a. Dispatch vs if/else: 3 branches (favorable to if/else) ---\n";

my %dispatch_3 = (
    'a' => sub { 1 },
    'b' => sub { 2 },
    'c' => sub { 3 },
);
my @keys_3 = ('a', 'b', 'c');

cmpthese(-3, {
    'dispatch' => sub {
        for my $k (@keys_3) {
            my $r = $dispatch_3{$k}->();
        }
    },
    'if_else' => sub {
        for my $k (@keys_3) {
            my $r;
            if    ($k eq 'a') { $r = 1 }
            elsif ($k eq 'b') { $r = 2 }
            elsif ($k eq 'c') { $r = 3 }
        }
    },
});

say "\n--- 4b. Dispatch vs if/else: 10 branches ---\n";

my %dispatch_10 = map { ("action_$_" => sub { $_ }) } 1..10;
my @keys_10 = map { "action_$_" } 1..10;

cmpthese(-3, {
    'dispatch' => sub {
        for my $k (@keys_10) {
            my $r = $dispatch_10{$k}->();
        }
    },
    'if_else' => sub {
        for my $k (@keys_10) {
            my $r;
            if    ($k eq 'action_1')  { $r = 1 }
            elsif ($k eq 'action_2')  { $r = 2 }
            elsif ($k eq 'action_3')  { $r = 3 }
            elsif ($k eq 'action_4')  { $r = 4 }
            elsif ($k eq 'action_5')  { $r = 5 }
            elsif ($k eq 'action_6')  { $r = 6 }
            elsif ($k eq 'action_7')  { $r = 7 }
            elsif ($k eq 'action_8')  { $r = 8 }
            elsif ($k eq 'action_9')  { $r = 9 }
            elsif ($k eq 'action_10') { $r = 10 }
        }
    },
});

say "\n--- 4c. Dispatch vs if/else: 50 branches (favorable to dispatch) ---\n";

my %dispatch_50 = map { ("action_$_" => sub { $_ }) } 1..50;
my @keys_50 = map { "action_$_" } 1..50;

cmpthese(-3, {
    'dispatch' => sub {
        for my $k (@keys_50) {
            my $r = $dispatch_50{$k}->();
        }
    },
    'if_else' => sub {
        for my $k (@keys_50) {
            my $r;
            for my $i (1..50) {
                if ($k eq "action_$i") { $r = $i; last }
            }
        }
    },
});

# ---------------------------------------------------------------------------
# 5. String concatenation
#    Preferred pattern: join.
#    Adversarial angle: tiny string counts where join has call overhead.
# ---------------------------------------------------------------------------

say "\n--- 5a. String concat: 2 strings (favorable to dot) ---\n";

my ($s1, $s2) = ('hello', 'world');

cmpthese(-3, {
    'dot' => sub {
        my $r = $s1 . ' ' . $s2;
    },
    'dot_eq' => sub {
        my $r = $s1;
        $r .= ' ';
        $r .= $s2;
    },
    'join' => sub {
        my $r = join(' ', $s1, $s2);
    },
    'interpolate' => sub {
        my $r = "$s1 $s2";
    },
});

say "\n--- 5b. String concat: 20 strings ---\n";

my @strings_20 = map { "str_$_" } 1..20;

cmpthese(-3, {
    'dot_eq' => sub {
        my $r = '';
        $r .= $_ for @strings_20;
    },
    'join' => sub {
        my $r = join('', @strings_20);
    },
    'sprintf' => sub {
        my $r = sprintf('%s' x 20, @strings_20);
    },
});

say "\n--- 5c. String concat: 100 strings ---\n";

my @strings_100 = map { "str_$_" } 1..100;

cmpthese(-3, {
    'dot_eq' => sub {
        my $r = '';
        $r .= $_ for @strings_100;
    },
    'join' => sub {
        my $r = join('', @strings_100);
    },
    'sprintf' => sub {
        my $r = sprintf('%s' x 100, @strings_100);
    },
});

# ---------------------------------------------------------------------------
# 6. Sub signatures vs traditional
#    Preferred pattern: hash slice destructuring.
#    Adversarial angle: it's the slowest. Try to find when it's worth it.
# ---------------------------------------------------------------------------

say "\n--- 6a. Argument passing: 2 args ---\n";

sub _sig_2 ($a, $b)           { $a + $b }
sub _trad_2                    { my ($a, $b) = @_; $a + $b }
sub _shift_2                   { my $a = shift; my $b = shift; $a + $b }
sub _hashref_2 ($h)            { $h->{'a'} + $h->{'b'} }
sub _hash_slice_2 ($h)         { my ($a, $b) = @{$h}{'a', 'b'}; $a + $b }

cmpthese(-3, {
    'signature'  => sub { _sig_2(1, 2) },
    'traditional' => sub { _trad_2(1, 2) },
    'shift'       => sub { _shift_2(1, 2) },
    'hashref'     => sub { _hashref_2({'a' => 1, 'b' => 2}) },
    'hash_slice'  => sub { _hash_slice_2({'a' => 1, 'b' => 2}) },
});

say "\n--- 6b. Argument passing: 5 args ---\n";

sub _sig_5 ($a, $b, $c, $d, $e)   { $a + $b + $c + $d + $e }
sub _trad_5                         { my ($a, $b, $c, $d, $e) = @_; $a + $b + $c + $d + $e }
sub _hashref_5 ($h)                 { $h->{'a'} + $h->{'b'} + $h->{'c'} + $h->{'d'} + $h->{'e'} }
sub _hash_slice_5 ($h) {
    my ($a, $b, $c, $d, $e) = @{$h}{'a', 'b', 'c', 'd', 'e'};
    $a + $b + $c + $d + $e;
}

cmpthese(-3, {
    'signature'   => sub { _sig_5(1, 2, 3, 4, 5) },
    'traditional' => sub { _trad_5(1, 2, 3, 4, 5) },
    'hashref'     => sub { _hashref_5({'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4, 'e' => 5}) },
    'hash_slice'  => sub { _hash_slice_5({'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4, 'e' => 5}) },
});

say "\n--- 6c. Argument passing: named params at call site (readability cost) ---\n";

sub _named_hash (%h)  { $h{'x'} + $h{'y'} + $h{'z'} }
sub _named_ref ($h)    { $h->{'x'} + $h->{'y'} + $h->{'z'} }
sub _positional_3 ($x, $y, $z) { $x + $y + $z }

cmpthese(-3, {
    'positional'  => sub { _positional_3(1, 2, 3) },
    'named_hash'  => sub { _named_hash('x' => 1, 'y' => 2, 'z' => 3) },
    'named_ref'   => sub { _named_ref({'x' => 1, 'y' => 2, 'z' => 3}) },
});

say "\n" . "=" x 72;
say "Done. Now look at what actually won.";
say "=" x 72;

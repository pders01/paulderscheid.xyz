#!/usr/bin/env perl
use v5.36;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Dig qw(dig maybe);

# ---------------------------------------------------------------------------
# dig() — function interface
# ---------------------------------------------------------------------------

subtest 'dig: hash traversal' => sub {
    my $data = {'a' => {'b' => {'c' => 42}}};

    is dig($data, 'a', 'b', 'c'), 42, 'deep hash access';
    is dig($data, 'a', 'b'), $data->{'a'}->{'b'}, 'partial path returns ref';
    is dig($data, 'a'), $data->{'a'}, 'single key';
};

subtest 'dig: undef at various depths' => sub {
    my $data = {'a' => {'b' => undef}};

    is dig($data, 'a', 'b'), undef, 'leaf is undef';
    is dig($data, 'a', 'b', 'c'), undef, 'access past undef';
    is dig($data, 'x'), undef, 'missing top-level key';
    is dig($data, 'a', 'x', 'y'), undef, 'missing intermediate key';
};

subtest 'dig: array traversal' => sub {
    my $data = {'users' => [{'name' => 'Paul'}, {'name' => 'Tomas'}]};

    is dig($data, 'users', 0, 'name'), 'Paul', 'hash -> array -> hash';
    is dig($data, 'users', 1, 'name'), 'Tomas', 'second element';
    is dig($data, 'users', 99, 'name'), undef, 'out of bounds';
};

subtest 'dig: negative array indices' => sub {
    my $data = [10, 20, 30];

    is dig($data, -1), 30, 'negative index';
    is dig($data, -2), 20, 'negative index -2';
};

subtest 'dig: wrong ref type' => sub {
    my $data = {'a' => 'scalar'};

    is dig($data, 'a', 'b'), undef, 'string is not a ref';
    is dig(undef, 'a'), undef, 'undef root';
    is dig('string', 'a'), undef, 'scalar root';
};

subtest 'dig: non-numeric array key' => sub {
    my $data = [1, 2, 3];

    is dig($data, 'foo'), undef, 'string key on array';
};

subtest 'dig: empty path' => sub {
    my $data = {'a' => 1};

    is_deeply dig($data), $data, 'empty path returns root';
};

# ---------------------------------------------------------------------------
# maybe() — chaining interface
# ---------------------------------------------------------------------------

subtest 'maybe: hash chaining' => sub {
    my $data = {'a' => {'b' => {'c' => 42}}};

    is maybe($data)->{'a'}->{'b'}->{'c'}->unfurl, 42, 'deep chain';
    is ref maybe($data)->{'a'}->{'b'}, 'Dig::Maybe', 'intermediate is Maybe';
};

subtest 'maybe: undef chaining' => sub {
    my $data = {'a' => {'b' => undef}};

    is maybe($data)->{'a'}->{'b'}->{'c'}->unfurl, undef, 'chain past undef';
    is maybe($data)->{'x'}->{'y'}->{'z'}->unfurl, undef, 'missing key chain';
};

subtest 'maybe: array chaining' => sub {
    my $data = {'users' => [{'name' => 'Paul'}]};

    is maybe($data)->{'users'}->[0]->{'name'}->unfurl, 'Paul', 'hash -> array -> hash';
    is maybe($data)->{'users'}->[99]->{'name'}->unfurl, undef, 'out of bounds chain';
};

subtest 'maybe: undef root' => sub {
    is maybe(undef)->{'a'}->{'b'}->unfurl, undef, 'undef root chains safely';
};

subtest 'maybe: bool context' => sub {
    my $data = {'a' => 1};

    ok maybe($data), 'defined value is truthy';
    ok !maybe(undef), 'undef is falsy';
};

subtest 'maybe: with defined-or default' => sub {
    my $data = {'a' => undef};

    is maybe($data)->{'a'}->unfurl // 'default', 'default', 'unfurl // works';
    is maybe($data)->{'x'}->unfurl // 'fallback', 'fallback', 'missing key // works';
};

done_testing;

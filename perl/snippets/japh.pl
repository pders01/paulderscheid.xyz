#!/usr/bin/env perl

use Time::HiRes qw(usleep);

$| = 1;
my @p = ('a'..'z', 'A'..'Z', 0..9);
my @t = split //, 'japh';
my @o;
{
  @o = map { ($o[$_] // '') eq $t[$_] ? $t[$_] : $p[rand @p] } 0..3;
  print @o, "\r";
  usleep 25_000;
  redo unless "@o" eq "@t";
}
print "\n";

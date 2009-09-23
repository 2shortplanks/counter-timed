#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 15;

use Counter::Timed::Types qw(:all);

########################################################################

ok(defined &PositiveSeconds, "positive seconds");

ok(is_PositiveSeconds(0));
ok(is_PositiveSeconds(5));
ok(is_PositiveSeconds(100_000_000_000));
ok(!is_PositiveSeconds(-100_000_000_000));
ok(!is_PositiveSeconds(1.1));
ok(!is_PositiveSeconds("fish"));

########################################################################

ok(defined &PositiveMicroseconds, "positive microseconds");
ok(is_PositiveMicroseconds(0));
ok(is_PositiveMicroseconds(5));
ok(is_PositiveMicroseconds(999_999));
ok(!is_PositiveMicroseconds(1_000_000));
ok(!is_PositiveMicroseconds(-1));
ok(!is_PositiveMicroseconds(1.1));
ok(!is_PositiveMicroseconds("fish"));

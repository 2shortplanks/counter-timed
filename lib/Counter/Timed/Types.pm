package Counter::Timed::Types;

use strict;
use warnings;

our $VERSION = 0.01;

use MooseX::Types::Moose qw/Int/;

use MooseX::Types -declare => [qw(
  PositiveSeconds
  PositiveMicroseconds
)];


########################################################################

subtype PositiveSeconds,
  as Int,
  where { $_ >= 0 },
  message { "seconds not larger than 0" };

coerce PositiveSeconds,
  from Int,
  via { 1 };

########################################################################

subtype PositiveMicroseconds,
  as Int,
  where { $_ >= 0 && $_ < 1_000_000 },
  message { "microseconds not between 0 and 999,999 inclusive" };

coerce PositiveMicroseconds,
  from Int,
  via { 1 };

########################################################################

1;
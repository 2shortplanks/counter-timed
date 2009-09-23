#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;
use Counter::Timed;

########################################################################
# explictly pass in integer seconds and microseconds
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
    expiry_microseconds => 0,
  );

  is($counter->expiry_seconds, 30, "seconds okay");
  is($counter->expiry_microseconds, 0, "useconds okay");
}

########################################################################
# leave out the microseconds
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
  );

  is($counter->expiry_seconds, 30, "seconds okay");
  is($counter->expiry_microseconds, 0, "useconds okay");
}

########################################################################
# leave out the seconds
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry_microseconds => 1_000,
  );

  is($counter->expiry_seconds, 0, "seconds okay");
  is($counter->expiry_microseconds, 1_000, "useconds okay");
}

########################################################################
# pass in just an expiry
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry => 30,
  );

  is($counter->expiry_seconds, 30, "seconds okay");
  is($counter->expiry_microseconds, 0, "useconds okay");
}

########################################################################
# pass in a floating expiry
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry => 30.5,
  );

  is($counter->expiry_seconds, 30, "seconds okay");
  is($counter->expiry_microseconds, 500_000, "useconds okay");
}

########################################################################
# failure: can't pass neither
########################################################################

dies_ok {
 my $counter = Counter::Timed->new();
};

########################################################################
# failure: can't pass both
########################################################################

dies_ok {
  my $counter = Counter::Timed->new(
    expiry => 1,
    expiry_seconds => 1,
  );
};

dies_ok {
  my $counter = Counter::Timed->new(
    expiry => 1,
    expiry_microseconds => 1,
  );
};

dies_ok {
  my $counter = Counter::Timed->new(
    expiry => 1,
    expiry_seconds => 1,
    expiry_microseconds => 1,
  );
};

#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 203;
use Test::Time::HiRes;
use Data::Dumper;

use Counter::Timed;

########################################################################
# whole seconds
########################################################################

{

  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
  );

  # put something in once a second for the next 60 seconds
  for (1..30) {
    $counter->add("something");
    is($counter->count("something"), $_)
      or dump_state($counter);
    time_travel_by(1);
  }

  # after thirty seconds they should start expiring!
  for (1..30) {
    $counter->add("something");
    is($counter->count("something"), 30 )
      or dump_state($counter);
    time_travel_by(1);
  }
}

########################################################################
# part seconds
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry_seconds => 0,
    expiry_microseconds => 100,
  );

  # put something in once a second for the next 60 seconds
  for (1..4) {
    $counter->add("something");
    is($counter->count("something"), $_)
      or dump_state($counter);
    time_travel_by(0,25);
  }

  for (1..10) {
    $counter->add("something");
    is($counter->count("something"), 4 )
      or dump_state($counter);
    time_travel_by(0,25);
  }
}

########################################################################
# values
########################################################################

my @values1 = (map { rand } 1..60);
my @values2 = (map { rand } 1..60);

use List::Util qw(max min sum);

{
  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
  );

  for my $i (0..59) {
    $counter->add( "wombat", $values1[ $i ], $values2[ $i ] );
    
    # work out what the values should be 
    my $start = max(0,$i-29);
    my $total1 = sum @values1[ $start..$i ];
    my $total2 = sum @values2[ $start..$i ];
    my $mean1 = $total1 / min($i+1, 30);
    my $mean2 = $total2 / min($i+1, 30);
    
    is_deeply([$total1, $total2], [ $counter->totals("wombat") ], "values totals $i");
    is_deeply([$mean1, $mean2],   [ $counter->mean("wombat")   ], "values means $i");
   
    time_travel_by(1);
  }
}

########################################################################
# keys
########################################################################

{
  my $counter = Counter::Timed->new(
     expiry_seconds => 30,
  );
  foreach (1..100) {
    $counter->add( "wombat$_" );
    time_travel_by(10);
  }
  is_deeply([sort $counter->keys ], [ sort map { "wombat$_" } (1..100)], "all keys there");
  
  # delete a key, and it's gone?
  $counter->remove("wombat74");
  is_deeply([sort $counter->keys ], [ sort map { "wombat$_" } (1..73, 75..100)], "all remaining keys there");

  # purge a key, and it's gone gone?
  $counter->remove("wombat88");
  is_deeply([sort $counter->keys ], [ sort map { "wombat$_" } (1..73, 75..87, 89..100)], "all remaining keys there");

  # check it's purged (warning: whitebox testing)
  ok(!grep{ $_->[2] eq "wombat88" } @{ $counter->_expiry_queue });

  # check neither actually will come back into existance
  time_travel_by(3600);
  is_deeply([sort $counter->keys ], [ sort map { "wombat$_" } (1..73, 75..87, 89..100)], "all remaining keys there");
}

########################################################################
# disabling updates
########################################################################

{
  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
  );
  $counter->auto_expire(0);
  $counter->add("bobby");
  time_travel_by(3600);
  is($counter->count("bobby"),1,"without auto expire still there");
  $counter->expire();
  is($counter->count("bobby"),0,"after expire gone");
}


{
  my $counter = Counter::Timed->new(
    expiry_seconds => 30,
  );
  $counter->add("bobby");
  {
    $counter->disable_expiry_for_scope();
    time_travel_by(3600);
    is($counter->count("bobby"),1,"in scope still there");
  }
  is($counter->count("bobby"),0,"after scope gone");
}


########################################################################

sub dump_state {
  my $c = shift;
  diag(Data::Dumper->Dump([ $c->_expiry_queue, $c->_totals ],[split /,\s*/,q[$c->_expiry_queue, $c->_totals]]));
}


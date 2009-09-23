use MooseX::Declare;
class Counter::Timed {

our $VERSION = 0.01;

use Counter::Timed::Types qw(:all);

use Carp qw(croak);
use Time::HiRes qw(gettimeofday);
use Counter::Timed::Types qw(:all);
use Scope::Upper qw(reap SCOPE);

=head1 NAME

Counter::Timed -

=head1 SYNOPSIS

  use Counter::Timed;

  # create a new counter that keeps values for 30s
  my $counter = Counter::Timed->new(
    expiry => 30,
  );

  # putting something in
  $counter->add($key);

  # count how many haven't timed out yet
  $counter->count($key);

  # store values when we put things in
  $counter->add($weight, $cost, $temperature);

  # find out our running stats on those values
  my ($weight, $cost, $temperature) = $counter->totals($key);
  my ($mean_weight, $mean_cost, $mean_temperature) = $counter->mean($key);

=head1 DESCRIPTION

A simple expiring counter that can track the number of entries you've put in
and the running values for those entries since a certain timeframe has elapsed.

=head2 Constructor

Standard Moose class, so handles attributes to the constructor like other Moose
classes.

The constructor also takes an addtional argument C<expiry>, being the floating
point number of seconds till values are "timed out", which takes the place of
C<expiry_seconds> and C<expiry_milliseconds>.

=head2 Attributes

=over

=item expiry_seconds

An integer number of seconds before expiry.  Required (unless you pass an "expiry"
argument to the constructor) and read only.

=item expiry_milliseconds

An integer number of milliseconds before expiry.  Required (unless you pass an "expiry"
argument to the constructor) and read only.

=cut

around BUILDARGS ($class: @args) {
  my %args = (ref $args[0] eq "HASH") ? %{ $args[0] } : @args;

  # force the user to either use "expiry" or "expire_seconds" and "expire_microseconds" not both
  if ((defined $args{expiry} && defined $args{expiry_seconds}) ||
      (defined $args{expiry} && defined $args{expiry_microseconds})) {
    croak "Can't pass both expiry and expiry_seconds / expiry_microseconds";
  }

  # change expiry into expiry_seconds and expiry_microseconds
  if (defined $args{expiry}) {
    my $seconds = delete $args{expiry};
    my $int_seconds = int($seconds);
    $args{expiry_seconds} = $int_seconds;
    $args{expiry_microseconds} = int( ($seconds - $int_seconds) * 1_000_000 );
  }

  # check that they've passed some expirey time of some kind
  unless ($args{expiry_seconds} || $args{expiry_microseconds}) {
    croak "zero expiry time passed";
  }

  $class->$orig(\%args);
}

has expiry_seconds => (
  is => 'ro',
  isa => PositiveSeconds,
  default => 0,
);

has expiry_microseconds => (
  is => 'ro',
  isa => PositiveMicroseconds,
  default => 0,
);

has _expiry_allowed => (
  is => 'rw',
  isa => "Bool",
  default => 1,
);

=item auto_expire

Boolean value that controls if we automatically attempt to expire old data
whenever this object is read or written to.  Read-write. By default this is on.

=cut

has auto_expire => (
  is => 'rw',
  isa => "Bool",
  default => 1,
);

# this data structure looks like this, ordered by $seconds and $microseconds
#
#   [ $seconds, $microseconds, $key, $count, $value1, $value2, $value3 ... ],
#   [ $seconds, $microseconds, $key, $count, $value1, $value2, $value3 ... ],
#   ...
#

has _expiry_queue => (
  is => 'ro',
  default => sub { [] },
  init_arg => undef,
);

=back

=head2 Methods

=over

=item add($key, @values)

=cut

method add($key, @values) {
  $self->expire() if $self->auto_expire;

  # work out the seconds and microseconds when this expires
  my ($seconds,$microseconds) = gettimeofday();
  $seconds      += $self->expiry_seconds;
  $microseconds += $self->expiry_microseconds;
  if ($microseconds > 1_000_000) {
   $microseconds -= 1_000_000;
   $seconds++;
  }

  $self->_schedule_undo(
   seconds      => $seconds,
   microseconds => $microseconds,
   key          => $key,
   values       => \@values
  );

  # now update the totals
  my $totals = $self->_totals->{ $key } ||= [];

  no warnings 'uninitialized';
  $totals->[0]++;
  foreach my $i (1..@values) {
    $totals->[$i] += $values[$i-1];
  };
  return;
}

# note that I want to use "PositiveSeconds" and "PositiveMicroseconds"
# here in the spec, but for some reasons it doesn't work...
method _schedule_undo(
   :$key,
   ArrayRef :$values,
   PositiveSeconds :$seconds,
   PositiveMicroseconds :$microseconds
) {
  push @{ $self->_expiry_queue }, [$seconds, $microseconds, $key, @{ $values }];
}

=item remove($key)

(Quickly) remove the key from this object.  Does not purge the internal
queue of pending updates to the key.

Please note that this means if you call C<add> with this key before
pending updates have expired then those pending updates will be executed.

This function is probably inherently unsafe to use.  Use C<purge> below
for your own sanity.

=cut

method remove($key) {
  delete $self->_totals->{ $key };
}

=item purge($key)

Remove the key from this object free back to perl the memory used used in
the internal queue of pending updates to the key count and values. Note
that this involves a linear search through the pending queue which,
depending on the size of your pending queue, may take some time.

=cut

method purge($key) {
  $self->remove($key);
  $self->expire() if $self->auto_expire;

  my $queue = $self->_expiry_queue;

  my $i = 0;
  while ($i < @{ $queue }) {
    if ($queue->[$i][3] eq $key) {
      splice @{ $queue }, $i, 1;
      next;
    }
    $i++;
  }

  return;
}

##########################################################################
# this data structure looks like this:
#
#   $key1 => [ $count, $total_for_value1, $total_for_value2, $total_for_value3 ... ],
#   $key2 => [ $count, $total_for_value1, $total_for_value2, $total_for_value3 ... ],
#   $key3 => [ $count, $total_for_value1, $total_for_value2, $total_for_value3 ... ],
#   ...
#

has _totals => (
  is => 'ro',
  default => sub { +{} },
  init_arg => undef,
);

=item count($key)

Returns the number of current values for the given key.  Returns
the empty list if there's no such key.

=cut

method count($key) {
  $self->expire if $self->auto_expire;
  my $t = $self->_totals->{ $key };
  return unless $t;
  return $t->[0];
}

=item totals($key)

Returns the totals for current values for the current key.
e.g.

  my ($weight, $size) = $self->totals("widgets");

=cut

method totals($key) {
  $self->expire if $self->auto_expire;
  my $t = $self->_totals->{ $key };
  return unless $t && @{$t}>1;
  return map { $t->[$_] } (1..(@{$t}-1));
}

=item mean($key)

Return the arithmetic mean for the current values for the
current key.  e.g.

  my ($weight, $size) = $self->mean("widgets");

=cut

method mean($key) {
  $self->expire if $self->auto_expire;
  my $t = $self->_totals->{ $key };
  return unless $t && @{$t}>1;
  my $count = $t->[0];
  return map { $t->[$_] / $count } (1..(@{$t}-1));
}

=item keys()

Returns the keys that we've got values stored for.

=cut

method keys() {
  $self->expire if $self->auto_expire;
  return keys %{ $self->_totals };
}

=item expire()

Manually trigger the analysis that removes all values that are due
to be expired.

As long as C<auto_expire> remains on this method will be
automatically called for you whenever you read or write data
to this object.

=cut

method expire() {
  return unless $self->_expiry_allowed;

  # work out when things should expire
  my ($seconds, $microseconds) = gettimeofday();

  # run through the expiry queue
  my $queue = $self->_expiry_queue;
  while (@{ $queue }) {
    # abort if this shouldn't be expired
    last if $queue->[0][0] > $seconds;
    last if $queue->[0][0] == $seconds && $queue->[0][1] > $microseconds;

    # this element should be expired, so remove it from the queue
    my $element = shift @{ $queue };

    # fixup the scores
    shift @{ $element };  # ignore seconds
    shift @{ $element };  # ignore miliseconds
    my $key = shift @{ $element };
    my $total = $self->_totals->{ $key };

    # decrease the overall count
    $total->[0]--;

    # decrease the values
    for my $i (1..@{ $element }) {
      $total->[ $i ] -= $element->[ $i - 1 ];
    }
  }
  return;
}

=item disable_expiry_for_scope()

Turns off expiry for the remainder of the scope.  Useful if you're bulk
inserting / bulk reading, as we won't pay the peformance cost of checking
the expiry queue each time (in particular, saves multiple calls to
Time::HiRes's gettimeofday).  For example:

  sub insert_many_values {
    my $self  = shift;
    my $timed = shift;
    $timed->disable_expiry_for_scope;
    $timed->add("filesize", $_) foreach $self->filesizes;
    return;
  }

This is much cleaner than writing:

  sub insert_many_values {
    my $self  = shift;
    my $timed = shift;
    $timed->auto_expire(0);
    $timed->add("filesize", $_) foreach $self->filesizes;
    $timed->auto_expire(1);
    return;
  }

As it doesn't accidentally leave expiry off C<filesizes>
throws an exception causing the method to exit via an unexpcted


=cut

method disable_expiry_for_scope() {
  $self->_expiry_allowed(0);

  # run when our parent scope exits

  # If there is a DB::sub(), this is part of a debugger/profiler,
  # and we assume that it is inserting an extra stack frame that
  # we need to skip.  caller() doesn't show such a stack frame,
  # so we're forced to guess.
  reap sub {
    $self->_expiry_allowed(1);
  }, defined(&DB::sub) ? SCOPE(3) : SCOPE(1);
}

=back

=head1 AUTHOR

Written by Mark Fowler E<lt>mark@twoshortplanks.comE<gt>.

Copyright Photobox 2009.  All Rights Reserved.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 BUGS

Please see http://twoshortplanks.com/dev/countertimed for
details of how to submit bugs, access the source control for
this project, and contact the author.

=head1 SEE ALSO

L<Tie::Hash::Expire>

=cut

} # end of class

1;

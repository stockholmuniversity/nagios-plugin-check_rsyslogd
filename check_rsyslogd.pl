#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(strftime);
use JSON;
use Nagios::Plugin;
use Storable;
use Date::Parse;
use Array::Utils 'intersect';
use File::Basename 'fileparse';
use Data::Dumper;

my $np = Nagios::Plugin->new(
  shortname => "#",
	usage => "Usage: %s [-v|--verbose] [-t <timeout>] [--critical=<value to emit critical>] [--warning=<value to emit warning>] --one-of-the-checks-below",
  version => "1.0",
  timeout => 10,
  extra => qq(
See <https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT> for
information on how to use thresholds.
),
);

my $code;
my $now = strftime('%FT%T%z', localtime);
my ($db, undef) = fileparse($0, qr/\..*?$/);
$db = "/tmp/$db";

my $stats = {};

$np->add_arg(
  spec => 'warning|w=i',
  help => 'Set the warning threshold in INTEGER',
  default => '100:',
);

$np->add_arg(
  spec => 'critical|c=i',
  help => 'Set the critical threshold in INTEGER',
  default => '10:',
);

$np->add_arg(
  spec => 'write',
  help => "--write\n   Write rsyslog periodic stats to disk which can be checked. FIXME",
);

$np->add_arg(
  spec => 'check:s',
  help => "--check\n   Check rsyslog periodic stats from disk. (default: %s)",
  default => "all",
);

$np->getopts;

# Set the default for check
my $check_default;
for (@{$np->opts->{_args}}) {
  $check_default = $_->{default} if $_->{name} eq "check";
}
if (defined $np->opts->get('check') && $np->opts->get('check') eq "") {
  $np->opts->{check} = $check_default;
}

# Clean up if it contains the whole syslog message and not just the JSON
sub make_jsonish {
  chomp;
  s/^.*{/{/;
}

sub make_json {
  # Try to parse the JSON
  eval {
    $_ = decode_json($_);
  };
  if ($@) {
    $np->nagios_exit(CRITICAL, "JSON was invalid: $@");
  }
}

sub get_first_dates {
  ((reverse sort keys $stats)[0..1]);
}

sub get_checks_from_dates {
  my ($first_date, $second_date, $check) = @_;
  map { $stats->{$_}->{$check} } ($first_date, $second_date);
}

sub check_threshold {
  my ($check) = @_;
  my ($first_date, $second_date) = get_first_dates;
  my ($first, $second) = get_checks_from_dates($first_date, $second_date, $check);

  my $difference = $first-$second;
  # Check so number of log events aren't outside the limits
  $code = $np->check_threshold(
    check => $difference,
    warning => $np->opts->get('warning'),
    critical => $np->opts->get('critical'),
  );
  $np->add_message($code, "$check received $difference messages in ".(str2time($first_date)-str2time($second_date))." seconds which is outside the configured threshold.");
}

# Everyone wants a database!
unless (-e $db) {
  store $stats, $db;
}
$stats = retrieve($db);

if (defined $np->opts->get('write')) {
  while (<>) {
    make_jsonish;
    make_json;

    # TODO Also add the queues:
    # {"name":"om-logstash queue[DA]","origin":"core.queue","size":1553919,"enqueued":0,"full":0,"discarded.full":0,"discarded.nf":0,"maxqsize":0}
    # {"name":"om-logstash queue","origin":"core.queue","size":16,"enqueued":16,"full":0,"discarded.full":0,"discarded.nf":0,"maxqsize":16}
    # {"name":"main Q[DA]","origin":"core.queue","size":0,"enqueued":0,"full":0,"discarded.full":0,"discarded.nf":0,"maxqsize":0}
    # {"name":"main Q","origin":"core.queue","size":15,"enqueued":31,"full":0,"discarded.full":0,"discarded.nf":0,"maxqsize":15}
    if (defined($_->{name}) && defined($_->{submitted})) {
      $stats->{$now}->{$_->{name}} = $_->{submitted};

      if (scalar keys $stats > 10) {
        my %ten_newest;
        # Copy only the 10 newest
        for (((reverse sort keys $stats)[0..9])) {
          $ten_newest{$_} = $stats->{$_};
        }

        $stats = \%ten_newest;
      }

      store $stats, $db;
    }
  }
}

elsif (defined $np->opts->get('check')) {
  $np->nagios_exit(UNKNOWN, "There are fewer than 2 stats in $db") if scalar keys $stats < 2;

  if ($np->opts->get('check') eq $check_default) {
    my ($first_date, $second_date) = get_first_dates;

    for (intersect(@{[keys($stats->{$first_date})]}, @{[keys $stats->{$second_date}]})) {
      check_threshold($_);
    }
  }
  else {
    check_threshold($np->opts->get('check'));
  }

}

# Set final status and message
($code, my $message) = $np->check_messages();
$np->nagios_exit($code, $message);

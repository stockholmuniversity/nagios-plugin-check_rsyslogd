#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(strftime);
use JSON;
use Nagios::Plugin;
use Storable;
use Date::Parse;
use Data::Dumper;

my $np = Nagios::Plugin->new(
  shortname => "#",
	usage => "Usage: %s [-v|--verbose] [-t <timeout>] [--critical=<value to emit critical>] [--warning=<value to emit warning>] --one-of-the-checks-below",
  version => "1.0",
  timeout => 10,
  extra => qq(
See <https://nagios-plugins.org/doc/guidelines.html#THRESHOLDFORMAT> for
information on how to use thresholds.
),
);

my $code;
my $now = strftime('%FT%T%z', localtime);
# FIXME Put in a good place, like /var/tmp/
my $db = "./knyten";

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
if (defined $np->opts->get('check') && $np->opts->get('check') eq "") {
  for (@{$np->opts->{_args}}) {
    $np->opts->{check} = $_->{default} if $_->{name} eq "check";
  }
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

sub check_threshold {
  my ($check) = @_;
  my ($first_date, $second_date) = ((reverse sort keys $stats)[0..1]);
  my ($first, $second) = map { $stats->{$_}->{$check} } ($first_date, $second_date);

  my $difference = $first-$second;
  # Check so number of log events aren't outside the limits
  $code = $np->check_threshold(
    check => $difference,
    warning => $np->opts->get('warning'),
    critical => $np->opts->get('critical'),
  );
  $np->add_message($code, "rsyslog $check reported a difference of $difference in ".(str2time($first_date)-str2time($second_date))." seconds");
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
  # FIXME
  # * If "all" check all and add_message them appropriately
  # * Else:
  # ** Get that specific key and check on that

  $np->nagios_exit(UNKNOWN, "There are fewer than 2 stats in $db") if scalar keys $stats < 2;

  check_threshold($np->opts->get('check'));

}

# Set final status and message
($code, my $message) = $np->check_messages();
$np->nagios_exit($code, $message);

#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(strftime);
use JSON;
use Nagios::Plugin;
use Storable;
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
);

$np->add_arg(
  spec => 'critical|c=i',
  help => 'Set the critical threshold in INTEGER',
);

$np->add_arg(
  spec => 'write',
  help => "--write\n   Write rsyslog periodic stats to disk which can be checked. FIXME",
);

$np->getopts;

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

if (defined $np->opts->get('write')) {
  unless (-e $db) {
    store $stats, $db;
  }
  $stats = retrieve($db);

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

# Set final status and message
($code, my $message) = $np->check_messages();
$np->nagios_exit($code, $message);

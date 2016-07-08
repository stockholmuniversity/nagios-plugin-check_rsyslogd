# nagios-plugin-check\_rsyslogd

Nagios NRPE and "regular" check for rsyslogd throughput and queue size

## Dependencies

| CPAN module      | Debian/Ubuntu package   |
|------------------|-------------------------|
| `JSON`           | `libjson-perl`          |
| `Nagios::Plugin` | `libnagios-plugin-perl` |
| `Array::Utils`   | `libarray-utils-perl`   |
| `Date::Parse`    | `libtimedate-perl`      |

## Checks supported

For more details, see `--help`.

* Check input modules for throughput to see if rsyslogd is receiving any logs
* Check queues for size/depth to see how big or if you have a backlog.

## rsyslogd configuration

```
# NOTE If you are using Ubuntu (and possibly Debian) rsyslog of version
# 8.16.0-1ubuntu3 there is a bug where the `json` and `cee` formats are inverted.
# Ergo: If you pick `cee` you get `json` and vice versa.
module(load="impstats" interval="60" format="json")

module(load="omprog")
if $fromhost-ip == "127.0.0.1" and $programname == "rsyslogd-pstats" then {
  action(
    name="action-omprog-impstats"
    type="omprog"
    binary="/usr/lib/nagios/plugins/check_rsyslogd.pl --write"
  )
}
```

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

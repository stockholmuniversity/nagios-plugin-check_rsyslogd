# nagios-plugin-check\_rsyslogd

Nagios NRPE and "regular" check for rsyslogd throughput and queue size

## Dependencies

| CPAN module                           | Debian/Ubuntu package                               |
|---------------------------------------|-----------------------------------------------------|
| `JSON`                                | `libjson-perl`                                      |
| `Monitoring::Plugin`/`Nagios::Plugin` | `libmonitoring-plugin-perl`/`libnagios-plugin-perl` |
| `Array::Utils`                        | `libarray-utils-perl`                               |
| `Date::Parse`                         | `libtimedate-perl`                                  |

## Checks supported

For more details, see `--help`.

* Check input modules for throughput to see if rsyslogd is receiving any logs
* Check queues for size/depth to see how big or if you have a backlog.
* Take [ucarp](https://www.pureftpd.org/project/ucarp) status into account,
  i.e. don't error out if we're BACKUP because we won't receive any syslog then

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

### [ucarp](https://www.pureftpd.org/project/ucarp) support and configuration

[ucarp](https://www.pureftpd.org/project/ucarp) is a userland implementation of the [CARP protocol](https://en.wikipedia.org/wiki/Common_Address_Redundancy_Protocol).
Currently, it has no way to check the status of ucarp except sending a `USR1`
signal to it which syslogs if it's `MASTER` or `BACKUP`. The `--carp` check
creates a one line "status" file with the last `[INFO]` message from ucarp.

```
else if $fromhost-ip == "127.0.0.1" and $programname == "ucarp" and $msg startswith " [INFO]" then {
  action(
    name="action-omprog-ucarp-status"
    type="omprog"
    binary="/usr/lib/nagios/plugins/check_rsyslogd.pl --ucarp"
  )
}
```

### Naming input modules
If you are listening on both IPv6 and IPv4 the name in the statistic has the
same name/key. To avoid this, bind to IPv{6,4} seperately using two inputs and
name them manually.

There is also inconsistent naming of the input modules in the statistics.
`imudp` has a setting to append the port to the name but the others don't have
that setting but append it anyway.

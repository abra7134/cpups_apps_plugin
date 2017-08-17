# Cpups_apps netdata plugin

Cpups_apps is a example plugin for [netdata](https://my-netdata.io) monitoring system.  
It collects statistics of the processor usages as a percentage for the selected applications.  
Realized on shell and intended for use with the netdata's [charts.d](https://github.com/firehol/netdata/wiki/General-Info---charts.d) module.

ATTENTION
> As the mechanism of statistics collection through /proc filesystem is used, it is not possible
to obtain completely reliable data for cases when controlled process finishes the operation.
For tasks where accurate accounting of such scenarios is important it is necessary to use the pacct
mechanism just as it's used by the [atop](https://www.atoptool.nl/) utility.

### Install

- [Install](https://github.com/firehol/netdata/wiki/Installation) netdata
- Copy cpupc_apps.chart.sh to ${NETDATA_INSTALL_PREFIX}/usr/libexec/netdata/charts.d/cpupc_apps.chart.sh
- Copy cpupc_apps.conf to ${NETDATA_INSTALL_PREFIX}/etc/netdata/charts.d/cpupc_apps.conf
- Edit the configuration (cpupc_apps.conf) by specifying the needed application for monitoring
- Restart netdata

### Example

![Screenshot](cpupc_apps_screenshot.png)

### TODO

- Add get the cpu usage statistics through cgroup's cpuacct controller
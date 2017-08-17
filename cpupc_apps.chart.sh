# no need for shebang - this file is loaded from charts.d.plugin

# netdata
# real-time performance and health monitoring, done right!
# (C) 2016 Costa Tsaousis <costa@tsaousis.gr>
# GPL v3+
#

# a space separated list of command to monitor
cpupc_apps_apps=

# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
cpupc_apps_update_every=

# the priority is used to sort the charts on the dashboard
# 1 = the first chart
cpupc_apps_priority=20001

# these are required for computing cpu in percents
cpupc_apps_clock_ticks="$(getconf CLK_TCK)"
cpupc_apps_processors_count="$(nproc)"

# global array for storing our collected data
declare -A cpupc_apps_dimensions=()

cpupc_apps_check() {
  # this should return:
  #  - 0 to enable the chart
  #  - 1 to disable the chart

  if [ -z "${cpupc_apps_apps}" ]
  then
    error "manual configuration required: please set cpupc_apps_apps='command1 command2 ...' in ${NETDATA_CONFIG_DIR}/cpupc_apps.conf"
    return 1
  fi

  return 0
}

cpupc_apps_get() {
  local app
  local pid comm state ppid pgrp session tty_nc tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime others

  for app in ${cpupc_apps_apps}
  do
    local app_pids= app_pid=
    local -i utime_sum=0 stime_sum=0

    app_pids="$(
      pgrep --full "${app}"
    )"

    for app_pid in ${app_pids}
    do
      # From man 5 proc
      if [ -f /proc/${app_pid}/stat ]
      then
        read pid comm state ppid pgrp session tty_nc tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime others \
          < /proc/${app_pid}/stat \
          || continue
        let utime_sum+=utime+cutime
        let stime_sum+=stime+cstime
      fi
    done

    let cpupc_apps_dimensions[${app}_utime_1]=cpupc_apps_dimensions[${app}_utime_2]
    let cpupc_apps_dimensions[${app}_stime_1]=cpupc_apps_dimensions[${app}_stime_2]
    let cpupc_apps_dimensions[${app}_utime_2]=utime_sum
    let cpupc_apps_dimensions[${app}_stime_2]=stime_sum
  done

  return 0
}

cpupc_apps_create() {
  local app=
  local divisor=$((cpupc_apps_clock_ticks*cpupc_apps_update_every))

  echo "CHART chartsd_apps.cpupc '' 'Apps CPU percent usage ($((100*cpupc_apps_processors_count))% = $((cpupc_apps_processors_count)) cores)' 'cpu time %' apps apps stacked $((cpupc_apps_priority)) $((cpupc_apps_update_every))"

  for app in ${cpupc_apps_apps}
  do
    echo "DIMENSION ${app}_sys '' absolute 100 $((divisor))"
    echo "DIMENSION ${app}_user '' absolute 100 $((divisor))"
  done

  cpupc_apps_get

  return 0
}

cpupc_apps_update() {
  # do all the work to collect / calculate the values
  # for each dimension
  # remember: KEEP IT SIMPLE AND SHORT
  local app
  local utime_amount stime_amount

  echo "BEGIN chartsd_apps.cpupc"

  cpupc_apps_get

  for app in ${cpupc_apps_apps}
  do
    let utime_amount=cpupc_apps_dimensions[${app}_utime_2]-cpupc_apps_dimensions[${app}_utime_1]
    let stime_amount=cpupc_apps_dimensions[${app}_stime_2]-cpupc_apps_dimensions[${app}_stime_1]
    echo "SET ${app}_user = $((utime_amount > 0 ? utime_amount : 0 ))"
    echo "SET ${app}_sys = $((stime_amount > 0 ? stime_amount : 0 ))"
  done

  echo "END"

  return 0
}

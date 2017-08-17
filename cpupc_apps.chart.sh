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

_check called by netdata at once in startup
cpupc_apps_check() {
  # this return:
  #  - 0 to enable the chart
  #  - 1 to disable the chart

  if [ -z "${cpupc_apps_apps}" ]
  then
    error "Manual configuration required: please set cpupc_apps_apps='command1 command2 ...' in ${NETDATA_CONFIG_DIR}/cpupc_apps.conf"
    return 1
  fi

  if [ -z "${cpupc_apps_clock_ticks}" ]
  then
    error "Can't get CLK_TCK variable by getconf command, please manual check"
    return 1
  fi

  if [ -z "${cpupc_apps_processors_count}" ]
  then
    error "Can't get the count of installed processors by nproc command, please manual check"
    return 1
  fi

  if ! type -p pgrep >/dev/null
  then
    error "The required pgrep command is absent, please install by manual"
    return 1
  fi

  return 0
}

# _get called by _update by actual collect and calculates metrics
cpupc_apps_get() {
  # this return:
  #  - 0 to send the data to netdata
  #  - 1 to report a failure to collect the data

  local app
  local pid comm state ppid pgrp session tty_nc tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime others

  for app in ${cpupc_apps_apps}
  do
    local app_pids= app_pid=
    local -i utime_sum=0 stime_sum=0

    # Get pids for certain application and his childrens
    app_pids="$(
      pgrep --full "${app}"
    )"
    # Return error if pgrep also error return error
    [ ${?} -gt 0 ] \
      && return 1

    for app_pid in ${app_pids}
    do
      if [ -f /proc/${app_pid}/stat ]
      then
        # Named getting from man 5 proc
        read pid comm state ppid pgrp session tty_nc tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime others \
          < /proc/${app_pid}/stat \
          || continue
        # Consider time of the parent and his waiting childrens
        let utime_sum+=utime+cutime
        let stime_sum+=stime+cstime
      fi
    done

    # Shift a time ring
    let cpupc_apps_dimensions[${app}_utime_1]=cpupc_apps_dimensions[${app}_utime_2]
    let cpupc_apps_dimensions[${app}_stime_1]=cpupc_apps_dimensions[${app}_stime_2]
    let cpupc_apps_dimensions[${app}_utime_2]=utime_sum
    let cpupc_apps_dimensions[${app}_stime_2]=stime_sum
  done

  return 0
}

# _create is called once, to create the charts
cpupc_apps_create() {
  local app=
  local divisor=$((cpupc_apps_clock_ticks))

  # For interpretation see https://github.com/firehol/netdata/wiki/External-Plugins
  echo "CHART chartsd_apps.cpupc '' 'Apps CPU percent usage ($((100*cpupc_apps_processors_count))% = $((cpupc_apps_processors_count)) cores)' 'cpu time %' apps apps stacked $((cpupc_apps_priority)) $((cpupc_apps_update_every))"

  for app in ${cpupc_apps_apps}
  do
    echo "DIMENSION ${app}_sys '' absolute 100 $((divisor))"
    echo "DIMENSION ${app}_user '' absolute 100 $((divisor))"
  done

  # First take for initialize dimension array
  cpupc_apps_get
  let cpupc_apps_dimensions[seconds]=SECONDS

  return 0
}

# _update is called continiously, to collect the values
cpupc_apps_update() {
  # the first argument to this function is the microseconds since last update
  # pass this parameter to the BEGIN statement
  # (do all the work to collect / calculate the values for each dimension)
  # (remember: KEEP IT SIMPLE AND SHORT)
  local app
  local utime_amount stime_amount
  local seconds_now seconds_old interval_s

  cpupc_apps_get

  # Calculate time interval from last call this function
  let seconds_now=SECONDS
  let seconds_old=cpupc_apps_dimensions[seconds]
  let interval_s=$((seconds_now>seconds_old ? seconds_now-seconds_old : 1))
  let cpupc_apps_dimensions[seconds]=seconds_now

  echo "BEGIN chartsd_apps.cpupc ${1}"

  for app in ${cpupc_apps_apps}
  do
    let utime_amount=(cpupc_apps_dimensions[${app}_utime_2]-cpupc_apps_dimensions[${app}_utime_1])/interval_s
    let stime_amount=(cpupc_apps_dimensions[${app}_stime_2]-cpupc_apps_dimensions[${app}_stime_1])/interval_s
    # In case of completion of work of process - the _amount becomes negative then we return 0 instead
    echo "SET ${app}_user = $((utime_amount>0 ? utime_amount : 0 ))"
    echo "SET ${app}_sys = $((stime_amount>0 ? stime_amount : 0 ))"
  done

  echo "END"

  return 0
}

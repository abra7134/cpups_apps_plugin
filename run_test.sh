#!/bin/bash

source ./cpupc_apps.chart.sh

cpupc_apps_apps="firefox netdata"
cpupc_apps_create

while :;
do
  cpupc_apps_update
  sleep 1
done

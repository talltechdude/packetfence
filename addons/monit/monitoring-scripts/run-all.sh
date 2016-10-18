#!/bin/bash

source /usr/local/pf/addons/monit/monitoring-scripts/setup.sh

source /etc/monit.d/vars


full_output="Report for $uuid\n"
mailto="jsemaan@inverse.ca"

ERROR=0

function _run {
  cmd="$1"

  if is_ignored $cmd ; then
    echo "Ignoring $cmd."
    return 0
  fi

  output=`$cmd`
  if [ $? -eq 0 ]; then
    echo "$cmd succeeded" > /dev/null
  else
    ERROR=1
    output="$cmd failed"
    output="$output\nResult of $cmd"
    output="$output\n------------------------------------------"
    full_output="$full_output\n$output"
  fi
}

for f in $(find $script_dir -type f); do
  _run $f
done

echo -e $full_output
if [ $ERROR -ne 0 ]; then
  exit 1
else
  echo "No error to report"
  exit 0
fi


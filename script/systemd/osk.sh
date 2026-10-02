#!/bin/sh

niri_path=$1
grep_path=$2
awk_path=$3
wvkbd_path=$4

resolution=$("$niri_path"/bin/niri msg outputs | \
  "$grep_path"/bin/grep "Logical size:" | \
  "$awk_path"/bin/awk -F'[ ]' '{print $5}')
portrait=$(echo "$resolution" | "$awk_path"/bin/awk -F'[x]' '{print $1}')
landscape=$(echo "$resolution" | "$awk_path"/bin/awk -F'[x]' '{print $2}')

"$wvkbd_path"/bin/wvkbd-mobintl -L $(( "$landscape"/3 )) -H $(( "$portrait"/3 )) --hidden &

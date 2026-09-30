#!/bin/sh

glib_path=$1

pattern="'LockedHint': *<false>"

while IFS= read -r line; do
    if [[ "$line" =~ $pattern ]]; then
        break
    fi
done < <("$glib_path"/bin/gdbus monitor -y -d org.freedesktop.login1)

#!/bin/sh

glib_path=$1

while IFS= read -r line; do
    if [[ "$line" =~ "org.freedesktop.login1.Session.Unlock" ]]; then
        break
    fi
done < <("$glib_path"/bin/gdbus monitor -y -d org.freedesktop.login1)

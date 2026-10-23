#!/bin/sh

glib_path=$1
user_dirs_update_path=$2

pattern="'LockedHint': *<false>"

"$user_dirs_update_path"/bin/xdg-user-dirs-gtk-update

while IFS= read -r line; do
    if [[ "$line" =~ $pattern ]]; then
        break
    fi
done < <("$glib_path"/bin/gdbus monitor -y -d org.freedesktop.login1)

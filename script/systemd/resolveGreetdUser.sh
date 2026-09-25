#!/bin/sh

user_gid=$1
coreutils_path=$2
sed_path=$3

user=$("$coreutils_path"/bin/id -un "$user_gid")

"$sed_path"/bin/sed -i "/^\[initial_session\]/,/^\[/{/^user=/d}" /etc/greetd/config.toml
"$sed_path"/bin/sed -i "/^\[initial_session\]/a user=$user" /etc/greetd/config.toml

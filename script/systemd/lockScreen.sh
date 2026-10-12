#!/bin/sh

procps_path=$1
noctalia_path=$2
gnome_keyring_path=$3

"$procps_path"/bin/pkill gcr-prompter
"$noctalia_path"/bin/noctalia msg session lock
"$gnome_keyring_path"/bin/gnome-keyring-daemon --replace

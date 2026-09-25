#!/bin/sh

noctalia_path=$1
gnome_keyring_path=$2

"$noctalia_path"/bin/noctalia msg session lock
"$gnome_keyring_path"/bin/gnome-keyring-daemon --replace

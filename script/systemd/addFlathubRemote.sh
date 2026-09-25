#!/bin/sh

flatpak_path=$1

if ! "$flatpak_path"/bin/flatpak remote-modify flathub; then
    "$flatpak_path"/bin/flatpak -u remote-add flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

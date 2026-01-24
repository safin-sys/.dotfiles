#!/usr/bin/env bash

options="Power Off\nRestart\nSleep\nReboot to BIOS\nReboot to Windows"

choice=$(echo -e "$options" | rofi -dmenu -i -p "Power")

case "$choice" in
"Power Off")
  systemctl poweroff
  ;;
"Restart")
  systemctl reboot
  ;;
"Sleep")
  systemctl suspend
  ;;
"Reboot to BIOS")
  systemctl reboot --firmware-setup
  ;;
"Reboot to Windows")
  systemctl reboot --boot-loader-entry=auto-windows
  ;;
esac

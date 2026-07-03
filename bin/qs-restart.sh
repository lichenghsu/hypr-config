#!/bin/bash
# Restart quickshell after unlock to recover from monitor hotplug
# (external monitor removed while locked, different one attached at home).
pkill -x quickshell
sleep 0.5
exec quickshell --path ~/.config/quickshell/shell.qml

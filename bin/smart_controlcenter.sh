#!/bin/bash
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')

if [ -n "$QS_PID" ]; then
    quickshell ipc --pid "$QS_PID" call qsIpc toggleControlCenter
fi

#!/bin/bash
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')
[ -n "$QS_PID" ] && quickshell ipc --pid "$QS_PID" call qsIpc toggleWindowOverview

#!/bin/bash
# Reads password from stdin, passes directly to unix_chkpwd via exec
# Using exec avoids any shell variable interpolation of the password
exec /sbin/unix_chkpwd "$USER" nonull

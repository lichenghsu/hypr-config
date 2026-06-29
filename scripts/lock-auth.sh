#!/bin/bash
# PAM password verification via unix_chkpwd (setuid helper)
# Usage: echo "password" | lock-auth.sh
# Returns: 0 on success, 1 on failure
read -r password
printf '%s' "$password" | /sbin/unix_chkpwd "$USER" nonull 2>/dev/null

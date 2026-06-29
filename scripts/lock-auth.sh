#!/usr/bin/env python3
import sys, os, pam
password = sys.stdin.readline().rstrip("\n")
p = pam.pam()
sys.exit(0 if p.authenticate(os.environ["USER"], password) else 1)

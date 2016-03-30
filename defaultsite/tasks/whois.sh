#!/bin/bash
# whois - trivial user lookup, needs to be executed on a machine with a full
# user database.

[ "$1" = "-h" -o $# -eq 0 ] && { echo "Usage: rc whois <username>"; exit 1; }

whois $1

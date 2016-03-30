#!/bin/bash
# yumcheck.sh - check if updates are needed
#RCCONFIG:RCELEVATE=true

usage(){
	cat <<EOF
Usage: yumcheck.sh (-h) (-s)

Check to see if updates are needed. Non-zero return -> updates are needed.
-s - only output whether the host needs updates or not
EOF
	exit 1
}

[ "$1" = "-h"  ] && usage

[ -z "$1" ] && echo "*** $(date) - Checking whether updates are needed."

yum check-update
RETVAL=$?
[ -n "$1" -a $RETVAL -eq 100 ] && echo "needs updates"
exit $RETVAL

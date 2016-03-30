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

echo -n "*** $(date) - Checking whether updates are needed... "

yum check-update > /dev/null
RETVAL=$?
if [ $RETVAL -eq 100 ]
then
	echo "system needs updates"
elif [ $RETVAL -eq 0 ]
then
	echo "system is up-to-date"
else
	echo "error checking for updates"
fi
exit $RETVAL

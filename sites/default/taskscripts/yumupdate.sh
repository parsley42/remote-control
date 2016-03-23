#!/bin/bash
# yumupdate.sh - job for patching remote servers

usage(){
	cat <<EOF
Usage: yumupdate.sh (-r)

Apply yum updates; with -r reboot on success
EOF
	exit 1
}

[ "$1" = "-h"  ] && usage

echo "*** $(date) - Applying Updates"

for TRY in 1 2 3
do
	echo "=== update try $TRY:"
	yum -y update && break
	[ $TRY -eq 3 ] && { echo "Too many tries, failing"; exit 1; }
	sleep 30
done

if [ "$1" = "-r" ]
then
	echo "*** $(date) - Update successful, triggering reboot..."
	shutdown -r +1
else
	echo "*** $(date) - Update successful"
fi
exit 0

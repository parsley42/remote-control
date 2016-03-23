#!/bin/bash
# yumcheck.sh - check if updates are needed
#RCCONFIG:RCELEVATE=true

usage(){
	cat <<EOF
Usage: yumcheck.sh

Check to see if updates are needed. Non-zero return -> updates are needed.
EOF
	exit 1
}

[ "$1" = "-h"  ] && usage

echo "*** $(date) - Checking whether updates are needed."

yum check-update

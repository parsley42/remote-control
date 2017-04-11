#!/bin/bash
# common.sh - define useful functions for rc / jobs

function status(){
	echo -e "\n### $(date) - $1"
}

printout(){
	if [ -z "$RCQUIET" ]
	then
		echo "$1" >&2
	fi
}

generateid(){
	echo $(dd if=/dev/urandom bs=16 count=1 2>/dev/null | md5sum | cut -f 1 -d' ')
}

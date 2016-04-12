#!/bin/bash
# common.sh - define useful functions for rc / jobs

function status(){
	echo -e "\n### $(date) - $1"
}

generateid(){
	echo $(dd if=/dev/urandom bs=16 count=1 2>/dev/null | md5sum | cut -f 1 -d' ')
}

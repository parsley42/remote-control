#!/bin/bash
# freespace.sh - get the free space for a filesystem, output "$MBFREE $INODEFREE $PCTFREE $IPCTFREE"
#RCCONFIG:RCREQUIREDARGS=1

usage(){
	cat <<"EOF"
freespace.sh <path> - get the free space for the given path and output "$MBFREE $INODEFREE $PCTFREE $IPCTFREE"
EOF
	exit 1
}

[ -z "$1" -o "$1" = "-h" ] && usage

FREESPACE=($(df -BM --output="avail,iavail,pcent,ipcent" $1 | tail -1)) # store 2nd row in bash array
echo ${FREESPACE[0]%M} ${FREESPACE[1]} ${FREESPACE[2]%\%} ${FREESPACE[3]%\%}

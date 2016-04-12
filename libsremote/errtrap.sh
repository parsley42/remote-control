#!/bin/bash
error_handler(){
    echo -e "\n$RCTASKID ERROR: non-zero return from command \"$1\" at line $2, exit code:$3" >&2
	# reset EXIT trap so we don't trap twice
    trap - EXIT
}
trap 'error_handler "${BASH_COMMAND}" $((LINENO - RCFIRSTLINE)) $?' ERR

catch_exit(){
    if [ $1 -ne 0 ]
    then
        echo -e "\n$RCTASKID ERROR: script exit code:$1" >&2
    fi
}
trap 'catch_exit $?' EXIT

errtrap(){
	set -e
	trap 'error_handler "${BASH_COMMAND}" $((LINENO - RCFIRSTLINE)) $?' ERR
	trap 'catch_exit $?' EXIT
}

#!/bin/bash
# status.sh - simple status output function, looks pretty in logs

function status(){
	echo -e "\n### $(date) - $1"
}

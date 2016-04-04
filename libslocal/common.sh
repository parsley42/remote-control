#!/bin/bash
# common.sh - define useful functions for rc / jobs

function status(){
	echo -e "\n### $(date) - $1"
}

# taskdefs cat's out all the definitions files relevant to a task.
# Each successive definitions file can override a previous.
taskdefs (){
	local RCHOST=$1
	local RCTASK=$2
	# If there's a site.defs file, add it in
	[ -e "$RCROOT/sites/$RCSITE/site.defs" ] && cat "$RCROOT/sites/$RCSITE/site.defs" || :
	# Same for a host .defs file
	[ -e "$RCROOT/sites/$RCSITE/hosts/$RCHOST/host.defs" ] && cat "$RCROOT/sites/$RCSITE/hosts/$RCHOST/host.defs" || :
	# First, any definitions from defaultsite
	[ -e "$RCROOT/defaultsite/taskdefs/${RCTASK}.defs" ] && cat "$RCROOT/defaultsite/taskdefs/${RCTASK}.defs" || :
	# ... then definitions from sites/common
	[ -e "$RCROOT/sites/common/taskdefs/${RCTASK}.defs" ] && cat "$RCROOT/sites/common/taskdefs/${RCTASK}.defs" || :
	# Now check for site task definitions
	[ -e "$RCROOT/sites/$RCSITE/taskdefs/${RCTASK}.defs" ] && cat "$RCROOT/sites/$RCSITE/taskdefs/${RCTASK}.defs" || :
	# ... and host task definitions
	[ -e "$RCROOT/sites/$RCSITE/hosts/$RCHOST/taskdefs/${RCTASK}.defs" ] && cat "$RCROOT/sites/$RCSITE/hosts/$RCHOST/taskdefs/${RCTASK}.defs" || :
	# Finally, if an RCDEFSFILE argument was passed on the command line, it overrides everything
	[ -n "$RCDEFSFILE" ] && cat "$RCDEFSFILE" || :
}

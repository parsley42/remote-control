#!/bin/bash
# taskinfo.sh - get information about tasks

# List all site tasks for list command
listsitetasks(){
	functrap
	local RCSITESCRIPT
	local SITE=${1:-$RCSITE}
	echo "### Site tasks for $SITE:"
	if [ -e $RCROOT/sites/$SITE/tasks.conf ]
	then
		[ -e $RCROOT/sites/$SITE/tasks.conf ] && grep -v '^$' $RCROOT/sites/$SITE/tasks.conf | grep -v '^#'
	fi
	if [ -d "$RCROOT/sites/$SITE/taskscripts" ]
	then
		for RCSITESCRIPT in "$RCROOT/sites/$SITE/taskscripts/*"
		do
			[ ! -e "$RCSITESCRIPT" ] && break # when * expands to *
			RCSITESCRIPT=$(basename $RCSITESCRIPT .sh)
			if [ -e $RCROOT/sites/$SITE/tasks.conf ]
			then
				grep -q "^$RCSITESCRIPT:" "$RCROOT/sites/$SITE/tasks.conf" || echo "$RCSITESCRIPT"
			else
				echo "$RCSITESCRIPT"
			fi
		done
	fi
}

# Get RCCOMMAND or RCSCRIPT (full path) for RCTASKNAME, and configuration (RCELEVATE, etc.)
gettaskconf(){
	functrap
	local RCTASKNAME=$1
	local SITE
	# Look for task configuration first - userconf first, then RCSITE, then default; first wins
	if [ -e ~/.tasks.conf ]
	then
		RCTASKLINE=$(grep -h "^$RCTASKNAME:" ~/.tasks.conf || :)
	fi
	if [ -n "$RCTASKLINE" ]
	then
		eval ${RCTASKLINE#*:}
		[ -n "$RCCOMMAND" ] && return 0 # for an RCCOMMAND, there's no script
	else
		for SITE in "$RCSITE" default
		do
			TASKFILE="$RCROOT/sites/$SITE/tasks.conf"
			if [ -e "$TASKFILE" ]
			then
				RCTASKLINE=$(grep -h "^$RCTASKNAME:" "$TASKFILE" || :)
				if [ -n "$RCTASKLINE" ]
				then
					eval ${RCTASKLINE#*:}
					[ -n "$RCCOMMAND" ] && return 0
					break
				fi
			fi
		done
	fi
	# Now look for the script itself, first check RCSCRIPT, then look in
	# RCSITE/taskscripts/, then default/taskscripts/
	if [ -n "$RCSCRIPT" ]
	then
		if [[ $RCSCRIPT != */* ]]
		then
			RCSCRIPT="$RCROOT/$SITE/sites/taskscripts/$RCSCRIPT"
		fi # if it contains a slash, it's assumed to be the full path
	# Now search site directories
	elif [ -e "$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}" ]
	then
		RCSCRIPT="$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}"
	elif [ -e "$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}.sh" ]
	then
		RCSCRIPT="$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}.sh"
	elif [ -e "$RCROOT/sites/default/taskscripts/${RCTASKNAME}" ]
	then
		RCSCRIPT="$RCROOT/sites/default/taskscripts/${RCTASKNAME}"
	elif [ -e "$RCROOT/sites/default/taskscripts/${RCTASKNAME}.sh" ]
	then
		RCSCRIPT="$RCROOT/sites/default/taskscripts/${RCTASKNAME}.sh"
	fi
	[ ! -e "$RCSCRIPT" ] && errorout "No task script found for $RCTASKNAME" || :
	RCSCRIPTCFGLINE=$(grep -h "^#RCCONFIG:" "$RCSCRIPT" || :)
	if [ -n "$RCSCRIPTCFGLINE" ]
	then
		eval ${RCSCRIPTCFGLINE#*:}
		# Configured task options override task defaults, so re-eval
		[ -n "$RCTASKLINE" ] && eval ${RCTASKLINE#*:}
	fi
}

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

evaltaskline(){
	functrap
	local TASKLINE="$1"
	local SITE=$2
	eval ${TASKLINE#*:} # evaluate everything after the :
	[ -n "$RCCOMMAND" ] && return 0
	if [ -n "$RCSCRIPT" ]
	then # If the script name was supplied, use that
		[[ $RCSCRIPT != */* ]] && RCSCRIPT="$RCROOT/sites/$SITE/$RCSCRIPT"
	else # otherwise assume it's XXX.sh
		RCSCRIPT="$RCROOT/sites/$SITE/${RCSCRIPT}.sh"
	fi
	[ ! -e "$RCSCRIPT" ] && errorout "Can't find command/script for configured task: $TASKLINE"
}

# Get RCCOMMAND or RCSCRIPT (full path) for RCTASKNAME
gettaskconf(){
	functrap
	local RCTASKNAME=$1
	local SITE
	if [ -e ~/.tasks.conf ]
	then
		RCTASKLINE=$(grep -h "^$RCTASKNAME:" ~/.tasks.conf || :)
		if [ -n "$RCTASKLINE" ]
		then
			eval ${RCTASKLINE#*:}
			[ -n "$RCCOMMAND" ] && return 0
			[ ! -e "$RCSCRIPT" ] && errorout "Can't find path to script for user task $RCTASKNAME"
		fi
	fi
	for SITE in "$RCSITE" default
	do
		TASKFILE="$RCROOT/sites/$SITE/tasks.conf"
		if [ -e $TASKFILE ]
		then
			RCTASKLINE=$(grep -h "^$RCTASKNAME:" $TASKFILE || :)
			if [ -n "$RCTASKLINE" ]
			then
				eval ${RCTASKLINE#*:}
				[ -n "$RCCOMMAND" ] && return 0
			fi
		fi
		if [ -n "$RCSCRIPT" ]
		then
			if [[ $RCSCRIPT != */* ]]
			then
				RCSCRIPT="$RCROOT/$SITE/sites/taskscripts/$RCSCRIPT"
				break
			else
				break
			fi
		elif [ -e "$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}.sh" ]
		then
			RCSCRIPT="$RCROOT/sites/$SITE/taskscripts/${RCTASKNAME}.sh"
		fi
	done
	[ ! -e "$RCSCRIPT" ] && errorout "No task script found at $RCSCRIPT" || :
}

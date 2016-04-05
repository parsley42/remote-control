#!/bin/bash
# tasklib.sh - rc task functions

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

# List all site tasks for list command
listsitetasks(){
	functrap
	local RCSITESCRIPT RCSCRIPT SCRIPTCONF SITE RCTASKLINE
	if [ "$1" = defaultsite ]
	then
		SITE=$1
	else
		SITE="sites/${1:-$RCSITE}"
	fi
	echo "### Tasks for $SITE:"
	if [ -e "$RCROOT/$SITE/tasks.conf" ]
	then
		grep -v '^$' $RCROOT/$SITE/tasks.conf | grep -v '^#' | grep RCCOMMAND
	fi
	if [ -d "$RCROOT/$SITE/tasks" ]
	then
		for RCSITESCRIPT in $(cd "$RCROOT/$SITE/tasks"; echo *)
		do
			[ ! -e "$RCROOT/$SITE/tasks/$RCSITESCRIPT" ] && break # when * expands to *
			RCSCRIPT=$(basename $RCSITESCRIPT .sh)
			if [ -e "$RCROOT/$SITE/tasks.conf" ]
			then
				RCTASKLINE=$(grep -h "^$RCSCRIPT:" "$RCROOT/$SITE/tasks.conf" || :)
			fi
			SCRIPTCONF=$(grep -h "^#RCCONFIG:" "$RCROOT/$SITE/tasks/$RCSITESCRIPT" || :)
			echo -n "$RCSCRIPT"
			if [ -n "$SCRIPTCONF" ]
			then
				echo -n ":${SCRIPTCONF#*:}"
				[ -n "$RCTASKLINE" ] && echo ";${RCTASKLINE#*:}" || echo
			else
				[ -n "$RCTASKLINE" ] && echo ":${RCTASKLINE#*:}" || echo
			fi
		done
	fi
	set +x
}

# Get RCCOMMAND or RCSCRIPT (full path) for RCTASKNAME, and configuration (RCELEVATE, etc.)
gettaskconf(){
	functrap
	local RCTASKNAME=$1
	local SITE
	# Look for task configuration first - userconf first, then RCSITE, common, default; first wins
	if [ -e ~/.tasks.conf ]
	then
		RCTASKLINE=$(grep -h "^$RCTASKNAME:" ~/.tasks.conf || :)
	fi
	if [ -n "$RCTASKLINE" ]
	then
		eval ${RCTASKLINE#*:}
		[ -n "$RCCOMMAND" ] && return 0 # for an RCCOMMAND, there's no script
	else
		for SITE in "sites/$RCSITE" sites/common defaultsite
		do
			TASKFILE="$RCROOT/$SITE/tasks.conf"
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
	# RCSITE/tasks/, then default/tasks/
	if [ -n "$RCSCRIPT" ]
	then
		if [[ $RCSCRIPT = */* ]] # was the full path specified?
		then
			[ ! -e "$RCSCRIPT" ] && errorout "Task script \"$RCSCRIPT\" not found for $RCTASKNAME"
			RCSCRIPTPATH="$RCSCRIPT"
			return 0
		fi
	else
		RCSCRIPT=$RCTASKNAME
	fi
	# Now search site directories for RCSCRIPTPATH
	if [ -e "$RCROOT/sites/$RCSITE/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCROOT/sites/$RCSITE/tasks/${RCTASKNAME}"
	elif [ -e "$RCROOT/sites/$RCSITE/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCROOT/sites/$RCSITE/tasks/${RCTASKNAME}.sh"
	elif [ -e "$RCROOT/sites/common/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCROOT/sites/common/tasks/${RCTASKNAME}"
	elif [ -e "$RCROOT/sites/common/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCROOT/sites/common/tasks/${RCTASKNAME}.sh"
	elif [ -e "$RCROOT/defaultsite/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCROOT/defaultsite/tasks/${RCTASKNAME}"
	elif [ -e "$RCROOT/defaultsite/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCROOT/defaultsite/tasks/${RCTASKNAME}.sh"
	else
		errorout "Unable to locate task \"$RCTASKNAME\", maybe it's a job?"
	fi
	RCSCRIPTCFGLINE=$(grep -h "^#RCCONFIG:" "$RCSCRIPTPATH" || :)
	if [ -n "$RCSCRIPTCFGLINE" ]
	then
		eval ${RCSCRIPTCFGLINE#*:}
		# Configured task options override task defaults, so re-eval
		[ -n "$RCTASKLINE" ] && eval ${RCTASKLINE#*:}
	fi
	return 0
}

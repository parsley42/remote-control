#!/bin/bash
# tasklib.sh - rc task functions

connect(){
	local RCREMOTE=$1
	shift
	if [ "$RCREMOTE" = "localhost" ]
	then
		cat > $RCTASKTMP
		$RCTASKTMP "$@"
	else
		ssh $RCSSHOPTS -T $RCREMOTE "$@"
	fi
}

# Piper generates the input to ssh, which amounts to a shell script run
# in immediate mode
piper(){
	local RCCMDELEVATE
	if [ "$1" = "-c" ]
	then
		RCCMDELEVATE="true"
		RCSCRIPT="$3"
		shift
	fi
	local RCHOST=$1
	local RCTASK="$2"
	shift 2
	if [ "$RCHOST" = "localhost" ]
	then
		# When running locally, we need to spit out the shell heading and
		# remove the temporary file.
		echo "#!/bin/bash -e"
		echo "rm -f $RCTASKTMP"
	fi
	# If we're sudo'ing, take care of that first
	if [ -n "$RCELEVATE" ]
	then
		case $RCELEVATETYPE in
			SUDOPASS)
				# To supply a sudo password we have to jump through some hoops
				# with a very temporary sudo askpass helper script
				RCASKPASS=rc-helper-$(date | md5sum | cut -f 1 -d' ').sh
				echo "export SUDO_ASKPASS=\$HOME/$RCASKPASS"
				echo "echo '#!/bin/bash' > \$HOME/$RCASKPASS"
				[ -n "$RCDRYRUN" ] && echo "RCSUDOPASS=\"echo <password>\""
				if [ -z "$RCDRYRUN" ]
				then
					[ -n "$RCTRACE" ] && echo "set +x"
					echo "RCSUDOPASS=\"echo $RCSUDOPASS\""
					[ -n "$RCTRACE" ] && echo "set -x"
				fi
				cat $RCROOT/libsremote/sudosetup.sh
				# This will fail if user's $HOME != /home/$SUDO_USER
				# but the file will be removed below after sudo exits
				echo "rm -f /home/\$SUDO_USER/$RCASKPASS"
				;;
			SUDONOPASS)
				# When there's no password required, we just sudo su
				echo "sudo su <<\"RCSUDOSCRIPTEOF\""
				;;
			ROOTLOGIN)
				unset RCELEVATE # so we don't bother closing sudo later
				;;
		esac
	fi
	RCTASKID=$(generateid)
	if [ -n "$RCINTERPRETER" ]
	then # For custom interpreter, we send only the script, no var defs
		echo "$RCINTERPRETER -- - $SETSTRING <<\"RCINTERPRETEREOF\""
	else # bash scripts get a lot more
		echo "set -e"
		[ -n "$RCTRACE" ] && echo "set -x"
		# Set the task ID
		echo "RCTASKID=$RCTASKID"
		# Send libraries for remote use
		for RCREMOTELIB in errtrap.sh status.sh
		do
			if ! echo " $RCEXCLUDELIBS " | grep -q " $RCREMOTELIB "
			then
				cat $RCROOT/libsremote/$RCREMOTELIB
			fi
		done
		# Send variable definitions
		taskdefs $RCHOST $RCTASK
		# Set the positional values, options and arguments
		[ -n "$SETSTRING" ] && echo "set -- $SETSTRING" || :
		echo "echo $RCTASKID task starting on $RCHOST: $(basename $RCSCRIPT) >&2"
		# Make note of the line before the script starts
		echo "RCFIRSTLINE=\$LINENO"
	fi
	# Finally, run the task
	if [ "$RCCMDELEVATE" = "true" ]
	then
		echo "$RCTASK"
	else
		cat $RCSCRIPTPATH
	fi
	# If a custom interpreter was used, close the heredoc
	if [ -n "$RCINTERPRETER" ]
	then
		echo "RCINTERPRETEREOF"
	fi
	# Close the sudo verbatim heredoc started in sudosetup.sh
	if [ -n "$RCELEVATE" ]
	then
		echo "RCSUDOSCRIPTEOF"
		echo "RETVAL=\$?"
		[ "$RCELEVATETYPE" = "SUDOPASS" ] && echo "rm -f \$HOME/$RCASKPASS"
		echo "exit \$RETVAL"
	fi
}

hosterrorcheck(){
	RCRETVAL=$?
	if [ $RCRETVAL -ne 0 ]
	then
		if [ $RCRETVAL -eq 255 ]
		then
			echo "ssh process exited with error connecting to $RCREMOTE, exit code:255" >&2
		else
			[ -z "$RCPARALLEL" ] && echo "Remote host $RCREMOTE exited with error code:$RCRETVAL" >&2
		fi
		if [ $RCNUMHOSTS -eq 1 ]
		then
			# If we're operating on a single host and it fails,
			# exit with the same error code.
			trap - ERR
			exit $RCRETVAL
		fi
	fi
	return $RCRETVAL
}

# taskdefs cat's out all the definitions files relevant to a task.
# Each successive definitions file can override a previous.
taskdefs (){
	local RCHOST=$1
	local RCTASK=$2
	# If there's a site.defs file, add it in
	[ -e "$RCSITEDIR/$RCDEFAULTSITE/site.defs" ] && cat "$RCSITEDIR/$RCDEFAULTSITE/site.defs" || :
	# Same for a host .defs file
	[ -e "$RCSITEDIR/$RCDEFAULTSITE/hosts/$RCHOST/host.defs" ] && cat "$RCSITEDIR/$RCDEFAULTSITE/hosts/$RCHOST/host.defs" || :
	# First, any definitions from defaults
	[ -e "$RCROOT/defaults/taskdefs/${RCTASK}.defs" ] && cat "$RCROOT/defaults/taskdefs/${RCTASK}.defs" || :
	# ... then definitions from sites/common
	[ -e "$RCSITEDIR/common/taskdefs/${RCTASK}.defs" ] && cat "$RCSITEDIR/common/taskdefs/${RCTASK}.defs" || :
	# Now check for site task definitions
	[ -e "$RCSITEDIR/$RCDEFAULTSITE/taskdefs/${RCTASK}.defs" ] && cat "$RCSITEDIR/$RCDEFAULTSITE/taskdefs/${RCTASK}.defs" || :
	# ... and host task definitions
	[ -e "$RCSITEDIR/$RCDEFAULTSITE/hosts/$RCHOST/taskdefs/${RCTASK}.defs" ] && cat "$RCSITEDIR/$RCDEFAULTSITE/hosts/$RCHOST/taskdefs/${RCTASK}.defs" || :
	# Finally, if an RCDEFSFILE argument was passed on the command line, it overrides everything
	[ -n "$RCDEFSFILE" ] && cat "$RCDEFSFILE" || :
}

# List all site tasks for list command
listsitetasks(){
	trap 'func_error_handler ${FUNCNAME[0]} "${BASH_COMMAND}" $LINENO $?' ERR
	local RCDEFAULTSITESCRIPT RCSCRIPT SCRIPTCONF SITE RCTASKLINE
	if [ "$1" = defaults ]
	then
		SITE=$RCROOT/defaults
	else
		SITE="$RCSITEDIR/${1:-$RCDEFAULTSITE}"
	fi
	echo "### Tasks for $SITE:"
	if [ -e "$SITE/tasks.conf" ]
	then
		grep -v '^$' $SITE/tasks.conf | grep -v '^#' | grep RCCOMMAND || :
	fi
	if [ -d "$SITE/tasks" ]
	then
		for RCDEFAULTSITESCRIPT in $(cd "$SITE/tasks"; echo *)
		do
			[ ! -e "$SITE/tasks/$RCDEFAULTSITESCRIPT" ] && break # when * expands to *
			RCSCRIPT=$(basename $RCDEFAULTSITESCRIPT .sh)
			if [ -e "$SITE/tasks.conf" ]
			then
				RCTASKLINE=$(grep -h "^$RCSCRIPT:" "$SITE/tasks.conf" || :)
			fi
			SCRIPTCONF=$(grep -h "^#RCCONFIG:" "$SITE/tasks/$RCDEFAULTSITESCRIPT" || :)
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
}

# Get RCCOMMAND or RCSCRIPT (full path) for RCTASKNAME, and configuration (RCELEVATE, etc.)
gettaskconf(){
	trap 'func_error_handler ${FUNCNAME[0]} "${BASH_COMMAND}" $LINENO $?' ERR
	local RCTASKNAME=$1
	local SITE
	# Look for task configuration first - userconf first, then RCDEFAULTSITE, common, default; first wins
	if [ -e ~/.tasks.conf ]
	then
		RCTASKLINE=$(grep -h "^$RCTASKNAME:" ~/.tasks.conf || :)
	fi
	if [ -n "$RCTASKLINE" ]
	then
		eval ${RCTASKLINE#*:}
		[ -n "$RCCOMMAND" ] && return 0 # for an RCCOMMAND, there's no script
	else
		for SITE in "$RCSITEDIR/$RCDEFAULTSITE" $RCSITEDIR/common $RCROOT/defaults
		do
			TASKFILE="$SITE/tasks.conf"
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
	# RCDEFAULTSITE/tasks/, then default/tasks/
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
	if [ -e "$RCSITEDIR/$RCDEFAULTSITE/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCSITEDIR/$RCDEFAULTSITE/tasks/${RCTASKNAME}"
	elif [ -e "$RCSITEDIR/$RCDEFAULTSITE/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCSITEDIR/$RCDEFAULTSITE/tasks/${RCTASKNAME}.sh"
	elif [ -e "$RCSITEDIR/common/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCSITEDIR/common/tasks/${RCTASKNAME}"
	elif [ -e "$RCSITEDIR/common/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCSITEDIR/common/tasks/${RCTASKNAME}.sh"
	elif [ -e "$RCROOT/defaults/tasks/${RCTASKNAME}" ]
	then
		RCSCRIPTPATH="$RCROOT/defaults/tasks/${RCTASKNAME}"
	elif [ -e "$RCROOT/defaults/tasks/${RCTASKNAME}.sh" ]
	then
		RCSCRIPTPATH="$RCROOT/defaults/tasks/${RCTASKNAME}.sh"
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

# joblib.sh - job library for rc

# writeresumefile writes out a compiled VAR=VALUE file for the job, performing
# syntax checking along the way.
writeresumefile(){
	local RCJOBCFGLINE RCJOBSCRIPT RCREQUIRELINE RCVARLINE RCVAR
	RCJOBSCRIPT=$1
	RCRESUMEFILE="$RCRESUMEDIR/rc-resume-${RCJOBID}.defs"
	cat > "$RCRESUMEFILE" << EOF
RCJOB=$RCJOB
RCJOBSCRIPT=$RCJOBSCRIPT
RCDEFSNAME=$RCDEFSNAME
RCPROMPT=$RCPROMPT
EOF
	if [ -n "$RCREQUIRECONFIRM" ]
	then
		echo "RCREQUIRECONFIRM=$RCREQUIRECONFIRM" >> "$RCRESUMEFILE"
		if [ -n "$RCCONFIRMCODE" ]
		then
			echo "RCCONFIRMCODE=$RCCONFIRMCODE" >> "$RCRESUMEFILE"
		else
			echo "RCCONFIRMCODE=$RCJOBID" >> "$RCRESUMEFILE"
		fi
	else
		echo "RCREQUIRECONFIRM=\"\"" >> "$RCRESUMEFILE"
	fi
	if [ -n "$RCREQVARS" ]
	then
		echo "RCREQVARS=\"$RCREQVARS\"" >> "$RCRESUMEFILE"
	else
		RCREQUIRELINE=$(grep -h "^#RCREQVARS=" "$RCJOBSCRIPT" || :)
		[ -n "$RCREQUIRELINE" ] && eval ${RCREQUIRELINE#\#}
		echo "RCREQVARS=\"$RCREQVARS\"" >> "$RCRESUMEFILE"
	fi
	RCREQDEFLINE=$(grep -h "^#RCREQDEFS=" "$RCJOBSCRIPT" || :)
	[ -n '$RCREQDEFLINE' ] && eval ${RCREQDEFLINE#\#}
	RCOPTVARLINE=$(grep -h "^#RCOPTVARS=" "$RCJOBSCRIPT" || :)
	[ -n '$RCOPTVARLINE' ] && eval ${RCOPTVARLINE#\#}
	[ -n "$RCOPTVARS" ] && echo "RCOPTVARS=\"$RCOPTVARS\"" >> $RCRESUMEFILE
	RCRECORDED=""
	# Now record all required and optional vars
	for RCVAR in $RCREQVARS $RCOPTVARS
	do
		echo "$RCRECORDED" | grep -q "\<$RCVAR\>" && continue
		RCRECORDED="$RCRECORDED $RCVAR"
		parsevarline $RCVAR
		if [ -n "${!RCVAR}" ]
		then
			if ! echo "${!RCVAR}" | grep -qP "$RCVARREGEX"
			then
				errormsg "\"${!RCVAR}\" doesn't match regex for $RCVAR: \"$RCVARREGEX\", using default value: \"$RCVARDEFAULT\""
				echo "$RCVAR=\"$RCVARDEFAULT\"" >> "$RCRESUMEFILE"
			else
				echo "$RCVAR=\"${!RCVAR}\"" >> "$RCRESUMEFILE"
			fi
		else
			echo "$RCVAR=\"$RCVARDEFAULT\"" >> "$RCRESUMEFILE"
		fi
	done
}

# Catjob is only called by rc
catjob(){
	# We could have just used RCJOBSCRIPT, but it looks better this way
	local RCJOBPATH="$1"
	shift
	RCRESUMEFILE="$RCRESUMEDIR/rc-resume-${RCJOBID}.defs"
	echo "#!/bin/bash -e"
	# Clean up right away
	[ -n "$RCJOBTMP" ] && echo "rm -f $RCJOBTMP"
	# First include all variable definitions
	if [ -e "$RCRESUMEFILE" ]
	then
		echo "#### INCLUDING $RCRESUMEFILE"
		cat "$RCRESUMEFILE"
		echo
	fi
	# Next the user's .rcconfig (mainly for RCADMINMAIL), which may be
	# overridden by a job defs file.
	if [ -e ~/.rcconfig ]
	then
		echo "#### INCLUDING ~/.rcconfig"
		cat ~/.rcconfig
	fi
	# Now include all .defs files, which may have definitions that expand
	# variables from above.
	for RCJOBDEFPATH in "$RCROOT/defaultsite" "$RCROOT/sites/common" "$RCROOT/sites/$RCSITE"
    do
        if [ -e "$RCJOBDEFPATH/jobdefs/${RCDEFSNAME}.defs" ]
        then
            echo "#### INCLUDING $RCJOBDEFPATH/jobdefs/${RCDEFSNAME}.defs"
            cat "$RCJOBDEFPATH/jobdefs/${RCDEFSNAME}.defs"
            echo
        fi
    done
	for LOCALLIB in jobapi errhandle common
	do
		echo "#### INCLUDING $RCROOT/libslocal/$LOCALLIB.sh"
		cat "$RCROOT/libslocal/$LOCALLIB.sh"
		echo
	done
	echo "jobtrap"
	echo "#### JOBSCRIPT: \"$RCJOBPATH\""
	# If -h or help is given, pass it through to job script; everything
	# else is specified as VAR=VAL and processed by rc, then written to
	# the resume file.
	echo set -- $1
	[ -n "$RCTRACE" ] && echo "set -x"
	echo "RCFIRSTLINE=\$LINENO"
	cat "$RCJOBPATH"
}

# joblib.sh - job library for rc

# writeresumefile writes out a compiled VAR=VALUE file for the job, performing
# syntax checking along the way.
writeresumefile(){
	local RCJOBCFGLINE RCJOBSCRIPT RCREQUIRELINE RCVARLINE RCVAR
	local RCALLMET RCDEFLINE RCREQUIRE
	RCJOBSCRIPT=$1
	# First make sure all required definitions are defined
	RCALLMET="true"
	RCDEFLINE=$(grep -h "^#RCREQDEFS=" "$RCJOBSCRIPT" || :)
	[ -n "$RCDEFLINE" ] && eval ${RCDEFLINE#\#}
	# check vars that must be defined in a .defs file
	for RCREQUIRE in $RCREQDEFS
	do
		if [ -z "${!RCREQUIRE}" ]
		then
			RCALLMET="false"
			errormsg "Required definition $RCREQUIRE not defined"
		fi
	done
	if [ "$RCALLMET" = "false" ]
	then
		errorout "Missing definitions must be defined in a .defs file"
	fi
	# Once we know all definitions are good, go ahead and
	# start writing out the file.
	RCRESUMEFILE="$RCRESUMEDIR/rc-resume-${RCJOBID}.defs"
	cat > "$RCRESUMEFILE" << EOF
RCJOB=$RCJOB
RCJOBSCRIPT=$RCJOBSCRIPT
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
	[ -n '$RCOPTLINE' ] && eval ${RCOPTLINE#\#}
	RCRECORDED=""
	# Now record all required and optional vars
	for RCVAR in $RCREQVARS $RCOPTVARS
	do
		echo "$RCRECORDED" | grep -q "\<$RCVAR\>" && continue
		RCRECORDED="$RCRECORDED $RCVAR"
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
	# Required defs don't have var lines, so skip parsing, just write them out.
	# If they're not defined, the script will error out above.
	for RCVAR in $RCREQDEFS
	do
		echo "$RCVAR=\"${!RCVAR}\"" >> $RCRESUMEFILE
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
	if [ -e "$RCRESUMEFILE" ]
	then
		echo "#### INCLUDING $RCRESUMEFILE"
		cat "$RCRESUMEFILE"
		echo
	fi
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

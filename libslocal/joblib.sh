# joblib.sh - job library for rc

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

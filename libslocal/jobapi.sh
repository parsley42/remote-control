# jobapi.sh - API library for job scripts

# writeresumefile writes out a compiled VAR=VALUE file for the job to save
# state between runs. It also performs syntax checking of the job metadata.
writeresumefile(){
	local RCJOBCFGLINE RCREQUIRELINE RCVARLINE RCVAR RCRECORDED
	RCRESUMEFILE="$RCRESUMEDIR/rc-resume-${RCJOBID}.defs"
	cat > "$RCRESUMEFILE" << EOF
RCJOB=$RCJOB
RCJOBID=$RCJOBID
RCJOBSCRIPT=$RCJOBSCRIPT
RCDEFSNAME=$RCDEFSNAME
RCPROMPT=$RCPROMPT
RCREQUIRECONFIRM=$RCREQUIRECONFIRM
EOF
	if [ "$RCREQUIRECONFIRM" = "true" ]
	then
		# The generated confirmation code
		echo "RCCONFIRMCODE=$RCCONFIRMCODE" >> "$RCRESUMEFILE"
		# The user-supplied confirmation code (if it exists)
		echo "RCCONFIRMED=$RCCONFIRMED" >> "$RCRESUMEFILE"
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
	RCDEPVARLINE=$(grep -h "^#RCDEPVARS=" "$RCJOBSCRIPT" || :)
	[ -n '$RCDEPVARLINE' ] && eval ${RCDEPVARLINE#\#}
	[ -n "$RCDEPVARS" ] && echo "RCDEPVARS=\"$RCDEPVARS\"" >> $RCRESUMEFILE
	RCOPTVARLINE=$(grep -h "^#RCOPTVARS=" "$RCJOBSCRIPT" || :)
	[ -n '$RCOPTVARLINE' ] && eval ${RCOPTVARLINE#\#}
	[ -n "$RCOPTVARS" ] && echo "RCOPTVARS=\"$RCOPTVARS\"" >> $RCRESUMEFILE
	RCRECORDED=""
	# Now record all required and optional vars
	for RCVAR in $RCREQVARS $RCOPTVARS $RCDEPVARS
	do
		echo "$RCRECORDED" | grep -q "\<$RCVAR\>" && continue
		RCRECORDED="$RCRECORDED $RCVAR"
		parsevarline $RCVAR
		# Test if the variable has been set to anything, even ""
		if [ ! "${!RCVAR+UNSET}" = "" ]
		then
			if ! echo "${!RCVAR}" | grep -qP "$RCVARREGEX"
			then
				errormsg "\"${!RCVAR}\" doesn't match regex for $RCVAR: \"$RCVARREGEX\""
			else
				echo "$RCVAR=\"${!RCVAR}\"" >> "$RCRESUMEFILE"
			fi
		fi
	done
}

# parsevarline extracts information about a job variable from the script. This function is duplicated
# in joblib.sh
parsevarline(){
	local RCVAR=$1
	local RCLINEPART
	RCVARLINE=$(grep -h "^#$RCVAR:" $RCJOBSCRIPT || :)
	[ -z "$RCVARLINE" ] && errorout "Variable specification for \"$RCVAR\" not found in $RCJOBSCRIPT, check syntax"
	[[ $RCVARLINE != *:*:*:* ]] && errorout "Missing fields in definition of \"$RCVAR\" in $RCJOBSCRIPT, check syntax"
	[[ $RCVARLINE = *:*:*:*:* ]] && errorout "Too many fields in definition of \"$RCVAR\" in $RCJOBSCRIPT, check syntax"
	RCLINEPART="${RCVARLINE#*:}"
	RCVARREGEX="${RCLINEPART%%:*}"
	[ -z "$RCVARREGEX" ] && RCVARREGEX='.*'
	RCLINEPART="${RCLINEPART#*:}"
	RCVARDEFAULT="${RCLINEPART%%:*}"
	if [ -n "$RCVARDEFAULT" ]
	then
		if ! echo "$RCVARDEFAULT" | grep -qP "$RCVARREGEX"
		then
			errorout "Default value for $RCVAR \"$RCVARDEFAULT\" doesn't match regex for the variable \"$RCVARREGEX\" in $RCJOBSCRIPT, check syntax"
		fi
	fi
	RCLINEPART="${RCLINEPART#*:}"
	RCVARDESC="$RCLINEPART"
}

# processvars is called by the job script to:
# - check that all required variables are set
# - prompt for required and optional variables are set
# - check for confirm code if confirmation is required
# if procssvars doesn't exit, the job script can continue with all
# vars set to appropriate values.
processvars(){
	local RCREQUIRE RCALLMET RCVARLINE RCNEXTVAR RCANSWERED RVAR RCOPT RCVAL RCDEF RCECHOED
	RCALLMET="true"
	if [ "$RCPROMPT" = "true" ]
	then # prompting workflow
		RCANSWERED=""
		RCPROMPT="false"
		while :
		do
			# Find a var that needs to be answered, start with optional
			RCNEXTVAR=""
			RCOPTIONAL="true"
			for RCVAR in $RCOPTVARS RC_END_OPT $RCREQVARS
			do
				[ "$RCVAR" = "RC_END_OPT" ] && { RCOPTIONAL="false"; continue; }
				if ! echo "$RCANSWERED" | grep -q "\<$RCVAR\>"
				then
					RCNEXTVAR=$RCVAR
					break
				fi
			done
			[ -z "$RCNEXTVAR" ] && break # all vars should be set
			parsevarline $RCNEXTVAR
			unset RCDEFVAL RCDEF
			if [ -n "${!RCNEXTVAR}" ]
			then
				RCDEFVAL=${!RCNEXTVAR}
				RCDEF=" (default:${RCDEFVAL})"
			elif [ -n "$RCVARDEFAULT" ]
			then
				RCDEFVAL=$RCVARDEFAULT
				RCDEF=" (default:${RCDEFVAL})"
			fi
			RCOPT=""
			[ "$RCOPTIONAL" = "true" ] && RCOPT=" (optional)"
			echo -en "$RCVARDESC\n${RCNEXTVAR}${RCDEF}${RCOPT}: "
			read RCVAL
			if [ -z "$RCVAL" ]
			then
				if [ -z "$RCDEFVAL" ]
				then
					if [ "$RCOPTIONAL" = "false" ]
					then
						echo "$RCNEXTVAR can't be blank"
					else
						RCANSWERED="$RCANSWERED $RCNEXTVAR"
					fi
				else
					RCANSWERED="$RCANSWERED $RCNEXTVAR"
					eval $RCNEXTVAR=\"$RCDEFVAL\"
				fi
			else
				if echo "$RCVAL" | grep -qP "$RCVARREGEX"
				then
					RCANSWERED="$RCANSWERED $RCNEXTVAR"
					eval $RCNEXTVAR=\"$RCVAL\"
				else
					echo "\"$RCVAL\" doesn't match regex for $RCNEXTVAR: $RCVARREGEX" >&2
				fi
			fi
			# If the depvars function is defined, call it in case required vars needs to change
			type depvars &>/dev/null && depvars
		done
		writeresumefile
	else # exit / resume workflow
		# If the depvars function is defined, call it
		type depvars &>/dev/null && depvars
		for RCREQUIRE in $RCREQVARS
		do
			# Test if the required variable has been set to anything, even ""
			if [ "${!RCREQUIRE+UNSET}" = "" ]
			then
				RCALLMET="false"
				# All vars were checked in writeresumefile; this can't be blank
				parsevarline $RCREQUIRE
				echo "Missing: $RCREQUIRE:$RCVARDESC"
			fi
		done
		if [ "$RCALLMET" = "false" ]
		then
			writeresumefile
			for RCVAR in $RCOPTVARS
			do
				parsevarline $RCVAR
				echo "Optional: $RCVAR:$RCVARDESC"
			done
			echo "JOBID: $RCJOBID"
			echo "Continue job with \"rc resume $RCJOBID (var=value ...)\" to satisfy missing vars"
			# exit value 2 -> more params required
			exit 2
		fi
	fi
	# At this point, all required and optional vars for the job have appropriate
	# values. Next question is, do we require confirmation, and has the
	# confirmation code been supplied?
	if [ "$RCREQUIRECONFIRM" = "true" -a "$RCCONFIRMCODE" != "$RCCONFIRMED" ]
	then
		# When is this gonna ever happen?
		[ -n "$RCCONFIRMED" ] && echo "Invalid confirmation code: $RCCONFIRMED"
		echo -e "\n*** THIS JOB REQUIRES CONFIRMATION, continue with \"rc resume $RCJOBID CONFIRM=$RCCONFIRMCODE\""
		echo "Confirm: $RCCONFIRMCODE"
		echo "Currently configured parameters:"
		RCECHOED=""
		# Now record all required and optional vars
		RCOPTIONAL="false"
		for RCVAR in $RCREQVARS RC_START_OPT $RCOPTVARS
		do
			[ "$RCVAR" = "RC_START_OPT" ] && { RCOPTIONAL="true"; continue; }
			echo "$RCECHOED" | grep -q "\<$RCVAR\>" && continue
			RCECHOED="$RCECHOED $RCVAR"
			parsevarline $RCVAR
			if [ -n "${!RCVAR}" -o "$RCOPTIONAL" != "true" ]
			then
				echo "# $RCVARDESC"
				echo "$RCVAR=${!RCVAR}"
			fi
		done
		writeresumefile
		# exit value 3 -> confirmation required
		exit 3
	else
		echo "Running job $RCJOBID, modify and re-run with \"rc resume $RCJOBID (var=value ...)\""
	fi
}

addrequired(){
	local RCREQUIRE
	for RCREQUIRE in $*
	do
		echo " $RCREQVARS " | grep -q " $RCREQUIRE " || RCREQVARS="$RCREQVARS $RCREQUIRE"
	done
	RCREQVARS=${RCREQVARS# }
	RCREQVARS=${RCREQVARS% }
}

removerequired(){
	local RCNEWREQS=""
	local REMOVE="$*"
	local RCREQUIRE
	for RCREQUIRE in $RCREQVARS
	do
		echo " $REMOVE " | grep -q " $RCREQUIRE " || RCNEWREQS="$RCNEWREQS $RCREQUIRE"
	done
	RCREQVARS=${RCNEWREQS# }
	RCREQVARS=${RCREQVARS% }
}

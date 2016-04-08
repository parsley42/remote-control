# jobapi.sh - API library for job scripts

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

processvars(){
	local RCREQUIRE RCALLMET RCVARLINE
	RCALLMET="true"
	if [ "$RCPROMPT" = "true" ]
	then # prompting workflow
		while :
		do
			[ -z "$RCREQVARS" ] && break
		done
	else # exit / resume workflow
		# If the depvars function is defined, call it
		type depvars &>/dev/null && depvars
		for RCREQUIRE in $RCREQVARS
		do
			if [ -z "${!RCREQUIRE}" ]
			then
				RCALLMET="false"
				# All vars were checked in writeresumefile; this can't be blank
				parsevarline $RCREQUIRE
				echo "Missing required variable $RCREQUIRE:$RCVARDESC" >&2
			fi
		done
		if [ "$RCALLMET" = "false" ]
		then
			echo "Continue job with \"rc resume $RCJOBID (var=value ...)\" to satisfy missing vars"
			exit 2
		fi
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

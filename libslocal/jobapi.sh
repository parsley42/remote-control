# jobapi.sh - API library for job scripts

# parsevarline extracts information about a job variable from the script. This function is duplicated
# in joblib.sh
parsevarline(){
	local RCVAR=$1
	local RCLINEPART
	RCVARLINE=$(grep -h "^#$RCVAR:" $RCJOBSCRIPT || :)
	[ -z "$RCVARLINE" ] && errorout "Variable specification for \"$RCVAR\" not found in $RCJOBSCRIPT, check syntax"
	[[ $RCVARLINE != *:*:*:* ]] && errorout "Missing fields in definition of \"$RCVAR\" in $RCJOBSCRIPT, check syntax"
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

checkrequireddefs(){
	local RCALLMET RCDEFLINE RCREQUIRE
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
}

processvars(){
	local RCREQUIRE RCALLMET RCVARLINE
	checkrequireddefs
	RCALLMET="true"
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

# joblib.sh - library for rc and job scripts
findrcvars(){
	local RCVARPATH

	for RCVARPATH in "$RCROOT/sites/$RCSITE" "$RCROOT/sites/common" "$RCROOT/defaultsite"
	do
		if [ -e "$RCVARPATH/jobvars/${RCJOB}.vars" ]
		then
			RCVARSFILE="$RCVARPATH/jobvars/${RCJOB}.vars"
			break
		fi
	done
}

writejobdefs(){
	local RCJOBCFGLINE RCJOBSCRIPT RCREQUIRELINE RCVARLINE RCVAR
	RCJOBSCRIPT=$1
	findrcvars
	RCDEFSOUT="$RCRESUMEDIR/${RCJOBID}.defs"
	cat > "$RCDEFSOUT" << EOF
RCJOB=$RCJOB
RCJOBSCRIPT=$RCJOBSCRIPT
RCROOT=$RCROOT
EOF
	if [ -n "$RCREQUIRECONFIRM" ]
	then
		echo "RCREQUIRECONFIRM=$RCREQUIRECONFIRM" >> "$RCDEFSOUT"
		if [ -n "$RCCONFIRMCODE" ]
		then
			echo "RCCONFIRMCODE=$RCCONFIRMCODE" >> "$RCDEFSOUT"
		else
			echo "RCCONFIRMCODE=$(generateid)" >> "$RCDEFSOUT"
		fi
	else
		echo "RCREQUIRECONFIRM=\"\"" >> "$RCDEFSOUT"
	fi
	if [ -n "$RCJOBREQUIREVARS" ]
	then
		echo "RCJOBREQUIREVARS=\"$RCJOBREQUIREVARS\"" >> "$RCDEFSOUT"
	else
		RCREQUIRELINE=$(grep -h "^#RCJOBREQUIREVARS=" "$RCJOBSCRIPT" || :)
		[ -n "$RCREQUIRELINE" ] && eval ${RCREQUIRELINE#\#}
		echo "RCJOBREQUIREVARS=\"$RCJOBREQUIREVARS\"" >> "$RCDEFSOUT"
	fi
	if [ -e "$RCVARSFILE" ]
	then
		while read RCVARLINE
		do
			[[ $RCVARLINE = \#* ]] && continue
			RCVAR=${RCVARLINE%%:*}
			echo "$RCVAR=\"${!RCVAR}\"" >> "$RCDEFSOUT"
		done < "$RCVARSFILE"
	fi
}

checkrequireddefs(){
	local ALLMET DEFLINE REQUIRE
	ALLMET="true"
	DEFLINE=$(grep -h "^#RCJOBREQUIREDEFS=" "$RCJOBSCRIPT")
	[ -n "$DEFLINE" ] && eval ${DEFLINE#\#}
	# first check vars that must be defined in a .defs file
	for REQUIRE in $RCJOBREQUIREDEFS
	do
		if [ -z "${!REQUIRE}" ]
		then
			ALLMET="false"
			errormsg "Required definition $REQUIRE not defined"
		fi
	done
	if [ "$ALLMET" = "false" ]
	then
		errorout "Missing definitions must be defined in a .defs file"
	fi
}

processvars(){
	local DEPVARS REQUIRE ALLMET VARLINE
	checkrequireddefs
	ALLMET="true"
	findrcvars
	# See if the job defined a depvars function
	type depvars &>/dev/null && DEPVARS="true" || :
	for REQUIRE in $RCJOBREQUIREVARS
	do
		if [ -z "${!REQUIRE}" ]
		then
			ALLMET="false"
			[ ! -e "$RCVARSFILE" ] && errorout "Found required var $REQUIRE but no .vars file for $RCJOB"
			VARLINE=$(grep -h "^$REQUIRE:" $RCVARSFILE || :)
			[ -z "$VARLINE" ] && errorout "Found required var $REQUIRE but it wasn't listed in $RCVARSFILE"
			errormsg "Missing $VARLINE" >&2
		fi
	done
	if [ "$ALLMET" = "false" ]
	then
		echo "Continue job with \"rc resume $RCJOBID (var=value ...)\" to satisfy missing vars"
		exit 2
	fi
}

catjob(){
	local RCJOBPATH="$1"
	shift
	local RCDEFPATH
	echo "#!/bin/bash -e"
	# Clean up right away
	echo "rm -f $RCJOBTMP"
	[ -e ~/.rcconfig ] && { echo "#### INCLUDING ~/.rcconfig"; cat ~/.rcconfig; echo; }
	for RCJOBDEFPATH in "$RCROOT/defaultsite" "$RCROOT/sites/common" "$RCROOT/sites/$RCSITE"
	do
		if [ -e "$RCJOBDEFPATH/jobdefs/${RCJOB}.defs" ]
		then
			echo "#### INCLUDING $RCJOBDEFPATH/jobdefs/${RCJOB}.defs"
			cat "$RCJOBDEFPATH/jobdefs/${RCJOB}.defs"
			echo
		fi
	done
	if [ -e "$RCRESUMEDIR/${RCJOBID}.defs" ]
	then
		echo "#### INCLUDING $RCRESUMEDIR/${RCJOBID}.defs"
		cat "$RCRESUMEDIR/${RCJOBID}.defs"
		echo
	fi
	for LOCALLIB in joblib errhandle common
	do
		echo "#### INCLUDING $RCROOT/libslocal/$LOCALLIB.sh"
		cat "$RCROOT/libslocal/$LOCALLIB.sh"
		echo
	done
	echo "jobtrap"
	echo "#### JOBSCRIPT: \"$RCJOBPATH\""
	echo set -- "$@"
	[ -n "$RCTRACE" ] && echo "set -x"
	echo "RCFIRSTLINE=\$LINENO"
	cat "$RCJOBPATH"
}

addrequired(){
	local REQUIRE
	for REQUIRE in $*
	do
		echo " $RCJOBREQUIREVARS " | grep -q " $REQUIRE " || RCJOBREQUIREVARS="$RCJOBREQUIREVARS $REQUIRE"
	done
	RCJOBREQUIREVARS=${RCJOBREQUIREVARS# }
	RCJOBREQUIREVARS=${RCJOBREQUIREVARS% }
}

removerequired(){
	local NEWREQUIRES=""
	local REMOVE="$*"
	local REQUIRE
	for REQUIRE in $RCJOBREQUIREVARS
	do
		echo " $REMOVE " | grep -q " $REQUIRE " || NEWREQUIRES="$NEWREQUIRES $REQUIRE"
	done
	RCJOBREQUIREVARS=${NEWREQUIRES# }
	RCJOBREQUIREVARS=${RCJOBREQUIREVARS% }
}

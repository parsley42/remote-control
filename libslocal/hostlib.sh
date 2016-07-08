# Look up members of a host group and echo space-separated string

resolvehostgroup(){
	functrap
	local HOSTGROUP HOST REST HOSTLIST
	HOSTGROUP=${1#@}
	HOSTFILE="$RCSITEDIR/$RCDEFAULTSITE/hostgroups/${HOSTGROUP}.hosts"
	[ ! -e "$HOSTFILE" ] && { errormsg "Hosts file $RCSITEDIR/$RCDEFAULTSITE/hostgroups/${HOSTGROUP}.hosts doesn't exist"; return 0; }
	while read HOST REST
	do
		[[ $HOST = \#* ]] && continue
		HOSTLIST="$HOSTLIST $HOST"
	done < $HOSTFILE
	addhosts $HOSTLIST
}

# Look up a host alias in hostgroups/* files
resolvehostalias(){
	functrap
	local MATCHHOST HOSTMATCH HOSTLINES
	MATCHHOST=$1
	HOSTLINES=0
	if [ -n "$(ls -A "$RCSITEDIR/$RCDEFAULTSITE/hostgroups/" 2>/dev/null)" ]
	then
		HOSTMATCH=$(grep -Rh "\<$MATCHHOST\>" "$RCSITEDIR/$RCDEFAULTSITE/hostgroups" | sort | uniq)
		HOSTLINES=$(echo "$HOSTMATCH" | wc -l)
	fi
	if [ -n "$HOSTMATCH" -a $HOSTLINES -eq 1 ]
	then
		addhosts ${HOSTMATCH%% *}
		return 0
	fi
	[ $HOSTLINES -gt 1 ] && { errormsg "Host/alias $MATCHHOST found in multiple non-matching host lines: $HOSTMATCH"; return 0; }
	addhosts $MATCHHOST
}

hostnicename(){
	local MATCHHOST=$1
	[ ! -d "$RCSITEDIR/$RCDEFAULTSITE/hostgroups" ] && { RCNICENAME=$MATCHHOST; return 0; }
	if [ -n "$(ls -A "$RCSITEDIR/$RCDEFAULTSITE/hostgroups/")" ]
	then
		local HOSTMATCH=$(grep -Rh "^\<$MATCHHOST\>" "$RCSITEDIR/$RCDEFAULTSITE/hostgroups" | sort | uniq)
		local HOSTLINES=$(echo "$HOSTMATCH" | wc -l)
		if [ $HOSTLINES -eq 1 -a -n "$HOSTMATCH" ]
		then
			RCNICENAME=${HOSTMATCH##* }
		else
			RCNICENAME=$MATCHHOST
		fi
		[ $HOSTLINES -gt 1 ] && { errormsg "Host/alias $MATCHHOST found in multiple non-matching host lines: $HOSTMATCH"; return 0; }
	else
		RCNICENAME=$MATCHHOST
	fi
	return 0
}

# Add hosts to a list: addhosts varname <host> ...
addhosts(){
	functrap
	local ADDHOST

	for ADDHOST in $*
	do
		echo " $RCEXECHOSTS " | grep -q " $ADDHOST " || RCEXECHOSTS="$RCEXECHOSTS $ADDHOST"
	done
	RCEXECHOSTS=${RCEXECHOSTS# }
}

resolvehostlist(){
	functrap
	local HOSTSPEC HOSTARRAY
	for HOSTSPEC in $*
	do
		case $HOSTSPEC in
			@*)
				resolvehostgroup ${HOSTSPEC}
				;;
			*)
				resolvehostalias ${HOSTSPEC}
				;;
		esac
	done
	HOSTARRAY=($RCEXECHOSTS)
	[ ${#HOSTARRAY[@]} -eq 0 ] && { errormsg "Couldn't resolve any hosts in: $*"; return 0; } || :
}

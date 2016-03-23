# Look up members of a host group and echo space-separated string

resolvehostgroup(){
	local HOSTGROUP=${1#@}
	local HOST REST
	HOSTFILE="$RCROOT/sites/$RCSITE/hostgroups/${HOSTGROUP}.hosts"
	[ ! -e "$HOSTFILE" ] && { errormsg "Hosts file $RCROOT/sites/$RCSITE/hostgroups/${HOSTGROUP}.hosts doesn't exist"; return 1; }
	while read HOST REST
	do
		[[ $HOST = \#* ]] && continue
		echo -n "$HOST "
	done < $HOSTFILE
	echo
}

# Look up a host alias in hostgroups/* files
resolvehostalias(){
	local MATCHHOST=$1
	local HOSTMATCH=$(grep -Rh "\<$MATCHHOST\>" "$RCROOT/sites/$RCSITE/hostgroups" | sort | uniq)
	local HOSTLINES=$(echo "$HOSTMATCH" | wc -l)
	if [ -n "$HOSTMATCH" -a $HOSTLINES -eq 1 ]
	then
		echo ${HOSTMATCH%% *}
		return 0
	fi
	[ $HOSTLINES -gt 1 ] && { errormsg "Host/alias $MATCHHOST found in multiple non-matching host lines: $HOSTMATCH"; return 1; }
	echo $MATCHHOST
}

hostnicename(){
	local MATCHHOST=${1}
	[ ! -d "$RCROOT/sites/$RCSITE/hostgroups" ] && { echo $MATCHHOST; return 0; }
	if [ -n "$(ls -A "$RCROOT/sites/$RCSITE/hostgroups/")" ]
	then
		local HOSTMATCH=$(grep -Rh "^\<$MATCHHOST\>" "$RCROOT/sites/$RCSITE/hostgroups" | sort | uniq)
		local HOSTLINES=$(echo "$HOSTMATCH" | wc -l)
		if [ $HOSTLINES -eq 1 -a -n "$HOSTMATCH" ]
		then
			echo ${HOSTMATCH##* }
		else
			echo $MATCHHOST
		fi
		[ $HOSTLINES -gt 1 ] && { errormsg "Host/alias $MATCHHOST found in multiple non-matching host lines: $HOSTMATCH"; return 1; }
	else
		echo $MATCHHOST
	fi
	return 0
}

# Add hosts to a list: addhosts varname <host> ...
addhosts(){
	local ADDHOST
	local LISTNAME=$1
	local HOSTLIST=${!1}

	shift
	for ADDHOST in $*
	do
		echo " $HOSTLIST " | grep -q " $ADDHOST " || HOSTLIST="$HOSTLIST $ADDHOST"
	done
	HOSTLIST=${HOSTLIST# }
	eval $LISTNAME=\"$HOSTLIST\"
}

resolvehostlist(){
	local HOSTSPEC LIBHOSTSHOSTLIST HOSTARRAY RESHOST RESGROUP
	for HOSTSPEC in $*
	do
		case $HOSTSPEC in
			@*)
				RESGROUP=$(resolvehostgroup ${HOSTSPEC}) || return 1
				addhosts LIBHOSTSHOSTLIST $RESGROUP
				;;
			*)
				RESHOST=$(resolvehostalias ${HOSTSPEC}) || return 1
				addhosts LIBHOSTSHOSTLIST $RESHOST
				;;
		esac
	done
	HOSTARRAY=($LIBHOSTSHOSTLIST)
	[ ${#HOSTARRAY[@]} -eq 0 ] && { errormsg "Couldn't resolve any hosts in: $*"; return 1; }
	echo $LIBHOSTSHOSTLIST
}

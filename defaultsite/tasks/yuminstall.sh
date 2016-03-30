#!/bin/bash -e
# yuminstall.sh - Install a defined set of os packages.

# Package lists should be in packages.defs, probably in sites/common,
# or possibly sites/<somesite>.
#RCCONFIG:RCELEVATE=true;RCREQUIREDARGS=1;RCSCRIPTDEFS=packagelists.defs

usage(){
	cat <<EOF
Usage:
yuminstall.sh (-h) <pkgspec>

Where <pkgspec> can consist of individual package names
or @<listnames>; <listname> should the the name of a shell
variable that expands to a space separated list of packages.
The shell variable should be defined in a configured
.defs file for this task.
EOF
exit 1
}

[ "$1" = "-h" -o $# -eq 0 ] && usage

addpkg(){
	echo "$PACKAGES" | grep -q "\<$1\>" || PACKAGES="$PACKAGES $1"
}

for PKGSPEC in $*
do
	if [[ $PKGSPEC = @* ]]
	then
		PKGVAR=${PKGSPEC#@}
		[ -z "${!PKGVAR}" ] && { echo "No variable $PKGVAR defined" >&2; exit 1; }
		for GROUPPKG in ${!PKGVAR}
		do
			addpkg $GROUPPKG
		done
	else
		addpkg $PKGSPEC
	fi
done

echo "### $(date) - Installing packages"
for TRY in 1 2 3
do
	echo "=== Try $TRY:"
	yum -y install $PACKAGES && break
	[ $TRY -eq 3 ] && { echo "Too many tries, failing"; exit 1; }
	echo "... failed, retrying in 30s"
	sleep 30
done

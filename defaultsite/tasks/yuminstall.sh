#!/bin/bash -e
# yuminstall.sh - Install a defined set of os packages.

# Package lists should be in packages.defs, probably in sites/common,
# or possibly sites/<somesite>.
#RCCONFIG:RCELEVATE=true;RCREQUIREDARGS=1

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
	if ! echo "$PACKAGES" | grep -q "\<$1\>"
	then
		if rpm -q $1 >/dev/null
		then
			echo "$1 already installed"
		else
			PACKAGES="$PACKAGES $1"
		fi
	fi
}

status "Compiling package list..."
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

set -- $PACKAGES
[ $# -eq 0 ] && { echo "... no packages to install"; exit 0; }

status "Installing packages"
for TRY in 1 2 3
do
	echo "=== Try $TRY:"
	yum -y install $PACKAGES && break
	[ $TRY -eq 3 ] && { echo "Too many tries, failing"; exit 1; }
	echo "... failed, retrying in 30s"
	sleep 30
done

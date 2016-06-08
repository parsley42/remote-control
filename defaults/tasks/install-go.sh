#!/bin/bash -e
# install-go.sh - install go language for workstations and builders
#RCCONFIG:RCELEVATE=true

# Default version to install if GOVERSION isn't set in the server.defs
# This should be the full name of the archive
#TODO: implement requiredefs
#requiredefs GOVERSION

GOFULL=go${GOVERSION}
GOFILE=${GOFULL}.linux-amd64.tar.gz

status "Installing Google Go to /usr/local/go"

GOPATH='if ! echo ${PATH} | /bin/grep -q /usr/local/go/bin ; then
   PATH=${PATH}:/usr/local/go/bin
fi
export PATH'

if [ -d /etc/profile.d ]
then
	echo "$GOPATH" > /etc/profile.d/golang.sh
else
	if [ -f /etc/profile ]
	then
		if ! grep -q '/usr/local/go/bin' /etc/profile
		then
			echo "$GOPATH" >> /etc/profile
		fi
	fi
fi

if [ -x /usr/local/go/bin/go ]
then # See if we already have the desired version
	GOCHECK=$(/usr/local/go/bin/go version)
	GOCHECK=${GOCHECK% *}
	GOCHECK=${GOCHECK##* }
	[ "$GOCHECK" = "$GOFULL" ] && { echo "$GOFULL already installed"; exit 0; }
fi

cd /usr/local
[ -n "$GOCHECK" ] && { echo "Removing $GOCHECK"; rm -rf go; }

echo "Downloading and installing $GOFILE"

GOTMP=$(mktemp -d /tmp/goinstall-XXXXX)
cleanup(){
	cd /
	rm -rf $GOTMP
}
# Clean up tmpdir should anything fail below
trap cleanup EXIT

cd $GOTMP
wget https://storage.googleapis.com/golang/$GOFILE

cd /usr/local
tar xzvf $GOTMP/$GOFILE
status "finished"
# cleanup will clean up

#!/bin/bash

end_with_error()
{
 echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
 exit 1
}

progress()
{
    while true
    do
        echo -n "."
        sleep 10
    done
}

BUILD_REV=$(echo "$2" | sed -s 's/^ppa-godot-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\).*/\1/')
BUILD_DATE=$(echo "$2" | sed -s 's/^ppa-godot-\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.[0-9a-f]\{7\}.*/\1\2\3/')
BUILD_PPA=$(echo "$2" | sed -s 's/^ppa-godot-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')

DIST=$1
DISTNAME=../freeorion_0.4.10.999+1SNAPSHOT${BUILD_DATE}ppa${BUILD_PPA}~${DIST}


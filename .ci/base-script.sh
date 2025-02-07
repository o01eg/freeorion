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

BUILD_PPA=$(echo "$2" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')

DIST=$1
DISTNAME=../freeorion_0.5.1ppa${BUILD_PPA}~${DIST}


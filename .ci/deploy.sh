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

BUILD_REV=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\).*/\1/')
BUILD_DATE=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.[0-9a-f]\{7\}.*/\1\2\3/')
BUILD_PPA=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')

DIST=$1
DISTNAME=../freeorion_0.4.9.1+1SNAPSHOT${BUILD_DATE}ppa${BUILD_PPA}~${DIST}
echo "Uploading package ${DISTNAME}..."
progress &
PROGRESSPID=$!
yes | dput -d -c .ci/dput.cf freeorion-ppa-sftp ${DISTNAME}_source.changes || end_with_error "Cann't put package"
kill ${PROGRESSPID} >/dev/null 2>&1


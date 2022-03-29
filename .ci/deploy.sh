#!/bin/bash

source .ci/base-script.sh

echo "Uploading package ${DISTNAME}..."
progress &
PROGRESSPID=$!
yes | dput -d -c .ci/dput.cf freeorion-ppa-sftp ${DISTNAME}_source.changes || end_with_error "Cann't put package"
kill ${PROGRESSPID} >/dev/null 2>&1


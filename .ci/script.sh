#!/bin/bash

end_with_error()
{
 echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
 exit 1
}

BUILD_REV=$(echo "$2" | sed -s 's/^ppa-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\).*/\1/')
BUILD_DATE=$(echo "$2" | sed -s 's/^ppa-\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.[0-9a-f]\{7\}.*/\1\2\3/')
BUILD_PPA=$(echo "$2" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')
echo "REV=${BUILD_REV} DATE=${BUILD_DATE} PPA=${BUILD_PPA}"
sed -i "s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\]/${BUILD_REV}\]/" util/Version.cpp || end_with_error "Cann't set version"

DIST=$1
DISTNAME=../freeorion_0.4.10.999+1SNAPSHOT${BUILD_DATE}ppa${BUILD_PPA}~${DIST}
echo "Building package ${DISTNAME}..."
sed -i "1,+1{s/bionic\|disco\|eoan\|focal\|groovy\|hirsute\|impish\|jammy/${DIST}/g}" debian/changelog  || end_with_error "Cann't set distribution"
XZ_OPT=-9 tar --xz -cf ${DISTNAME}.orig.tar.xz --exclude .git --exclude .ci --exclude .github --exclude msvc2017 --exclude msvc2019 --exclude msvc2022 .  || end_with_error "Cann't make archive"
echo "Archived ${DISTNAME}"
debuild -S -sa || end_with_error "Cann't make package"


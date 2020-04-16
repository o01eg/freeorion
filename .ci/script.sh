#!/bin/bash

end_with_error()
{
 echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
 exit 1
}

BUILD_REV=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.\([0-9a-f]\{7\}\).*/\1/')
BUILD_DATE=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.[0-9a-f]\{7\}.*/\1\2\3/')
BUILD_PPA=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')
echo "REV=${BUILD_REV} DATE=${BUILD_DATE} PPA=${BUILD_PPA}"

DIST=$1
DISTNAME=../freeorion_0.4.9+git${BUILD_DATE}~${BUILD_REV}-fo0009-ppa${BUILD_PPA}~${DIST}
echo "Building package ${DISTNAME}..."
sed -i "1,+1{s/bionic\|disco\|eoan\|focal/${DIST}/g}" debian/changelog  || end_with_error "Cann't set distribution"
XZ_OPT=-9 tar --xz -cf ${DISTNAME}.orig.tar.xz --exclude .git --exclude .ci --exclude .github --exclude msvc2017 .  || end_with_error "Cann't make archive"
debuild -S -sa || end_with_error "Cann't make package"


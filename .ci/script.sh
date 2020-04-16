#!/bin/bash

end_with_error()
{
 echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
 exit 1
}

BUILD_REV=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\).*/\1/')
BUILD_DATE=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.[0-9a-f]\{7\}.*/\1\2\3/')
BUILD_PPA=$(echo "${TRAVIS_TAG}" | sed -s 's/^ppa-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}_\([0-9]\+\).*/\1/')
echo "REV=${BUILD_REV} DATE=${BUILD_DATE} PPA=${BUILD_PPA}"
sed -i "s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\]/${BUILD_REV}\]/" util/Version.cpp || end_with_error "Cann't set version"

for DIST in bionic eoan focal; do
    echo "Building package for ${DIST}..."
    DISTNAME=../freeorion_0.4.9.1+1SNAPSHOT${BUILD_DATE}ppa${BUILD_PPA}~${DIST}
    sed -i "1,+1{s/bionic\|disco\|eoan\|focal/${DIST}/g}" debian/changelog  || end_with_error "Cann't set distribution"
    tar --xz -cvf ${DISTNAME}.orig.tar.xz --exclude .git --exclude .ci --exclude .github .  || end_with_error "Cann't make archive"
    debuild -S -sa  || end_with_error "Cann't make package"
    for F in .dsc .orig.tar.xz .debian.tar.xz _source.buildinfo _source.changes; do
        echo "Pushing ${DISTNAME}${F}..."
        curl --disable-epsv --connect-timeout 20 --retry 10 --retry-delay 2 --ftp-method singlecwd -u anonymous:o01eg@yandex.ru -v -T "${DISTNAME}${F}" ftp://ppa.launchpad.net/~o01eg/freeorion/;type=i || end_with_error "Cann't upload package file ${DISTNAME} ${F}"
    done
done


#!/bin/bash

source .ci/base-script.sh

echo "REV=${BUILD_REV} DATE=${BUILD_DATE} PPA=${BUILD_PPA}"
sed -i "s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.[0-9a-f]\{7\}\]/${BUILD_REV}\]/" util/Version.cpp || end_with_error "Cann't set version"

head -n 1 debian/changelog

echo "Building package ${DISTNAME}..."
sed -i "1,+1{s/bionic\|disco\|eoan\|focal\|groovy\|hirsute\|impish\|jammy\|kinetic/${DIST}/g}" debian/changelog  || end_with_error "Cann't set distribution"
sed -i "1,+1{s/1SNAPSHOT[0-9]\{8\}ppa[0-9]\+~/1SNAPSHOT${BUILD_DATE}ppa${BUILD_PPA}~/g}" debian/changelog || end_with_error "Cann't set date"

head -n 1 debian/changelog

XZ_OPT=-9 tar --xz -cf ${DISTNAME}.orig.tar.xz --exclude .git --exclude .ci --exclude .github --exclude msvc2017 --exclude msvc2019 --exclude msvc2022 .  || end_with_error "Cann't make archive"
echo "Archived ${DISTNAME}"
debuild -S -sa || end_with_error "Cann't make package"


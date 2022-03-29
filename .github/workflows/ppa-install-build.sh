#!/bin/bash -e

sudo apt update
sudo apt install -y devscripts \
        dput \
        python3-paramiko \
        fakeroot \
        cmake \
        debhelper \
        libalut-dev \
        libboost-all-dev \
        libgl1-mesa-dev \
        libglew-dev \
        libogg-dev \
        libopenal-dev \
        libsdl2-dev \
        libvorbis-dev \
	dh-python

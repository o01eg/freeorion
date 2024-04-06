FROM docker.io/ubuntu:jammy

LABEL version="0" \
      maintainer="O01eg <o01eg@yandex.ru>"

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "# don't install documentation inside container\n\
path-exclude=/usr/share/cmake-*/Help/*\n\
" > /etc/dpkg/dpkg.cfg.d/docker-no-documentation

RUN echo "# don't install static libraries inside container\n\
path-exclude=/usr/lib/x86_64-linux-gnu/*.a\n\
path-exclude=/usr/lib/python3.10/config-3.10-x86_64-linux-gnu/*.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libc_nonshared.a\n\
path-include=/usr/lib/gcc/x86_64-linux-gnu/11/libgcc.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libmvec_nonshared.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libpthread.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libpthread-2.0.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libpthread_nonshared.a\n\
path-include=/usr/lib/x86_64-linux-gnu/librt.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libdl.a\n\
path-include=/usr/lib/x86_64-linux-gnu/libutil.a\n\
" > /etc/dpkg/dpkg.cfg.d/docker-no-static-libraries

RUN echo "# don't install recommends and suggests packages\n\
APT::Install-Recommends \"false\";\n\
APT::Install-Suggests \"false\";\n\
" > /etc/apt/apt.conf.d/docker-no-suggests

RUN apt-get update --assume-yes

RUN apt-get install --assume-yes \
        git \
        g++ \
        cmake \
        coreutils \
	libalut-dev \
        libpython3-dev \
        libfreetype-dev \
	libgl-dev \
        libglew-dev \
        libopenal-dev \
        libogg-dev \
        libvorbis-dev \
        zlib1g-dev \
        libsdl2-dev \
        mesa-common-dev \
        libpng-dev \
        libboost-all-dev \
        devscripts \
        dput \
        fakeroot \
        build-essential \
        debhelper \
        dh-apparmor \
	dh-python \
        python3-psycopg2 \
	python3-aiohttp \
	python3-aiosmtplib \
	ssh \
	libjpeg-dev \
	libtiff-dev \
	godot3-server \
	curl \
	libssl-dev \
	gdb \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/cache/apt/archives/*


ENV RUSTUP_HOME=/usr/local/rustup \
	CARGO_HOME=/usr/local/cargo \
	PATH=/usr/local/cargo/bin:$PATH \
	RUST_VERSION=1.73.0 \
	RUSTUP_VERSION=1.26.0

RUN curl -o rustup-init https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-unknown-linux-gnu/rustup-init \
    && echo "0b2f6c8f85a3d02fde2efc0ced4657869d73fccfce59defb4e8d29233116e6db *rustup-init" | sha256sum -c - \
    && chmod +x rustup-init

RUN ./rustup-init --help

RUN ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host x86_64-unknown-linux-gnu

RUN rm rustup-init

RUN rustup --version

RUN cargo --version

RUN rustc --version

RUN which cargo


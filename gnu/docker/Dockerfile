# 32-bit build host for gcc 3.3.2 (it does not work as a 64-bit host program)
FROM i386/debian:buster@sha256:631ad34423340d42c4a93d1ac63339adc3f73a842a9d77f209ce78d5629d1c82
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian buster-updates main\ndeb http://archive.debian.org/debian-security buster/updates main\n' \
        > /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        gcc libc6-dev make flex bison && \
    rm -rf /var/lib/apt/lists/*

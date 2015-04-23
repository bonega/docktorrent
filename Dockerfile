FROM debian:jessie

MAINTAINER bonega <bonega@gmail.com>

WORKDIR /usr/local/src

# This long disgusting instruction saves your image ~130 MB
RUN build_deps="automake build-essential libc-ares-dev libcppunit-dev libtool"; \
    build_deps="${build_deps} libssl-dev libxml2-dev libncurses5-dev pkg-config subversion wget git ca-certificates"; \
    set -x && \
    apt-get update && apt-get install -q -y --no-install-recommends ${build_deps}

RUN wget http://curl.haxx.se/download/curl-7.39.0.tar.gz && \
    tar xzvfp curl-7.39.0.tar.gz && \
    cd curl-7.39.0 && \
    ./configure --enable-ares --enable-tls-srp --enable-gnu-tls --with-zlib --with-ssl && \
    make && \
    make install && \
    cd .. && \
    rm -rf curl-* && \
    ldconfig && \
    svn --trust-server-cert checkout https://svn.code.sf.net/p/xmlrpc-c/code/stable/ xmlrpc-c && \
    cd xmlrpc-c && \
    ./configure --enable-libxml2-backend --disable-abyss-server --disable-cgi-server && \
    make && \
    make install && \
    cd .. && \
    rm -rf xmlrpc-c && \
    ldconfig

RUN wget http://libtorrent.rakshasa.no/downloads/libtorrent-0.13.4.tar.gz && \
    mkdir libtorrent && \
    tar -zxf libtorrent-* -C libtorrent --strip-components=1 && \
    cd libtorrent && \
    ./autogen.sh && \
    ./configure --with-posix-fallocate && \
    make && \
    make install && \
    cd .. && \
    rm -rf libtorrent* && \
    ldconfig

RUN wget http://libtorrent.rakshasa.no/downloads/rtorrent-0.9.4.tar.gz && \
    mkdir rtorrent && \
    tar -zxf rtorrent-*.tar.gz -C rtorrent --strip-components=1 && \
    cd rtorrent && \
    ./autogen.sh && \
    ./configure --with-xmlrpc-c --with-ncurses && \
    make && \
    make install && \
    cd .. && \
    rm -rf rtorrent* && \
    ldconfig && \
    mkdir -p /usr/share/nginx/html

# Install required packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    apache2-utils \
    libc-ares2 \
    nginx \
    php5-cli \
    php5-fpm

# Install packages for ruTorrent plugins
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    mediainfo \
    unrar-free \
    unzip

# For ffmpeg, which is required by the ruTorrent screenshots plugin
# This increases ~53 MB of the image size, remove it if you really don't need screenshots
RUN echo "deb http://www.deb-multimedia.org jessie main" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -q -y --force-yes --no-install-recommends \
    deb-multimedia-keyring \
    ffmpeg


RUN cd /usr/share/nginx/html && \
    git clone --quiet https://github.com/bonega/ruTorrent.git rutorrent && \
    cd rutorrent && git reset --hard 3.7 && \
    apt-get purge -y --auto-remove ${build_deps} && \
    apt-get autoremove -y

# IMPORTANT: Change the default login/password of ruTorrent before build
RUN htpasswd -cb /usr/share/nginx/html/rutorrent/.htpasswd docktorrent p@ssw0rd

# Copy config files
COPY config/nginx/default /etc/nginx/sites-available/default
COPY config/rtorrent/.rtorrent.rc /root/.rtorrent.rc
COPY config/rutorrent/config.php /usr/share/nginx/html/rutorrent/conf/config.php

# Add the s6 binaries fs layer
ADD s6-1.1.3.2-musl-static.tar.xz /

# Service directories and the wrapper script
COPY rootfs /

# Run the wrapper script first
ENTRYPOINT ["/usr/local/bin/docktorrent"]

# Declare ports to expose
EXPOSE 80 9527 45566

# Declare volumes
VOLUME ["/rtorrent", "/var/log"]

# This should be removed in the latest version of Docker
ENV HOME /root

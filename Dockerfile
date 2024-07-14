# accel-ppp build in alpine
FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache \
    build-base \
    linux-headers \
    cmake \
    git \
    libpcap-dev \
    ppp-dev \
    ppp \
    readline-dev \
    zlib-dev \
    pcre-dev lua5.1-dev libucontext-dev \
    openssl-dev \
    iptables

# Clone accel-ppp
RUN git clone https://github.com/accel-ppp/accel-ppp
# Or use local copy for development
#COPY accel-ppp /accel-ppp

# Build accel-ppp
WORKDIR /accel-ppp

RUN mkdir build && cd build && cmake -DBUILD_IPOE_DRIVER=FALSE -DBUILD_VLAN_MON_DRIVER=FALSE -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-`uname -r` -DLUA=TRUE -DSHAPER=FALSE -DRADIUS=TRUE ..
RUN cd build && make -j$(nproc) && make install

# certbot
RUN apk add --no-cache certbot

# Make directory /etc/letsencrypt/live
RUN mkdir -p /etc/letsencrypt /etc/accel-ppp
COPY certconfig.sh /usr/bin/certconfig.sh
# Make script executable
RUN chmod +x /usr/bin/certconfig.sh
# copy accel-ppp config
COPY accel-ppp.conf /etc/accel-ppp.conf

# ports 443
EXPOSE 443

CMD ["/usr/bin/certconfig.sh"]

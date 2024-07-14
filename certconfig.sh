#!/bin/sh
# SSTP_HOSTNAME - SSTP server hostname
# DEBUG
#syslogd
if [ -z "${SSTP_HOSTNAME}" ]; then
    echo "SSTP_HOSTNAME is not set"
    exit 1
fi
echo "SSTP_HOSTNAME: ${SSTP_HOSTNAME}"
echo "Check if file /etc/letsencrypt/live/${SSTP_HOSTNAME}/fullchain.pem exists"
if [ ! -e "/etc/letsencrypt/live/${SSTP_HOSTNAME}/fullchain.pem" ]; then
    echo "Creating certificate for ${SSTP_HOSTNAME}"
    certbot certonly --standalone -d ${SSTP_HOSTNAME} --email nuclearcat@nuclearcat.com --agree-tos --no-eff-email
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/fullchain.pem /etc/accel-ppp/ca.crt
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/privkey.pem /etc/accel-ppp/server.key
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/cert.pem /etc/accel-ppp/server.crt
else
    echo "Certificate for ${SSTP_HOSTNAME} already exists"
    if [ -e /etc/accel-ppp/ca.crt ]; then
        rm /etc/accel-ppp/ca.crt
    fi
    if [ -e /etc/accel-ppp/server.key ]; then
        rm /etc/accel-ppp/server.key
    fi
    if [ -e /etc/accel-ppp/server.crt ]; then
        rm /etc/accel-ppp/server.crt
    fi
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/fullchain.pem /etc/accel-ppp/ca.crt
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/privkey.pem /etc/accel-ppp/server.key
    ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/cert.pem /etc/accel-ppp/server.crt
fi

# replace in accel-ppp.conf vpn.example.com with SSTP_HOSTNAME
sed -i "s/vpn.example.com/${SSTP_HOSTNAME}/g" /etc/accel-ppp.conf

# /dev/ppp
echo "Creating /dev/ppp"
if [ ! -e /dev/ppp ]; then
    mknod /dev/ppp c 108 0
    chmod 600 /dev/ppp
fi

# if chap-secrets does not exist, create it
if [ ! -e /etc/ppp/chap-secrets ]; then
    echo "Creating /etc/ppp/chap-secrets"
    cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client    server    secret            IP addresses
EOF
fi
# can't use nft in docker, it says using iptables :(
#cat > /etc/nftables.conf <<EOF
#table ip nat {
#     chain postrouting {z
#        type nat hook postrouting priority 100; policy accept;
#        oif eth0 masquerade
#    }
#}
#EOF
#nft -f /etc/nftables.conf
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE

echo "Starting accel-ppp"
while true; do
    /usr/sbin/accel-pppd -c /etc/accel-ppp.conf
    echo "accel-ppp exited, restarting in 10 seconds"
    sleep 10
done

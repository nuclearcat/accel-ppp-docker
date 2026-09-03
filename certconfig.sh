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
else
    echo "Certificate for ${SSTP_HOSTNAME} already exists"
    echo "Check if certificate for ${SSTP_HOSTNAME} is about to expire"
    # openssl is installed in the image, so this check is meaningful:
    # renew only when the certificate really is within a day of expiring
    openssl x509 -in /etc/letsencrypt/live/${SSTP_HOSTNAME}/cert.pem -checkend 86400 -noout
    if [ $? -ne 0 ]; then
        echo "Certificate for ${SSTP_HOSTNAME} is expired, renewing"
        certbot renew --standalone
    else
        echo "Certificate for ${SSTP_HOSTNAME} is valid"
    fi
fi

# accel-ppp.conf reads the certificate through these three links, so they have
# to be in place before accel-pppd starts below. Drop any left over from an
# earlier run first: they point into /etc/letsencrypt, which is a mounted
# volume that certbot rewrites on renewal, so a stale link can outlive the file
# it named.
rm -f /etc/accel-ppp/ca.crt /etc/accel-ppp/server.key /etc/accel-ppp/server.crt
ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/fullchain.pem /etc/accel-ppp/ca.crt
ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/privkey.pem /etc/accel-ppp/server.key
ln -s /etc/letsencrypt/live/${SSTP_HOSTNAME}/cert.pem /etc/accel-ppp/server.crt

# Refuse to start rather than serve port 443 without SSL: with accept=ssl and a
# missing pemfile, sstp answers in plaintext and every client fails with an
# opaque TLS error instead of anything pointing back at the certificate.
# -e follows the symlink, so this also catches a link whose target is gone.
if [ ! -e /etc/accel-ppp/server.crt ] || [ ! -e /etc/accel-ppp/server.key ]; then
    echo "Error: no usable certificate in /etc/letsencrypt/live/${SSTP_HOSTNAME}/"
    echo "Certbot needs port 80 reachable from the internet to issue one."
    exit 1
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

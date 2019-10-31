#!/bin/bash

#Install required modules
modprobe iptable_nat

#Configure Kernel routing
echo Starting kernal routing...
echo 1 > /proc/sys/net/ipv4/ip_forward

# Setup default variables
IPTABLES=/sbin/iptables
UNPRIV_PORTS=1024:65535
WEB="80/tcp 443/tcp"
SSH="22/tcp 1611/tcp"
DNS="53/udp 53/tcp"
UBIQUITI="10001/udp"
SAMBA="137/udp 138/udp 139/tcp 445/tcp"
DHCP="67/udp"
MINECRAFT=""
STALE_WEB="SPT:443/tcp"
STALE_RDP="SPT:$RDP"
NTP="123/udp"
DROPBOX_LAN="17500/udp"
RDP="3389/tcp"
STALE_RDP="SPT:$RDP"

#Configure Access
#ALLOW_OUT="$WEB $DNS $SSH $SAMBA $NTP $RDP"
ALLOW_OUT=""
ALLOW_IN="$DHCP"
ALLOW_MULTICAST="yes"

#Allow port range in
PORT_RANGE_SERVER=""
ENABLE_LOGGING="yes"
DONT_LOG="$UBIQUITI $STALE_WEB $DROPBOX_LAN $STALE_RDP"
#LIBVIRT_NETWORKS="virbr1:192.168.100.0/24 virbr0:192.168.122.0/24"
LIBVIRT_NETWORKS=$(
    ip -o address|
    awk '/virbr[0-9]+/ {
        gsub(/\.1\//,".0/",$4);
        printf $2":"$4" "
    }'
)

#Clean up old IP chains
echo Cleaning old chains
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X
$IPTABLES -t filter -F
$IPTABLES -t filter -X
# 
#Set initial policies to DROP
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP
$IPTABLES -P OUTPUT DROP

#Allow unlimited traffic on the loopback interface
echo Allowing loopback interface full access to internal interfaces
$IPTABLES -A INPUT -i lo -j ACCEPT

#Allow Server Out
if [ "$ALLOW_OUT" = "" ]; then
    echo Allowing server full access...
    $IPTABLES -P OUTPUT ACCEPT
else
    for EXCEPTION in $ALLOW_OUT
    do
        PORT=${EXCEPTION%/*}
        PROTO=${EXCEPTION#*/}
        echo Allowing server out on $PROTO/$PORT
        $IPTABLES -A OUTPUT -p $PROTO --dport $PORT -j ACCEPT
    done
fi

#Allow Server In
if [ "$ALLOW_IN" = "" ]; then
    echo No ports forwarded to server
else
    for EXCEPTION in $ALLOW_IN
    do
        PORT=${EXCEPTION%/*}
        PROTO=${EXCEPTION#*/}
        echo Server is accepting incoming $PROTO connections on port $PORT
        $IPTABLES -A INPUT -p $PROTO --dport $PORT -j ACCEPT
    done
fi

#Allow Port Range in
if [ ! "$PORT_RANGE_SERVER" = "" ]; then
    for RANGE in $PORT_RANGE_SERVER
    do
    CPORT=$(echo $RANGE|awk -F '-' '{print$1}')
    FPORT=$(echo $RANGE|awk -F '-' '{print$2}')
    echo Server is accepting incoming connections on port range $RANGE
        $IPTABLES -A INPUT -i $IF_WAN -p tcp \
        -m multiport --destination-ports $CPORT:$FPORT \
            -j ACCEPT
        $IPTABLES -A INPUT -i $IF_WAN -p udp \
        -m multiport --destination-ports $CPORT:$FPORT \
            -j ACCEPT
    done
fi

#Allow already established connections.
$IPTABLES -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

if [ "${ALLOW_MULTICAST}" == "yes" ]
then
    echo Allowing multicast
    $IPTABLES -A INPUT -s 224.0.0.0/4 -j ACCEPT
    $IPTABLES -A INPUT -s 0.0.0.0 -d 224.0.0.0/4 -j ACCEPT
    $IPTABLES -A FORWARD -s 224.0.0.0/4 -d 224.0.0.0/4 -j ACCEPT
    $IPTABLES -A OUTPUT -d 224.0.0.0/4 -j ACCEPT
fi

if [ -n "$DONT_LOG" ]
then
    $IPTABLES -A INPUT -p udp -d 10.204.100.255 -j DROP
    $IPTABLES -A INPUT -p udp -d 255.255.255.255 -j DROP
    for LOG_EXCEPTION in $DONT_LOG
    do
        if [[ "${LOG_EXCEPTION}" =~ "SPT" ]]
        then
            PORT=${LOG_EXCEPTION%/*}
            PORT=${PORT#*:}
            PROTO=${LOG_EXCEPTION#*/}
            echo "Won't log SPT $PORT/$PROTO"
            $IPTABLES -A INPUT -p $PROTO --sport $PORT -j DROP
            $IPTABLES -A OUTPUT -p $PROTO --sport $PORT -j DROP
        else
            PORT=${LOG_EXCEPTION%/*}
            PROTO=${LOG_EXCEPTION#*/}
            echo "Won't log $PORT/$PROTO"
            $IPTABLES -A INPUT -p $PROTO --dport $PORT -j DROP
            $IPTABLES -A OUTPUT -p $PROTO --dport $PORT -j DROP
        fi
    done
fi

if [ -n "$LIBVIRT_NETWORKS" ]
then
    echo Applying LibVirt Network Rules
    $IPTABLES -t nat -N LIBVIRT_PRT
    $IPTABLES -t nat -A POSTROUTING -j LIBVIRT_PRT
    $IPTABLES -t mangle -N LIBVIRT_PRT
    $IPTABLES -t mangle -A POSTROUTING -j LIBVIRT_PRT
    $IPTABLES -N LIBVIRT_FWI
    $IPTABLES -N LIBVIRT_FWO
    $IPTABLES -N LIBVIRT_FWX
    $IPTABLES -N LIBVIRT_INP
    $IPTABLES -N LIBVIRT_OUT
    $IPTABLES -A INPUT -j LIBVIRT_INP
    $IPTABLES -A FORWARD -j LIBVIRT_FWX
    $IPTABLES -A FORWARD -j LIBVIRT_FWI
    $IPTABLES -A FORWARD -j LIBVIRT_FWO
    $IPTABLES -A OUTPUT -j LIBVIRT_OUT
    for LIBVIRT_NETWORK in $LIBVIRT_NETWORKS
    do
        IFACE=${LIBVIRT_NETWORK%:*}
        CIDR=${LIBVIRT_NETWORK#*:}
        echo Setting rules for $CIDR on $IFACE
        $IPTABLES -t nat -A LIBVIRT_PRT -s $CIDR -d 224.0.0.0/24 -j RETURN
        $IPTABLES -t nat -A LIBVIRT_PRT -s $CIDR -d 255.255.255.255/32 -j RETURN
        $IPTABLES -t nat -A LIBVIRT_PRT -s $CIDR ! -d $CIDR -p tcp -j MASQUERADE --to-ports 1024-65535
        $IPTABLES -t nat -A LIBVIRT_PRT -s $CIDR ! -d $CIDR -p udp -j MASQUERADE --to-ports 1024-65535
        $IPTABLES -t nat -A LIBVIRT_PRT -s $CIDR ! -d $CIDR -j MASQUERADE
        $IPTABLES -t mangle -A LIBVIRT_PRT -o $IFACE -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
        for po in 53 67
        do
            for pr in udp tcp
            do
                $IPTABLES -A LIBVIRT_INP -i $IFACE -p $pr -m $pr \
                    --dport $po -j ACCEPT
            done
        done
        $IPTABLES -A LIBVIRT_OUT -o $IFACE -p udp -m udp --dport 68 -j ACCEPT
        $IPTABLES -A LIBVIRT_FWX -i $IFACE -o $IFACE -j ACCEPT
        $IPTABLES -A LIBVIRT_FWI -d $CIDR -o $IFACE -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        $IPTABLES -A LIBVIRT_FWI -o $IFACE -j REJECT --reject-with icmp-port-unreachable 
        $IPTABLES -A LIBVIRT_FWO -s $CIDR -i $IFACE -j ACCEPT
        $IPTABLES -A LIBVIRT_FWO -i $IFACE -j REJECT --reject-with icmp-port-unreachable 
    done
fi


if [ -n "$ENABLE_LOGGING" ]
then
    echo Logging dropped packets enabled
    $IPTABLES -A INPUT -j LOG --log-level info --log-prefix "IPTABLES-DROP: "
    $IPTABLES -A OUTPUT -j LOG --log-level info --log-prefix "IPTABLES-DROP: "
    if [ -n "$LIBVIRT_NETWORKS" ]
    then
        $IPTABLES -A LIBVIRT_INP -j LOG --log-level info --log-prefix "IPTABLES-LIBVIRT: "
        $IPTABLES -A LIBVIRT_OUT -j LOG --log-level info --log-prefix "IPTABLES-LIBVIRT: "
        $IPTABLES -A LIBVIRT_FWO -j LOG --log-level info --log-prefix "IPTABLES-LIBVIRT: "
        $IPTABLES -A LIBVIRT_FWI -j LOG --log-level info --log-prefix "IPTABLES-LIBVIRT: "
        $IPTABLES -A LIBVIRT_FWX -j LOG --log-level info --log-prefix "IPTABLES-LIBVIRT: "
    fi
fi

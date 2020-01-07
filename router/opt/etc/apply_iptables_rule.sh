#!/bin/sh

/opt/etc/clean_iptables_rule.sh

echo '[0m[33mApply iptables rule ...[0m'

if iptables -t nat -C PREROUTING -p tcp -j V2RAY_TCP 2>/dev/null; then
    exit 0
fi

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
else
    alias iptables='/opt/sbin/iptables'
fi

local_v2ray_port=$(cat /opt/etc/v2ray.json |grep '"inbounds"' -A10 |grep '"protocol" *: *"dokodemo-door"' -A10 |grep '"port"' |grep -o '[0-9]*')

if [ -z "$local_v2ray_port" ]; then
    echo 'can not find out v2ray port setting in /opt/etc/v2ray.json'
    exit
fi

LOCAL_IPS="
***REMOVED***
0.0.0.0/8
10.0.0.0/8
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.168.0.0/16
224.0.0.0/4
240.0.0.0/4
"

iptables -t nat -N V2RAY_TCP
for local_ip in $LOCAL_IPS; do
    iptables -t nat -A V2RAY_TCP -d $local_ip -j RETURN
done
iptables -t nat -A V2RAY_TCP -p tcp -j RETURN -m mark --mark 0xff
iptables -t nat -A V2RAY_TCP -p tcp -j REDIRECT --to-ports $local_v2ray_port
# apply rule
iptables -t nat -A PREROUTING -p tcp -j V2RAY_TCP
iptables -t nat -A OUTPUT -p tcp -j V2RAY_TCP

if modprobe xt_TPROXY &>/dev/null; then
    # Add any UDP rules
    ip rule add fwmark 1 table 100
    ip route add local default dev lo table 100

    iptables -t mangle -N V2RAY_UDP
    for local_ip in $LOCAL_IPS; do
        iptables -t mangle -A V2RAY_UDP -d $local_ip -j RETURN
    done
    iptables -t mangle -A V2RAY_UDP -p udp -j TPROXY --on-port $local_v2ray_port --tproxy-mark 1
    # Apply the rules
    iptables -t mangle -A PREROUTING -j V2RAY_UDP
fi

echo '[0m[33mApply iptables rule done.[0m'
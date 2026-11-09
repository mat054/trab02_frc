#!/bin/sh
# Coleta evidências do roteador em docs/evidencias/<data>/ (sem segredos).
# Uso (root, no roteador): sh tests/collect-evidence.sh
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT="$REPO/docs/evidencias/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
run() { f=$1; shift; echo "\$ $*" > "$OUT/$f.txt"; "$@" >> "$OUT/$f.txt" 2>&1; }
run uname uname -a
run ifconfig ifconfig
run rotas netstat -rn -f inet
run forwarding sysctl net.inet.ip.forwarding
run pf-regras pfctl -sr
run pf-nat pfctl -sn
run pf-estados pfctl -ss
run dnsmasq-status service dnsmasq status
run dnsmasq-conf cat /usr/local/etc/dnsmasq.conf
run leases cat /var/db/dnsmasq.leases
run dhcp-log tail -n 100 /var/log/dnsmasq.log
run portas sockstat -4 -l
echo "evidências em $OUT"

#!/bin/sh
# Desfaz o roteador: desliga PF e DHCP, tira o IP da LAN e o repasse de pacotes,
# agora e no boot. A WAN não é tocada, para não perder o acesso de administração.
# Pacotes instalados e arquivos de configuração (com seus .bak) são mantidos:
# scripts/apply.sh reaplica tudo.
# Uso (como root, no roteador FreeBSD): sh scripts/rollback.sh --sim
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"

[ "$(id -u)" -eq 0 ] || { echo "execute como root"; exit 1; }
[ "${1:-}" = "--sim" ] || { echo "isto desliga NAT, firewall, DHCP e a LAN. Confirme com: sh $0 --sim"; exit 1; }
[ -f "$ENV" ] || { echo "falta $ENV"; exit 1; }
. "$ENV"

echo "== firewall"
sysrc pf_enable=NO
pfctl -d 2>/dev/null || echo "PF já estava desligado"

echo "== DHCP"
sysrc dnsmasq_enable=NO
service dnsmasq onestop 2>/dev/null || echo "dnsmasq já estava parado"

echo "== LAN e repasse de pacotes"
sysrc -x "ifconfig_${LAN_IF}" 2>/dev/null || true
ifconfig "$LAN_IF" inet "$LAN_IP" delete 2>/dev/null || true
sysrc gateway_enable=NO
sysctl net.inet.ip.forwarding=0

echo
echo "desfeito. Backups mantidos: /etc/rc.conf.bak.*, /etc/pf.conf.bak.*, /usr/local/etc/dnsmasq.conf.bak.*"
echo "para reaplicar: sh scripts/apply.sh"

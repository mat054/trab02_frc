#!/bin/sh
# Mostra o estado do roteador e confere os pontos principais (só leitura).
# Uso (como root, no roteador FreeBSD): sh scripts/status.sh
# Sai com código 1 se alguma conferência falhar.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"
[ "$(id -u)" -eq 0 ] || { echo "execute como root (pfctl e leases exigem)"; exit 1; }
[ -f "$ENV" ] || { echo "falta $ENV"; exit 1; }
. "$ENV"

falhas=0
check() {  # check "descrição" comando...
  desc=$1; shift
  if "$@" >/dev/null 2>&1; then echo "  OK     $desc"; else echo "  FALHA  $desc"; falhas=$((falhas + 1)); fi
}

echo "== conferências"
check "WAN $WAN_IF com IPv4" sh -c "ifconfig $WAN_IF | grep -q 'inet '"
check "LAN $LAN_IF com $LAN_IP" sh -c "ifconfig $LAN_IF | grep -q 'inet $LAN_IP '"
check "rota padrão presente" sh -c "netstat -rn -f inet | grep -q '^default'"
check "ip.forwarding = 1" sh -c "[ \"\$(sysctl -n net.inet.ip.forwarding)\" = 1 ]"
check "PF ligado" sh -c "pfctl -si 2>/dev/null | grep -q 'Status: Enabled'"
check "NAT na $WAN_IF" sh -c "pfctl -sn 2>/dev/null | grep -q '^nat on $WAN_IF'"
check "DNAT :$DNAT_WAN_PORT -> $RESERVED_IP:$DNAT_LAN_PORT" sh -c "pfctl -sn 2>/dev/null | grep -q 'rdr on $WAN_IF.*-> $RESERVED_IP port $DNAT_LAN_PORT'"
check "bloqueio de entrada na $WAN_IF" sh -c "pfctl -sr 2>/dev/null | grep -q '^block drop in on $WAN_IF all'"
check "dnsmasq rodando" service dnsmasq status
check "persistência: gateway_enable, pf_enable, dnsmasq_enable" sh -c \
  "[ \"\$(sysrc -n gateway_enable)\" = YES ] && [ \"\$(sysrc -n pf_enable)\" = YES ] && [ \"\$(sysrc -n dnsmasq_enable)\" = YES ]"

echo; echo "== interfaces"
ifconfig "$WAN_IF" | grep -E 'ether|inet |status'
ifconfig "$LAN_IF" | grep -E 'ether|inet |status'
echo; echo "== rotas"; netstat -rn -f inet
echo; echo "== PF: NAT/DNAT"; pfctl -sn 2>/dev/null
echo; echo "== PF: filtro"; pfctl -sr 2>/dev/null
echo; echo "== PF: estados com a LAN"; pfctl -ss 2>/dev/null | grep -F "${LAN_IP%.*}." | head -10
echo; echo "== DHCP: leases (/var/db/dnsmasq.leases)"; cat /var/db/dnsmasq.leases 2>/dev/null
echo; echo "== DHCP: últimas concessões (/var/log/dnsmasq.log)"
grep -E 'DHCP(ACK|NAK)' /var/log/dnsmasq.log 2>/dev/null | tail -5

echo
if [ "$falhas" -eq 0 ]; then echo "status: tudo OK"; else echo "status: $falhas falha(s)"; exit 1; fi

#!/bin/sh
# Confere, sem alterar nada, se o roteador está pronto para os scripts 01-03.
# Uso (como root, no roteador FreeBSD): sh scripts/00-check-prerequisites.sh
# Sai com código 1 se algum item obrigatório falhar.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"
falhas=0
ok()    { echo "  OK     $1"; }
falha() { echo "  FALHA  $1"; falhas=$((falhas + 1)); }
aviso() { echo "  AVISO  $1"; }

echo "== sistema"
[ "$(uname -s)" = FreeBSD ] && ok "FreeBSD $(uname -r) $(uname -m)" || falha "sistema não é FreeBSD ($(uname -s))"
[ "$(id -u)" -eq 0 ] && ok "executando como root" || falha "execute como root"

echo "== configuração"
if [ -f "$ENV" ]; then
  ok "config/lab.env existe"
  . "$ENV"
  for v in WAN_IF LAN_IF WAN_IP WAN_GATEWAY LAN_IP LAN_CIDR LAN_NETMASK DHCP_START DHCP_END DHCP_LEASE \
           DNS_IP RESERVED_MAC RESERVED_IP RESERVED_NAME DNAT_WAN_PORT DNAT_LAN_PORT; do
    eval "val=\${$v:-}"
    if [ -z "$val" ]; then falha "$v vazia"
    else case "$val" in *X*|*Y*) falha "$v ainda com valor de exemplo: $val";; esac
    fi
  done
  [ "${WAN_IF:-}" != "${LAN_IF:-}" ] || falha "WAN_IF e LAN_IF são a mesma interface"
else
  falha "falta config/lab.env (copie de config/lab.env.example)"
fi

echo "== interfaces (ifconfig -l: $(ifconfig -l))"
for i in "${WAN_IF:-}" "${LAN_IF:-}"; do
  [ -n "$i" ] || continue
  ifconfig "$i" >/dev/null 2>&1 && ok "$i existe (MAC $(ifconfig "$i" | awk '/ether/{print $2}'))" || falha "interface $i não existe"
done
if [ -n "${RESERVED_MAC:-}" ]; then
  echo "$RESERVED_MAC" | grep -Eq '^([0-9a-f]{2}:){5}[0-9a-f]{2}$' && ok "RESERVED_MAC com formato válido" \
    || falha "RESERVED_MAC inválido (use minúsculas, aa:bb:cc:dd:ee:ff)"
fi

echo "== WAN"
ifconfig "${WAN_IF:-none}" 2>/dev/null | grep -q 'inet ' && ok "WAN com IPv4" \
  || aviso "WAN sem IPv4 ainda (01-setup-network.sh configura)"
if [ -n "${WAN_GATEWAY:-}" ]; then
  ping -c 1 -t 3 "$WAN_GATEWAY" >/dev/null 2>&1 && ok "gateway $WAN_GATEWAY responde" \
    || aviso "gateway $WAN_GATEWAY não respondeu ao ping (pode ser bloqueio de ICMP)"
fi

echo "== programas"
for c in pfctl sysrc tcpdump nc; do
  command -v "$c" >/dev/null && ok "$c" || falha "$c ausente"
done
if command -v dnsmasq >/dev/null; then ok "dnsmasq instalado"
else aviso "dnsmasq ausente: 03-setup-dhcp.sh instala via pkg (precisa de internet na WAN)"
fi

echo
if [ "$falhas" -eq 0 ]; then echo "pré-requisitos: OK"; else echo "pré-requisitos: $falhas falha(s)"; exit 1; fi

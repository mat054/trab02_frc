#!/bin/sh
# Fase 1: configura WAN, LAN /16, rota padrão e IPv4 forwarding (persistente).
# Uso (como root, no roteador FreeBSD): sh scripts/01-setup-network.sh
# WAN_IP=DHCP usa o DHCP da rede externa (UTM Shared); senão, IP estático + WAN_GATEWAY.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"
RENDERED="$REPO/entrega/config-renderizada/rc.conf.rede"

[ "$(id -u)" -eq 0 ] || { echo "execute como root"; exit 1; }
[ -f "$ENV" ] || { echo "falta $ENV (copie de lab.env.example)"; exit 1; }
. "$ENV"
WAN_NETMASK=${WAN_NETMASK:-255.255.255.0}

for v in WAN_IF LAN_IF WAN_IP WAN_GATEWAY LAN_IP LAN_NETMASK; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "variável $v vazia em lab.env"; exit 1; }
  case "$val" in *X*|*Y*) echo "variável $v ainda com valor de exemplo: $val"; exit 1;; esac
done
[ "$WAN_IF" != "$LAN_IF" ] || { echo "WAN_IF e LAN_IF não podem ser a mesma interface"; exit 1; }
for i in "$WAN_IF" "$LAN_IF"; do
  ifconfig "$i" >/dev/null 2>&1 || { echo "interface $i não existe (ifconfig -l: $(ifconfig -l))"; exit 1; }
done

if [ "$WAN_IP" = "DHCP" ]; then
  WAN_RC="DHCP"
else
  WAN_RC="inet $WAN_IP netmask $WAN_NETMASK"
fi
LAN_RC="inet $LAN_IP netmask $LAN_NETMASK"

# 1. Persistência: o rc.conf é lido a cada boot.
cp /etc/rc.conf "/etc/rc.conf.bak.$(date +%Y%m%d%H%M%S)"
sysrc "ifconfig_${WAN_IF}=${WAN_RC}"
sysrc "ifconfig_${LAN_IF}=${LAN_RC}"
sysrc gateway_enable=YES                       # net.inet.ip.forwarding=1 no boot
if [ "$WAN_IP" = "DHCP" ]; then
  sysrc -x defaultrouter 2>/dev/null || true   # a rota padrão vem do DHCP
else
  sysrc "defaultrouter=${WAN_GATEWAY}"
fi

mkdir -p "$(dirname "$RENDERED")"
{
  echo "# Linhas de /etc/rc.conf gravadas por scripts/01-setup-network.sh"
  echo "ifconfig_${WAN_IF}=\"${WAN_RC}\""
  echo "ifconfig_${LAN_IF}=\"${LAN_RC}\""
  echo "gateway_enable=\"YES\""
  [ "$WAN_IP" = "DHCP" ] || echo "defaultrouter=\"${WAN_GATEWAY}\""
} > "$RENDERED"

# 2. Aplicar agora, sem reiniciar. A LAN é refeita sempre; a WAN só se mudou,
#    para não derrubar uma sessão SSH que chega por ela.
ifconfig "$LAN_IF" inet "$LAN_IP" netmask "$LAN_NETMASK" up
sysctl net.inet.ip.forwarding=1

wan_atual=$(ifconfig "$WAN_IF" | awk '$1 == "inet" {print $2; exit}')
if [ "$WAN_IP" = "DHCP" ]; then
  [ -n "$wan_atual" ] || service netif restart "$WAN_IF"
elif [ "$wan_atual" != "$WAN_IP" ]; then
  ifconfig "$WAN_IF" inet "$WAN_IP" netmask "$WAN_NETMASK" up
fi
if [ "$WAN_IP" != "DHCP" ]; then
  route -n delete default >/dev/null 2>&1 || true
  route -n add default "$WAN_GATEWAY"
fi

# 3. Conferência.
echo; echo "== interfaces"
ifconfig "$WAN_IF" | grep -E 'inet |status'
ifconfig "$LAN_IF" | grep -E 'inet |status'
echo "== rotas"; netstat -rn -f inet
echo "== forwarding"; sysctl net.inet.ip.forwarding
echo "== gateway WAN"
ping -c 2 -t 3 "$WAN_GATEWAY" >/dev/null 2>&1 && echo "OK: $WAN_GATEWAY responde" \
  || echo "AVISO: $WAN_GATEWAY não respondeu ao ping (pode ser bloqueio de ICMP)"
echo "rc.conf renderizado em $RENDERED"

#!/bin/sh
# Instala, configura e inicia o dnsmasq como servidor DHCP restrito à LAN.
# Uso (como root, no roteador FreeBSD): sh scripts/03-setup-dhcp.sh
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"
TEMPLATE="$REPO/config/dnsmasq.conf.template"
RENDERED="$REPO/entrega/config-renderizada/dnsmasq.conf"
TARGET=/usr/local/etc/dnsmasq.conf

[ "$(id -u)" -eq 0 ] || { echo "execute como root"; exit 1; }
[ -f "$ENV" ] || { echo "falta $ENV (copie de lab.env.example)"; exit 1; }
. "$ENV"

for v in WAN_IF LAN_IF LAN_IP LAN_NETMASK DHCP_START DHCP_END DHCP_LEASE DNS_IP RESERVED_MAC RESERVED_IP RESERVED_NAME; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "variável $v vazia em lab.env"; exit 1; }
  case "$val" in *X*|*Y*) echo "variável $v ainda com valor de exemplo: $val"; exit 1;; esac
done
ifconfig "$LAN_IF" >/dev/null 2>&1 || { echo "interface LAN $LAN_IF não existe"; exit 1; }

# FreeBSD novo não tem o pkg instalado; o bootstrap pede confirmação.
pkg -N >/dev/null 2>&1 || env ASSUME_ALWAYS_YES=yes pkg bootstrap
command -v dnsmasq >/dev/null || pkg install -y dnsmasq

mkdir -p "$(dirname "$RENDERED")"
sed -e "s|__WAN_IF__|$WAN_IF|g" -e "s|__LAN_IF__|$LAN_IF|g" -e "s|__LAN_IP__|$LAN_IP|g" \
    -e "s|__LAN_NETMASK__|$LAN_NETMASK|g" -e "s|__DHCP_START__|$DHCP_START|g" -e "s|__DHCP_END__|$DHCP_END|g" \
    -e "s|__DHCP_LEASE__|$DHCP_LEASE|g" -e "s|__DNS_IP__|$DNS_IP|g" -e "s|__RESERVED_MAC__|$RESERVED_MAC|g" \
    -e "s|__RESERVED_IP__|$RESERVED_IP|g" -e "s|__RESERVED_NAME__|$RESERVED_NAME|g" "$TEMPLATE" > "$RENDERED"
! grep -q '__[A-Z_]*__' "$RENDERED" || { echo "marcador não substituído em $RENDERED"; exit 1; }

# Arquivo com erro de sintaxe é anulado na avaliação: validar antes de instalar.
dnsmasq --test -C "$RENDERED"

[ -f "$TARGET" ] && cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d%H%M%S)"
install -m 644 "$RENDERED" "$TARGET"
touch /var/log/dnsmasq.log /var/db/dnsmasq.leases

sysrc dnsmasq_enable=YES
service dnsmasq restart
service dnsmasq status
echo "DHCP ativo em $LAN_IF: pool $DHCP_START-$DHCP_END, reserva $RESERVED_MAC -> $RESERVED_IP"
echo "leases: /var/db/dnsmasq.leases | log: /var/log/dnsmasq.log"

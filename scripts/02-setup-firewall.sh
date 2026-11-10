#!/bin/sh
# Fase 2A: renderiza, valida e aplica as regras do PF (NAT, isolamento e DNAT).
# Uso (como root, no roteador FreeBSD): sh scripts/02-setup-firewall.sh
# Se rodar por SSH, a sessão atual pode cair quando o PF liga; basta reconectar.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV="$REPO/config/lab.env"
TEMPLATE="$REPO/config/pf.conf.template"
RENDERED="$REPO/entrega/config-renderizada/pf.conf"
TARGET=/etc/pf.conf

[ "$(id -u)" -eq 0 ] || { echo "execute como root"; exit 1; }
[ -f "$ENV" ] || { echo "falta $ENV (copie de lab.env.example)"; exit 1; }
. "$ENV"

for v in WAN_IF LAN_IF LAN_CIDR RESERVED_IP DNAT_WAN_PORT DNAT_LAN_PORT; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "variável $v vazia em lab.env"; exit 1; }
  case "$val" in *X*|*Y*) echo "variável $v ainda com valor de exemplo: $val"; exit 1;; esac
done
for i in "$WAN_IF" "$LAN_IF"; do
  ifconfig "$i" >/dev/null 2>&1 || { echo "interface $i não existe"; exit 1; }
done
[ "$(sysctl -n net.inet.ip.forwarding)" = 1 ] || echo "AVISO: ip.forwarding=0; rode antes scripts/01-setup-network.sh"

mkdir -p "$(dirname "$RENDERED")"
sed -e "s|__WAN_IF__|$WAN_IF|g" -e "s|__LAN_IF__|$LAN_IF|g" -e "s|__LAN_CIDR__|$LAN_CIDR|g" \
    -e "s|__RESERVED_IP__|$RESERVED_IP|g" -e "s|__DNAT_WAN_PORT__|$DNAT_WAN_PORT|g" \
    -e "s|__DNAT_LAN_PORT__|$DNAT_LAN_PORT|g" "$TEMPLATE" > "$RENDERED"
! grep -q '__[A-Z_]*__' "$RENDERED" || { echo "marcador não substituído em $RENDERED"; exit 1; }

# Arquivo com erro de sintaxe é anulado na avaliação: validar antes de instalar.
kldstat -q -m pf || kldload pf
pfctl -nf "$RENDERED"
echo "pf.conf: sintaxe OK"

[ -f "$TARGET" ] && cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d%H%M%S)"
install -m 600 "$RENDERED" "$TARGET"

sysrc pf_enable=YES pf_rules="$TARGET"
pfctl -f "$TARGET"
pfctl -e 2>/dev/null || true   # "already enabled" não é erro

echo; echo "== NAT e DNAT (pfctl -sn)"; pfctl -sn
echo "== filtro (pfctl -sr)"; pfctl -sr
echo "== estado"; pfctl -si | head -2
echo "Recuperar acesso se algo bloquear a administração (console do UTM): pfctl -d"

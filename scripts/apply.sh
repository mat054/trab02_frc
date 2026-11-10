#!/bin/sh
# Aplica tudo em ordem segura: pré-requisitos (00) -> rede (01) -> DHCP (03) -> firewall (02).
# Uso (como root, no roteador FreeBSD): sh scripts/apply.sh
#
# Roda em segundo plano com nohup e grava o log em $LOG: se a sessão SSH cair
# quando o PF ligar, a aplicação continua; reconecte e leia o log.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
LOG=/var/log/trab02-apply.log

[ "$(id -u)" -eq 0 ] || { echo "execute como root"; exit 1; }

if [ "${1:-}" != "--foreground" ]; then
  nohup sh "$0" --foreground > "$LOG" 2>&1 &
  pid=$!
  echo "aplicando em segundo plano (pid $pid); log em $LOG"
  echo "se a sessão SSH cair, reconecte e rode: cat $LOG"
  while kill -0 "$pid" 2>/dev/null; do sleep 1; done
  cat "$LOG"
  grep -q '^== APLICADO' "$LOG"
  exit
fi

for step in 00-check-prerequisites.sh 01-setup-network.sh 03-setup-dhcp.sh 02-setup-firewall.sh; do
  echo; echo "== $step ($(date +%T))"
  sh "$REPO/scripts/$step"
done

echo; echo "== status"
sh "$REPO/scripts/status.sh"
echo; echo "== APLICADO ($(date '+%d/%m/%Y %T'))"

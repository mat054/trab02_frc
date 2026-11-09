#!/bin/sh
# Servidor TCP de teste no cliente LAN reservado (10.20.0.10). Fica em loop
# aceitando uma conexão por vez na porta 8080 e ecoa o que recebe.
# Uso: sh tests/tcp-server.sh [porta]   (Ctrl+C para parar)
PORT=${1:-8080}
command -v nc >/dev/null || { echo "instale netcat (nc)"; exit 1; }
echo "escutando TCP $PORT em $(hostname) — teste do outro lado com: nc <IP_WAN_DO_ROTEADOR> 80"
while :; do
  { echo "OK $(hostname) $(date) porta $PORT"; cat; } | nc -l "$PORT"
done

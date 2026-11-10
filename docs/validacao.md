# Validação

Roteiro completo para demonstrar os requisitos no LDS. Cada teste tem roteiro detalhado em `tests/`; as evidências coletadas ficam em `docs/evidencias/` (`tests/collect-evidence.sh`).

## Preparação (antes da demonstração)

1. `cp config/lab.env.example config/lab.env` e preencher `X`, `Y`, `DNS_IP` e `RESERVED_MAC` reais.
2. No roteador, como root: `sh scripts/apply.sh` (rede → PF → DHCP) e `sh scripts/status.sh`.
3. Validar sintaxe: `pfctl -nf /etc/pf.conf` e `dnsmasq --test -C /usr/local/etc/dnsmasq.conf`.
4. Ligar o cliente reservado na LAN e um host de teste na WAN. Em desenvolvimento (UTM), ligar o roteador antes do cliente; o cliente só tem a placa da LAN, então o acesso é pelo roteador: `ssh -J root@<IP_WAN_ROTEADOR> root@10.20.0.10`.

## Ordem dos testes

| # | Requisito do enunciado | Roteiro | Prova mínima |
|---|---|---|---|
| 1 | Roteador com WAN em 192.168.X.0/24 e LAN /16 privada | `tests/01-connectivity.md` | `ifconfig`, `netstat -rn`, `ip.forwarding=1` |
| 2 | NAT entre LAN e rede de acesso | `tests/02-nat.md` | `tcpdump` WAN mostra IP do roteador; `pfctl -ss` |
| 3 | Isolamento do segmento (WAN → LAN bloqueado) | `tests/03-isolation.md` | ping/TCP do host WAN para a LAN falham, mesmo com rota; só TCP 80 (DNAT) entra; LAN → WAN continua saindo |
| 4 | DHCP com máscara, gateway, DNS; reserva fixa; leases em log | `tests/04-dhcp.md` | cliente recebe config; `10.20.0.10` repetido; `dnsmasq.leases` e `dnsmasq.log` |
| 5 | DNAT WAN:80 → LAN:8080 com netcat/telnet | `tests/05-dnat.md` | `nc 192.168.X.Y 80` do host WAN recebe resposta do servidor LAN |
| 6 | Persistência | reiniciar roteador | `status.sh` igual ao anterior; repetir 4 e 5 |

## Como conferir as leases do DHCP

- Arquivo: `/var/db/dnsmasq.leases` (uma linha por concessão: expiração, MAC, IP, hostname).
- Log: `/var/log/dnsmasq.log`, eventos `DHCPDISCOVER/OFFER/REQUEST/ACK` por interface e MAC (`log-dhcp` ativo).
- `tail -f /var/log/dnsmasq.log` durante `dhclient` no cliente mostra o ciclo em tempo real.

## Resultados

_Preencher na Fase 3 (integração), com data, quem executou e o arquivo de evidência._

| Teste | Data | Resultado | Evidência |
|---|---|---|---|
| 01 | | | |
| 02 | | | |
| 03 | | | |
| 04 | 09/11/2026 | **OK** (ambiente UTM) — cliente `52:54:00:4c:41:10` recebeu `10.20.0.10/16`, gateway `10.20.0.1`, DNS `192.168.64.1`; 3 renovações mantiveram o IP; DORA e leases registrados | `docs/evidencias/20261109-144603/` (`dhcp-log.txt`, `leases.txt`, `dnsmasq-conf.txt`) — Luiza |
| 05 | | | |
| 06 | | | |

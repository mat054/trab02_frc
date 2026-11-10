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

Ambiente de desenvolvimento (UTM): WAN `192.168.64.0/24` no papel de `192.168.X.0/24`, roteador `192.168.64.2`, host WAN = o Mac (`192.168.64.1`). Integração em 10/11/2026 no Mac de Mateus, com o PF ligado.

| Teste | Data | Resultado | Evidência |
|---|---|---|---|
| 01 | 10/11/2026 | **OK** — roteador com `vtnet0` `192.168.64.2/24` e `vtnet1` `10.20.0.1/16`, `default` → `192.168.64.1`, `ip.forwarding=1`; cliente com `10.20.0.10/16`, gateway `10.20.0.1`, pinga o roteador | `docs/evidencias/20261110-125035-teste01/` |
| 02 | 10/11/2026 | **OK** — o mesmo ping aparece como `10.20.0.10 > 192.168.64.1` na LAN e `192.168.64.2 > 192.168.64.1` na WAN; `pfctl -ss` mostra a tradução; `fetch` para a internet OK | `docs/evidencias/20261110-1421-fase2a/`; repetido após reinício em `20261110-162724-fase3-pos-reboot/` |
| 03 | 10/11/2026 | **OK após correção** — com rota `10.20.0.0/16` no Mac: ping, `10.20.0.10:22`, `10.20.0.10:8080` direto e `192.168.64.2:8080` dão timeout; só a porta 80 (DNAT) entra. A 1ª rodada mostrou `10.20.0.10:8080` acessível direto; corrigido com `tag DNAT`/`tagged DNAT` no PF | `docs/evidencias/20261110-1421-fase2a/teste03-com-rota.txt` |
| 04 | 09/11/2026 | **OK** (ambiente UTM) — cliente `52:54:00:4c:41:10` recebeu `10.20.0.10/16`, gateway `10.20.0.1`, DNS `192.168.64.1`; 3 renovações mantiveram o IP; DORA e leases registrados | `docs/evidencias/20261109-144603/` (`dhcp-log.txt`, `leases.txt`, `dnsmasq-conf.txt`) — Luiza |
| 04 | 10/11/2026 | **OK com PF ligado** — 3 renovações com `10.20.0.10` e ids de transação novos; cliente comum (MAC trocado para `...41:99`) recebeu `10.20.0.126` do pool; DNS entregue resolve `www.unb.br` via NAT; nenhuma linha `(vtnet0)` no log do dnsmasq | `docs/evidencias/20261110-162724-fase3-pos-reboot/` (`teste04-cliente.log`, `dhcp-log.txt`, `leases.txt`) |
| 05 | 10/11/2026 | **OK** — do Mac, `nc 192.168.64.2 80` recebe `OK cliente-lan ... porta 8080`; o texto enviado aparece no servidor; `pfctl -ss` mostra `10.20.0.10:8080 (192.168.64.2:80) <- 192.168.64.1` | `docs/evidencias/20261110-1421-fase2a/`; repetido após reinício |
| 06 | 10/11/2026 | **OK** — após `shutdown -r` do roteador, rede, forwarding, PF e dnsmasq voltam sozinhos; após `shutdown -r` do cliente, ele recebe `10.20.0.10` no boot; 02, 03 (sem rota) e 05 repetidos com sucesso | `docs/evidencias/20261110-162724-fase3-pos-reboot/resumo-testes.txt` |

Limitação: no UTM só cabe um cliente no link da LAN, então o "cliente comum" do teste 04 foi simulado trocando o MAC do cliente reservado por alguns segundos. `scripts/apply.sh` e `scripts/status.sh`, citados na preparação, ainda não foram implementados: os scripts foram rodados um a um (`01`, `03`, `02`).

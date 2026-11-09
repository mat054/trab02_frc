# Teste 01 — Conectividade

Valida a rede básica (Fase 1) sem alterar a configuração do roteador. Valores em `config/lab.env`.

## No roteador (FreeBSD)

| Comando | Esperado |
|---|---|
| `ifconfig $WAN_IF` | `inet 192.168.X.Y netmask 0xffffff00`, status `active` |
| `ifconfig $LAN_IF` | `inet 10.20.0.1 netmask 0xffff0000` |
| `netstat -rn -f inet` | rota `default` → `192.168.X.1`; rota `10.20.0.0/16` → `$LAN_IF` |
| `sysctl net.inet.ip.forwarding` | `1` |
| `ping -c 3 192.168.X.1` | 3 respostas |
| `fetch -o /dev/null https://www.freebsd.org/` | download OK (plano B se a rede bloquear ICMP) |

## No cliente LAN (após o Teste 04 ou com IP manual `10.20.0.50/16`)

| Comando | Esperado |
|---|---|
| `ifconfig` / `ip a` | IP em `10.20.0.0/16`, máscara `255.255.0.0` |
| `ping -c 3 10.20.0.1` | 3 respostas (gateway LAN alcançável) |
| `ping -c 3 192.168.X.1` | respostas: o roteador encaminha (precisa do NAT, Teste 02) |
| `traceroute 192.168.X.1` | 1º salto `10.20.0.1` |

## Falhas comuns

- Sem rota `10.20.0.0/16`: a interface LAN não recebeu IP (`01-setup-network.sh`).
- Gateway responde mas a WAN não: `ip.forwarding=0` ou NAT ausente.
- ICMP bloqueado pela rede do laboratório: usar `nc -vz 192.168.X.1 53` ou `fetch` em vez de `ping`.

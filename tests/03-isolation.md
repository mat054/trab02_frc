# Teste 03 — Isolamento do segmento

Hosts da WAN não alcançam a LAN diretamente; ICMP ping para fora do segmento é bloqueado pelo firewall. Só a exceção do DNAT (TCP 80) entra.

## Do host WAN de teste (ex.: o Mac, na mesma rede 192.168.X.0/24)

| Comando | Esperado |
|---|---|
| `ping -c 3 10.20.0.10` | 100% perda (rede privada não roteável a partir da WAN) |
| `sudo route add 10.20.0.0/16 192.168.X.Y` e repetir o ping | 100% perda: o PF bloqueia WAN → LAN mesmo com rota |
| `nc -vz -w 3 10.20.0.10 8080` | timeout / recusado |
| `nc -vz -w 3 192.168.X.Y 8080` | recusado (só a porta 80 é redirecionada) |
| `nc -vz -w 3 192.168.X.Y 80` | **sucesso** (exceção do DNAT, Teste 05) |

Remover a rota de teste ao final: `sudo route delete 10.20.0.0/16`.

## Do cliente LAN (regra de ICMP para fora do segmento)

| Comando | Esperado |
|---|---|
| `ping -c 3 10.20.0.1` | responde (ICMP dentro da LAN permitido) |
| `ping -c 3 192.168.X.1` | 100% perda: regra bloqueia ICMP ping para fora da LAN |
| `curl -sI https://www.freebsd.org/` | responde: só o ICMP é bloqueado, TCP continua saindo pelo NAT |

## No roteador

```sh
pfctl -sr                    # regras block in on $WAN_IF ... e block ... icmp
pfctl -vsr | grep -A1 block  # contadores das regras de bloqueio devem crescer
tcpdump -ni $LAN_IF icmp     # durante o ping do cliente para 192.168.X.1: nada sai pela WAN
```

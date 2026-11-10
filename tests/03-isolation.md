# Teste 03 — Isolamento do segmento

Hosts da WAN não alcançam a LAN diretamente: o firewall bloqueia todo tráfego iniciado de fora (WAN → LAN), e só a exceção do DNAT (TCP 80) entra. No sentido contrário não há bloqueio: tráfego iniciado pela LAN, inclusive ping, sai pelo NAT, como pede o teste de conectividade do enunciado.

## Do host WAN de teste (ex.: o Mac, na mesma rede 192.168.X.0/24)

| Comando | Esperado |
|---|---|
| `ping -c 3 10.20.0.10` | 100% perda (rede privada não roteável a partir da WAN) |
| `sudo route add 10.20.0.0/16 192.168.X.Y` e repetir o ping | 100% perda: o PF bloqueia WAN → LAN mesmo com rota |
| `nc -vz -w 3 10.20.0.10 8080` | timeout (o PF descarta em silêncio: `set block-policy drop`) |
| `nc -vz -w 3 192.168.X.Y 8080` | timeout (só a porta 80 é redirecionada) |
| `nc -vz -w 3 192.168.X.Y 80` | **sucesso** (exceção do DNAT, Teste 05) |

Remover a rota de teste ao final: `sudo route delete 10.20.0.0/16`.

## Do cliente LAN (contraprova: o isolamento é só de fora para dentro)

| Comando | Esperado |
|---|---|
| `ping -c 3 10.20.0.1` | responde (tráfego dentro da LAN) |
| `ping -c 3 192.168.X.1` | responde: saída LAN → WAN permitida, traduzida pelo NAT |
| `curl -sI https://www.freebsd.org/` | responde: TCP também sai pelo NAT |

## No roteador

```sh
pfctl -sr                    # regra block in on $WAN_IF (sem bloqueio de ICMP saindo da LAN)
pfctl -vsr | grep -A1 block  # contadores da regra de bloqueio crescem durante os testes do host WAN
tcpdump -ni $LAN_IF icmp     # durante o ping do host WAN para 10.20.0.10 (com rota): nada aparece na LAN
```

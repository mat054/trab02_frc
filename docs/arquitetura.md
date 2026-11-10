# Arquitetura

Topologia do ambiente de desenvolvimento (UTM, Mac Apple Silicon). No laboratório presencial (LDS) a WAN passa a ser a rede `192.168.X.0/24` real; a LAN e o restante não mudam.

## Diagrama

```
   Mac (host)                     VM roteadora                         VM cliente
   192.168.64.1  ── Shared ──  vtnet0 (WAN)                          (Luiza)
   (gateway/WAN                192.168.64.2/24                         MAC reservado
    de teste)                  freebsd-router                          52:54:00:4c:41:10
                               vtnet1 (LAN)  ── link LAN ──────────►  10.20.0.10 (DHCP)
                               10.20.0.1/16                            servidor TCP :8080
```

Fluxos: LAN → WAN com **NAT**; WAN:80 → `10.20.0.10:8080` com **DNAT**; WAN → LAN bloqueado pelo **PF**; **DHCP** só em `vtnet1`.

## Roteador (verificado em 10/11/2026)

| Item | Valor |
|---|---|
| Hostname | `freebsd-router` |
| SO | FreeBSD 15.1-RELEASE, arm64 (GENERIC) |
| Hipervisor | UTM (QEMU), interfaces `virtio` (`vtnet*`) |
| `net.inet.ip.forwarding` | `0` (ligar na Fase 1) |

## Interfaces

| Papel | Interface | Rede UTM | Endereço | MAC | Estado |
|---|---|---|---|---|---|
| WAN | `vtnet0` | Shared Network | `192.168.64.2/24` (DHCP do UTM), gateway `192.168.64.1` | `72:f7:12:be:72:47` | ativa |
| LAN | `vtnet1` | link QEMU ponto a ponto (ver abaixo) | `10.20.0.1/16` (estático, Fase 1) | `52:54:00:4c:41:01` | placa criada; sem IP até a Fase 1 |

### Link da LAN no UTM

A LAN não usa uma rede do painel *Network* do UTM, porque Host-Only e Shared trazem DHCP do macOS. É um cabo virtual do QEMU em loopback, criado em *Edit → QEMU → Arguments* (um argumento por item):

| VM | Argumentos |
|---|---|
| Roteadora | `-netdev socket,id=lan0,listen=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:01` |
| Cliente | `-netdev socket,id=lan0,connect=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:10` |

A roteadora (`listen`) deve ser ligada antes da cliente (`connect`), e as duas precisam estar no mesmo Mac. Detalhes em `docs/limitacoes.md`.

## Endereçamento

| Rede | Faixa | Observação |
|---|---|---|
| WAN (dev) | `192.168.64.0/24` | no LDS: `192.168.X.0/24`, gateway `192.168.X.1` |
| LAN | `10.20.0.0/16` (`255.255.0.0`) | RFC 1918; não usa `192.168.0.0/16` para não sobrepor a WAN |
| Pool DHCP | `10.20.0.100`–`10.20.0.200` | lease de 12h |
| Reserva por MAC | `10.20.0.10` | cliente com servidor TCP em `:8080` |

Valores compartilhados: `config/lab.env.example`.

## Pendências desta página

- Substituir `192.168.64.x` por `192.168.X.Y` quando o professor informar X.
- Confirmar o MAC do cliente reservado com a Luiza (hoje `52:54:00:4c:41:10`, de `lab.env.example`).

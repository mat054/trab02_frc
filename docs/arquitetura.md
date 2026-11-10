# Arquitetura

## Topologia

No laboratório (LDS) a WAN é a rede de acesso `192.168.X.0/24`. Em desenvolvimento, a rede *Shared* do UTM (`192.168.64.0/24`) faz esse papel, e o Mac é o "outro equipamento do lado WAN". O restante não muda.

```
   Host WAN de teste                VM roteadora                          VM cliente
   (dev: Mac 192.168.64.1)          freebsd-router                        cliente-lan
          │                                                               MAC 52:54:00:4c:41:10
          └── rede de acesso ──  vtnet0 (WAN)                             10.20.0.10/16 (reserva DHCP)
              192.168.X.0/24     192.168.X.Y  (dev: 192.168.64.2)         servidor TCP :8080
              gw 192.168.X.1     vtnet1 (LAN)  ── LAN 10.20.0.0/16 ──  vtnet0
                                 10.20.0.1/16
```

## Roteador (verificado em 10/11/2026)

| Item | Valor |
|---|---|
| Hostname | `freebsd-router` |
| SO | FreeBSD 15.1-RELEASE, arm64, kernel GENERIC (instalação padrão) |
| Hipervisor (dev) | UTM 5.0.8 (QEMU 10.0, máquina `virt`), interfaces `virtio-net` (`vtnet*`) |
| Encaminhamento IPv4 | `gateway_enable="YES"` → `net.inet.ip.forwarding=1` |
| Serviços no boot | `pf_enable="YES"`, `dnsmasq_enable="YES"` |

## Interfaces

| Papel | Interface | Rede UTM (dev) | Endereço | MAC |
|---|---|---|---|---|
| WAN | `vtnet0` | Shared Network (no LDS: Bridged) | `192.168.64.2/24` por DHCP do UTM (no LDS: `192.168.X.Y/24` estático), gateway `192.168.64.1` (no LDS: `192.168.X.1`) | `72:f7:12:be:72:47` |
| LAN | `vtnet1` | link QEMU ponto a ponto (ver abaixo) | `10.20.0.1/16` estático | `52:54:00:4c:41:01` |

### Link da LAN no UTM

A LAN não usa uma rede do painel *Network* do UTM, porque *Host Only* e *Shared* trazem DHCP do macOS. É um cabo virtual do QEMU em loopback, criado em *Edit → QEMU → Arguments* (um argumento por item):

| VM | Painel *Network* | Argumentos |
|---|---|---|
| Roteadora | 1 placa Shared (WAN) | `-netdev socket,id=lan0,listen=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:01` |
| Cliente | nenhuma placa | `-netdev socket,id=lan0,connect=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:10` |

A roteadora (`listen`) deve ser ligada antes da cliente (`connect`), e as duas precisam estar no mesmo Mac (ver `docs/limitacoes.md`).

## Endereçamento

| Rede | Faixa | Observação |
|---|---|---|
| WAN | `192.168.X.0/24` (dev: `192.168.64.0/24`) | rede de acesso do laboratório |
| LAN | `10.20.0.0/16` (`255.255.0.0`) | faixa privada RFC 1918; não usa `192.168.0.0/16` para não sobrepor a WAN |
| Gateway da LAN | `10.20.0.1` | entregue pelo DHCP (opção 3) |
| Pool DHCP | `10.20.0.100`–`10.20.0.200` | concessão de 12 h |
| Reserva por MAC | `10.20.0.10` ← `52:54:00:4c:41:10` | fora do pool; destino do DNAT |
| DNS entregue | `DNS_IP` (dev: `192.168.64.1`; LDS: `192.168.X.1` ou `164.41.101.4`/`.11`) | opção 6; o roteador não serve DNS |

Valores compartilhados: `config/lab.env.example`.

## Aplicações utilizadas

| Aplicação | Origem | Função | Configuração |
|---|---|---|---|
| **PF** (`pf`, `pfctl`) | base do FreeBSD | NAT de saída, firewall (isolamento) e DNAT | `config/pf.conf.template` → `/etc/pf.conf` |
| **dnsmasq** 2.93 | pacote (`pkg install dnsmasq`) | só DHCP na LAN: pool, gateway, DNS, máscara, reserva por MAC, leases e log | `config/dnsmasq.conf.template` → `/usr/local/etc/dnsmasq.conf` |
| `ifconfig`, `sysctl`, `sysrc`, `rc.conf` | base | endereços das interfaces, rota padrão e encaminhamento IPv4 persistentes | `scripts/01-setup-network.sh` |
| `dhclient` | base | cliente DHCP (no cliente da LAN e, em dev, na WAN do roteador) | `ifconfig_vtnet0="DHCP"` |
| `nc` (netcat) | base | servidor TCP `:8080` no cliente e cliente TCP no host WAN (teste de DNAT) | `tests/tcp-server.sh` |
| `tcpdump`, `pfctl -s*` | base | observar a tradução e os bloqueios | `tests/*.md`, `scripts/status.sh` |
| `doas` | pacote | root sem senha **só na VM de desenvolvimento** | `/usr/local/etc/doas.conf` |

Nenhuma distribuição pronta de firewall/roteador foi usada.

## Caminho dos pacotes

**Saída da LAN (NAT).** O cliente `10.20.0.10` envia para `192.168.X.1` pela rota padrão `10.20.0.1`. O roteador recebe em `vtnet1` (`pass in on $lan`), encaminha (`ip.forwarding=1`) e, ao sair por `vtnet0`, a regra `nat on $wan from $lan_net -> ($wan)` troca a origem por `192.168.X.Y` e uma porta própria. A resposta casa com o estado criado e volta traduzida para `10.20.0.10`.

**Entrada pela WAN (isolamento).** Todo pacote que entra por `vtnet0` cai em `block in on $wan all`, inclusive vindo de um host que tenha rota para `10.20.0.0/16`. As exceções valem só para o **próprio roteador** (SSH, ping no IP WAN e respostas DHCP da WAN) e para o DNAT.

**DNAT.** Um host WAN conecta em `192.168.X.Y:80`. A regra `rdr ... port 80 tag DNAT -> 10.20.0.10 port 8080` reescreve o destino e **marca** o pacote; o filtro só libera `10.20.0.10:8080` para pacotes com a marca (`tagged DNAT`). Uma conexão direta a `10.20.0.10:8080`, sem passar pela porta 80, não tem a marca e é bloqueada. A resposta do servidor sai pelo gateway `10.20.0.1`, e o estado desfaz a tradução (origem volta a ser `192.168.X.Y:80`).

**DHCP.** O dnsmasq escuta só em `vtnet1` (`interface=`, `bind-interfaces`, `no-dhcp-interface=vtnet0`). O pedido do cliente entra por `pass in on $lan all`; na WAN não sai nenhuma resposta DHCP (verificado no log: nenhuma linha `(vtnet0)`).

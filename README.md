# Trabalho 02 — Camada de Rede: NAT + DHCP + DNAT

**Disciplina:** Fundamentos de Redes de Computadores (UnB Gama) · **Professor:** Tiago Alves
**Dupla:** Mateus Castro e Luiza Maluf

Roteador FreeBSD com a WAN na rede de acesso `192.168.X.0/24` (gateway `192.168.X.1`) e uma LAN privada `10.20.0.0/16`. Ele faz NAT de saída, isola a LAN de acessos vindos de fora, distribui endereços por DHCP com reserva por MAC e redireciona a porta TCP 80 da WAN para a porta TCP 8080 de um cliente da LAN (DNAT).

```
 rede de acesso 192.168.X.0/24 (gateway 192.168.X.1)
        │
   vtnet0 (WAN) 192.168.X.Y
 ┌─────────────────────────────────────┐
 │ Roteador FreeBSD 15.1               │
 │ ip.forwarding · PF (NAT, filtro,    │
 │ DNAT) · dnsmasq (só DHCP)           │
 └─────────────────────────────────────┘
   vtnet1 (LAN) 10.20.0.1/16
        │
 LAN 10.20.0.0/16 ── cliente reservado 10.20.0.10 (servidor TCP :8080)
                 └── clientes comuns 10.20.0.100–200 (pool DHCP)
```

## Os cinco tópicos pedidos no enunciado

| Tópico | Resposta curta | Detalhes |
|---|---|---|
| **1. Sistema operacional** | **FreeBSD 15.1-RELEASE**, arm64 (kernel GENERIC), instalação padrão, sem distribuição de firewall pronta. Em desenvolvimento roda em VM no UTM (QEMU) num Mac Apple Silicon | [docs/arquitetura.md](docs/arquitetura.md) |
| **2. Aplicações** | **PF** (base do FreeBSD): NAT, firewall e DNAT · **dnsmasq** (pacote): só DHCP, com o DNS desligado · **sysctl/rc.conf**: roteamento IPv4 · **netcat**: servidor e cliente TCP do teste de DNAT · **tcpdump** e **pfctl**: inspeção · **doas**: root na VM de desenvolvimento | [docs/arquitetura.md](docs/arquitetura.md#aplicações-utilizadas) |
| **3. Como implementar a LAN** | Preencher `config/lab.env` e rodar `sh scripts/apply.sh` como root | [docs/instalacao.md](docs/instalacao.md) |
| **4. Como validar** | `sh scripts/status.sh` e os roteiros `tests/01` a `tests/05` (conectividade, NAT, isolamento, DHCP e DNAT) | [docs/validacao.md](docs/validacao.md) |
| **5. Limitações conhecidas** | Ambiente virtual, um cliente por link no UTM, só IPv4, entre outras | [docs/limitacoes.md](docs/limitacoes.md) |

## Execução rápida (no roteador, como root)

```sh
cp config/lab.env.example config/lab.env   # preencher X, Y, DNS e o MAC do cliente reservado
sh scripts/apply.sh                        # pré-requisitos -> rede -> DHCP -> firewall -> status
sh scripts/status.sh                       # deve terminar com "status: tudo OK"
```

No laboratório, `config/lab.env` fica assim (os demais valores do exemplo não mudam):

```sh
WAN_IP=192.168.X.Y           # IP autorizado na rede de acesso
WAN_GATEWAY=192.168.X.1
DNS_IP=192.168.X.1           # ou 164.41.101.4 / 164.41.101.11, conforme o professor
RESERVED_MAC=<MAC do cliente que roda o servidor TCP>
```

Para desfazer: `sh scripts/rollback.sh --sim` (mantém a WAN, para não perder o acesso).

## Lista de testes

| # | Teste | Roteiro | Resultado em 10/11/2026 (UTM) |
|---|---|---|---|
| 01 | Conectividade | [tests/01-connectivity.md](tests/01-connectivity.md) | OK |
| 02 | Tradução de endereço (NAT) | [tests/02-nat.md](tests/02-nat.md) | OK |
| 03 | Isolamento de segmento | [tests/03-isolation.md](tests/03-isolation.md) | OK (após corrigir uma falha, ver `docs/validacao.md`) |
| 04 | DHCP, reserva, leases e logs | [tests/04-dhcp.md](tests/04-dhcp.md) | OK |
| 05 | DNAT TCP 80 → 8080 com netcat | [tests/05-dnat.md](tests/05-dnat.md) | OK |
| 06 | Persistência após reinício | [docs/validacao.md](docs/validacao.md) | OK |

As evidências estão em [docs/evidencias/](docs/evidencias/).

## Estrutura

```
config/   lab.env.example, pf.conf.template, dnsmasq.conf.template
scripts/  00-check-prerequisites, 01-setup-network, 02-setup-firewall, 03-setup-dhcp,
          apply, status, rollback (POSIX sh, FreeBSD)
tests/    roteiros 01-05, tcp-server.sh (servidor do DNAT), collect-evidence.sh
docs/     arquitetura, instalacao, validacao, limitacoes, evidencias/
entrega/  checklist.md e config-renderizada/ (pf.conf, dnsmasq.conf e rc.conf finais, sintaxe validada)
```

Os scripts geram `/etc/pf.conf` e `/usr/local/etc/dnsmasq.conf` a partir dos templates, validam a sintaxe (`pfctl -nf`, `dnsmasq --test`) **antes** de instalar, guardam backup do arquivo anterior e gravam a configuração no `/etc/rc.conf` para valer após reiniciar.

## Referências

- Wright, G. R.; Stevens, W. R. *TCP/IP Illustrated, Vol. 2*. Addison-Wesley, 1995.
- Lucas, M. W. *Networking for System Administrators*. 2nd ed., Tilted Windmill Press, 2025.
- FreeBSD Handbook, *Firewalls (PF)* e *Advanced Networking*: https://docs.freebsd.org/en/books/handbook/
- Manual do dnsmasq: https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
- Páginas de manual do FreeBSD: `pf.conf(5)`, `pfctl(8)`, `rc.conf(5)`, `dhclient(8)`, `nc(1)`.

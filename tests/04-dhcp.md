# Teste 04 — DHCP e reserva

Cliente recebe IP, máscara `/16`, gateway `10.20.0.1` e DNS automaticamente; o cliente reservado recebe sempre `10.20.0.10`.

## Pré-requisitos

- `scripts/03-setup-dhcp.sh` executado; `service dnsmasq status` → running.
- Cliente ligado **somente** na rede LAN (sem DHCP do virtualizador nessa rede).
- `RESERVED_MAC` em `lab.env` é o MAC real do cliente reservado.

## A. Cliente comum (concessão dinâmica)

Cliente FreeBSD: `dhclient vtnet0`. Linux: `sudo dhclient -v eth0` ou `sudo dhcpcd eth0`.

| Comando | Esperado |
|---|---|
| `ifconfig` | IP em `10.20.0.100`–`10.20.0.200`, máscara `255.255.0.0` (`0xffff0000`) |
| `netstat -rn` / `ip r` | `default` → `10.20.0.1` |
| `cat /etc/resolv.conf` | `nameserver <DNS_IP>` (e não `10.20.0.1`) |
| `nslookup www.unb.br` | resolve, passando pelo NAT |

## B. Cliente reservado

Mesmo procedimento. Esperado: IP **exatamente** `10.20.0.10`, hostname `cliente-reservado` no lease.
Repetir `service dhclient restart vtnet0` três vezes: o IP não muda.

## C. Renovação

Cliente: `service dhclient restart vtnet0` (no FreeBSD o `dhclient` é gerido pelo rc/devd; chamar `dhclient` direto responde "already running"). No roteador o log mostra `DHCPREQUEST` + `DHCPACK` com novo id de transação.

## D. Conferir leases e logs no roteador

```sh
cat /var/db/dnsmasq.leases
# formato: <expira (epoch)> <MAC> <IP> <hostname> <client-id>
date -r <epoch>                         # converte o tempo de expiração

tail -f /var/log/dnsmasq.log
# DHCPDISCOVER(vtnet1) <MAC>
# DHCPOFFER(vtnet1) 10.20.0.10 <MAC>
# DHCPREQUEST(vtnet1) 10.20.0.10 <MAC>
# DHCPACK(vtnet1) 10.20.0.10 <MAC> cliente-reservado
```

## E. DHCP não vaza para a WAN

No roteador, `sockstat -4 -l | grep dnsmasq` mostra UDP `*:67` (no FreeBSD o socket DHCP é sempre curinga; o filtro por interface é feito pelo próprio dnsmasq via `interface=`/`no-dhcp-interface=`). A prova é `tcpdump -ni $WAN_IF port 67 or port 68`: nenhum OFFER/ACK sai do roteador quando um host da WAN pede DHCP, e o log mostra apenas `DHCP...(vtnet1)`.

## Falhas comuns

- Cliente sem IP: PF bloqueando UDP 67/68 na LAN (`pfctl -sr`), ou cliente em outra rede virtual.
- Cliente reservado pegou IP do pool: MAC em `lab.env` diferente do real (`ifconfig` no cliente); regerar com `03-setup-dhcp.sh`.
- DNS veio como `10.20.0.1`: faltou `port=0` ou `dhcp-option=option:dns-server`.

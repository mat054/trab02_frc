# Instalação

Como transformar um FreeBSD 15.1 com duas placas de rede no roteador do trabalho e ligar um cliente na LAN. A topologia está em `docs/arquitetura.md`.

## 1. Preparar as máquinas

### Roteador

1. Instalar o **FreeBSD 15.1-RELEASE** (usado: imagem `FreeBSD-15.1-RELEASE-arm64-aarch64-disc1.iso`) com as opções padrão do instalador, `sshd` ligado e um usuário no grupo `wheel`.
2. Duas placas de rede:
   - **WAN** (`vtnet0`): ligada à rede de acesso. No UTM em desenvolvimento, uma placa *Shared Network*; no LDS, *Bridged* para o adaptador ligado à rede cabeada.
   - **LAN** (`vtnet1`): rede só da LAN, sem nenhum outro DHCP. No UTM, criada em *Edit → QEMU → Arguments* com os dois argumentos da tabela "Link da LAN no UTM" em `docs/arquitetura.md`; num equipamento físico, a segunda placa ligada a um switch só da LAN.
3. Conferir: `ifconfig -l` → `vtnet0 vtnet1 lo0`.

### Cliente da LAN

FreeBSD (ou outro SO) com **uma** placa, ligada **só** à LAN e configurada para DHCP (no FreeBSD, `ifconfig_vtnet0="DHCP"` no `rc.conf`). Anotar o MAC dela (`ifconfig vtnet0 | grep ether`): ele vai em `RESERVED_MAC`. No UTM, a placa vem dos argumentos QEMU do cliente (MAC `52:54:00:4c:41:10`); o painel *Network* fica sem placa. Ligar o roteador **antes** do cliente.

### Host de teste na WAN

Qualquer máquina da rede de acesso com `nc` ou `telnet`. Em desenvolvimento, o próprio Mac. Ele **não** pode ser o roteador nem um cliente da LAN.

## 2. Pré-requisitos no roteador

1. **Acesso de root.** No LDS, rodar os scripts como root (`su -`). Na VM de desenvolvimento foi instalado o `doas`:
   ```sh
   su -
   env ASSUME_ALWAYS_YES=yes pkg bootstrap
   pkg install -y doas
   echo "permit nopass <usuario>" > /usr/local/etc/doas.conf   # só em VM de teste
   ```
2. **Copiar o projeto** para o roteador (ex.: `~/trab02_frc`). Do Mac, na pasta que contém o projeto:
   ```sh
   COPYFILE_DISABLE=1 tar --exclude .git -czf - trab02_frc | ssh <usuario>@<IP_WAN> 'tar -xzf - -C ~'
   ```
3. **Criar `config/lab.env`** a partir de `config/lab.env.example` e ajustar:

   | Variável | Desenvolvimento (UTM) | Laboratório (LDS) |
   |---|---|---|
   | `WAN_IP` | `DHCP` (endereço vem do UTM) | `192.168.X.Y` (estático) |
   | `WAN_GATEWAY` | `192.168.64.1` | `192.168.X.1` |
   | `DNS_IP` | `192.168.64.1` | `192.168.X.1`, `164.41.101.4` ou `164.41.101.11` |
   | `RESERVED_MAC` | `52:54:00:4c:41:10` | MAC real do cliente reservado |

   Os demais valores (`LAN_IP=10.20.0.1`, `LAN_CIDR=10.20.0.0/16`, pool `10.20.0.100`–`200`, `RESERVED_IP=10.20.0.10`, portas `80`/`8080`) não mudam.
4. **Conferir:** `sh scripts/00-check-prerequisites.sh` deve terminar com `pré-requisitos: OK`.

## 3. Instalação rápida

```sh
cd ~/trab02_frc
sh scripts/apply.sh          # 00 -> 01 (rede) -> 03 (DHCP) -> 02 (PF) -> status
sh scripts/status.sh         # deve terminar com "status: tudo OK"
sh scripts/rollback.sh --sim # desfaz (mantém a WAN, os pacotes e os backups)
```

- `apply.sh` roda em segundo plano com `nohup` e grava o log em `/var/log/trab02-apply.log`: se a sessão SSH cair quando o PF liga, a aplicação continua. Reconecte e leia o log; a última linha é `== APLICADO <data>`.
- `status.sh` só lê. Faz 10 conferências (OK/FALHA) e mostra interfaces, rotas, regras, estados e leases. Sai com código `1` se algo falhar.
- `rollback.sh` pede `--sim` para não ser rodado por engano. Desliga PF e dnsmasq, tira o IP da LAN e o `gateway_enable`, agora e no boot. Depois dele, `apply.sh` reconstrói tudo (testado em 10/11/2026).
- Todos podem ser executados de novo: o resultado é o mesmo.

As seções 4 a 6 detalham cada etapa, para quem quiser rodar os scripts um a um.

## 4. Rede e roteamento — `scripts/01-setup-network.sh`

1. Valida `lab.env` (sem valores de exemplo `X`/`Y`) e confere se as duas interfaces existem.
2. Faz backup de `/etc/rc.conf` (`/etc/rc.conf.bak.<data>`) e grava com `sysrc`:
   - `ifconfig_<WAN_IF>`: `DHCP` ou `inet WAN_IP netmask 255.255.255.0`;
   - `ifconfig_<LAN_IF>`: `inet 10.20.0.1 netmask 255.255.0.0`;
   - `gateway_enable="YES"`, que liga `net.inet.ip.forwarding` em todo boot;
   - `defaultrouter`, só com WAN estática; com DHCP, a rota padrão vem do servidor.
3. Aplica na hora, sem reiniciar. A WAN só é refeita se o endereço mudou, para não derrubar o SSH.
4. Mostra interfaces, rotas, forwarding e o ping ao gateway WAN.
5. Salva as linhas gravadas em `entrega/config-renderizada/rc.conf.rede`.

**Conferência** (10/11/2026, inclusive após `shutdown -r now`):

```
vtnet0  inet 192.168.64.2 netmask 0xffffff00
vtnet1  inet 10.20.0.1    netmask 0xffff0000
default         192.168.64.1  UGS  vtnet0
10.20.0.0/16    link#2        U    vtnet1
net.inet.ip.forwarding: 1
```

## 5. DHCP — `scripts/03-setup-dhcp.sh`

1. Valida `lab.env` e a interface LAN.
2. Instala o `pkg` (se o sistema for novo) e o pacote `dnsmasq`.
3. Renderiza `config/dnsmasq.conf.template` em `entrega/config-renderizada/dnsmasq.conf` e valida com `dnsmasq --test` **antes** de instalar.
4. Faz backup e instala em `/usr/local/etc/dnsmasq.conf`; cria `/var/db/dnsmasq.leases` e `/var/log/dnsmasq.log`.
5. Grava `dnsmasq_enable="YES"` e reinicia o serviço.

Configuração entregue (principais linhas):

| Linha | Efeito |
|---|---|
| `port=0` | Desliga o DNS do dnsmasq: o roteador só faz DHCP |
| `interface=vtnet1`, `bind-interfaces`, `no-dhcp-interface=vtnet0` | Responde DHCP só na LAN; nada vaza para a rede do laboratório |
| `dhcp-range=10.20.0.100,10.20.0.200,255.255.0.0,12h` | Pool, máscara `/16` e tempo de concessão |
| `dhcp-option=option:router,10.20.0.1` | Gateway entregue aos clientes |
| `dhcp-option=option:dns-server,<DNS_IP>` | DNS entregue aos clientes |
| `dhcp-host=52:54:00:4c:41:10,10.20.0.10,cliente-reservado` | Reserva: esse MAC recebe sempre `10.20.0.10` |
| `dhcp-leasefile=/var/db/dnsmasq.leases`, `log-dhcp`, `log-facility=/var/log/dnsmasq.log` | Onde conferir as concessões |

**Conferir as concessões:**

```sh
cat /var/db/dnsmasq.leases     # <expira (epoch)> <MAC> <IP> <hostname> <client-id>
date -r <epoch>                # converte a expiração
grep -E 'DHCP(DISCOVER|OFFER|REQUEST|ACK|NAK)' /var/log/dnsmasq.log | tail
```

## 6. Firewall — `scripts/02-setup-firewall.sh`

O script renderiza `config/pf.conf.template` com os valores de `lab.env`, carrega o módulo `pf`, valida com `pfctl -nf` **antes** de instalar, faz backup de `/etc/pf.conf`, grava `pf_enable="YES"` e liga o PF. A cópia renderizada fica em `entrega/config-renderizada/pf.conf`.

Regras (o PF aplica a **última** regra que casa):

| Regra | Efeito |
|---|---|
| `nat on $wan from $lan_net -> ($wan)` | A LAN sai com o IP WAN do roteador |
| `rdr on $wan proto tcp to ($wan) port 80 tag DNAT -> 10.20.0.10 port 8080` | DNAT para o cliente reservado; o pacote redirecionado recebe a marca `DNAT` |
| `block in on $wan all` | Isolamento: nada iniciado de fora entra |
| `pass in on $wan ... to 10.20.0.10 port 8080 tagged DNAT` | Libera só o que veio pela porta 80. Sem o `tagged`, um host WAN com rota para `10.20.0.0/16` alcançaria `10.20.0.10:8080` direto (falha encontrada no teste 03 e corrigida) |
| `pass in on $wan ... to ($wan) port 22` / `icmp echoreq` | SSH e ping **no próprio roteador**, para administração; não alcançam a LAN |
| `pass in on $wan udp port 67 -> 68` | Respostas DHCP, quando a WAN usa DHCP |
| `pass in on $lan all` / `pass out all` | A LAN inicia o que quiser; as respostas voltam pelo estado |

**Por SSH:** a sessão aberta pode cair no instante em que o PF liga, porque ela não tem estado na tabela. `apply.sh` já trata disso; rodando o script sozinho:

```sh
sh -c "nohup sh scripts/02-setup-firewall.sh > /tmp/pf-apply.log 2>&1 &"
```

**Inspeção:**

```sh
pfctl -sn            # regras de NAT e rdr
pfctl -sr            # regras de filtro
pfctl -ss            # estados: 192.168.X.Y:porta (10.20.0.10:porta) -> destino
pfctl -vsr           # contadores por regra
tcpdump -ni vtnet0   # WAN: origem deve ser o IP do roteador, nunca 10.20.x.x
```

## 7. Cliente e servidor do DNAT

No cliente reservado:

```sh
dhclient vtnet0                 # "bound to 10.20.0.10"
sh tests/tcp-server.sh 8080     # servidor netcat; não sobe sozinho após reiniciar
```

No host de teste da WAN: `nc -v 192.168.X.Y 80` (ou `telnet 192.168.X.Y 80`). Roteiro completo em `tests/05-dnat.md`.

## 8. Recuperar ou desfazer

- **Firewall bloqueou a administração:** no console do equipamento (ou do UTM), `pfctl -d` desliga o PF; `cp /etc/pf.conf.bak.<data> /etc/pf.conf && pfctl -f /etc/pf.conf` volta à versão anterior.
- **Desfazer tudo:** `sh scripts/rollback.sh --sim`.
- **Voltar o `rc.conf` anterior:** `cp /etc/rc.conf.bak.<data> /etc/rc.conf` e reiniciar.

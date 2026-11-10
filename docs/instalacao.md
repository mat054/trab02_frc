# Instalação

Passo a passo para transformar uma VM FreeBSD 15.1 com duas placas de rede no roteador do trabalho. A topologia está em `docs/arquitetura.md`.

## 0. Pré-requisitos

- FreeBSD 15.1 com duas interfaces: WAN (`vtnet0`) e LAN (`vtnet1`). No UTM, a LAN é criada pelos argumentos QEMU descritos em `docs/arquitetura.md`.
- Acesso de root. Na VM de desenvolvimento foi instalado o `doas` (equivalente ao `sudo`):
  ```sh
  su -
  env ASSUME_ALWAYS_YES=yes pkg bootstrap
  pkg install -y doas
  echo "permit nopass mateus" > /usr/local/etc/doas.conf
  ```
  O `nopass` serve só para o ambiente de desenvolvimento. No laboratório, rodar os scripts como root.
- Repositório copiado para o roteador (ex.: `~/trab02_frc`) e `config/lab.env` criado a partir de `config/lab.env.example`:

  | Variável | Desenvolvimento (UTM) | Laboratório (LDS) |
  |---|---|---|
  | `WAN_IP` | `DHCP` | `192.168.X.Y` |
  | `WAN_GATEWAY` | `192.168.64.1` | `192.168.X.1` |
  | `DNS_IP` | `192.168.64.1` | informado pelo professor |

## 1. Rede básica e roteamento (Fase 1)

```sh
doas sh scripts/01-setup-network.sh
```

O script:

1. Valida `lab.env` (sem valores de exemplo `X`/`Y`) e confere se as duas interfaces existem.
2. Faz backup de `/etc/rc.conf` (`/etc/rc.conf.bak.<data>`) e grava com `sysrc`:
   - `ifconfig_<WAN_IF>`: `DHCP` ou `inet WAN_IP netmask 255.255.255.0`;
   - `ifconfig_<LAN_IF>`: `inet 10.20.0.1 netmask 255.255.0.0`;
   - `gateway_enable="YES"`, que liga `net.inet.ip.forwarding` em todo boot;
   - `defaultrouter`, só com WAN estática; com DHCP, a rota padrão vem do servidor.
3. Aplica na hora, sem reiniciar. A WAN só é refeita se o endereço mudou, para não derrubar o SSH.
4. Mostra interfaces, rotas, forwarding e o ping ao gateway WAN.
5. Salva as linhas gravadas em `entrega/config-renderizada/rc.conf.rede`.

Pode ser executado mais de uma vez: o resultado é o mesmo.

**Conferência** (resultado obtido em 10/11/2026, inclusive após `shutdown -r now`):

```
vtnet0  inet 192.168.64.2 netmask 0xffffff00
vtnet1  inet 10.20.0.1    netmask 0xffff0000
default         192.168.64.1  UGS  vtnet0
10.20.0.0/16    link#2        U    vtnet1
net.inet.ip.forwarding: 1
```

**Desfazer:** restaurar o backup (`cp /etc/rc.conf.bak.<data> /etc/rc.conf`) e reiniciar.

## 2. Firewall PF: NAT, isolamento e DNAT (Fase 2A)

```sh
doas sh scripts/02-setup-firewall.sh
```

O script renderiza `config/pf.conf.template` com os valores de `lab.env`, valida com `pfctl -nf` **antes** de instalar, faz backup de `/etc/pf.conf`, grava `pf_enable="YES"` no `rc.conf`, carrega e liga o PF. A cópia renderizada fica em `entrega/config-renderizada/pf.conf`.

Regras (o PF aplica a **última** regra que casa):

| Regra | Efeito |
|---|---|
| `nat on $wan from $lan_net -> ($wan)` | A LAN sai com o IP WAN do roteador |
| `rdr on $wan proto tcp to ($wan) port 80 tag DNAT -> 10.20.0.10 port 8080` | DNAT para o cliente reservado; o pacote redirecionado recebe a marca `DNAT` |
| `block in on $wan all` | Isolamento: nada iniciado de fora entra |
| `pass in on $wan ... to 10.20.0.10 port 8080 tagged DNAT` | Libera só o tráfego que veio pela porta 80. Sem o `tagged`, um host WAN com rota para `10.20.0.0/16` alcançaria `10.20.0.10:8080` direto (falha encontrada no teste 03 e corrigida) |
| `pass in on $wan ... to ($wan) port 22` / `icmp echoreq` | SSH e ping **no próprio roteador**, para administração; não alcançam a LAN |
| `pass in on $wan udp port 67 -> 68` | Respostas DHCP, quando a WAN usa DHCP |
| `pass in on $lan all` / `pass out all` | A LAN inicia o que quiser; as respostas voltam pelo estado |

**Por SSH:** a sessão aberta pode cair no instante em que o PF liga, porque ela não tem estado na tabela. Rodar desacoplado e reconectar:

```sh
doas sh -c "nohup sh scripts/02-setup-firewall.sh > /tmp/pf-apply.log 2>&1 &"
```

**Inspeção:**

```sh
pfctl -sn            # regras de NAT e rdr
pfctl -sr            # regras de filtro
pfctl -ss            # estados: 10.20.0.10:porta (192.168.X.Y:porta) -> destino
pfctl -vsr           # contadores por regra
tcpdump -ni vtnet0   # WAN: origem deve ser o IP do roteador, nunca 10.20.x.x
```

**Recuperar acesso** se uma regra bloquear a administração: no console do UTM (ou do equipamento), `pfctl -d` desliga o PF; `cp /etc/pf.conf.bak.<data> /etc/pf.conf && pfctl -f /etc/pf.conf` volta à versão anterior.

## 3. DHCP (Fase 2B)

```sh
doas sh scripts/03-setup-dhcp.sh
```

Detalhes no próprio script e em `docs/validacao.md`.

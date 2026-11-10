# Replicar o ambiente e os testes em outro Mac

Guia para repetir no UTM o que o Mateus rodou em 10/11/2026: Fases 0, 1 e 2A, testes 01, 02, 03 (com e sem rota) e 05.
Evidências: `docs/evidencias/20261110-125035-teste01/` e `docs/evidencias/20261110-1421-fase2a/`.

> Documento interno da dupla (ensaio). Não faz parte da documentação de entrega.

## 0. Antes de começar

- [ ] O trabalho do Mateus está na branch **`feature/rede-pf`** (commit `b166756`). Depois do push dele:
  ```sh
  git fetch origin
  git switch feature/rede-pf     # ou: git pull na main, se a branch já tiver sido juntada
  ```
- [ ] As duas VMs (roteadora e cliente) estão no **mesmo Mac**: o cabo `127.0.0.1:12345` só funciona assim.

## 1. Conferir as VMs no UTM

Só edite com a VM **desligada** (*Edit → QEMU → Arguments*, um argumento por item).

| VM | Network (painel do UTM) | Arguments |
|---|---|---|
| Roteadora | 1 placa **Shared** (vira `vtnet0`, WAN) | `-netdev socket,id=lan0,listen=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:01` |
| Cliente | **nenhuma** placa | `-netdev socket,id=lan0,connect=127.0.0.1:12345`<br>`-device virtio-net-pci,netdev=lan0,mac=52:54:00:4c:41:10` |

- **Ligue sempre a roteadora primeiro**: ela é o lado `listen`.
- Na roteadora, `ifconfig -l` deve mostrar `vtnet0 vtnet1 lo0`.
- Anote o IP WAN da roteadora (`ifconfig vtnet0`) e o gateway (`netstat -rn -f inet | grep default`). No Mac do Mateus são `192.168.64.2` e `192.168.64.1`; no seu podem ser outros. Abaixo, `<IP_WAN>` e `<GW_WAN>`.

## 2. Preparar as VMs

1. **Root sem senha** (só em VM de teste), na **roteadora e no cliente**:
   ```sh
   su -
   env ASSUME_ALWAYS_YES=yes pkg bootstrap
   pkg install -y doas
   echo "permit nopass <seu_usuario>" > /usr/local/etc/doas.conf
   exit
   ```
   O cliente precisa de internet para o `pkg`. Se ainda não tiver (antes do NAT), instale o `doas` nele depois da seção 3, ou use `su -` no lugar de `doas`.
2. **Chave SSH** (opcional, evita digitar senha): no Mac, `ssh-copy-id <usuario>@<IP_WAN>`.
3. **Copiar o projeto para a roteadora**. No Mac, **na pasta que contém `trab02_frc`**; o `COPYFILE_DISABLE=1` evita arquivos `._*` do macOS:
   ```sh
   COPYFILE_DISABLE=1 tar --exclude .git -czf - trab02_frc | ssh <usuario>@<IP_WAN> 'tar -xzf - -C ~'
   ```
4. **Criar o `config/lab.env`** na roteadora (não vai para o Git):
   ```sh
   cd ~/trab02_frc
   sed -e 's|^WAN_IP=.*|WAN_IP=DHCP|' -e 's|^WAN_GATEWAY=.*|WAN_GATEWAY=<GW_WAN>|' \
       -e 's|^DNS_IP=.*|DNS_IP=<GW_WAN>|' config/lab.env.example > config/lab.env
   ```
   Os scripts recusam valores com `X` ou `Y`.

## 3. Aplicar na roteadora, em ordem

```sh
cd ~/trab02_frc
doas sh scripts/01-setup-network.sh     # LAN 10.20.0.1/16, forwarding, rc.conf
doas sh scripts/03-setup-dhcp.sh        # dnsmasq (DHCP + reserva)
doas sh -c "nohup sh scripts/02-setup-firewall.sh > /tmp/pf-apply.log 2>&1 &"
cat /tmp/pf-apply.log
```

- O script 01 **sobrescreve** a configuração feita à mão (`ifconfig_vtnet1`, `gateway_enable`). Backup em `/etc/rc.conf.bak.<data>`.
- O PF vai com `nohup` porque a sessão SSH aberta **pode cair** quando ele liga. Reconecte e leia o log.

**Verificar:**
- [ ] `ifconfig vtnet1` → `inet 10.20.0.1 netmask 0xffff0000`
- [ ] `sysctl net.inet.ip.forwarding` → `1`
- [ ] `doas pfctl -sn` → `nat on vtnet0 ... -> (vtnet0)` e `rdr on vtnet0 ... port = http tag DNAT -> 10.20.0.10 port 8080`
- [ ] `doas pfctl -sr` → `block drop in on vtnet0 all` e `pass in on vtnet0 ... port = http-alt ... tagged DNAT`
- [ ] Depois de `doas shutdown -r now`, tudo continua igual (persistência)

## 4. Cliente

1. Pegar o IP reservado: `doas dhclient vtnet0` → `bound to 10.20.0.10`.
2. Acessar do Mac **passando pela roteadora**:
   ```sh
   ssh -o ConnectTimeout=40 -o StrictHostKeyChecking=accept-new -J <usuario>@<IP_WAN> <usuario>@10.20.0.10
   ```
3. Levar o servidor TCP para o cliente (se ele não tiver o projeto):
   ```sh
   scp -o ConnectTimeout=40 -J <usuario>@<IP_WAN> trab02_frc/tests/tcp-server.sh <usuario>@10.20.0.10:
   ```

## 5. Testes

| Teste | Onde | Resultado esperado |
|---|---|---|
| 01 | Roteador e cliente | Cliente com `10.20.0.10/16`, gateway `10.20.0.1`; pinga `10.20.0.1`. Com o PF já ligado, o ping para `<GW_WAN>` **responde** (sem PF, falharia: falta NAT) |
| 02 | Cliente + `tcpdump -l` no roteador | Ping/`fetch` para fora OK; `vtnet1` mostra origem `10.20.0.10`, `vtnet0` mostra `<IP_WAN>`; `doas pfctl -ss` mostra `<IP_WAN>:porta (10.20.0.10:porta) -> destino` |
| 05 | Cliente: `sh tcp-server.sh 8080`<br>Mac: `nc -v <IP_WAN> 80` | Mac recebe `OK <hostname> ... porta 8080`; o texto digitado no Mac aparece no terminal do **servidor** (não volta ecoado) |
| 03 sem rota | Mac | `nc -vz -G 3 -w 3 <IP_WAN> 8080` → **timeout**; `nc -vz -G 3 <IP_WAN> 80` → conecta |
| 03 com rota | Mac (exige `sudo`) | Ver abaixo |

**Teste 03 com rota** (simula um host WAN que conhece o caminho para a LAN):

```sh
netstat -rn -f inet | grep 10.20                         # se aparecer "10.20.0.10 ... bridge100", apague:
sudo route -n delete 10.20.0.10 -ifscope bridge100        # (alternativa: sudo arp -d 10.20.0.10 ifscope bridge100)
sudo route add -net 10.20.0.0/16 <IP_WAN>
route -n get 10.20.0.10 | grep gateway                    # deve mostrar <IP_WAN>

ping -c 3 10.20.0.10                  # 100% perda
nc -vz -G 3 -w 3 10.20.0.10 8080      # timeout (direto, sem passar pela porta 80)
nc -vz -G 3 -w 3 10.20.0.10 22        # timeout
nc -vz -G 3 -w 3 <IP_WAN> 80          # conecta (exceção do DNAT)

sudo route delete -net 10.20.0.0/16   # desfazer ao final
```

Na roteadora, durante o teste: `doas tcpdump -l -ni vtnet1 host <GW_WAN>` deve mostrar **só** a conexão da porta 80 → `10.20.0.10:8080`.

**Ainda falta (para ninguém):** repetir o teste 04 com o PF ligado e repetir tudo depois de reiniciar as duas VMs.

## 6. Problemas encontrados

| Sintoma | Causa | Solução |
|---|---|---|
| A VM só tem `vtnet0` | Faltam os argumentos QEMU | Seção 1 |
| `sudo: not found` | FreeBSD não vem com sudo | `doas` (seção 2) |
| `pkg: pkg is not installed` | FreeBSD novo | `pkg bootstrap` |
| Cliente pega `10.20.0.10` e minutos depois perde ("My address ... was deleted, dhclient exiting") | Cliente ligou **antes** do DHCP; sobraram dois `dhclient` brigando | No cliente: `doas dhclient vtnet0` |
| Cliente sem IPv4 logo após `service netif restart` | O `dhclient` roda em segundo plano | Espere uns segundos ou `doas dhclient vtnet0` |
| SSH no cliente: "Connection timed out during banner exchange" | O sshd do cliente demora ~15 s para responder | `-o ConnectTimeout=40` |
| "Host key verification failed" em `10.20.0.10` | Primeiro acesso em modo não interativo | `-o StrictHostKeyChecking=accept-new` |
| Sessão SSH cai ao ligar o PF | A conexão aberta não tem estado no PF | `nohup` e reconectar |
| `scp` de `/etc/pf.conf`: Permission denied | Arquivo com permissão `600` | `ssh ... 'doas cat /etc/pf.conf'` |
| `nc` na porta 8080 dá timeout, não "recusado" | `set block-policy drop` | Esperado (`tests/03` ajustado) |
| `nc -w 3` no Mac fica pendurado | No macOS, `-w` não limita o tempo de conexão | Use `-G 3` |
| `tcpdump` com `timeout` grava arquivo vazio | Saída em buffer, perdida quando o `timeout` mata o processo | `tcpdump -l` |
| Teste 03 com rota: o Mac faz `ARP who-has 10.20.0.10` em vez de mandar para a roteadora | Rota velha `10.20.0.10 ... bridge100` presa à interface; `route delete` simples não apaga | `sudo route -n delete 10.20.0.10 -ifscope bridge100` |
| Mexer no UTM pelo terminal (`utmctl`) | O macOS bloqueia sem permissão de Automação | Fazer pela tela do UTM |

## 7. Decisões já tomadas

- **Ping da LAN para fora é permitido.** O isolamento é só de fora para dentro (WAN → LAN). `tests/03` e `docs/validacao.md` foram ajustados.
- **DNAT com `tag`.** A primeira versão liberava `10.20.0.10:8080` para qualquer pacote vindo da WAN, e o teste 03 com rota mostrou acesso direto sem passar pela porta 80. Agora o `rdr` marca o pacote (`tag DNAT`) e só o marcado passa (`tagged DNAT`).
- O teste integrado oficial roda no Mac do Mateus. Repetir em outro Mac serve como ensaio.
- Em aberto com o professor: valor de X, se aceita VM no LDS e qual DNS usar.
- Em aberto na dupla: juntar `feature/rede-pf` na `main` e a linha `Co-Authored-By` no commit `e8d8275`.

# Teste 05 — DNAT TCP 80 (WAN) → 10.20.0.10:8080 (LAN)

Conexão feita de **outro host na WAN** à porta 80 do roteador chega ao servidor TCP do cliente reservado na porta 8080.

## Passos

1. Cliente reservado (deve estar com `10.20.0.10`, Teste 04):
   ```sh
   sh tests/tcp-server.sh 8080
   ```
   Conferir local: `sockstat -4 -l | grep 8080` (FreeBSD) ou `ss -ltn` (Linux).
2. Roteador, em outro terminal:
   ```sh
   pfctl -sn | grep rdr           # rdr ... port 80 -> 10.20.0.10 port 8080
   tcpdump -ni $LAN_IF port 8080
   ```
3. Host WAN de teste (não pode ser o roteador nem um host da LAN):
   ```sh
   nc -v 192.168.X.Y 80           # ou: telnet 192.168.X.Y 80
   ```
   Digitar `ola` e Enter.

## Esperado

| Onde | Evidência |
|---|---|
| host WAN | `Connection to 192.168.X.Y 80 port [tcp/http] succeeded!` e a linha `OK <hostname do cliente> <data> porta 8080` |
| servidor LAN | o texto digitado no host WAN aparece no terminal do servidor (o servidor não ecoa de volta: o que se digita no terminal do servidor é que vai para o host WAN) |
| `tcpdump` LAN | `192.168.X.Z.porta > 10.20.0.10.8080` (destino reescrito pelo DNAT) |
| `pfctl -ss` | estado `192.168.X.Z -> 192.168.X.Y:80 -> 10.20.0.10:8080` |

## Por que testar de fora

Da LAN ou do próprio roteador o pacote não entra por `$WAN_IF`, então a regra `rdr on $WAN_IF` não dispara. Em desenvolvimento o host WAN é o Mac (rede Shared do UTM); no LDS, outra máquina da rede `192.168.X.0/24`.

## Falhas comuns

- `nc` conecta mas sem resposta: servidor não está escutando em `0.0.0.0:8080` ou PF não permite `pass in on $LAN_IF ... port 8080` após o redirect.
- Conexão recusada: `rdr` ausente ou cliente não está com `10.20.0.10`.

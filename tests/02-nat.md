# Teste 02 — NAT (tradução de endereços)

Prova que o tráfego da LAN sai pela WAN com o IP do roteador.

## Passos

1. No roteador, capturar nas duas interfaces (dois terminais):
   ```sh
   tcpdump -ni $LAN_IF 'host 10.20.0.0/16 and not port 67 and not port 68'
   tcpdump -ni $WAN_IF 'host 192.168.X.1 or port 443'
   ```
2. No cliente LAN, gerar tráfego:
   ```sh
   ping -c 3 192.168.X.1
   curl -sI https://www.freebsd.org/ | head -1     # plano B se ICMP for bloqueado
   ```
3. No roteador, listar regras e estados do NAT:
   ```sh
   pfctl -sn
   pfctl -ss | grep 10.20.0.
   ```

## Esperado

| Onde | Evidência |
|---|---|
| `tcpdump` na LAN | origem `10.20.0.x` |
| `tcpdump` na WAN | origem `192.168.X.Y` (IP WAN do roteador), nunca `10.20.0.x` |
| `pfctl -ss` | estado `10.20.0.x:porta -> 192.168.X.Y:porta -> destino` |
| cliente | ping/curl respondem |

## Falha

Se a WAN mostrar origem `10.20.0.x`, a regra `nat on $WAN_IF` não casou; conferir `pfctl -sn` e `pfctl -nf /etc/pf.conf`.

# Limitações conhecidas

- **Virtualização.** O roteador roda em FreeBSD 15.1 sob UTM/QEMU (Apple Silicon). O enunciado diz que o segmento não pode ser implantado em ambiente virtualizado; é preciso confirmar com o professor o formato aceito e, se necessário, levar o roteador em hardware ou usar bridge para a rede cabeada do LDS.
- **WAN em bridge.** Em desenvolvimento a WAN é a rede Shared do UTM (`192.168.64.0/24`), não `192.168.X.0/24`. O modo Bridged exige adaptador Ethernet no Mac e deve ser ensaiado antes do dia da validação.
- **ICMP bloqueado por redes externas.** Algumas redes descartam ping; os testes trazem plano B por TCP (`fetch`, `curl`, `nc`) com `tcpdump` para não confundir bloqueio da rede com falha do NAT.
- **DNAT só é testável de fora.** A regra `rdr on $WAN_IF` não dispara para conexões vindas da LAN ou do próprio roteador; o teste precisa de um host distinto na WAN.
- **Reserva por MAC.** Se o cliente reservado trocar de placa (ou o virtualizador gerar novo MAC), ele passa a receber IP do pool e o DNAT deixa de alcançá-lo; atualizar `RESERVED_MAC` e reexecutar `03-setup-dhcp.sh`.
- **DHCP do virtualizador.** Redes Host-Only/Shared do UTM têm DHCP próprio do macOS. Em desenvolvimento a LAN foi montada como um link QEMU ponto a ponto em loopback (roteador `-netdev socket,listen=127.0.0.1:12345`, cliente `connect=127.0.0.1:12345`, em *QEMU → Arguments* do UTM), sem nenhum DHCP do host. O modo `mcast` do QEMU não funciona no UTM (sandbox do macOS bloqueia multicast). Consequência: o roteador deve ser ligado antes do cliente e só um cliente cabe nesse link; no LDS a LAN é um switch físico.
- **Um servidor TCP simples.** `tests/tcp-server.sh` atende uma conexão por vez (netcat em loop); serve para demonstrar o DNAT, não para carga.
- **Sem IPv6.** Toda a configuração é IPv4; `ip6` não é tratado pelo NAT nem pelo DHCP.

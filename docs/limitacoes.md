# Limitações conhecidas

## Ambiente

- **Virtualização.** O roteador e o cliente foram desenvolvidos e testados como VMs FreeBSD 15.1 no UTM/QEMU, num Mac Apple Silicon. O enunciado não trata de virtualização; ele só limita o escore por sistema operacional (*BSD 100%). Falta confirmar com o professor se a demonstração no LDS pode ser feita nesse formato ou se deve usar equipamento do laboratório.
- **WAN de desenvolvimento.** Nos testes, a WAN foi a rede *Shared* do UTM (`192.168.64.0/24`, gateway `192.168.64.1`), no papel de `192.168.X.0/24`. No LDS, a placa WAN da VM precisa estar em modo *Bridged* ligado à rede cabeada (o que pode exigir adaptador Ethernet no Mac), com `WAN_IP` e `WAN_GATEWAY` reais em `config/lab.env`. Essa ligação ainda não foi ensaiada.
- **Valores do laboratório.** O valor de `X`, o IP WAN do roteador e o DNS a entregar (`192.168.X.1`, `164.41.101.4` ou `164.41.101.11`) dependem do professor. Os scripts recusam `config/lab.env` com valores de exemplo (`X`/`Y`).

## LAN no UTM

- **Um cliente por link.** As redes *Host Only* e *Shared* do UTM trazem um DHCP do macOS, que disputaria com o dnsmasq. Por isso a LAN de desenvolvimento é um link QEMU ponto a ponto em loopback (`-netdev socket`, `listen`/`connect` em `127.0.0.1:12345`, ver `docs/arquitetura.md`). Esse link só liga **duas** VMs, ambas no mesmo Mac. O modo `mcast` do QEMU, que permitiria mais VMs, é bloqueado pelo sandbox do macOS. No LDS, a LAN seria um switch físico.
- **Cliente comum simulado.** Com um só cliente, a concessão do pool (teste 04 A) foi demonstrada trocando o MAC do cliente reservado por alguns segundos (`52:54:00:4c:41:99` recebeu `10.20.0.126`).
- **Ordem de inicialização.** A VM roteadora (`listen`) precisa ser ligada antes da cliente (`connect`). Se o cliente ligar antes de o DHCP estar no ar, um `dhclient` antigo pode apagar o endereço depois; resolve com `dhclient vtnet0` no cliente.

## Política do firewall

- **Administração do roteador pela WAN.** SSH (TCP 22) e ping no IP WAN do **próprio roteador** são aceitos, para administração e diagnóstico. Não dão acesso à LAN. Em uma rede hostil, restringir a origem dessas regras ou removê-las.
- **Saída da LAN sem restrição.** Tudo que a LAN inicia (inclusive ping) sai pelo NAT. O isolamento pedido pelo enunciado é de fora para dentro.
- **Bloqueio silencioso.** `set block-policy drop`: tentativas bloqueadas dão *timeout*, não "conexão recusada".
- **DNAT para um único IP.** O redirecionamento aponta para `RESERVED_IP`. Se o cliente reservado trocar de placa (ou o virtualizador gerar outro MAC), ele passa a receber IP do pool e o DNAT deixa de alcançá-lo; é preciso atualizar `RESERVED_MAC` e rodar `03-setup-dhcp.sh` de novo.
- **DNAT só é testável de fora.** A regra `rdr on $WAN_IF` não dispara para conexões vindas da LAN ou do próprio roteador (não há *hairpin NAT*). O teste exige um host distinto na WAN.
- **Ativação por SSH.** A sessão SSH aberta pode cair no instante em que o PF liga, porque ela não tem estado na tabela. `apply.sh` e `02-setup-firewall.sh` usam `nohup`; basta reconectar.

## Serviços e escopo

- **Sem IPv6.** Toda a configuração é IPv4. O PF bloqueia entradas IPv6 pela WAN (`block in on $WAN_IF all`), mas não há NAT, DHCPv6 nem anúncio de rotas IPv6 na LAN.
- **DNS não é servido pelo roteador.** O dnsmasq roda com `port=0` (só DHCP); os clientes usam `DNS_IP`, que precisa ser alcançável pelo NAT.
- **Servidor TCP simples.** `tests/tcp-server.sh` atende uma conexão por vez (netcat em loop) e não sobe sozinho após reiniciar o cliente. Serve para demonstrar o DNAT, não para carga.
- **ICMP bloqueado por redes externas.** Algumas redes descartam ping; os roteiros trazem plano B por TCP (`fetch`, `curl`, `nc`) e `tcpdump`, para não confundir bloqueio da rede com falha do NAT.
- **`rollback.sh` é parcial.** Desliga PF, dnsmasq, a LAN e o repasse de pacotes, mas mantém a WAN, os pacotes instalados e os arquivos de configuração (com backups `.bak.<data>`), para que `apply.sh` reconstrua tudo.
- **`doas` sem senha.** Na VM de desenvolvimento, o usuário administrador usa `doas` com `nopass`. No laboratório, rodar os scripts como root.

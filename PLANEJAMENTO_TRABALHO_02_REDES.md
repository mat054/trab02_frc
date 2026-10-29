# Planejamento — Trabalho 02: NAT + DHCP + DNAT

**Disciplina:** Fundamentos de Redes de Computadores  
**Plataforma proposta:** FreeBSD em VM UTM (desenvolvimento no VS Code do macOS)  
**Equipe:** 2 integrantes  
**Objetivo:** configurar um roteador com WAN na rede do laboratório `192.168.X.0/24` (gateway `192.168.X.1`) e LAN privada `/16`, com NAT, DHCP, reserva de IP e DNAT TCP `80 -> 8080`; entregar scripts, documentação e evidências reproduzíveis.

> **Origem dos requisitos:** enunciado `trabalho_02_v5.pdf`, pp. 1–3. As escolhas por FreeBSD, PF, dnsmasq, organização do repositório e endereços ilustrativos abaixo são decisões de projeto, não imposições do enunciado.

## 1. Escopo e critérios de aceitação

| ID | Requisito | Demonstração de aceite |
|---|---|---|
| R01 | Roteador com WAN conectada à rede `192.168.X.0/24` | `ifconfig`, `netstat -rn`, comunicação com gateway `192.168.X.1` |
| R02 | LAN com máscara `/16` em faixa privada | Cliente e roteador mostram IP/máscara corretos |
| R03 | Encaminhamento IPv4 entre interfaces | `sysctl net.inet.ip.forwarding` retorna `1`; tráfego passa conforme política |
| R04 | NAT de saída LAN → WAN | Captura na WAN mostra IP de origem traduzido; estado/regras do PF corroboram |
| R05 | Isolamento da LAN | Teste negativo WAN → cliente sem regra explícita é bloqueado; exceção DNAT funciona |
| R06 | DHCP automático na LAN | Cliente recebe IP, máscara `/16`, gateway e DNS corretamente |
| R07 | Reserva DHCP para máquina específica | Mesmo MAC recebe o mesmo IP após renovação |
| R08 | Registros de concessões DHCP | Arquivo de *leases* e logs mostram os eventos relevantes |
| R09 | DNAT TCP 80 (WAN) → 8080 (LAN) | Cliente na WAN conecta à porta 80 do roteador e alcança servidor TCP 8080 na LAN |
| R10 | Procedimentos reproduzíveis e ZIP | Instalação, validação, limitações e evidências são documentadas; arquivos de configuração passam na verificação de sintaxe; demonstração presencial preparada |

**Pesos informados no enunciado:** documentação 30%, validação presencial 70%. Limites de escore indicados: *BSD 100%, Linux 90%, outros 70%. Derivações de *BSD ou Linux com pacotes para configuração rápida de gateway (por exemplo, distribuições de firewall/roteador prontas) entram em "outros" (70%); configurar PF, dnsmasq e roteamento manualmente em FreeBSD puro evita esse enquadramento. Confirmar com o professor que FreeBSD virtualizado é aceito e qual equipamento será usado na avaliação.

### Requisitos de entrega e avaliação (enunciado)

| Item do enunciado | Como o projeto atende |
|---|---|
| Submissão no ponto de coleta do **Sigaa ou Office365**; um pacote **ZIP** por grupo, com a documentação | `entrega/checklist.md` registra o canal confirmado e a montagem do ZIP |
| **Documentação mínima do script/roteiro de configuração (30%)**, com cinco tópicos: (a) SO usado, (b) aplicações demandadas na LAN, (c) como implementar a LAN, (d) como validar a configuração, (e) limitações conhecidas | (a) `README.md`; (b) `docs/arquitetura.md`; (c) `docs/instalacao.md` e `scripts/`; (d) `docs/validacao.md` e `tests/`; (e) `docs/limitacoes.md` |
| **Lista de testes necessários**: validar conectividade, tradução de endereço (NAT) e isolamento de segmento (NAT) | `tests/01` a `tests/03` e tabela da Fase 3, consolidadas em `docs/validacao.md` |
| **Arquivos de configuração com erro de interpretação são anulados** | Validar sintaxe antes de entregar (`pfctl -nf`, `dnsmasq --test`, `sh -n`) e incluir no ZIP, além dos templates, cópias renderizadas sem marcadores de substituição |
| **Testes de validação executados na presença do professor (70%)** | Ensaio completo na Fase 4; demonstração de NAT, DHCP e DNAT |
| **Validação da documentação no LDS**, "em momento oportuno" | Documentação reproduzível por quem não participou do projeto; confirmar data e ambiente com o professor |
| Trabalho em **dupla**; cópia ou plágio provocam anulação de todos os artefatos (em recorrência) | Autoria própria; citar as referências usadas |

## 2. Arquitetura planejada

```text
REDE DO LABORATÓRIO / WAN: 192.168.X.0/24
Gateway existente: 192.168.X.1
          |
   WAN (ex.: 192.168.X.Y)
   +---------------------------+
   | VM FreeBSD — roteador     |
   | Encaminhamento IPv4       |
   | PF: NAT + firewall + DNAT |
   | dnsmasq: DHCP             |
   +---------------------------+
   LAN (ex.: 10.20.0.1/16)
          |
    REDE LAN: 10.20.0.0/16
      |                 |
  Cliente comum     Cliente reservado
  DHCP dinâmico     10.20.0.10/16
                    Servidor TCP :8080

Host separado na WAN testa conexão em 192.168.X.Y:80.
```

### Variáveis de ambiente (valores propostos)

| Variável | Exemplo | Observação |
|---|---|---|
| `WAN_IF` | `vtnet0` | Confirmar com `ifconfig`; pode ser outro nome |
| `LAN_IF` | `vtnet1` | Interface virtual dedicada à LAN |
| `WAN_IP` | `192.168.X.Y` | Valor autorizado/disponibilizado no laboratório |
| `WAN_GATEWAY` | `192.168.X.1` | Dado pelo enunciado |
| `LAN_IP` | `10.20.0.1` | Sugestão, não obrigação |
| `LAN_CIDR` | `10.20.0.0/16` | Faixa privada que atende à máscara solicitada |
| `DHCP_START` / `DHCP_END` | `10.20.0.100` / `10.20.0.200` | Faixa dinâmica sugerida |
| `RESERVED_IP` | `10.20.0.10` | Fora da faixa dinâmica, mas dentro da LAN |
| `RESERVED_MAC` | `aa:bb:cc:dd:ee:ff` | Exemplo fictício; substituir pelo MAC real |
| `DNS_IP` | `192.168.X.1` | Alternativas do enunciado: `164.41.101.4` e `164.41.101.11` |
| `DNAT_WAN_PORT` / `DNAT_LAN_PORT` | `80` / `8080` | Valores obrigatórios |

**Faixa da LAN:** o enunciado pede uma sub-rede `/16` dentro das faixas reservadas para uso privado (RFC 1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`). Evitar `192.168.0.0/16`, que contém a WAN `192.168.X.0/24` e geraria sobreposição de rotas.

**Nota de infraestrutura:** no UTM, a WAN de laboratório não aparece automaticamente: uma WAN *Shared Network* do UTM pode ter outra faixa IP. Para a validação com `192.168.X.0/24`, será preciso ajustar a ligação à rede física (bridge/adaptador, conforme suporte e autorização; o enunciado descreve a rede de acesso como cabeada, então confirmar se a ponte do UTM funciona com a interface disponível, o que pode exigir um adaptador Ethernet) ou utilizar o ambiente indicado pelo professor. Nunca executar DHCP na rede WAN do laboratório: vincular o serviço exclusivamente à LAN.

## 3. Escolhas técnicas

- **SO:** FreeBSD, versão e arquitetura registradas no README.
- **Firewall/NAT/DNAT:** PF, com regras em `config/pf.conf.template` e verificação por `pfctl -nf` antes de aplicar. A política de isolamento será explícita, pois NAT por si só não substitui firewall.
- **DHCP:** dnsmasq, com `config/dnsmasq.conf.template`, escuta restrita à LAN, reserva por MAC, *leases* e `log-dhcp`; o DNS entregue aos clientes deve ser `DNS_IP` (opção DHCP 6), pois por padrão o dnsmasq anuncia o próprio endereço como DNS quando seu serviço de DNS está ativo (avaliar `port=0`). Registrar o caminho efetivo do arquivo de *leases* e dos logs. Pode-se definir `dhcp-leasefile` explicitamente para evitar ambiguidade.
- **Automação:** scripts POSIX `sh`, compatíveis com FreeBSD, com parâmetros em `config/lab.env` criado a partir do exemplo; scripts devem validar privilégios, interfaces e variáveis antes de modificar o sistema.
- **Versionamento:** Git, pequenas branches de funcionalidade, revisões cruzadas e nenhum segredo/IP real sensível commitado por acidente.
- **Cliente de testes:** outra VM na LAN; uma terceira máquina/VM no lado WAN para testar o DNAT externamente.

## 4. Estrutura do repositório

```text
trabalho-02-redes/
├── README.md                         # Visão geral, requisitos e execução rápida
├── PLANEJAMENTO.md                   # Este plano, marcos e responsáveis
├── .gitignore                        # lab.env, logs, capturas temporárias, segredos
├── config/
│   ├── lab.env.example               # Parâmetros de WAN, LAN, DHCP e DNAT
│   ├── pf.conf.template              # Regras PF: NAT, isolamento e DNAT
│   └── dnsmasq.conf.template         # Pool, DNS, gateway, reserva, logs/leases
├── scripts/
│   ├── 00-check-prerequisites.sh      # FreeBSD, root, interfaces, dependências
│   ├── 01-setup-network.sh            # WAN/LAN, gateway e ip.forwarding
│   ├── 02-setup-firewall.sh           # Renderizar, validar, aplicar PF
│   ├── 03-setup-dhcp.sh               # Instalar/configurar/iniciar dnsmasq
│   ├── apply.sh                       # Orquestrar em ordem segura
│   ├── status.sh                      # Exibir interfaces, serviços, regras
│   └── rollback.sh                    # Reverter mudanças documentadas
├── tests/
│   ├── 01-connectivity.md             # Testes do roteador e cliente
│   ├── 02-nat.md                      # Tráfego, tradução, captura e estados PF
│   ├── 03-isolation.md                # Negativos WAN -> LAN e exceções
│   ├── 04-dhcp.md                     # Oferta, renovação, reserva e logs
│   ├── 05-dnat.md                     # Netcat TCP 8080; acesso externo TCP 80
│   ├── tcp-server.sh                  # Exemplo de servidor TCP para o cliente LAN
│   └── collect-evidence.sh            # Captura saídas e metadados sem segredos
├── docs/
│   ├── arquitetura.md                 # Diagrama, interfaces, sub-redes, fluxos
│   ├── instalacao.md                  # Instalação FreeBSD, pacotes e provisionamento
│   ├── validacao.md                   # Procedimento completo de demonstração
│   ├── limitacoes.md                  # Virtualização, acesso WAN, riscos e hipóteses
│   └── evidencias/
│       └── .gitkeep                    # Saídas, logs recortados, imagens ou pcaps
└── entrega/
    ├── checklist.md                   # Arquivos obrigatórios e montagem do ZIP
    └── config-renderizada/            # pf.conf e dnsmasq.conf finais, gerados pelos scripts, para conferir sintaxe
```

**Local da configuração ativa no FreeBSD:** scripts copiam/geram arquivos finais, conforme o sistema instalado, em `/etc/pf.conf` (PF) e `/usr/local/etc/dnsmasq.conf` (dnsmasq); o Git armazena as **templates**, e não pretende que o sistema execute arquivos diretamente do repositório. Os scripts devem preservar backup dos arquivos substituídos.

## 5. Fases e entregáveis

### Fase 0 — Acordo e ambiente (conjunta)

1. Ler o enunciado e confirmar com o professor critérios de VM, laboratório, acesso WAN e forma de demonstração, além do valor de `X`, do DNS a usar, do canal de submissão (Sigaa ou Office365) e de quando e onde a documentação será validada (LDS).
2. Criar o repositório Git e o `lab.env.example`; registrar FreeBSD e arquitetura.
3. Criar VM FreeBSD roteadora com duas NICs; criar uma VM cliente na LAN e definir como testar a partir da WAN.
4. Fixar contrato de IPs, interfaces, DHCP e portas antes do trabalho paralelo.

**Aceite:** ambas as pessoas compreendem a topologia, conseguem acessar a VM e conhecem as variáveis do projeto.

### Fase 1 — Rede básica e roteamento (Pessoa A)

1. Identificar interfaces físicas/virtuais e configurar WAN e LAN sem sobreposição.
2. Definir rota padrão `192.168.X.1` **no laboratório**, ou gateway equivalente **na rede virtual**.
3. Ativar encaminhamento IPv4, inclusive após reinicialização.
4. Validar conectividade do roteador com o gateway e comunicação cliente ↔ LAN do roteador.

**Aceite:** interfaces e rotas comprovadas; `net.inet.ip.forwarding=1`.

### Fase 2A — NAT, política de isolamento e DNAT (Pessoa A)

1. Criar `pf.conf.template` com NAT de saída da LAN para a WAN.
2. Estabelecer política de filtragem com retorno de conexões legítimas e bloqueio de acesso indevido WAN → LAN.
3. Criar exceção DNAT para `WAN:80 → 10.20.0.10:8080`, alinhada à reserva DHCP da Pessoa B.
4. Verificar sintaxe antes de carregar PF; preservar acesso por console/SSH e backup.
5. Registrar comandos de inspeção (`pfctl`, `tcpdump`) e o resultado esperado.

**Aceite:** NAT observável na WAN; acesso inesperado de fora bloqueado; DNAT definido e apto a teste.

### Fase 2B — DHCP e reserva (Pessoa B)

1. Instalar/configurar dnsmasq para escutar apenas na interface LAN.
2. Definir pool dinâmico, máscara `/16`, gateway `10.20.0.1` e DNS permitido pelo enunciado.
3. Reservar `10.20.0.10` pelo MAC real do cliente do serviço TCP.
4. Registrar *leases* e eventos de DHCP; documentar como consultar ambos.
5. Renovar concessão do cliente e conferir IP, máscara, rota e DNS.

**Aceite:** cliente recebe configuração automática e o dispositivo reservado mantém o IP após renovar.

### Fase 3 — Testes integrados (conjunta)

| Teste | Onde executar | Evidência |
|---|---|---|
| Conectividade | Roteador e cliente LAN | IPs, rotas, `ping` para gateway e roteador |
| NAT | Cliente LAN + observação na WAN do roteador | Captura com origem traduzida e estado PF |
| Isolamento | Host WAN tentando alcançar LAN diretamente | Tentativa não autorizada falha; regra PF explica bloqueio |
| DHCP | Cliente LAN + roteador | Configuração recebida, concessão e logs |
| Reserva DHCP | Cliente com MAC conhecido | Mesmo IP após renovação |
| DNS recebido | Cliente LAN | `nslookup`/`dig` resolve nomes usando o DNS entregue pelo DHCP, passando pelo NAT |
| DNAT | Servidor na LAN em `:8080` e cliente externo na WAN | Conexão TCP bem-sucedida ao IP WAN em `:80` |
| Reboot/reprodutibilidade | Roteador | Serviços voltam, configurações persistem |

No DNAT, usar `netcat`/`telnet`, conforme o enunciado. O tráfego de retorno do servidor precisa passar pelo roteador. Diferenciar **testes negativos de firewall** de **testes de tradução NAT**: um não comprova automaticamente o outro.

### Fase 4 — Documentação, ensaio e entrega (conjunta)

1. Revisar README, arquitetura, instalação e limitações com os comandos realmente validados.
2. Documentar cada teste: objetivo, ambiente, comando, resultado esperado, resultado observado e evidência.
3. Fazer ensaio completo sem depender de comandos improvisados; se possível, repetir a configuração em VM limpa.
4. Validar a sintaxe de todos os arquivos de configuração (`pfctl -nf`, `dnsmasq --test`, `sh -n`), pois arquivos com erro de interpretação são anulados, e gerar as cópias renderizadas em `entrega/config-renderizada/`.
5. Preparar ZIP contendo scripts, templates, cópias renderizadas, documentação e evidências permitidas; excluir `.git`, credenciais e arquivos temporários; enviar no Sigaa ou Office365.
6. Conferir que a documentação cobre os cinco tópicos mínimos do enunciado (SO, aplicações, implementação, validação e limitações) e que outra pessoa consegue reproduzi-la, pois será validada no LDS.
7. Confirmar que cada integrante sabe demonstrar NAT, DHCP e DNAT na presença do professor.

## 6. Organização do trabalho paralelo

| Área | Pessoa A — infraestrutura e PF | Pessoa B — DHCP e validação |
|---|---|---|
| Topologia/VM | Responsável | Revisão e criação do cliente de teste |
| WAN, LAN e IPv4 forwarding | Responsável | Testes de conectividade |
| NAT e isolamento | Responsável | Roteiros de testes e evidências |
| DNAT | Responsável pela regra PF | Servidor TCP e teste de ponta a ponta |
| DHCP, reserva e *leases* | Revisão de acesso via PF | Responsável |
| Scripts e templates | `01-*`, `02-*`, PF | `03-*`, DHCP, testes |
| Documentação | Arquitetura e instalação de rede | Validação, evidências e limitações |
| Integração e demonstração | Ambos | Ambos |

**Regra para evitar conflitos:** somente Pessoa A modifica `pf.conf.template`; somente Pessoa B modifica `dnsmasq.conf.template`. Mudanças que afetem o outro serviço são registradas em issue/PR e revisadas em conjunto.

**Dependências de integração:** antes das duas frentes em paralelo, alinhar `WAN_IF`, `LAN_IF`, `LAN_CIDR`, `RESERVED_IP`, `RESERVED_MAC` e as portas `80/8080`. A Pessoa B pode configurar DHCP e preparar os testes em LAN isolada enquanto a Pessoa A implementa PF. O teste real de DNAT só ocorre após o cliente reservado ter IP estável, o servidor estar escutando e a regra PF estar ativa.

**Git sugerido:** branches `feature/rede-pf` e `feature/dhcp-testes`, PRs com revisão cruzada, merge na `main` apenas após checagem de sintaxe e testes correspondentes. Ambos participam do ensaio final.

## 7. Cronograma por marcos (sem prazo fixo)

| Marco | Conclusão necessária | Pessoas |
|---|---|---|
| M0 | Repositório, VM, topologia e parâmetros acordados | A + B |
| M1 | WAN, LAN e roteamento básicos | A; B valida |
| M2 | NAT/PF e DHCP funcionando independentemente | A e B em paralelo |
| M3 | Reserva DHCP + DNAT + isolamento testados juntos | A + B |
| M4 | Evidências, documentação, roteiro de defesa e ZIP | A + B |

## 8. Cuidados e dúvidas para confirmar

- **Aceitação de VM e limites de pontuação:** o enunciado não especifica se a demonstração poderá ser virtualizada; perguntar ao professor.
- **Rede física do laboratório:** conhecer `X`, IP WAN atribuído e gateway real; confirmar como conectar duas NICs à topologia proposta.
- **Ambiente de avaliação:** identificar se a dupla levará computador próprio ou deverá reproduzir a configuração em máquina do laboratório.
- **Política de rede:** não ligar o DHCP à rede institucional; não publicar serviço além do necessário; obter autorização antes de alterar portas/firewall em redes compartilhadas.
- **Isolamento:** implementar política explícita de firewall; NAT sozinho não prova isolamento completo.
- **Portabilidade:** scripts POSIX shell não tornam as configurações portáveis para Linux; `pf` e caminhos de serviços exigem FreeBSD.
- **Configurações anuladas:** o enunciado desconsidera arquivos de configuração com erro de interpretação. Validar a sintaxe antes de cada ensaio e de cada entrega, e entregar também versões renderizadas, sem marcadores de substituição.
- **Validação da documentação no LDS:** o enunciado prevê testes da documentação "em momento oportuno". Confirmar data e ambiente com o professor e escrever os passos de modo que alguém sem contexto consiga reproduzi-los.
- **Submissão e autoria:** entregar o ZIP no Sigaa ou Office365. Cópia ou plágio anulam os artefatos, então manter o histórico Git e citar as referências usadas.
- **Derivações de SO:** não usar distribuições prontas de firewall/roteador baseadas em *BSD ou Linux, que entram na categoria de 70%.

## 9. Checklist final de aceite

- [ ] VM FreeBSD e interfaces documentadas.
- [ ] WAN e LAN `/16` corretas; rota padrão e encaminhamento IPv4 funcionando.
- [ ] NAT comprovado por observação e não apenas `ping`.
- [ ] Política de isolamento testada com tentativa negativa.
- [ ] DHCP fornece IP/máscara/gateway/DNS adequados.
- [ ] Reserva DHCP e arquivos/logs de *leases* conferidos.
- [ ] DNAT WAN TCP 80 → LAN TCP 8080 demonstrado com `netcat`/`telnet` de outro host na WAN.
- [ ] Serviços persistem após reiniciar a VM.
- [ ] Scripts validados, seguros para repetição ou com limitações explicitadas; backups e reversão documentados.
- [ ] Documentação cobre SO, aplicações, implantação, validação e limitações, e inclui a lista de testes (conectividade, NAT e isolamento).
- [ ] Todos os arquivos de configuração passam na verificação de sintaxe e o ZIP inclui as cópias renderizadas.
- [ ] ZIP montado e enviado no Sigaa ou Office365, e ambos conseguem realizar a apresentação prática.

## Referências técnicas sugeridas

- FreeBSD Handbook, **Firewalls / PF**: https://docs.freebsd.org/en/books/handbook/firewalls/
- FreeBSD Handbook, **Advanced Networking**: https://docs.freebsd.org/en/books/handbook/advanced-networking/
- Documentação do **dnsmasq**: https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html

Referências teóricas indicadas no enunciado:

- Wright, Gary R., and W. Richard Stevens. *TCP/IP Illustrated, Vol. 2*. Addison-Wesley Professional, 1995.
- Lucas, Michael W. *Networking for System Administrators*. 2nd ed., Tilted Windmill Press, 2025.

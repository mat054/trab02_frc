# Divisão do planejamento

**Projeto:** Trabalho 02 — Fundamentos de Redes de Computadores (NAT + DHCP + DNAT)  
**Documento-base:** [PLANEJAMENTO_TRABALHO_02_REDES.md](./PLANEJAMENTO_TRABALHO_02_REDES.md)

O desenvolvimento será dividido entre duas pessoas, alternando períodos de trabalho paralelo com etapas de integração. Mateus ficará concentrado principalmente na infraestrutura de rede e no PF (roteamento, NAT, isolamento e DNAT), enquanto Luiza cuidará do DHCP com reserva de IP, dos clientes e da validação. As etapas iniciais, a integração dos serviços e a validação final serão realizadas em conjunto para evitar incompatibilidades entre os componentes.

Este documento define **quem implementa cada parte**, **quais arquivos cada integrante entrega**, **quando as atividades podem ocorrer em paralelo** e **como integrar os resultados**. Ele complementa o planejamento principal e não substitui os requisitos nem os critérios de aceite definidos nele.

> **Convenção:** **Mateus = infraestrutura, roteamento e PF**; **Luiza = DHCP, clientes e validação**. As fases usam a mesma numeração da [seção 5 do planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#5-fases-e-entregáveis), e os marcos M0–M4 correspondem à [seção 7](./PLANEJAMENTO_TRABALHO_02_REDES.md#7-cronograma-por-marcos-sem-prazo-fixo).

| Momento | Mateus | Luiza | Situação |
|---|---|---|---|
| **Base** (M0) | **Fase 0** — VM roteadora, interfaces e topologia inicial | **Fase 0** — VM cliente na LAN, host WAN de teste e MAC do cliente reservado | 🟡 Em andamento — estrutura do repositório criada; faltam VMs, topologia e `lab.env.example` |
| **Rede básica** (M1) | **Fase 1** — WAN, LAN `/16`, rota padrão e `ip.forwarding` | **Fase 1** — validar a rede sem alterar a configuração de Mateus; `tests/01-connectivity.md` | ⬜ Pendente |
| **Paralelo 1** (M2) | **Fase 2A** — NAT, isolamento e DNAT no PF; apoio à integração do DHCP | **Fase 2B** — DHCP, reserva, *leases* e logs; roteiros de teste e servidor TCP | ⬜ Pendente |
| **Integração 1** (M3) | **Fase 3** — testes integrados | **Fase 3** — testes integrados | ⬜ Pendente |
| **Final** (M4) | **Fase 4** — arquitetura e instalação de rede/PF | **Fase 4** — validação, evidências e limitações | ⬜ Pendente |
| **Entrega** | Revisão cruzada, ensaio e ZIP | Revisão cruzada, ensaio e ZIP | ⬜ Pendente |

## 1. Responsabilidade principal de cada integrante

| Mateus — infraestrutura e PF | Luiza — DHCP e validação |
|---|---|
| Montar/configurar a **VM roteadora FreeBSD** (WAN e LAN). | Preparar o **cliente LAN** e o **host de teste do lado WAN**, conforme a topologia acordada. |
| Configurar IPs, rotas e **encaminhamento IPv4**. | Implementar o **servidor DHCP** restrito à LAN. |
| Implementar **NAT** de saída no firewall PF. | Configurar **pool DHCP, gateway, DNS e máscara /16**. |
| Implementar **isolamento da LAN** com regras de firewall. | Configurar **reserva DHCP por MAC** e consulta de *leases*/logs. |
| Implementar a regra de **DNAT WAN:80 → LAN:8080**. | Implementar o **servidor TCP de teste** e preparar os testes de ponta a ponta do DNAT. |
| Documentar **arquitetura e instalação da rede**. | Documentar **testes, evidências e limitações**. |

**Divisão em uma frase:** Mateus faz a infraestrutura e as regras do roteador; Luiza faz a distribuição de endereços e constrói a bancada de validação. **Os dois testam a integração e apresentam o trabalho.**

## 2. Contrato inicial obrigatório (antes de dividir as tarefas)

Na **Fase 0**, os dois devem concordar e registrar em `config/lab.env.example`:

- Interfaces `WAN_IF` e `LAN_IF` e suas redes (WAN `192.168.X.0/24` no laboratório; LAN sugerida `10.20.0.0/16`).
- IP LAN do roteador: `10.20.0.1`; pool DHCP: `10.20.0.100–10.20.0.200`.
- IP reservado ao cliente que executará o servidor TCP: `10.20.0.10` e MAC real a ser informado por Luiza.
- Portas do DNAT: **TCP 80 na WAN → TCP 8080 na LAN**.
- DNS definido pelo professor e modo de conexão WAN/LAN no UTM.

**Por que isso é necessário?** A regra de DNAT de Mateus usa o mesmo IP que Luiza reservará via DHCP. Sem um contrato comum, as duas entregas podem funcionar separadamente e falhar juntas.

## 3. Tarefas por fase do planejamento original

### Fase 0 / M0 — Acordo e ambiente

**Referência:** [Fase 0 no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-0--acordo-e-ambiente-conjunta)

**Mateus — executar:**
- [ ] Criar/configurar a **VM roteadora FreeBSD** com duas interfaces de rede, identificando quais serão WAN e LAN.
- [ ] Verificar que o sistema, as interfaces e o acesso administrativo funcionam.
- [ ] Registrar a topologia inicial em `docs/arquitetura.md`.

**Luiza — executar:**
- [ ] Preparar a **VM cliente da LAN** e definir como haverá um **host distinto na WAN** para testar o DNAT.
- [ ] Identificar o **MAC do cliente reservado** e fornecer a Mateus.
- [ ] Conferir que o cliente LAN está ligado **somente à rede LAN de testes**, sem expor o DHCP à rede do laboratório.

**Ambos — decidir e registrar:**
- [ ] Confirmar com o professor a aceitação de FreeBSD virtualizado e o formato do teste presencial.
- [ ] Criar/revisar `config/lab.env.example` e os valores compartilhados listados na seção 2.
- [ ] Confirmar repositório, branches e acesso às VMs.

**Fase concluída quando:** topologia, interfaces, IPs, cliente reservado e estratégia de teste WAN estão definidos. **Só então a dupla separa o desenvolvimento.**

### Fase 1 / M1 — Rede básica e roteamento

**Referência:** [Fase 1 no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-1--rede-básica-e-roteamento-pessoa-a)

**Mateus — implementar:**
- [ ] Configurar **IP WAN, IP LAN e rota padrão**, respeitando o ambiente virtual ou a rede real do laboratório.
- [ ] Ativar e tornar persistente o **IPv4 forwarding**.
- [ ] Implementar `scripts/01-setup-network.sh`.
- [ ] Descrever os comandos de instalação/configuração em `docs/instalacao.md`.

**Luiza — validar, sem alterar a configuração de Mateus:**
- [ ] Escrever `tests/01-connectivity.md` com comandos e resultados esperados.
- [ ] Validar IP/máscara no cliente, alcance do gateway LAN e caminhos de rede disponíveis.
- [ ] Reportar falhas identificadas para Mateus corrigir.

**Fase concluída quando:** a VM roteadora tem WAN/LAN e rotas corretas, IPv4 forwarding ativo e conectividade básica verificada.

### Fase 2A / M2 — NAT, isolamento e regra DNAT (Mateus)

**Referência:** [Fase 2A no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-2a--nat-política-de-isolamento-e-dnat-pessoa-a)

**Mateus — implementar:**
- [ ] Criar `config/pf.conf.template` com **NAT de saída da LAN para a WAN**.
- [ ] Criar regras de **isolamento**, impedindo acesso indevido WAN → LAN, sem bloquear conexões legítimas.
- [ ] Configurar a regra **DNAT TCP WAN:80 → 10.20.0.10:8080**.
- [ ] Criar `scripts/02-setup-firewall.sh` com **validação de sintaxe** antes da aplicação das regras.
- [ ] Registrar como consultar regras/estados do PF e como recuperar acesso caso uma regra bloqueie a administração.

**Luiza — desenvolver em paralelo:**
- [ ] Escrever `tests/02-nat.md` (como comprovar tradução de endereços).
- [ ] Escrever `tests/03-isolation.md` (tentativa WAN → LAN bloqueada e exceção permitida).
- [ ] Escrever `tests/05-dnat.md` (cliente WAN → WAN:80 → servidor LAN:8080).
- [ ] Preparar `tests/tcp-server.sh` para iniciar o serviço TCP na porta **8080** do cliente reservado.

**Fase concluída quando:** as regras do PF foram validadas e estão prontas para os testes conjuntos; os roteiros de NAT, isolamento e DNAT estão preparados. **O DNAT de ponta a ponta só será considerado aprovado na Fase 3.**

### Fase 2B / M2 — DHCP, reserva e logs (Luiza)

**Referência:** [Fase 2B no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-2b--dhcp-e-reserva-pessoa-b)

**Luiza — implementar:**
- [ ] Criar `config/dnsmasq.conf.template` e restringir a escuta do DHCP **à LAN**.
- [ ] Configurar distribuição de IPs `10.20.0.100–10.20.0.200`, máscara `/16`, gateway `10.20.0.1` e DNS acordado.
- [ ] Reservar `10.20.0.10` para o **MAC** do cliente que receberá o tráfego DNAT.
- [ ] Configurar arquivo de *leases* e logs de DHCP; documentar como consultá-los.
- [ ] Criar `scripts/03-setup-dhcp.sh` e `tests/04-dhcp.md`.
- [ ] Validar concessão, renovação e reserva com o cliente LAN.

**Mateus — apoiar integração, sem assumir o DHCP:**
- [ ] Verificar se a política PF permite tráfego DHCP **na interface LAN**, mantendo-o bloqueado na WAN.
- [ ] Revisar se a reserva/IP de Luiza coincide com o destino DNAT definido em `pf.conf.template`.

**Fase concluída quando:** o cliente recebe IP/máscara/gateway/DNS automaticamente; o cliente reservado recebe o IP fixo por DHCP; *leases* e logs são consultáveis.

> **Paralelismo real:** as **Fases 2A e 2B acontecem ao mesmo tempo** depois do contrato inicial e da rede básica. Mateus não precisa esperar Luiza terminar o DHCP para escrever as regras PF; Luiza não precisa esperar Mateus terminar o NAT para configurar o DHCP na LAN isolada.

### Fase 3 / M3 — Integração e validação (ambos)

**Referência:** [Fase 3 no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-3--testes-integrados-conjunta)

| Teste integrado | Mateus faz | Luiza faz |
|---|---|---|
| Conectividade/roteamento | Confere interfaces, forwarding e rotas | Executa testes do cliente e coleta resultados |
| NAT | Confere regras/estados PF e captura WAN | Gera tráfego da LAN e registra evidências |
| Isolamento | Confere política e bloqueios PF | Executa tentativas WAN → LAN não autorizadas |
| DHCP e reserva | Confere que o PF não bloqueia DHCP LAN | Renova concessão, confirma IP fixo e consulta *leases*/logs |
| DNAT TCP 80 → 8080 | Confere regra PF e caminho de retorno | Inicia servidor TCP LAN:8080 e conecta do host WAN à WAN:80 |
| Reinício/persistência | Confere retorno da rede e PF | Confere retorno do DHCP e repete testes |

**Ambos — executar:**
- [ ] Ajustar `scripts/apply.sh`, `scripts/status.sh` e `scripts/rollback.sh` para instalação, diagnóstico e reversão.
- [ ] Rodar a bateria de testes completa, com as duas pessoas presentes.
- [ ] Registrar **resultado real** e evidência de cada teste em `docs/validacao.md` e `docs/evidencias/` (Luiza organiza, Mateus revisa).
- [ ] Corrigir problemas de integração antes de considerar a fase encerrada.

**Fase concluída quando:** NAT, isolamento, DHCP, reserva, *leases* e DNAT funcionam **na mesma topologia**, com evidências verificáveis.

### Fase 4 / M4 — Documentação, ensaio e ZIP (ambos)

**Referência:** [Fase 4 no planejamento](./PLANEJAMENTO_TRABALHO_02_REDES.md#fase-4--documentação-ensaio-e-entrega-conjunta)

**Mateus — entregar e revisar:**
- [ ] Finalizar `docs/arquitetura.md` e parte de rede/PF de `docs/instalacao.md`.
- [ ] Conferir `01-setup-network.sh`, `02-setup-firewall.sh` e `pf.conf.template`.
- [ ] Explicar na documentação NAT, isolamento, DNAT e recuperação de falhas de firewall.

**Luiza — entregar e revisar:**
- [ ] Finalizar `docs/validacao.md`, `docs/limitacoes.md` e `docs/evidencias/`.
- [ ] Conferir `03-setup-dhcp.sh`, `dnsmasq.conf.template` e os roteiros em `tests/`.
- [ ] Descrever como provar DHCP, reserva, consulta de *leases* e conexão TCP redirecionada.

**Ambos — entregar:**
- [ ] Revisar `README.md`, `scripts/apply.sh`, `scripts/status.sh`, `scripts/rollback.sh` e `entrega/checklist.md`.
- [ ] Reproduzir a configuração e fazer **ensaio da demonstração**; cada um deve conseguir explicar todos os serviços.
- [ ] Preparar o **ZIP** com scripts, templates, documentação e evidências, sem credenciais, `.git` ou arquivos temporários.

**Fase concluída quando:** outra pessoa consegue seguir a documentação para montar o ambiente compatível, e a dupla consegue comprovar os requisitos presencialmente.

## Independência das fases paralelas

- **Rede básica:** Mateus configura as interfaces, a rota padrão e o encaminhamento IPv4, enquanto Luiza, sem alterar essa configuração, escreve os testes de conectividade e valida o resultado pelo lado do cliente.
- **Paralelo 1:** o PF e o dnsmasq são serviços separados, com templates próprios (`pf.conf.template` e `dnsmasq.conf.template`). Luiza pode configurar o DHCP e testá-lo em LAN isolada enquanto Mateus implementa as regras do PF, e os roteiros de NAT, isolamento e DNAT e o servidor TCP de teste também podem ser preparados sem o PF pronto.
- **Integração 1:** o teste real de DNAT depende dos dois lados. Só ocorre depois de o cliente reservado ter IP estável (`RESERVED_IP`), de o servidor estar escutando na porta `8080` e de a regra PF estar ativa.

## Arquivos por responsável

| Arquivo/pasta | Responsável principal | Revisão |
|---|---|---|
| `config/pf.conf.template` | **Mateus** | Luiza |
| `scripts/01-setup-network.sh` | **Mateus** | Luiza |
| `scripts/02-setup-firewall.sh` | **Mateus** | Luiza |
| `docs/arquitetura.md` | **Mateus** | Luiza |
| `docs/instalacao.md` (rede e PF) | **Mateus** | Luiza |
| `config/dnsmasq.conf.template` | **Luiza** | Mateus |
| `scripts/03-setup-dhcp.sh` | **Luiza** | Mateus |
| `tests/01-connectivity.md` a `tests/05-dnat.md` | **Luiza** | Mateus |
| `tests/tcp-server.sh` e `tests/collect-evidence.sh` | **Luiza** | Mateus |
| `docs/validacao.md`, `docs/limitacoes.md`, `docs/evidencias/` | **Luiza** | Mateus |
| `config/lab.env.example` e `scripts/00-check-prerequisites.sh` | **Ambos** | Ambos |
| `scripts/apply.sh`, `scripts/status.sh`, `scripts/rollback.sh` | **Ambos** | Ambos |
| `README.md`, `entrega/checklist.md` e ZIP final | **Ambos** | Ambos |

## Regras para evitar conflitos

- Antes de iniciar as frentes em paralelo, alinhar `WAN_IF`, `LAN_IF`, `LAN_CIDR`, `RESERVED_IP`, `RESERVED_MAC` e as portas `80`/`8080` (contrato da seção 2).
- Somente Mateus modifica `pf.conf.template`; somente Luiza modifica `dnsmasq.conf.template`.
- Mudanças de IP, porta, interface ou outro valor compartilhado só ocorrem depois de avisar o outro integrante. Mudanças que afetem o serviço do outro são registradas em issue/PR e revisadas em conjunto.
- Scripts: Mateus cuida de `01-*` e `02-*`; Luiza, de `03-*` e dos testes.
- Branches sugeridas: `feature/rede-pf` (Mateus) e `feature/dhcp-testes` (Luiza). Cada pessoa abre um pull request com os próprios arquivos e a outra revisa; os arquivos compartilhados são ajustados em conjunto durante a integração. O merge na `main` ocorre somente após checagem de sintaxe e testes correspondentes.

## Fluxo de trabalho e pontos de sincronização

```text
FASE 0 / M0 — JUNTOS
Contrato de rede + VMs + repositório
             |
FASE 1 / M1 — MATEUS CONFIGURA A REDE; LUIZA ESCREVE/EXECUTA TESTES BÁSICOS
             |
             +------------------------------+
             |                              |
FASE 2A / M2 — MATEUS            FASE 2B / M2 — LUIZA
PF: NAT, isolamento e DNAT       dnsmasq: DHCP, reserva e leases
Rede e firewall automatizados    Cliente TCP e roteiros de teste
             |                              |
             +--------------+---------------+
                            |
FASE 3 / M3 — JUNTOS
Integração + teste real de todos os requisitos
                            |
FASE 4 / M4 — JUNTOS
Revisão cruzada + documentação + ensaio + ZIP
```

**Pontos de sincronização mínimos:**

1. **Fim da Fase 0:** confirmar variáveis e a arquitetura; Luiza informa o MAC e Mateus confirma o IP de destino do DNAT.
2. **Fim da Fase 1:** Luiza confirma conectividade básica antes da bateria integrada.
3. **Durante a Fase 2:** Mateus avisa quando PF/NAT/DNAT estiver pronto; Luiza avisa quando DHCP/reserva/servidor TCP estiver pronto.
4. **Início da Fase 3:** juntar os dois conjuntos de arquivos na **mesma VM roteadora** e executar testes juntos.
5. **Fim da Fase 4:** ambos aprovam ZIP e roteiro de demonstração.

As fases seguem esta ordem: acordo e preparação do ambiente, rede básica, desenvolvimento paralelo de PF e DHCP, integração dos serviços, documentação e ensaio, e entrega. Cada integração deve ocorrer somente após os testes das fases anteriores.

---

**Resumo final:** **Mateus entrega o roteador e suas regras; Luiza entrega o DHCP e a validação; ambos entregam a integração, a documentação final e a demonstração.**

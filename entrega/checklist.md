# Checklist de entrega

Envio: **um ZIP por dupla**, no ponto de coleta do **Sigaa ou do Office365** (canal a confirmar com o professor).

## 1. Conteúdo obrigatório (30% da nota: documentação)

| Tópico do enunciado | Onde está | OK |
|---|---|---|
| Sistema operacional usado | `README.md` (tópico 1) e `docs/arquitetura.md` | [x] |
| Aplicações usadas na LAN | `README.md` (tópico 2) e `docs/arquitetura.md` → "Aplicações utilizadas" | [x] |
| Como implementar a LAN | `docs/instalacao.md` e `scripts/` | [x] |
| Como validar | `docs/validacao.md` e `tests/01` a `tests/05` | [x] |
| Limitações conhecidas | `docs/limitacoes.md` | [x] |
| Lista de testes: conectividade, NAT e isolamento | `tests/01`, `tests/02`, `tests/03` e `docs/validacao.md` | [x] |
| Onde conferir os leases do DHCP | `docs/instalacao.md` (seção 5), `tests/04-dhcp.md` (D) e `docs/validacao.md` | [x] |
| Evidências dos testes | `docs/evidencias/` | [x] |

## 2. Validar a sintaxe antes de zipar

Arquivo de configuração com erro de interpretação é **anulado**. No roteador, como root, com o `lab.env` do ambiente final:

```sh
pfctl -nf entrega/config-renderizada/pf.conf && echo "pf.conf OK"
dnsmasq --test -C entrega/config-renderizada/dnsmasq.conf
for f in scripts/*.sh tests/*.sh; do sh -n "$f" || echo "ERRO: $f"; done
grep -l '__[A-Z_]*__' entrega/config-renderizada/* && echo "ERRO: marcador sem substituir"
```

As cópias em `entrega/config-renderizada/` são geradas pelos scripts com os valores do `lab.env`. As versões atuais são do ambiente de desenvolvimento (WAN `vtnet0` por DHCP, DNS `192.168.64.1`) e passaram nessas verificações em 10/11/2026. Se o professor fixar outros valores, rodar `sh scripts/apply.sh` com o `lab.env` final e copiar a pasta de volta antes de zipar.

## 3. Montar o ZIP

No Mac, na pasta do repositório, com tudo commitado:

```sh
git archive --format=zip --prefix=trab02_frc/ -o entrega/trab02_frc.zip HEAD
unzip -l entrega/trab02_frc.zip | less     # conferir o conteúdo
```

O `git archive` leva só o que está no Git, então **não** entram `.git`, `config/lab.env` nem arquivos temporários. O `.gitattributes` deixa de fora os documentos internos da dupla (`PLANEJAMENTO_TRABALHO_02_REDES.md`, `divisao_planejamento.md` e `docs/replicar-ambiente.md`). O ZIP gerado fica fora do Git (`.gitignore`).

## 4. Antes de enviar

- [ ] Professor confirmou: valor de `X`, se aceita o roteador em VM no LDS, DNS a usar e canal de entrega.
- [ ] `lab.env` do laboratório preenchido e `apply.sh` + `status.sh` ensaiados na rede do LDS (WAN em *Bridged*).
- [ ] Bateria de testes repetida com as duas pessoas presentes; as duas sabem demonstrar NAT, DHCP e DNAT.
- [ ] Sintaxe validada (seção 2) e ZIP conferido (seção 3).
- [ ] ZIP enviado no Sigaa ou no Office365.

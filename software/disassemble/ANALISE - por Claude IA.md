# Engenharia reversa da ROM do INTERFAX 20

Placa conversora **Olivetti Praxis 20 → impressora**, fabricada por **HD - Sist.
Elet. Ind. e Com. Ltda** (revisão de hardware 01, software 8220301, versão
ABNT — esses textos estão gravados na própria ROM, dentro do banner de
autoteste). CPU Z80 + Z80 PIO + EPROM **HN462732G** (Hitachi, pino a pino
compatível com o 2732 industry-standard: 24 pinos, 4096 × 8 bits, **12
linhas de endereço A0-A11**, apagável por UV).

Esse detalhe do chip — que vocês já sabiam, mas eu não tinha quando fiz a
primeira análise — confirma e explica com precisão de hardware um achado que
eu tinha feito por pura observação do código: ver a seção "A ROM está
espelhada a cada 4KB — e por quê", mais abaixo.

Este documento resume o que consegui reconstruir a partir da leitura estática
do binário. O arquivo `disassembly_anotado.asm` traz o disassembly completo,
byte a byte, com comentários inseridos nos pontos relevantes.

## Metodologia

Não havia disassembler Z80 disponível no ambiente, então escrevi um do zero
(implementa o conjunto completo Z80, incluindo prefixos CB/ED/DD/FD e
DD CB/FD CB). Rodei uma varredura linear do arquivo inteiro e, em paralelo,
rastreei o fluxo de execução a partir de vários pontos de entrada plausíveis
(reset, vetores de interrupção, alvos de CALL/JP encontrados) para separar
código de dados — a ROM mistura os dois, como é comum em firmware de 8 bits
tão compacto.

## Mapa de E/S (Z80 PIO)

| Porta | Função |
|---|---|
| `00h` | Porta A – registrador de **dados** (liga na matriz de teclado da Olivetti) |
| `01h` | Porta B – registrador de **dados** (linha vinda do computador/host) |
| `02h` | Porta A – registrador de **controle** (modo, direção E/S, interrupção) |
| `03h` | Porta B – registrador de **controle** |

A Porta A é configurada em **Modo 3 (bit control)**, com máscara de direção
`B8h` (`1011 1000`): bits 7, 5, 4, 3 = entrada; bits 6, 2, 1, 0 = saída. Isso
confirma a hipótese da pergunta: a placa não trata a Porta A como um
barramento de dados comum, e sim **bit a bit**, porque cada linha está ligada
diretamente a um ponto específico da matriz de teclado da Olivetti (algumas
linhas são lidas — o estado da própria varredura interna da máquina — e
outras são acionadas — para simular o fechamento de uma tecla).

A Porta B é configurada como **Modo 1 (entrada pura)**, com interrupção
habilitada — muito provavelmente é por onde entra o dado vindo do computador
host (byte a ser "digitado").

Descobri também que a decodificação de endereços da placa parece usar poucos
bits: `IN A,(80h)` é usado em vários pontos com o mesmo efeito de
`IN A,(00h)` (ver seção sobre espelhamento abaixo), então portas 0x00/0x80
(e prováveis 0x01/0x81, etc.) acessam o mesmo registrador físico.

## Descrição de fluxo alto nível

```
0000h  vetor de reset "oficial" do Z80        (ver ressalva abaixo)
000Dh  checagem de checksum da própria ROM     (aparenta ser vestigial)
002Dh  init da PIO — bloco 1 (Porta A)
0060h  init da PIO — bloco 2 (Porta A + Porta B completa)
008Ch  tabela de handshake (11 pares saída/entrada esperada)
00A3h  máquina de estados de handshake/autodetecção (vários estágios,
       com timeout e contagem de pulsos via interrupção)
0238h  "desiste" do handshake (caminho de erro)
023Ch  ISR (vetor PIO 5Ah) — 2a checagem de checksum + reconfig Porta B,
       GATILHO CONDICIONAL DO AUTOTESTE (ver seção dedicada abaixo)
0586h  ROTINA CENTRAL — simula o toque de uma tecla na matriz
06F8h  despacho de caracteres recebidos (CR/TAB/BS tratados à parte)
       + contador de coluna da folha
0782h  reconfig. da PIO + monta ponteiro para o texto do autoteste
0843h  texto do banner "INTERFAX 20" + padrão de autoteste (é DADO,
       enviado caractere a caractere pela rotina de 0586h)
0F00h  tabela de vetores de interrupção IM2 (reside na própria ROM)
```

## Como ela entra em autoteste

Rastreei o caminho até o texto do banner (`0843h`) e a rotina que o alimenta
para a matriz de teclas (`0782h`). A entrada **não é incondicional a cada
ligamento** — encontrei uma condição de guarda clara no código.

Existe uma rotina em **`023Ch`**, disparada por **interrupção da Z80 PIO**
(confirmei isso encontrando o ponteiro `023Ch` gravado na tabela de vetores
IM2, no offset `0F5Ah` — ou seja, é o tratador do vetor de interrupção
`5Ah`). A primeira coisa que essa rotina faz é:

```
0244  EX AF,AF'
0245  IN A,(00h)     ; le a Porta A
0247  AND 80h        ; testa o bit 7
0249  RET Z          ; se bit 7 = 0, retorna sem fazer nada
```

**Se o bit 7 da Porta A não estiver em nível alto, a rotina não faz nada e
retorna.** Se estiver em nível alto, ela roda uma **segunda checagem de
checksum da ROM** (usa os bytes `0FFEh-0FFFh` como valor esperado — diferente
do checksum vestigial de `0000h`, que usa `0FFCh-0FFDh`; este segundo parece
ser o "de verdade", já que fica retestando em loop até bater, o que só
funciona se o cálculo realmente confere com o conteúdo real da ROM),
reconfigura a Porta B e prepara o terreno.

Rastreei a partir dali até `0782h`, que reconfigura a Porta A e monta
`HL=0843h` (ponteiro para o texto do banner). A partir de `07A8h`, o código
lê caractere a caractere de `(HL)` e empurra cada um pela **mesma pipeline
de despacho de caracteres** usada para bytes recebidos do host — ou seja,
**o autoteste "digita" o banner usando exatamente a mesma rotina de toque
de tecla (`0586h`) que processaria um caractere vindo da serial/paralela**.

**O bit 7 da Porta A é uma linha de ENTRADA** (parte da configuração
`B8h`/`38h` de direção da Porta A usada em vários pontos do código — bits
7, 5, 4, 3 são entrada), ligada à interface com a matriz da Olivetti. Não
é uma saída controlada pela própria placa. As duas hipóteses mais prováveis
para o que está nessa linha:

- **Um jumper/DIP switch na própria placa INTERFAX 20** — comum nessa
  época para habilitar modo de teste de fábrica sem precisar reprogramar a
  ROM. Vale abrir a placa e procurar.
- **Um sinal vindo da própria Olivetti** — por exemplo, segurar uma tecla
  específica ligando a máquina. Era comum em impressoras/máquinas de
  escrever eletrônicas dessa geração usar essa técnica para entrar em modo
  de diagnóstico, já que a placa está lendo diretamente a matriz de
  teclado da Olivetti.

Não dei confirmado qual das duas é a causa real (ou se é outra coisa) só
com análise estática — o jeito mais direto de confirmar é com uma ponta de
prova lógica nesse pino da Porta A durante o power-on, comparando o
resultado com/sem o jumper (se existir) e com/sem alguma tecla pressionada
na Olivetti.

## O "handshake" (resposta à sua pergunta principal)

Existe sim uma sequência de handshake, e ela é bem mais elaborada do que um
simples aperto de mão de porta serial — parece ser uma **sincronização com a
própria eletrônica de varredura de teclado da Olivetti**, não com o
computador host:

1. Em `008Ch` há uma tabela de 11 pares `(byte de saída, complemento
   esperado na entrada)`. O código em `011Bh` escreve cada byte de saída na
   Porta A e fica lendo a Porta B até o complemento bater, com um timeout
   generoso (contador de 24 bits: B×C×D×E). Isso parece testar se a
   controladora da máquina de escrever está presente e "viva".
2. A partir de `00A3h` há vários estágios adicionais alternativos — alguns
   usam contagem de **pulsos de interrupção** (habilita `EI`, e a própria
   ISR incrementa o registrador `L` compartilhado; o código principal só
   fica comparando `L` até chegar a 5). Suspeito que isso sirva para
   **detectar automaticamente qual variante/modelo** de controladora
   Olivetti está conectada (o produto claramente suporta mais de uma
   configuração — o banner até imprime "Versão ABNT").
3. Se tudo falhar, `0238h` desiste silenciosamente (`DI`/`RETI`).

## O mecanismo de "fingir que apertou a tecla" (o núcleo do produto)

Esta é a parte mais importante e a que tenho mais confiança, porque o código
ali é limpo e absolutamente consistente — reproduzido em detalhe no `.asm`,
endereço **`0586h`**:

- A Olivetti Praxis 20, por dentro, varre continuamente as **linhas** da
  matriz de teclado (fica ciclando qual linha está "ativa" a cada instante).
  Essa varredura aparece na Porta A, bits 3-4-5 (`AND 38h`).
- Para "digitar" um caractere, uma tabela (no final da ROM) traduz o código
  ASCII recebido em um valor de 3 bits = **em qual linha da matriz** a tecla
  correspondente fica.
- A rotina fica lendo a Porta A em loop até a varredura da própria Olivetti
  chegar exatamente naquela linha (com dupla confirmação/debounce, e um
  segundo temporizador cruzado com o bit 0 — provavelmente um sinal de
  "strobe" da máquina).
- No instante exato em que a linha certa está ativa, a placa escreve na
  Porta A um valor com um bit específico zerado — **esse é o pulso elétrico
  que a matriz da Olivetti interpreta como "a tecla desta coluna, nesta
  linha, foi fechada agora"**, exatamente como você descreveu na pergunta.
- Segura o pulso enquanto a varredura ainda está na linha, depois solta
  (com uma pequena variação dependendo de bits que parecem indicar se a
  tecla precisa de SHIFT — ou seja, o SHIFT também é "pressionado
  virtualmente" quando necessário).
- Repete o ciclo duas vezes (reforço, para não perder o registro caso a
  controladora perca um ciclo de varredura) e no fim manda o padrão neutro
  `C0h` para a Porta A (o mesmo valor "de repouso" usado na inicialização).

Existe uma segunda cópia mais simples dessa rotina em `0BFEh` (sem a
checagem extra do bit de strobe, sem repetir 2x) — possivelmente usada só
durante o autoteste de fábrica, onde robustez extra não é necessária.

## A ROM está "espelhada" a cada 4KB — e por quê

Boa parte do código contém saltos para endereços **fora** da faixa
`0000h-0FFFh` desta ROM (`1CCCh`, `2586h`, `3C44h`, `3C58h`, `3C61h`, etc.).
À primeira vista isso parecia um bug ou sinal de que faltava uma segunda
ROM. Mas checando byte a byte, **todos** esses endereços, subtraindo
múltiplos de `1000h`, caem exatamente em código real e coerente desta mesma
imagem (`2586h → 0586h`, a própria rotina de toque de tecla; `3C44h →
0C44h`; `3C58h → 0C58h`; `3C61h → 0C61h`; `1CCCh → 0CCCh`, perto do coto de
checksum). Cheguei a essa conclusão só de olhar o comportamento do código,
antes de saber qual CI era usado — imaginei que o motivo fosse uma
decodificação de endereço "econômica" que só olha os bits baixos.

**Com a informação de que o chip é o HN462732G, isso deixa de ser hipótese
e vira certeza de hardware**: o 2732 é fisicamente um EPROM de 4K×8 com
**apenas 12 pinos de endereço (A0-A11)** — ele não tem, e nunca teve, pinos
para A12-A15. Não existe "decodificação parcial" nem economia de lógica
acontecendo aqui: é simplesmente que **o chip não tem como saber** o valor
das linhas de endereço A12-A15 do Z80, porque elas nunca chegam até ele.
Se a placa não tiver nenhum outro circuito de seleção de banco/chip-select
adicional amarrando o `/CE` do 2732 a essas linhas altas (o que é comum e
esperado num projeto minimalista de 3 CIs como este), o resultado
inevitável é que **os mesmos 4096 bytes respondem em todas as 16 "janelas"
de 4KB do espaço de 64KB do Z80** (`0000h-0FFFh`, `1000h-1FFFh`,
`2000h-2FFFh`, ..., `F000h-FFFFh` — todas leem o mesmo conteúdo).

Isso também explica por que o `IN A,(80h)` se comporta como `IN A,(00h)`:
o barramento de E/S do Z80 usa só 8 bits para número da porta, e se a placa
também não decodificar todos eles, o mesmo fenômeno de espelhamento ocorre
nas portas de E/S.

O firmware provavelmente foi escrito/portado de uma versão com mapa de
memória maior (mais RAM/ROM mapeada de fato), e os endereços absolutos com
bits altos "sobrando" (`1xxx`, `2xxx`, `3xxx`...) simplesmente nunca foram
corrigidos — e não precisavam ser, já que o espelhamento do 2732 os torna
funcionalmente equivalentes ao endereço real de 12 bits.

**Isso é uma boa notícia para a preservação**: confirma que os 4096 bytes
que vocês dumparam são o firmware **completo** — não falta uma segunda ROM,
não há bank switching escondido, e não há nada "fora do alcance" de verdade;
são só os 12 bits baixos do mesmo endereço aparecendo escritos de formas
diferentes no código-fonte original.

## O que ficou em aberto / recomendo verificar na bancada

- O vetor de reset em `0000h` (`EX (SP),IX` / ... / `RET`) não parece ser um
  ponto de entrada funcional de verdade — o `RET` final depende do
  conteúdo de uma posição de RAM (`FF54h`/`FF55h`) que não está definida em
  lugar nenhum desta ROM. É bem possível que isso seja código residual de
  outra versão do produto, e que na prática nunca importe (o handshake em
  `00A3h`+ parece ser alcançado de outra forma — vale conferir com um
  analisador lógico o que a CPU busca logo após o reset real).
- O significado bit a bit exato de cada estágio do handshake (o que cada
  padrão específico da tabela de `008Ch` está testando) eu não consegui
  confirmar sem o hardware real — a estrutura geral (desafio/resposta com
  timeout) está clara, os detalhes finos não.
- As tabelas de tradução caractere→posição-de-matriz, no final da ROM
  (a partir de ~`0CA0h`, misturadas com mais código), eu não decodifiquei
  campo a campo — são registros de bytes cuja estrutura exata (quantos
  bytes por caractere, offset por tabela de idioma/ABNT) precisaria de mais
  tempo ou de captura ao vivo para confirmar com certeza.

## Arquivos

- `disassembly_anotado.asm` — disassembly completo (todos os 4096 bytes,
  endereço + bytes + mnemônico), com os comentários acima inseridos nos
  pontos relevantes.

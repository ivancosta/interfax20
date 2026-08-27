;==============================================================================
; INTERFAX 20 (HD - SIST. ELET. IND. E COM. LTDA)
; Disassembly comentado - Z80, EPROM HN462732G (Hitachi, compativel 2732:
; 24 pinos, 4096 x 8 bits, 12 linhas de endereco A0-A11), enderecos 0000h-0FFFh
; Placa conversora Olivetti Praxis 20 -> impressora serial/paralela
;
; Gerado por analise estatica (disassembler proprio) + engenharia
; reversa manual. Ver relatorio ANALISE.md para a explicacao
; completa, tabela de portas, e ressalvas de confianca.
;
; IMPORTANTE: como o 2732 so tem 12 pinos de endereco (A0-A11), sem
; logica extra de selecao de banco esta ROM de 4KB aparece REPETIDA
; ('espelhada') em todas as 16 janelas de 4KB do mapa de 64KB do Z80.
; Isso explica todos os saltos para enderecos 'fora' de 0000h-0FFFh
; encontrados no codigo (ver comentarios em 000Dh e 06F8h).
;==============================================================================


;==============================================================================
; BLOCO 0000h-0009h - VETOR DE RESET (endereco 0000h)
;
; Sequencia executada ao ligar o Z80 (PC=0000h por hardware).
; 'EX (SP),IX' logo no inicio nao tem efeito util (SP ainda indefinido
; apos reset) - parece ser so 'lixo'/padding sem funcao real.
; Em seguida acerta SP para FF54h (topo da RAM externa, fora desta ROM)
; e termina em RET. Esse RET desvia para o endereco guardado em
; (FF54h)/(FF55h) na RAM - ou seja, ESTE BLOCO NAO E REALMENTE O PONTO
; DE ENTRADA FUNCIONAL do firmware; e mais provavel que seja HERANCA/
; RESIDUO de outro produto da familia (uma rotina de checksum de ROM,
; ver abaixo) que nesta revisao acabou nunca sendo chamada 'a serio'.
; CONFIANCA: BAIXA quanto a ser o entry point real. Vale conferir com
; osciloscopio/analisador logico o que a placa realmente faz ao ligar.
;==============================================================================
0000  DD E3         EX (SP),IX
0002  00            NOP
0003  00            NOP
0004  31 54 FF      LD SP,FF54h
0007  00            NOP
0008  00            NOP
0009  C9            RET

;--- pequenas rotinas auxiliares 'soltas' ---
; 000A: RET NZ isolado
; 000B-000C: PUSH HL / RET  -> truque classico do Z80 para simular
;   'JP (HL)' quando chamado via CALL 000Bh (empilha HL e retorna)
000A  C0            RET NZ
000B  E5            PUSH HL
000C  C9            RET

;==============================================================================
; ROTINA DE CHECKSUM/AUTOTESTE DA PROPRIA ROM (0000h-0FFBh)
; HL = valor esperado, lido em (0FFCh)-(0FFDh) [ultimos bytes da ROM]
; DE percorre 0FFBh...0001h subtraindo cada byte de HL (SBC HL,BC)
; Se HL != 0 ao final -> 'checksum ruim' -> JP NZ,0CCDh (rotina-coto
;   'XOR A / OR A / RET' - basicamente um retorno rapido/inofensivo)
; Se HL == 0 -> 'checksum OK' -> JP 1CCCh
;   ATENCAO: 1CCCh esta FORA desta imagem de 4KB (0000h-0FFFh).
;   Ver nota sobre 'espelhamento de endereco' no relatorio: como o
;   decodificador de enderecos desta placa provavelmente so usa os
;   12 bits baixos (A0-A11), 1CCCh e 0CCCh (mod 1000h) apontam para
;   O MESMO byte fisico - ou seja, os DOIS desvios acabam, na pratica,
;   caindo bem perto um do outro (0CCCh e 0CCDh), reforcando a ideia
;   de que esta checagem de checksum e vestigial/pouco relevante.
;   (O chip desta ROM e um HN462732G/2732: 12 pinos de endereco A0-A11
;   apenas, sem A12-A15. Sem decodificacao extra de banco, o espelhamento
;   e consequencia fisica direta do chip, nao um palpite - ver 06F8h.)
;==============================================================================
000D  2A FC 0F      LD HL,(0FFCh)
0010  11 FB 0F      LD DE,0FFBh
0013  06 00         LD B,00h
0015  1B            DEC DE
0016  00            NOP
0017  00            NOP
0018  1A            LD A,(DE)
0019  4F            LD C,A
001A  AF            XOR A
001B  ED 42         SBC HL,BC
001D  7A            LD A,D
001E  00            NOP
001F  B3            OR E
0020  28 03         JR Z,0025h
0022  1B            DEC DE
0023  18 F0         JR 0015h
0025  7C            LD A,H
0026  B5            OR L
0027  C2 CD 0C      JP NZ,0CCDh
002A  C3 CC 1C      JP 1CCCh

;==============================================================================
; INICIALIZACAO DO Z80 PIO - BLOCO 1 (chamado/entrado em 002Dh)
;
; Portas E/S usadas neste board (Z80 PIO):
;   porta 00h = Porta A, registrador de DADOS
;   porta 01h = Porta B, registrador de DADOS
;   porta 02h = Porta A, registrador de CONTROLE
;   porta 03h = Porta B, registrador de CONTROLE
;
; (mais adiante o codigo tambem le 'IN A,(80h)' com o MESMO efeito de
; 'IN A,(00h)' - o barramento de E/S do Z80 usa 8 bits para o numero
; da porta, e como a placa nao decodifica todos eles, o mesmo tipo de
; espelhamento visto na ROM HN462732G/2732 tambem ocorre aqui)
;
; IM 2          -> modo de interrupcao 2 (vetorizado)
; OUT(02h),00h  -> byte de reset/soft-reset da Porta A
; OUT(02h),CFh  -> CFh=11001111b: bits 7-6=11 => seleciona MODO 3
;                  (Bit Control / E-S bit a bit) da Porta A
; OUT(02h),B8h  -> palavra de DIRECAO (DDR) do modo 3:
;                  B8h=10111000b -> bits 7,5,4,3 = ENTRADA
;                                   bits 6,2,1,0 = SAIDA
;                  (a Porta A liga direto na matriz de teclado da
;                   Olivetti: parte das linhas de varredura sao
;                   lidas como entrada, e a placa injeta o 'toque'
;                   de tecla como saida em outros bits)
; OUT(02h),07h  -> palavra de controle de interrupcao (ICW)
; OUT(00h),C0h  -> mascara de interrupcao (modo 3): C0h=11000000b
; IN A,(00h)    -> leitura de reconhecimento/'clear'
; OUT(03h),07h  -> ICW tambem para a Porta B (config minima)
; LD A,0Fh / LD I,A -> registrador I = 0Fh: em modo IM2 os vetores
;                  de interrupcao sao lidos em (0F00h+vetor).
;                  Essa tabela cai DENTRO desta propria ROM (ver
;                  0F00h adiante) e por isso pode ser so-leitura.
; RETI           -> retorna (tambem usado como 'fecha' o ciclo de
;                  interrupcao pendente da PIO)
; HALT (004Fh)   -> alvo de HALT provavelmente usado como 'ponto
;                  de espera' de outro lugar do codigo (loop ocioso
;                  ate a proxima interrupcao), nao e alcancado em
;                  sequencia direta a partir do RETI acima.
;==============================================================================
002D  ED 5E         IM 2
002F  3E 00         LD A,00h
0031  D3 02         OUT (02h),A
0033  3E CF         LD A,CFh
0035  D3 02         OUT (02h),A
0037  3E B8         LD A,B8h
0039  D3 02         OUT (02h),A
003B  3E 07         LD A,07h
003D  D3 02         OUT (02h),A
003F  3E C0         LD A,C0h
0041  D3 00         OUT (00h),A
0043  DB 00         IN A,(00h)
0045  3E 07         LD A,07h
0047  D3 03         OUT (03h),A
0049  3E 0F         LD A,0Fh
004B  ED 47         LD I,A
004D  ED 4D         RETI
004F  76            HALT

;--- bytes intermediarios (0050h-005Ch), possivel tabela pequena
;    ou parametros; DI + LD SP,0058h antes do 2o bloco de init.
0050  B0            OR B
0051  02            LD (BC),A
0052  BC            CP H
0053  00            NOP
0054  FC 00 00      CALL M,0000h
0057  01 A3 00      LD BC,00A3h
005A  38 02         JR C,005Eh
005C  F3            DI
005D  31 58 00      LD SP,0058h

;==============================================================================
; INICIALIZACAO DO Z80 PIO - BLOCO 2 (entrado em 0060h)
; Repete a config. da Porta A (igual ao bloco 1: modo 3, DDR B8h)
; e desta vez configura tambem a PORTA B por completo:
;   OUT(03h),5Ah -> 5Ah=01011010b: bits7-6=01 => Porta B = MODO 1
;                   (entrada pura) - provavelmente a porta que le
;                   o sinal serial/paralelo vindo do computador
;   OUT(03h),4Fh -> palavra de controle de interrupcao (ICW)
;   OUT(03h),87h -> 87h=10000111b: padrao fixo 0111 identifica
;                   'habilita/desabilita interrupcao'; bit7=1
;                   => HABILITA interrupcao da Porta B
; IN A,(01h)     -> leitura inicial da Porta B (dado vindo do host)
; RETI
;==============================================================================
0060  ED 5E         IM 2
0062  3E 00         LD A,00h
0064  ED 47         LD I,A
0066  3E 00         LD A,00h
0068  D3 02         OUT (02h),A
006A  3E CF         LD A,CFh
006C  D3 02         OUT (02h),A
006E  3E B8         LD A,B8h
0070  D3 02         OUT (02h),A
0072  3E 07         LD A,07h
0074  D3 02         OUT (02h),A
0076  3E 40         LD A,40h
0078  D3 00         OUT (00h),A
007A  DB 00         IN A,(00h)
007C  3E 5A         LD A,5Ah
007E  D3 03         OUT (03h),A
0080  3E 4F         LD A,4Fh
0082  D3 03         OUT (03h),A
0084  3E 87         LD A,87h
0086  D3 03         OUT (03h),A
0088  DB 01         IN A,(01h)
008A  ED 4D         RETI

;==============================================================================
; TABELA DE DADOS - SEQUENCIA DE 'HANDSHAKE'/AUTODETECCAO (008Ch-00A2h)
; 11 pares (byte_de_saida, byte_esperado_de_entrada) + terminador FFh:
;   (00h,20h) (01h,10h) (02h,40h) (03h,04h) (84h,80h) (05h,05h)
;   (06h,03h) (07h,02h) (40h,00h) (44h,00h) (C0h,00h)  FFh=fim
; Usada pelo loop em 011Bh: para cada par, escreve o 1o byte na
; Porta A (00h) e fica lendo a Porta B (01h) ate o complemento (CPL)
; do valor lido bater com o 2o byte, com timeout generoso (BC/D/E).
; Isto E o 'handshake' citado na pergunta: a placa manda um padrao
; de bits e espera a controladora da Olivetti responder com o padrao
; certo antes de prosseguir - provavel deteccao de presenca/modelo.
; (bytes 008Ch-00A2h = DADOS, nao instrucoes; abaixo o disassembler
;  ainda os mostra como 'codigo' por varredura linear - ignorar)
;==============================================================================
008C  00            NOP
008D  20 01         JR NZ,0090h
008F  10 02         DJNZ 0093h
0091  40            LD B,B
0092  03            INC BC
0093  04            INC B
0094  84            ADD A,H
0095  80            ADD A,B
0096  05            DEC B
0097  05            DEC B
0098  06 03         LD B,03h
009A  07            RLCA
009B  02            LD (BC),A
009C  40            LD B,B
009D  00            NOP
009E  44            LD B,H
009F  00            NOP
00A0  C0            RET NZ
00A1  00            NOP
00A2  FF            RST 38h

;==============================================================================
; MAQUINA DE ESTADOS DE HANDSHAKE / AUTODETECCAO (00A3h-0235h aprox.)
; Varios estagios sucessivos, cada um: envia um padrao pela Porta A,
; espera resposta especifica na Porta B dentro de um timeout, e em
; alguns estagios CONTA PULSOS DE INTERRUPCAO (via EI + IM2) usando
; o registrador L como contador compartilhado com a ISR (ver 0F00h).
; Todos os caminhos de falha convergem para 013Eh, que funciona como
; um dispatcher: usa o registrador sombra C' como 'numero do estagio'
; e tenta o proximo metodo de deteccao. Se tudo falhar, cai em 0238h
; (DI + RETI = desiste e devolve o controle 'silenciosamente').
; CONFIANCA: media-alta na ESTRUTURA geral; o significado exato de
; cada bit individual nao foi confirmado (precisaria de bancada).
;==============================================================================
00A3  3E 00         LD A,00h
00A5  D3 00         OUT (00h),A
00A7  01 00 00      LD BC,0000h
00AA  10 FE         DJNZ 00AAh
00AC  0D            DEC C
00AD  C2 AA 00      JP NZ,00AAh
00B0  3E 04         LD A,04h
00B2  D3 00         OUT (00h),A
00B4  D9            EXX
00B5  4F            LD C,A
00B6  D9            EXX
00B7  01 00 00      LD BC,0000h
00BA  60            LD H,B
00BB  69            LD L,C
00BC  31 54 00      LD SP,0054h
00BF  DB 01         IN A,(01h)
00C1  2C            INC L
00C2  FB            EI
00C3  7D            LD A,L
00C4  FE 05         CP 05h
00C6  CA D7 00      JP Z,00D7h
00C9  F3            DI
00CA  10 F6         DJNZ 00C2h
00CC  0D            DEC C
00CD  C2 C2 00      JP NZ,00C2h
00D0  25            DEC H
00D1  C2 C2 00      JP NZ,00C2h
00D4  C3 3E 01      JP 013Eh
00D7  F3            DI
00D8  31 56 00      LD SP,0056h
00DB  FB            EI
00DC  16 06         LD D,06h
00DE  01 00 00      LD BC,0000h
00E1  10 FE         DJNZ 00E1h
00E3  0D            DEC C
00E4  C2 E1 00      JP NZ,00E1h
00E7  15            DEC D
00E8  C2 E1 00      JP NZ,00E1h
00EB  F3            DI
00EC  31 58 00      LD SP,0058h
00EF  FB            EI
00F0  16 04         LD D,04h
00F2  10 FE         DJNZ 00F2h
00F4  0D            DEC C
00F5  C2 F2 00      JP NZ,00F2h
00F8  15            DEC D
00F9  C2 F2 00      JP NZ,00F2h
00FC  F3            DI
00FD  C3 3E 01      JP 013Eh
0100  F3            DI
0101  01 00 00      LD BC,0000h
0104  3E 00         LD A,00h
0106  D3 00         OUT (00h),A
0108  10 FE         DJNZ 0108h
010A  0D            DEC C
010B  C2 08 01      JP NZ,0108h
010E  3E 02         LD A,02h
0110  D3 00         OUT (00h),A
0112  D9            EXX
0113  5F            LD E,A
0114  D9            EXX
0115  10 FE         DJNZ 0115h
0117  0D            DEC C
0118  C2 15 01      JP NZ,0115h
011B  21 8C 00      LD HL,008Ch
011E  01 00 00      LD BC,0000h
0121  16 FF         LD D,FFh
0123  7E            LD A,(HL)
0124  FE FF         CP FFh
0126  CA 81 01      JP Z,0181h
0129  D3 00         OUT (00h),A
012B  23            INC HL
012C  4E            LD C,(HL)
012D  23            INC HL
012E  DB 01         IN A,(01h)
0130  2F            CPL
0131  B9            CP C
0132  28 EA         JR Z,011Eh
0134  10 F8         DJNZ 012Eh
0136  1D            DEC E
0137  C2 2E 01      JP NZ,012Eh
013A  15            DEC D
013B  C2 2E 01      JP NZ,012Eh
013E  F3            DI
013F  01 00 00      LD BC,0000h
0142  16 1E         LD D,1Eh
0144  1E 02         LD E,02h
0146  D9            EXX
0147  79            LD A,C
0148  D9            EXX
0149  FE 00         CP 00h
014B  20 02         JR NZ,014Fh
014D  1E 03         LD E,03h
014F  3E 40         LD A,40h
0151  D3 00         OUT (00h),A
0153  10 FE         DJNZ 0153h
0155  0D            DEC C
0156  0D            DEC C
0157  C2 53 01      JP NZ,0153h
015A  D9            EXX
015B  79            LD A,C
015C  D9            EXX
015D  D3 00         OUT (00h),A
015F  10 FE         DJNZ 015Fh
0161  0D            DEC C
0162  0D            DEC C
0163  C2 5F 01      JP NZ,015Fh
0166  3E 40         LD A,40h
0168  D3 00         OUT (00h),A
016A  1D            DEC E
016B  20 E6         JR NZ,0153h
016D  10 FE         DJNZ 016Dh
016F  0D            DEC C
0170  0D            DEC C
0171  C2 6D 01      JP NZ,016Dh
0174  15            DEC D
0175  28 DC         JR Z,0153h
0177  D9            EXX
0178  79            LD A,C
0179  D9            EXX
017A  FE 00         CP 00h
017C  20 C0         JR NZ,013Eh
017E  C3 5C 00      JP 005Ch
0181  01 00 00      LD BC,0000h
0184  3E 00         LD A,00h
0186  D3 00         OUT (00h),A
0188  10 FE         DJNZ 0188h
018A  0D            DEC C
018B  C2 88 01      JP NZ,0188h
018E  3E 06         LD A,06h
0190  D9            EXX
0191  4F            LD C,A
0192  D9            EXX
0193  3E 40         LD A,40h
0195  D3 00         OUT (00h),A
0197  DB 00         IN A,(00h)
0199  E6 80         AND 80h
019B  C2 A7 01      JP NZ,01A7h
019E  10 F7         DJNZ 0197h
01A0  0D            DEC C
01A1  C2 97 01      JP NZ,0197h
01A4  C3 3E 01      JP 013Eh
01A7  01 00 00      LD BC,0000h
01AA  3E 44         LD A,44h
01AC  D3 00         OUT (00h),A
01AE  DB 00         IN A,(00h)
01B0  E6 80         AND 80h
01B2  CA BE 01      JP Z,01BEh
01B5  10 F7         DJNZ 01AEh
01B7  0D            DEC C
01B8  C2 AE 01      JP NZ,01AEh
01BB  C3 3E 01      JP 013Eh
01BE  01 00 00      LD BC,0000h
01C1  DB 80         IN A,(80h)
01C3  E6 01         AND 01h
01C5  CA 3E 01      JP Z,013Eh
01C8  3E 07         LD A,07h
01CA  D3 00         OUT (00h),A
01CC  DB 80         IN A,(80h)
01CE  E6 01         AND 01h
01D0  CA DC 01      JP Z,01DCh
01D3  10 F7         DJNZ 01CCh
01D5  0D            DEC C
01D6  C2 CC 01      JP NZ,01CCh
01D9  C3 3E 01      JP 013Eh
01DC  01 00 00      LD BC,0000h
01DF  16 FF         LD D,FFh
01E1  DB 00         IN A,(00h)
01E3  5F            LD E,A
01E4  E6 10         AND 10h
01E6  CA 3E 01      JP Z,013Eh
01E9  7B            LD A,E
01EA  E6 08         AND 08h
01EC  20 0D         JR NZ,01FBh
01EE  10 F1         DJNZ 01E1h
01F0  0D            DEC C
01F1  C2 E1 01      JP NZ,01E1h
01F4  15            DEC D
01F5  C2 E1 01      JP NZ,01E1h
01F8  C3 3E 01      JP 013Eh
01FB  01 00 00      LD BC,0000h
01FE  DB 01         IN A,(01h)
0200  DB 00         IN A,(00h)
0202  E6 18         AND 18h
0204  28 1B         JR Z,0221h
0206  DB 01         IN A,(01h)
0208  DB 00         IN A,(00h)
020A  E6 18         AND 18h
020C  28 13         JR Z,0221h
020E  DB 01         IN A,(01h)
0210  DB 00         IN A,(00h)
0212  E6 18         AND 18h
0214  28 0B         JR Z,0221h
0216  DB 01         IN A,(01h)
0218  DB 00         IN A,(00h)
021A  E6 18         AND 18h
021C  28 03         JR Z,0221h
021E  C3 3E 01      JP 013Eh
0221  DB 00         IN A,(00h)
0223  E6 18         AND 18h
0225  FE 10         CP 10h
0227  28 08         JR Z,0231h
0229  10 F6         DJNZ 0221h
022B  0D            DEC C
022C  20 F3         JR NZ,0221h
022E  C3 3E 01      JP 013Eh
0231  D9            EXX
0232  0E 00         LD C,00h
0234  D9            EXX
0235  C3 3E 01      JP 013Eh

;--- 0238h: 'desiste' do handshake (DI, RETI) ---
0238  F3            DI
0239  00            NOP
023A  ED 4D         RETI

;==============================================================================
; >>> GATILHO CONDICIONAL DO AUTOTESTE (023Ch) <<<
;
; ISR disparada por interrupcao da PIO com vetor 5Ah - confirmado
; encontrando o ponteiro 023Ch gravado na tabela de vetores IM2 em
; 0F5Ah (0F00h + 5Ah).
;
; 0244: EX AF,AF'
; 0245: IN A,(00h)   -> le a Porta A
; 0247: AND 80h      -> testa o BIT 7
; 0249: RET Z        -> se bit7=0, RETORNA SEM FAZER NADA
;
; Ou seja: esta rotina (e, por extensao, o caminho que leva ao
; autoteste - ver 0782h) so prossegue se o BIT 7 DA PORTA A estiver
; em nivel alto. Se prosseguir, roda uma SEGUNDA checagem de checksum
; da ROM (valor esperado em 0FFEh-0FFFh, diferente do checksum
; vestigial de 0000h que usa 0FFCh-0FFDh - este parece ser o de
; verdade, ja que fica reexecutando em loop ate bater) e reconfigura
; a Porta B.
;
; O bit 7 da Porta A e uma linha de ENTRADA (parte da config B8h/38h
; de direcao da Porta A usada em varios pontos - bits 7,5,4,3 sao
; entrada), ligada a interface com a matriz da Olivetti - NAO e uma
; saida controlada pela propria placa. Duas hipoteses mais provaveis
; pra essa linha (nao confirmadas sem bancada):
;   - jumper/DIP switch na propria placa INTERFAX 20 (comum na epoca
;     para habilitar modo de teste de fabrica)
;   - sinal vindo da propria Olivetti (ex: segurar uma tecla
;     especifica ligando a maquina - tecnica comum em impressoras/
;     maquinas eletronicas dessa geracao p/ entrar em diagnostico)
;==============================================================================
023C  3E 00         LD A,00h
023E  57            LD D,A
023F  4F            LD C,A
0240  06 38         LD B,38h
0242  58            LD E,B
0243  D9            EXX
0244  08            EX AF,AF'
0245  DB 00         IN A,(00h)
0247  E6 80         AND 80h
0249  C8            RET Z
024A  3E CF         LD A,CFh
024C  D3 02         OUT (02h),A
024E  3E 38         LD A,38h
0250  D3 02         OUT (02h),A
0252  3E 07         LD A,07h
0254  D3 02         OUT (02h),A
0256  3E C0         LD A,C0h
0258  D3 00         OUT (00h),A
025A  DB 00         IN A,(00h)
025C  2A FE 0F      LD HL,(0FFEh)
025F  11 FE 0F      LD DE,0FFEh
0262  06 00         LD B,00h
0264  1B            DEC DE
0265  1A            LD A,(DE)
0266  4F            LD C,A
0267  AF            XOR A
0268  ED 42         SBC HL,BC
026A  1B            DEC DE
026B  7A            LD A,D
026C  B3            OR E
026D  28 02         JR Z,0271h
026F  18 F3         JR 0264h
0271  7C            LD A,H
0272  B5            OR L
0273  20 D5         JR NZ,024Ah
0275  06 1E         LD B,1Eh
0277  21 44 16      LD HL,1644h
027A  2B            DEC HL
027B  7D            LD A,L
027C  B4            OR H
027D  20 FB         JR NZ,027Ah
027F  05            DEC B
0280  20 F5         JR NZ,0277h
0282  31 50 00      LD SP,0050h
0285  3E CF         LD A,CFh
0287  D3 03         OUT (03h),A
0289  3E FF         LD A,FFh
028B  D3 03         OUT (03h),A
028D  3E 07         LD A,07h
028F  D3 02         OUT (02h),A
0291  DB 01         IN A,(01h)
0293  47            LD B,A
0294  3E 4F         LD A,4Fh
0296  D3 03         OUT (03h),A
0298  3E 17         LD A,17h
029A  D3 03         OUT (03h),A
029C  3E 50         LD A,50h
029E  D3 03         OUT (03h),A
02A0  3E 50         LD A,50h
02A2  D3 03         OUT (03h),A
02A4  3E 4F         LD A,4Fh
02A6  D3 03         OUT (03h),A
02A8  3E 87         LD A,87h
02AA  D3 03         OUT (03h),A
02AC  DB 01         IN A,(01h)
02AE  ED 4D         RETI
02B0  31 B6 02      LD SP,02B6h
02B3  C3 DD 3B      JP 3BDDh
02B6  31 52 FF      LD SP,FF52h
02B9  D9            EXX
02BA  7A            LD A,D
02BB  E6 7F         AND 7Fh
02BD  57            LD D,A
02BE  D9            EXX
02BF  FB            EI
02C0  00            NOP
02C1  00            NOP
02C2  F3            DI
02C3  C9            RET
02C4  D9            EXX
02C5  7A            LD A,D
02C6  E6 80         AND 80h
02C8  D9            EXX
02C9  28 EB         JR Z,02B6h
02CB  D9            EXX
02CC  7B            LD A,E
02CD  D9            EXX
02CE  E6 80         AND 80h
02D0  28 04         JR Z,02D6h
02D2  7A            LD A,D
02D3  E6 7F         AND 7Fh
02D5  57            LD D,A
02D6  D9            EXX
02D7  79            LD A,C
02D8  E6 10         AND 10h
02DA  28 0F         JR Z,02EBh
02DC  79            LD A,C
02DD  E6 EF         AND EFh
02DF  4F            LD C,A
02E0  D9            EXX
02E1  7A            LD A,D
02E2  B7            OR A
02E3  CA 7E 03      JP Z,037Eh
02E6  06 40         LD B,40h
02E8  C3 87 03      JP 0387h
02EB  7A            LD A,D
02EC  D9            EXX
02ED  E6 30         AND 30h
02EF  FE 30         CP 30h
02F1  20 1B         JR NZ,030Eh
02F3  7A            LD A,D
02F4  E6 7F         AND 7Fh
02F6  57            LD D,A
02F7  D9            EXX
02F8  7B            LD A,E
02F9  D9            EXX
02FA  E6 80         AND 80h
02FC  B2            OR D
02FD  D9            EXX
02FE  5F            LD E,A
02FF  78            LD A,B
0300  D9            EXX
0301  E6 80         AND 80h
0303  B2            OR D
0304  D9            EXX
0305  47            LD B,A
0306  7A            LD A,D
0307  E6 CF         AND CFh
0309  57            LD D,A
030A  D9            EXX
030B  C3 B6 12      JP 12B6h
030E  7A            LD A,D
030F  31 6B 16      LD SP,166Bh
0312  E6 7F         AND 7Fh
0314  FE 1B         CP 1Bh
0316  20 16         JR NZ,032Eh
0318  D9            EXX
0319  7A            LD A,D
031A  D9            EXX
031B  E6 20         AND 20h
031D  28 03         JR Z,0322h
031F  C3 B6 12      JP 12B6h
0322  D9            EXX
0323  7A            LD A,D
0324  F6 20         OR 20h
0326  57            LD D,A
0327  D9            EXX
0328  C3 E2 13      JP 13E2h
032B  CA 31 03      JP Z,0331h
032E  D9            EXX
032F  7A            LD A,D
0330  D9            EXX
0331  E6 20         AND 20h
0333  CA 11 24      JP Z,2411h
0336  D9            EXX
0337  7A            LD A,D
0338  E6 DF         AND DFh
033A  57            LD D,A
033B  D9            EXX
033C  7A            LD A,D
033D  E6 7F         AND 7Fh
033F  FE 2D         CP 2Dh
0341  28 32         JR Z,0375h
0343  FE 5A         CP 5Ah
0345  28 48         JR Z,038Fh
0347  FE 59         CP 59h
0349  28 4D         JR Z,0398h
034B  FE 52         CP 52h
034D  06 10         LD B,10h
034F  28 36         JR Z,0387h
0351  FE 40         CP 40h
0353  CA DD 3B      JP Z,3BDDh
0356  FE 4E         CP 4Eh
0358  CA A1 33      JP Z,33A1h
035B  FE 4F         CP 4Fh
035D  CA AA 33      JP Z,33AAh
0360  FE 43         CP 43h
0362  CA B3 33      JP Z,33B3h
0365  FE 49         CP 49h
0367  CA BE 3B      JP Z,3BBEh
036A  FE 44         CP 44h
036C  16 00         LD D,00h
036E  0E F9         LD C,F9h
0370  CA 25 25      JP Z,2525h
0373  18 6D         JR 03E2h
0375  D9            EXX
0376  79            LD A,C
0377  F6 10         OR 10h
0379  4F            LD C,A
037A  D9            EXX
037B  C3 B6 12      JP 12B6h
037E  D9            EXX
037F  7A            LD A,D
0380  E6 BF         AND BFh
0382  57            LD D,A
0383  D9            EXX
0384  C3 B6 12      JP 12B6h
0387  78            LD A,B
0388  D9            EXX
0389  B2            OR D
038A  57            LD D,A
038B  D9            EXX
038C  C3 B6 12      JP 12B6h
038F  D9            EXX
0390  79            LD A,C
0391  F6 80         OR 80h
0393  4F            LD C,A
0394  D9            EXX
0395  C3 B6 12      JP 12B6h
0398  D9            EXX
0399  79            LD A,C
039A  E6 7F         AND 7Fh
039C  4F            LD C,A
039D  D9            EXX
039E  C3 B6 12      JP 12B6h
03A1  D9            EXX
03A2  78            LD A,B
03A3  F6 80         OR 80h
03A5  47            LD B,A
03A6  D9            EXX
03A7  C3 B6 12      JP 12B6h
03AA  D9            EXX
03AB  78            LD A,B
03AC  E6 7F         AND 7Fh
03AE  47            LD B,A
03AF  D9            EXX
03B0  C3 B6 12      JP 12B6h
03B3  D9            EXX
03B4  7A            LD A,D
03B5  F6 30         OR 30h
03B7  57            LD D,A
03B8  D9            EXX
03B9  C3 B6 12      JP 12B6h
03BC  D9            EXX
03BD  7A            LD A,D
03BE  E6 EF         AND EFh
03C0  57            LD D,A
03C1  D9            EXX
03C2  7A            LD A,D
03C3  FE 20         CP 20h
03C5  38 1B         JR C,03E2h
03C7  FE 5F         CP 5Fh
03C9  28 17         JR Z,03E2h
03CB  D9            EXX
03CC  7A            LD A,D
03CD  D9            EXX
03CE  E6 40         AND 40h
03D0  28 10         JR Z,03E2h
03D2  16 08         LD D,08h
03D4  31 89 16      LD SP,1689h
03D7  C3 11 24      JP 2411h
03DA  16 5F         LD D,5Fh
03DC  31 91 16      LD SP,1691h
03DF  C3 11 24      JP 2411h
03E2  3E C0         LD A,C0h
03E4  D3 00         OUT (00h),A
03E6  D9            EXX
03E7  7A            LD A,D
03E8  E6 EF         AND EFh
03EA  57            LD D,A
03EB  79            LD A,C
03EC  D9            EXX
03ED  E6 40         AND 40h
03EF  C2 A8 37      JP NZ,37A8h
03F2  D9            EXX
03F3  79            LD A,C
03F4  D9            EXX
03F5  E6 20         AND 20h
03F7  C2 44 3C      JP NZ,3C44h
03FA  D9            EXX
03FB  78            LD A,B
03FC  E6 80         AND 80h
03FE  28 0D         JR Z,040Dh
0400  78            LD A,B
0401  E6 7F         AND 7Fh
0403  FE 05         CP 05h
0405  30 06         JR NC,040Dh
0407  D9            EXX
0408  16 0C         LD D,0Ch
040A  C3 CB 12      JP 12CBh
040D  D9            EXX
040E  C3 B6 12      JP 12B6h
0411  D9            EXX
0412  79            LD A,C
0413  E6 F0         AND F0h
0415  F6 02         OR 02h
0417  4F            LD C,A
0418  D9            EXX
0419  7A            LD A,D
041A  FE 7F         CP 7Fh
041C  CA B6 12      JP Z,12B6h
041F  E6 80         AND 80h
0421  28 0A         JR Z,042Dh
0423  D9            EXX
0424  7A            LD A,D
0425  F6 10         OR 10h
0427  57            LD D,A
0428  D9            EXX
0429  7A            LD A,D
042A  E6 7F         AND 7Fh
042C  57            LD D,A
042D  7A            LD A,D
042E  FE 20         CP 20h
0430  DA FD 16      JP C,16FDh
0433  20 09         JR NZ,043Eh
0435  D9            EXX
0436  7A            LD A,D
0437  D9            EXX
0438  E6 40         AND 40h
043A  28 02         JR Z,043Eh
043C  16 5F         LD D,5Fh
043E  D9            EXX
043F  7A            LD A,D
0440  D9            EXX
0441  E6 10         AND 10h
0443  20 6B         JR NZ,04B0h
0445  7A            LD A,D
0446  FE 40         CP 40h
0448  21 46 17      LD HL,1746h
044B  28 62         JR Z,04AFh
044D  21 56 17      LD HL,1756h
0450  FE 7E         CP 7Eh
0452  28 5B         JR Z,04AFh
0454  FE 60         CP 60h
0456  28 57         JR Z,04AFh
0458  FE 5E         CP 5Eh
045A  28 53         JR Z,04AFh
045C  FE 5C         CP 5Ch
045E  28 4F         JR Z,04AFh
0460  21 26 17      LD HL,1726h
0463  FE 3C         CP 3Ch
0465  28 48         JR Z,04AFh
0467  21 2E 17      LD HL,172Eh
046A  FE 3E         CP 3Eh
046C  28 41         JR Z,04AFh
046E  21 36 17      LD HL,1736h
0471  FE 23         CP 23h
0473  28 3A         JR Z,04AFh
0475  18 39         JR 04B0h
0477  0E E0         LD C,E0h
0479  31 56 17      LD SP,1756h
047C  C3 25 35      JP 3525h
047F  0E A0         LD C,A0h
0481  31 56 17      LD SP,1756h
0484  C3 25 35      JP 3525h
0487  16 08         LD D,08h
0489  31 3E 17      LD SP,173Eh
048C  C3 11 34      JP 3411h
048F  16 7C         LD D,7Ch
0491  31 6B 16      LD SP,166Bh
0494  C3 11 34      JP 3411h
0497  16 08         LD D,08h
0499  31 4E 17      LD SP,174Eh
049C  C3 11 34      JP 3411h
049F  16 4F         LD D,4Fh
04A1  31 6B 16      LD SP,166Bh
04A4  C3 11 34      JP 3411h
04A7  16 20         LD D,20h
04A9  31 6B 16      LD SP,166Bh
04AC  C3 11 34      JP 3411h
04AF  F9            LD SP,HL
04B0  D9            EXX
04B1  7A            LD A,D
04B2  D9            EXX
04B3  E6 10         AND 10h
04B5  28 5D         JR Z,0514h
04B7  7A            LD A,D
04B8  D6 20         SUB 20h
04BA  21 00 B0      LD HL,B000h
04BD  06 30         LD B,30h
04BF  4F            LD C,A
04C0  09            ADD HL,BC
04C1  09            ADD HL,BC
04C2  09            ADD HL,BC
04C3  01 FD DD      LD BC,DDFDh
04C6  D9            EXX
04C7  79            LD A,C
04C8  D9            EXX
04C9  E6 80         AND 80h
04CB  28 03         JR Z,04D0h
04CD  01 D0 6C      LD BC,6CD0h
04D0  09            ADD HL,BC
04D1  31 85 17      LD SP,1785h
04D4  18 48         JR 051Eh
04D6  7A            LD A,D
04D7  D6 20         SUB 20h
04D9  21 00 B0      LD HL,B000h
04DC  06 30         LD B,30h
04DE  4F            LD C,A
04DF  09            ADD HL,BC
04E0  09            ADD HL,BC
04E1  09            ADD HL,BC
04E2  01 FE DD      LD BC,DDFEh
04E5  D9            EXX
04E6  79            LD A,C
04E7  D9            EXX
04E8  E6 80         AND 80h
04EA  28 03         JR Z,04EFh
04EC  01 D1 6C      LD BC,6CD1h
04EF  09            ADD HL,BC
04F0  31 A4 17      LD SP,17A4h
04F3  18 29         JR 051Eh
04F5  7A            LD A,D
04F6  D6 20         SUB 20h
04F8  21 00 B0      LD HL,B000h
04FB  06 30         LD B,30h
04FD  4F            LD C,A
04FE  09            ADD HL,BC
04FF  09            ADD HL,BC
0500  09            ADD HL,BC
0501  01 FF DD      LD BC,DDFFh
0504  D9            EXX
0505  79            LD A,C
0506  D9            EXX
0507  E6 80         AND 80h
0509  28 03         JR Z,050Eh
050B  01 D2 6C      LD BC,6CD2h
050E  09            ADD HL,BC
050F  31 6B 16      LD SP,166Bh
0512  18 0A         JR 051Eh
0514  7A            LD A,D
0515  D6 20         SUB 20h
0517  4F            LD C,A
0518  06 30         LD B,30h
051A  21 6C EC      LD HL,EC6Ch
051D  09            ADD HL,BC
051E  7E            LD A,(HL)
051F  FE 00         CP 00h
0521  CA F8 06      JP Z,06F8h
0524  4F            LD C,A
0525  79            LD A,C
0526  E6 40         AND 40h
0528  20 07         JR NZ,0531h
052A  79            LD A,C
052B  E6 80         AND 80h
052D  F6 44         OR 44h
052F  18 03         JR 0534h
0531  79            LD A,C
0532  E6 C0         AND C0h
0534  D3 00         OUT (00h),A
0536  79            LD A,C
0537  E6 3F         AND 3Fh
0539  FE 20         CP 20h
053B  CA 65 17      JP Z,1765h
053E  FE 23         CP 23h
0540  CA 65 17      JP Z,1765h
0543  79            LD A,C
0544  FE 24         CP 24h
0546  CA 65 17      JP Z,1765h
0549  FE C6         CP C6h
054B  CA 21 37      JP Z,3721h
054E  FE F9         CP F9h
0550  CA 7F 27      JP Z,277Fh
0553  FE FD         CP FDh
0555  CA 7F 27      JP Z,277Fh
0558  FE FA         CP FAh
055A  CA 7F 27      JP Z,277Fh
055D  FE FE         CP FEh
055F  CA 7F 27      JP Z,277Fh
0562  FE FF         CP FFh
0564  CA 7F 27      JP Z,277Fh
0567  FE C3         CP C3h
0569  CA 7F 27      JP Z,277Fh
056C  FE FB         CP FBh
056E  CA 7B 05      JP Z,057Bh
0571  FE C2         CP C2h
0573  C2 7D 15      JP NZ,157Dh
0576  16 0D         LD D,0Dh
0578  C3 FD 16      JP 16FDh
057B  16 09         LD D,09h
057D  D9            EXX
057E  7A            LD A,D
057F  F6 80         OR 80h
0581  57            LD D,A
0582  D9            EXX
0583  08            EX AF,AF'
0584  3C            INC A
0585  08            EX AF,AF'

;==============================================================================
; >>> ROTINA CENTRAL: SIMULA O TOQUE DE UMA TECLA NA MATRIZ (0586h) <<<
;
; Esta e a rotina que faz, na pratica, 'como se alguem tivesse
; apertado a tecla' - exatamente o mecanismo descrito na pergunta.
;
; Entrada: C = codigo de 3 bits (posicao na matriz) da LINHA alvo,
;          previamente obtido de uma tabela caractere->matriz.
;   C AND C7h -> B = padrao-base de saida (mantem bits 7,2,1,0)
;   C AND 38h -> C = padrao da LINHA a esperar (bits 5,4,3)
;
; 1) Espera a varredura interna da Olivetti SAIR da linha-alvo
;    (garante que vai pegar um ciclo de varredura novo).
; 2) Fica lendo a Porta A (00h/80h - mesmo registrador, o endereco-
;    amento de E/S so decodifica poucos bits) mascarada com 38h,
;    ate encontrar a linha-alvo ativa (com dupla confirmacao =
;    debounce), monitorando tambem o bit 0 (provavel linha de
;    'strobe'/status vinda da propria Olivetti) com um contador
;    de timeout estendido em H/L.
; 3) No instante certo (linha correta ativa), ASSERTA o bit de
;    'sensor de tecla pressionada': A=B AND BFh ; OUT(00h),A
;    -> isso e literalmente o pulso eletrico que a matriz da
;    Olivetti interpreta como 'uma tecla desta coluna, nesta
;    linha, foi fechada agora'.
; 4) Mantem o pulso enquanto a varredura ainda esta na linha-alvo,
;    depois libera (OUT com mascara C0h/80h/40h dependendo dos
;    bits 6/7 de B - provavelmente distingue tecla normal de
;    tecla com SHIFT, i.e. faz o SHIFT 'virtual' tambem).
; 5) Repete o ciclo de assert/release 2 vezes (E=02h) - reforco
;    para garantir que a controladora da maquina registre o toque
;    mesmo perdendo um ciclo de varredura.
; 6) Ao final, manda o padrao 'neutro'/ocioso C0h para a Porta A
;    (mesmo valor usado na inicializacao - o estado de repouso).
;
; CONFIANCA: ALTA. Fluxo limpo, coerente, sem ambiguidade de fase.
;==============================================================================
0586  79            LD A,C
0587  E6 C7         AND C7h
0589  47            LD B,A
058A  79            LD A,C
058B  E6 38         AND 38h
058D  4F            LD C,A
058E  1E 02         LD E,02h
0590  2E 02         LD L,02h
0592  26 23         LD H,23h
0594  DB 00         IN A,(00h)
0596  E6 38         AND 38h
0598  B9            CP C
0599  28 F9         JR Z,0594h
059B  DB 80         IN A,(80h)
059D  E6 01         AND 01h
059F  28 0F         JR Z,05B0h
05A1  DB 80         IN A,(80h)
05A3  E6 01         AND 01h
05A5  28 09         JR Z,05B0h
05A7  26 23         LD H,23h
05A9  7D            LD A,L
05AA  FE 01         CP 01h
05AC  20 0B         JR NZ,05B9h
05AE  18 08         JR 05B8h
05B0  7D            LD A,L
05B1  FE 02         CP 02h
05B3  20 04         JR NZ,05B9h
05B5  25            DEC H
05B6  20 01         JR NZ,05B9h
05B8  2D            DEC L
05B9  DB 00         IN A,(00h)
05BB  E6 38         AND 38h
05BD  B9            CP C
05BE  20 DB         JR NZ,059Bh
05C0  DB 00         IN A,(00h)
05C2  E6 38         AND 38h
05C4  B9            CP C
05C5  20 D4         JR NZ,059Bh
05C7  78            LD A,B
05C8  E6 BF         AND BFh
05CA  D3 00         OUT (00h),A
05CC  DB 80         IN A,(80h)
05CE  E6 01         AND 01h
05D0  28 0F         JR Z,05E1h
05D2  DB 80         IN A,(80h)
05D4  E6 01         AND 01h
05D6  28 09         JR Z,05E1h
05D8  26 23         LD H,23h
05DA  7D            LD A,L
05DB  FE 01         CP 01h
05DD  20 0B         JR NZ,05EAh
05DF  18 08         JR 05E9h
05E1  7D            LD A,L
05E2  FE 02         CP 02h
05E4  20 04         JR NZ,05EAh
05E6  25            DEC H
05E7  20 01         JR NZ,05EAh
05E9  2D            DEC L
05EA  DB 00         IN A,(00h)
05EC  E6 38         AND 38h
05EE  B9            CP C
05EF  28 DB         JR Z,05CCh
05F1  78            LD A,B
05F2  E6 40         AND 40h
05F4  20 07         JR NZ,05FDh
05F6  78            LD A,B
05F7  E6 80         AND 80h
05F9  F6 44         OR 44h
05FB  18 03         JR 0600h
05FD  78            LD A,B
05FE  E6 C0         AND C0h
0600  D3 00         OUT (00h),A
0602  1D            DEC E
0603  20 96         JR NZ,059Bh
0605  3E C0         LD A,C0h
0607  D3 00         OUT (00h),A
0609  D9            EXX
060A  79            LD A,C
060B  E6 0F         AND 0Fh
060D  D9            EXX
060E  5F            LD E,A
060F  DB 80         IN A,(80h)
0611  E6 01         AND 01h
0613  28 0F         JR Z,0624h
0615  DB 80         IN A,(80h)
0617  E6 01         AND 01h
0619  28 09         JR Z,0624h
061B  26 23         LD H,23h
061D  7D            LD A,L
061E  FE 01         CP 01h
0620  20 0B         JR NZ,062Dh
0622  18 08         JR 062Ch
0624  7D            LD A,L
0625  FE 02         CP 02h
0627  20 04         JR NZ,062Dh
0629  25            DEC H
062A  20 01         JR NZ,062Dh
062C  2D            DEC L
062D  DB 00         IN A,(00h)
062F  E6 38         AND 38h
0631  B9            CP C
0632  20 DB         JR NZ,060Fh
0634  DB 00         IN A,(00h)
0636  E6 38         AND 38h
0638  B9            CP C
0639  20 D4         JR NZ,060Fh
063B  1D            DEC E
063C  DB 80         IN A,(80h)
063E  E6 01         AND 01h
0640  28 0F         JR Z,0651h
0642  DB 80         IN A,(80h)
0644  E6 01         AND 01h
0646  28 09         JR Z,0651h
0648  26 23         LD H,23h
064A  7D            LD A,L
064B  FE 01         CP 01h
064D  20 0B         JR NZ,065Ah
064F  18 08         JR 0659h
0651  7D            LD A,L
0652  FE 02         CP 02h
0654  20 04         JR NZ,065Ah
0656  25            DEC H
0657  20 01         JR NZ,065Ah
0659  2D            DEC L
065A  7B            LD A,E
065B  B7            OR A
065C  28 09         JR Z,0667h
065E  DB 00         IN A,(00h)
0660  E6 38         AND 38h
0662  B9            CP C
0663  28 D7         JR Z,063Ch
0665  18 A8         JR 060Fh
0667  D9            EXX
0668  7A            LD A,D
0669  D9            EXX
066A  E6 80         AND 80h
066C  CA DB 16      JP Z,16DBh
066F  01 98 3A      LD BC,3A98h
0672  DB 80         IN A,(80h)
0674  E6 01         AND 01h
0676  28 0F         JR Z,0687h
0678  DB 80         IN A,(80h)
067A  E6 01         AND 01h
067C  28 09         JR Z,0687h
067E  26 23         LD H,23h
0680  7D            LD A,L
0681  FE 01         CP 01h
0683  20 0B         JR NZ,0690h
0685  18 08         JR 068Fh
0687  7D            LD A,L
0688  FE 02         CP 02h
068A  20 04         JR NZ,0690h
068C  25            DEC H
068D  20 01         JR NZ,0690h
068F  2D            DEC L
0690  7D            LD A,L
0691  B7            OR A
0692  28 05         JR Z,0699h
0694  0B            DEC BC
0695  78            LD A,B
0696  B1            OR C
0697  20 D9         JR NZ,0672h
0699  D9            EXX
069A  7A            LD A,D
069B  E6 F0         AND F0h
069D  57            LD D,A
069E  D9            EXX
069F  E6 10         AND 10h
06A1  20 55         JR NZ,06F8h
06A3  7A            LD A,D
06A4  FE 0D         CP 0Dh
06A6  28 04         JR Z,06ACh
06A8  FE 09         CP 09h
06AA  20 4C         JR NZ,06F8h
06AC  2E 02         LD L,02h
06AE  26 23         LD H,23h
06B0  DB 80         IN A,(80h)
06B2  E6 01         AND 01h
06B4  28 0F         JR Z,06C5h
06B6  DB 80         IN A,(80h)
06B8  E6 01         AND 01h
06BA  28 09         JR Z,06C5h
06BC  26 23         LD H,23h
06BE  7D            LD A,L
06BF  FE 01         CP 01h
06C1  20 0B         JR NZ,06CEh
06C3  18 08         JR 06CDh
06C5  7D            LD A,L
06C6  FE 02         CP 02h
06C8  20 04         JR NZ,06CEh
06CA  25            DEC H
06CB  20 01         JR NZ,06CEh
06CD  2D            DEC L
06CE  7D            LD A,L
06CF  FE 02         CP 02h
06D1  30 DD         JR NC,06B0h
06D3  21 AE 06      LD HL,06AEh
06D6  2B            DEC HL
06D7  7D            LD A,L
06D8  B4            OR H
06D9  20 FB         JR NZ,06D6h
06DB  7A            LD A,D
06DC  FE 0D         CP 0Dh
06DE  20 18         JR NZ,06F8h
06E0  08            EX AF,AF'
06E1  3E 00         LD A,00h
06E3  08            EX AF,AF'
06E4  D9            EXX
06E5  78            LD A,B
06E6  E6 7F         AND 7Fh
06E8  3D            DEC A
06E9  20 0B         JR NZ,06F6h
06EB  78            LD A,B
06EC  E6 80         AND 80h
06EE  47            LD B,A
06EF  7B            LD A,E
06F0  E6 7F         AND 7Fh
06F2  B0            OR B
06F3  47            LD B,A
06F4  18 01         JR 06F7h
06F6  05            DEC B
06F7  D9            EXX

;==============================================================================
; DESPACHO DE CARACTERES / CONTROLE DE COLUNA (06F8h-07A8h)
; Usa o registrador sombra D' como contador de coluna da folha
; (mascarado em 7 bits, ou seja 0-127 colunas - condizente com a
; largura de carro de uma maquina de escrever).
; Trata especialmente:
;   0Ch (FF)  -> 
;   08h (BS)  -> decrementa coluna
;   0Dh (CR)  -> zera bit da coluna; se posicao >= 2, chama a rotina
;                de tecla em 2586h
;   09h (TAB) -> soma 8 a coluna (tabulacao de 8 colunas) e chama
;                2586h
;   outros    -> incrementa coluna e chama 2586h
;
; NOTA IMPORTANTE sobre os enderecos '2586h', '1CCCh', '3C44h' etc:
; Esses saltos ficam FORA do intervalo 0000h-0FFFh desta ROM de 4KB.
; Confirmei que 2586h MOD 1000h = 0586h - exatamente o endereco da
; rotina de toque de tecla acima! O mesmo vale para os outros casos
; (3C44h->0C44h, 3C58h->0C58h, 3C61h->0C61h, 1CCCh->0CCCh), todos
; caindo em codigo real e coerente desta mesma imagem.
;
; CONFIRMADO PELO HARDWARE: o CI desta ROM e um HN462732G (Hitachi,
; compativel 2732) - 24 pinos, 4096x8 bits, com APENAS 12 linhas de
; endereco fisicas (A0-A11). O chip nao tem pinos A12-A15; essas linhas
; do Z80 simplesmente nao chegam a ele. Sem um circuito adicional de
; selecao de banco amarrando o /CE do 2732 as linhas altas (o que nao
; existe numa placa minimalista de 3 CIs como esta), o resultado
; INEVITAVEL e que os mesmos 4096 bytes respondem em TODAS as 16
; janelas de 4KB do mapa de 64KB do Z80 (0000h, 1000h, 2000h, ...,
; F000h - todas leem o mesmo conteudo). Nao e decodificacao parcial
; 'econômica', e simplesmente o chip fisico nao tendo esses pinos.
; O firmware provavelmente foi portado de uma versao com mapa de
; memoria maior, e os enderecos absolutos com bits altos 'sobrando'
; nunca foram corrigidos - nao precisavam, gracas ao espelhamento.
;==============================================================================
06F8  21 51 ED      LD HL,ED51h
06FB  39            ADD HL,SP
06FC  E9            JP (HL)
06FD  D9            EXX
06FE  7A            LD A,D
06FF  F6 80         OR 80h
0701  57            LD D,A
0702  D9            EXX
0703  7A            LD A,D
0704  FE 0C         CP 0Ch
0706  20 15         JR NZ,071Dh
0708  31 BE 19      LD SP,19BEh
070B  16 0D         LD D,0Dh
070D  18 EE         JR 06FDh
070F  D9            EXX
0710  78            LD A,B
0711  E6 7F         AND 7Fh
0713  FE 01         CP 01h
0715  D9            EXX
0716  31 91 16      LD SP,1691h
0719  28 F0         JR Z,070Bh
071B  18 EB         JR 0708h
071D  FE 08         CP 08h
071F  20 16         JR NZ,0737h
0721  1E 0A         LD E,0Ah
0723  08            EX AF,AF'
0724  4F            LD C,A
0725  08            EX AF,AF'
0726  79            LD A,C
0727  B7            OR A
0728  28 CE         JR Z,06F8h
072A  08            EX AF,AF'
072B  3D            DEC A
072C  08            EX AF,AF'
072D  D9            EXX
072E  7A            LD A,D
072F  E6 7F         AND 7Fh
0731  57            LD D,A
0732  D9            EXX
0733  0E C6         LD C,C6h
0735  18 30         JR 0767h
0737  FE 0D         CP 0Dh
0739  20 1B         JR NZ,0756h
073B  D9            EXX
073C  7A            LD A,D
073D  E6 BF         AND BFh
073F  57            LD D,A
0740  D9            EXX
0741  0E C2         LD C,C2h
0743  08            EX AF,AF'
0744  5F            LD E,A
0745  08            EX AF,AF'
0746  7B            LD A,E
0747  FE 02         CP 02h
0749  D2 86 25      JP NC,2586h
074C  D9            EXX
074D  7A            LD A,D
074E  E6 7F         AND 7Fh
0750  57            LD D,A
0751  D9            EXX
0752  1E 0F         LD E,0Fh
0754  18 11         JR 0767h
0756  FE 09         CP 09h
0758  0E FB         LD C,FBh
075A  20 07         JR NZ,0763h
075C  08            EX AF,AF'
075D  C6 08         ADD A,08h
075F  08            EX AF,AF'
0760  C3 86 25      JP 2586h
0763  18 93         JR 06F8h
0765  1E 07         LD E,07h
0767  D9            EXX
0768  7A            LD A,D
0769  E6 08         AND 08h
076B  20 09         JR NZ,0776h
076D  14            INC D
076E  7A            LD A,D
076F  E6 7F         AND 7Fh
0771  57            LD D,A
0772  D9            EXX
0773  C3 86 25      JP 2586h
0776  79            LD A,C
0777  E6 F0         AND F0h
0779  D9            EXX
077A  B3            OR E
077B  D9            EXX
077C  4F            LD C,A
077D  18 EF         JR 076Eh
077F  D9            EXX
0780  18 EC         JR 076Eh

;==============================================================================
; INICIO DA IMPRESSAO DO BANNER/AUTOTESTE (0782h)
; So chega aqui se a condicao de gatilho em 023Ch (bit7 da Porta A)
; foi satisfeita - ver comentario detalhado la.
; Reconfigura a Porta A (mesma sequencia CFh/38h/07h/C0h vista na
; inicializacao) - provavelmente re-arma o modo 3 antes de comecar a
; imprimir o banner/autoteste, seguido de delay (loop 1E x 1644h) e
; entao HL=0843h (endereco do texto do banner) e C=40h.
; A partir de 07A8h, le (HL) caractere a caractere e empurra cada um
; pela MESMA pipeline de despacho usada para bytes vindos do host
; (mesmo registrador D, mesma logica em 02CBh/06F8h) - o autoteste
; 'digita' o banner usando a mesma rotina de toque de tecla (0586h).
;==============================================================================
0782  3E CF         LD A,CFh
0784  D3 02         OUT (02h),A
0786  3E 38         LD A,38h
0788  D3 02         OUT (02h),A
078A  3E 07         LD A,07h
078C  D3 02         OUT (02h),A
078E  3E C0         LD A,C0h
0790  D3 00         OUT (00h),A
0792  DB 00         IN A,(00h)
0794  06 1E         LD B,1Eh
0796  21 44 16      LD HL,1644h
0799  2B            DEC HL
079A  7D            LD A,L
079B  B4            OR H
079C  20 FB         JR NZ,0799h
079E  05            DEC B
079F  20 F5         JR NZ,0796h
07A1  D9            EXX
07A2  0E 40         LD C,40h
07A4  21 43 08      LD HL,0843h
07A7  D9            EXX
07A8  D9            EXX
07A9  7E            LD A,(HL)
07AA  23            INC HL
07AB  D9            EXX
07AC  57            LD D,A
07AD  FE 00         CP 00h
07AF  CA C4 07      JP Z,07C4h
07B2  E6 80         AND 80h
07B4  CA CB 02      JP Z,02CBh
07B7  D9            EXX
07B8  7A            LD A,D
07B9  F6 10         OR 10h
07BB  57            LD D,A
07BC  D9            EXX
07BD  7A            LD A,D
07BE  E6 7F         AND 7Fh
07C0  57            LD D,A
07C1  C3 CB 22      JP 22CBh
07C4  D3 02         OUT (02h),A
07C6  3E CF         LD A,CFh
07C8  D3 02         OUT (02h),A
07CA  3E B8         LD A,B8h
07CC  D3 02         OUT (02h),A
07CE  3E 07         LD A,07h
07D0  D3 02         OUT (02h),A
07D2  3E 40         LD A,40h
07D4  D3 00         OUT (00h),A
07D6  DB 00         IN A,(00h)
07D8  D9            EXX
07D9  0E 00         LD C,00h
07DB  D9            EXX
07DC  DB 00         IN A,(00h)
07DE  E6 80         AND 80h
07E0  20 04         JR NZ,07E6h
07E2  D9            EXX
07E3  0E 10         LD C,10h
07E5  D9            EXX
07E6  3E CF         LD A,CFh
07E8  D3 02         OUT (02h),A
07EA  3E 38         LD A,38h
07EC  D3 02         OUT (02h),A
07EE  3E 07         LD A,07h
07F0  D3 02         OUT (02h),A
07F2  3E C0         LD A,C0h
07F4  D3 00         OUT (00h),A
07F6  DB 00         IN A,(00h)
07F8  D9            EXX
07F9  79            LD A,C
07FA  D9            EXX
07FB  E6 10         AND 10h
07FD  0E 00         LD C,00h
07FF  C2 04 08      JP NZ,0804h
0802  0E C3         LD C,C3h
0804  31 B9 1A      LD SP,1AB9h
0807  C3 61 0C      JP 0C61h
080A  D9            EXX
080B  79            LD A,C
080C  D9            EXX
080D  E6 10         AND 10h
080F  CA 22 08      JP Z,0822h
0812  06 1E         LD B,1Eh
0814  21 44 16      LD HL,1644h
0817  2B            DEC HL
0818  7D            LD A,L
0819  B4            OR H
081A  20 FB         JR NZ,0817h
081C  05            DEC B
081D  20 F5         JR NZ,0814h
081F  C3 A1 07      JP 07A1h
0822  06 0A         LD B,0Ah
0824  21 AE 06      LD HL,06AEh
0827  2B            DEC HL
0828  7D            LD A,L
0829  B4            OR H
082A  20 FB         JR NZ,0827h
082C  05            DEC B
082D  20 F5         JR NZ,0824h
082F  3E 40         LD A,40h
0831  D3 00         OUT (00h),A
0833  06 0A         LD B,0Ah
0835  21 AE 06      LD HL,06AEh
0838  2B            DEC HL
0839  7D            LD A,L
083A  B4            OR H
083B  20 FB         JR NZ,0838h
083D  05            DEC B
083E  20 F5         JR NZ,0835h
0840  C3 C4 07      JP 07C4h

;==============================================================================
; ===== BLOCO DE DADOS: BANNER + PADRAO DE AUTOTESTE (0843h-0BBDh) =====
; Nao e codigo - e uma STRING/tabela enviada caractere a caractere
; pela rotina de toque de tecla (0586h), fazendo a Olivetti 'digitar'
; sozinha este texto quando ligada (autoteste de fabrica).
;
; Texto revelado (ASCII), moldura + identificacao do produto:
;
;   +-----------------------------------+
;   |                                   |
;   |  HD - SIST. ELET. IND E COM LTDA  |
;   |                                   |
;   |            INTERFAX 20            |
;   |          REV HARDWARE 01          |
;   |       REV SOFTWARE  8220301       |
;   |                                   |
;   |           Versao ABNT             |
;   |                                   |
;   +-----------------------------------+
;
;   AUTO TESTE
;
; Seguido por padroes repetidos de digitos '7278747579717673737671...'
; (parece testar as teclas numericas) e depois grupos 'BK BX B$ BY
; BW BH BG BU BQ BM BD BL BP BN BC BT BR BI SE SI B' repetidos varias
; vezes - muito provavelmente cada par de caracteres codifica uma
; posicao (linha,coluna) da matriz sendo varrida sequencialmente,
; teste de fabrica para verificar TODAS as teclas/posicoes.
; (o disassembler abaixo ainda mostra estes bytes como 'instrucoes',
;  varredura linear cega - e tudo DADO/TEXTO, nao codigo)
;==============================================================================
0843  0D            DEC C
0844  0D            DEC C
0845  2B            DEC HL
0846  2D            DEC L
0847  2D            DEC L
0848  2D            DEC L
0849  2D            DEC L
084A  2D            DEC L
084B  2D            DEC L
084C  2D            DEC L
084D  2D            DEC L
084E  2D            DEC L
084F  2D            DEC L
0850  2D            DEC L
0851  2D            DEC L
0852  2D            DEC L
0853  2D            DEC L
0854  2D            DEC L
0855  2D            DEC L
0856  2D            DEC L
0857  2D            DEC L
0858  2D            DEC L
0859  2D            DEC L
085A  2D            DEC L
085B  2D            DEC L
085C  2D            DEC L
085D  2D            DEC L
085E  2D            DEC L
085F  2D            DEC L
0860  2D            DEC L
0861  2D            DEC L
0862  2D            DEC L
0863  2D            DEC L
0864  2D            DEC L
0865  2D            DEC L
0866  2D            DEC L
0867  2D            DEC L
0868  2D            DEC L
0869  2B            DEC HL
086A  0D            DEC C
086B  7C            LD A,H
086C  20 20         JR NZ,088Eh
086E  20 20         JR NZ,0890h
0870  20 20         JR NZ,0892h
0872  20 20         JR NZ,0894h
0874  20 20         JR NZ,0896h
0876  20 20         JR NZ,0898h
0878  20 20         JR NZ,089Ah
087A  20 20         JR NZ,089Ch
087C  20 20         JR NZ,089Eh
087E  20 20         JR NZ,08A0h
0880  20 20         JR NZ,08A2h
0882  20 20         JR NZ,08A4h
0884  20 20         JR NZ,08A6h
0886  20 20         JR NZ,08A8h
0888  20 20         JR NZ,08AAh
088A  20 20         JR NZ,08ACh
088C  20 20         JR NZ,08AEh
088E  20 7C         JR NZ,090Ch
0890  0D            DEC C
0891  7C            LD A,H
0892  20 20         JR NZ,08B4h
0894  48            LD C,B
0895  44            LD B,H
0896  20 2D         JR NZ,08C5h
0898  20 53         JR NZ,08EDh
089A  49            LD C,C
089B  53            LD D,E
089C  54            LD D,H
089D  2E 20         LD L,20h
089F  45            LD B,L
08A0  4C            LD C,H
08A1  45            LD B,L
08A2  54            LD D,H
08A3  2E 20         LD L,20h
08A5  49            LD C,C
08A6  4E            LD C,(HL)
08A7  44            LD B,H
08A8  20 45         JR NZ,08EFh
08AA  20 43         JR NZ,08EFh
08AC  4F            LD C,A
08AD  4D            LD C,L
08AE  20 4C         JR NZ,08FCh
08B0  54            LD D,H
08B1  44            LD B,H
08B2  41            LD B,C
08B3  20 20         JR NZ,08D5h
08B5  7C            LD A,H
08B6  0D            DEC C
08B7  7C            LD A,H
08B8  20 20         JR NZ,08DAh
08BA  20 20         JR NZ,08DCh
08BC  20 20         JR NZ,08DEh
08BE  20 20         JR NZ,08E0h
08C0  20 20         JR NZ,08E2h
08C2  20 20         JR NZ,08E4h
08C4  20 20         JR NZ,08E6h
08C6  20 20         JR NZ,08E8h
08C8  20 20         JR NZ,08EAh
08CA  20 20         JR NZ,08ECh
08CC  20 20         JR NZ,08EEh
08CE  20 20         JR NZ,08F0h
08D0  20 20         JR NZ,08F2h
08D2  20 20         JR NZ,08F4h
08D4  20 20         JR NZ,08F6h
08D6  20 20         JR NZ,08F8h
08D8  20 20         JR NZ,08FAh
08DA  20 7C         JR NZ,0958h
08DC  0D            DEC C
08DD  7C            LD A,H
08DE  20 20         JR NZ,0900h
08E0  20 20         JR NZ,0902h
08E2  20 20         JR NZ,0904h
08E4  20 20         JR NZ,0906h
08E6  20 20         JR NZ,0908h
08E8  20 20         JR NZ,090Ah
08EA  49            LD C,C
08EB  4E            LD C,(HL)
08EC  54            LD D,H
08ED  45            LD B,L
08EE  52            LD D,D
08EF  46            LD B,(HL)
08F0  41            LD B,C
08F1  58            LD E,B
08F2  20 32         JR NZ,0926h
08F4  30 20         JR NC,0916h
08F6  20 20         JR NZ,0918h
08F8  20 20         JR NZ,091Ah
08FA  20 20         JR NZ,091Ch
08FC  20 20         JR NZ,091Eh
08FE  20 20         JR NZ,0920h
0900  20 7C         JR NZ,097Eh
0902  0D            DEC C
0903  7C            LD A,H
0904  20 20         JR NZ,0926h
0906  20 20         JR NZ,0928h
0908  20 20         JR NZ,092Ah
090A  20 20         JR NZ,092Ch
090C  20 20         JR NZ,092Eh
090E  52            LD D,D
090F  45            LD B,L
0910  56            LD D,(HL)
0911  20 48         JR NZ,095Bh
0913  41            LD B,C
0914  52            LD D,D
0915  44            LD B,H
0916  57            LD D,A
0917  41            LD B,C
0918  52            LD D,D
0919  45            LD B,L
091A  20 30         JR NZ,094Ch
091C  31 20 20      LD SP,2020h
091F  20 20         JR NZ,0941h
0921  20 20         JR NZ,0943h
0923  20 20         JR NZ,0945h
0925  20 20         JR NZ,0947h
0927  7C            LD A,H
0928  0D            DEC C
0929  7C            LD A,H
092A  20 20         JR NZ,094Ch
092C  20 20         JR NZ,094Eh
092E  20 20         JR NZ,0950h
0930  20 52         JR NZ,0984h
0932  45            LD B,L
0933  56            LD D,(HL)
0934  20 53         JR NZ,0989h
0936  4F            LD C,A
0937  46            LD B,(HL)
0938  54            LD D,H
0939  57            LD D,A
093A  41            LD B,C
093B  52            LD D,D
093C  45            LD B,L
093D  20 20         JR NZ,095Fh
093F  38 32         JR C,0973h
0941  32 30 33      LD (3330h),A
0944  30 31         JR NC,0977h
0946  20 20         JR NZ,0968h
0948  20 20         JR NZ,096Ah
094A  20 20         JR NZ,096Ch
094C  20 7C         JR NZ,09CAh
094E  0D            DEC C
094F  7C            LD A,H
0950  20 20         JR NZ,0972h
0952  20 20         JR NZ,0974h
0954  20 20         JR NZ,0976h
0956  20 20         JR NZ,0978h
0958  20 20         JR NZ,097Ah
095A  20 20         JR NZ,097Ch
095C  20 20         JR NZ,097Eh
095E  20 20         JR NZ,0980h
0960  20 20         JR NZ,0982h
0962  20 20         JR NZ,0984h
0964  20 20         JR NZ,0986h
0966  20 20         JR NZ,0988h
0968  20 20         JR NZ,098Ah
096A  20 20         JR NZ,098Ch
096C  20 20         JR NZ,098Eh
096E  20 20         JR NZ,0990h
0970  20 20         JR NZ,0992h
0972  20 7C         JR NZ,09F0h
0974  0D            DEC C
0975  7C            LD A,H
0976  20 20         JR NZ,0998h
0978  20 20         JR NZ,099Ah
097A  20 20         JR NZ,099Ch
097C  20 20         JR NZ,099Eh
097E  20 20         JR NZ,09A0h
0980  20 56         JR NZ,09D8h
0982  65            LD H,L
0983  72            LD (HL),D
0984  73            LD (HL),E
0985  61            LD H,C
0986  6F            LD L,A
0987  20 41         JR NZ,09CAh
0989  42            LD B,D
098A  4E            LD C,(HL)
098B  54            LD D,H
098C  20 20         JR NZ,09AEh
098E  20 20         JR NZ,09B0h
0990  20 20         JR NZ,09B2h
0992  20 20         JR NZ,09B4h
0994  20 20         JR NZ,09B6h
0996  20 20         JR NZ,09B8h
0998  20 7C         JR NZ,0A16h
099A  0D            DEC C
099B  7C            LD A,H
099C  20 20         JR NZ,09BEh
099E  20 20         JR NZ,09C0h
09A0  20 20         JR NZ,09C2h
09A2  20 20         JR NZ,09C4h
09A4  20 20         JR NZ,09C6h
09A6  20 20         JR NZ,09C8h
09A8  20 20         JR NZ,09CAh
09AA  20 20         JR NZ,09CCh
09AC  20 20         JR NZ,09CEh
09AE  20 20         JR NZ,09D0h
09B0  20 20         JR NZ,09D2h
09B2  20 20         JR NZ,09D4h
09B4  20 20         JR NZ,09D6h
09B6  20 20         JR NZ,09D8h
09B8  20 20         JR NZ,09DAh
09BA  20 20         JR NZ,09DCh
09BC  20 20         JR NZ,09DEh
09BE  20 7C         JR NZ,0A3Ch
09C0  0D            DEC C
09C1  2B            DEC HL
09C2  2D            DEC L
09C3  2D            DEC L
09C4  2D            DEC L
09C5  2D            DEC L
09C6  2D            DEC L
09C7  2D            DEC L
09C8  2D            DEC L
09C9  2D            DEC L
09CA  2D            DEC L
09CB  2D            DEC L
09CC  2D            DEC L
09CD  2D            DEC L
09CE  2D            DEC L
09CF  2D            DEC L
09D0  2D            DEC L
09D1  2D            DEC L
09D2  2D            DEC L
09D3  2D            DEC L
09D4  2D            DEC L
09D5  2D            DEC L
09D6  2D            DEC L
09D7  2D            DEC L
09D8  2D            DEC L
09D9  2D            DEC L
09DA  2D            DEC L
09DB  2D            DEC L
09DC  2D            DEC L
09DD  2D            DEC L
09DE  2D            DEC L
09DF  2D            DEC L
09E0  2D            DEC L
09E1  2D            DEC L
09E2  2D            DEC L
09E3  2D            DEC L
09E4  2D            DEC L
09E5  2B            DEC HL
09E6  0D            DEC C
09E7  0D            DEC C
09E8  0A            LD A,(BC)
09E9  41            LD B,C
09EA  55            LD D,L
09EB  54            LD D,H
09EC  4F            LD C,A
09ED  20 54         JR NZ,0A43h
09EF  45            LD B,L
09F0  53            LD D,E
09F1  54            LD D,H
09F2  45            LD B,L
09F3  0D            DEC C
09F4  37            SCF
09F5  32 37 38      LD (3837h),A
09F8  37            SCF
09F9  34            INC (HL)
09FA  37            SCF
09FB  35            DEC (HL)
09FC  37            SCF
09FD  39            ADD HL,SP
09FE  37            SCF
09FF  31 37 36      LD SP,3637h
0A02  37            SCF
0A03  33            INC SP
0A04  37            SCF
0A05  33            INC SP
0A06  37            SCF
0A07  36 37         LD (HL),37h
0A09  31 37 39      LD SP,3937h
0A0C  37            SCF
0A0D  35            DEC (HL)
0A0E  37            SCF
0A0F  34            INC (HL)
0A10  37            SCF
0A11  38 37         JR C,0A4Ah
0A13  32 37 0D      LD (0D37h),A
0A16  37            SCF
0A17  32 37 38      LD (3837h),A
0A1A  37            SCF
0A1B  34            INC (HL)
0A1C  37            SCF
0A1D  35            DEC (HL)
0A1E  37            SCF
0A1F  39            ADD HL,SP
0A20  37            SCF
0A21  31 37 36      LD SP,3637h
0A24  37            SCF
0A25  33            INC SP
0A26  37            SCF
0A27  33            INC SP
0A28  37            SCF
0A29  36 37         LD (HL),37h
0A2B  31 37 39      LD SP,3937h
0A2E  37            SCF
0A2F  35            DEC (HL)
0A30  37            SCF
0A31  34            INC (HL)
0A32  37            SCF
0A33  38 37         JR C,0A6Ch
0A35  32 37 0D      LD (0D37h),A
0A38  37            SCF
0A39  32 37 38      LD (3837h),A
0A3C  37            SCF
0A3D  34            INC (HL)
0A3E  37            SCF
0A3F  35            DEC (HL)
0A40  37            SCF
0A41  39            ADD HL,SP
0A42  37            SCF
0A43  31 37 36      LD SP,3637h
0A46  37            SCF
0A47  33            INC SP
0A48  37            SCF
0A49  33            INC SP
0A4A  37            SCF
0A4B  36 37         LD (HL),37h
0A4D  31 37 39      LD SP,3937h
0A50  37            SCF
0A51  35            DEC (HL)
0A52  37            SCF
0A53  34            INC (HL)
0A54  37            SCF
0A55  38 37         JR C,0A8Eh
0A57  32 37 0D      LD (0D37h),A
0A5A  37            SCF
0A5B  33            INC SP
0A5C  37            SCF
0A5D  36 37         LD (HL),37h
0A5F  31 37 39      LD SP,3937h
0A62  37            SCF
0A63  35            DEC (HL)
0A64  37            SCF
0A65  34            INC (HL)
0A66  37            SCF
0A67  38 37         JR C,0AA0h
0A69  32 37 32      LD (3237h),A
0A6C  37            SCF
0A6D  38 37         JR C,0AA6h
0A6F  34            INC (HL)
0A70  37            SCF
0A71  35            DEC (HL)
0A72  37            SCF
0A73  39            ADD HL,SP
0A74  37            SCF
0A75  31 37 36      LD SP,3637h
0A78  37            SCF
0A79  33            INC SP
0A7A  37            SCF
0A7B  0D            DEC C
0A7C  37            SCF
0A7D  33            INC SP
0A7E  37            SCF
0A7F  36 37         LD (HL),37h
0A81  31 37 39      LD SP,3937h
0A84  37            SCF
0A85  35            DEC (HL)
0A86  37            SCF
0A87  34            INC (HL)
0A88  37            SCF
0A89  38 37         JR C,0AC2h
0A8B  32 37 32      LD (3237h),A
0A8E  37            SCF
0A8F  38 37         JR C,0AC8h
0A91  34            INC (HL)
0A92  37            SCF
0A93  35            DEC (HL)
0A94  37            SCF
0A95  39            ADD HL,SP
0A96  37            SCF
0A97  31 37 36      LD SP,3637h
0A9A  37            SCF
0A9B  33            INC SP
0A9C  37            SCF
0A9D  0D            DEC C
0A9E  37            SCF
0A9F  33            INC SP
0AA0  37            SCF
0AA1  36 37         LD (HL),37h
0AA3  31 37 39      LD SP,3937h
0AA6  37            SCF
0AA7  35            DEC (HL)
0AA8  37            SCF
0AA9  34            INC (HL)
0AAA  37            SCF
0AAB  38 37         JR C,0AE4h
0AAD  32 37 32      LD (3237h),A
0AB0  37            SCF
0AB1  38 37         JR C,0AEAh
0AB3  34            INC (HL)
0AB4  37            SCF
0AB5  35            DEC (HL)
0AB6  37            SCF
0AB7  39            ADD HL,SP
0AB8  37            SCF
0AB9  31 37 36      LD SP,3637h
0ABC  37            SCF
0ABD  33            INC SP
0ABE  37            SCF
0ABF  0D            DEC C
0AC0  42            LD B,D
0AC1  4B            LD C,E
0AC2  42            LD B,D
0AC3  58            LD E,B
0AC4  42            LD B,D
0AC5  24            INC H
0AC6  42            LD B,D
0AC7  59            LD E,C
0AC8  42            LD B,D
0AC9  57            LD D,A
0ACA  42            LD B,D
0ACB  48            LD C,B
0ACC  42            LD B,D
0ACD  47            LD B,A
0ACE  42            LD B,D
0ACF  55            LD D,L
0AD0  42            LD B,D
0AD1  51            LD D,C
0AD2  42            LD B,D
0AD3  4D            LD C,L
0AD4  42            LD B,D
0AD5  44            LD B,H
0AD6  42            LD B,D
0AD7  4C            LD C,H
0AD8  42            LD B,D
0AD9  50            LD D,B
0ADA  42            LD B,D
0ADB  4E            LD C,(HL)
0ADC  42            LD B,D
0ADD  43            LD B,E
0ADE  42            LD B,D
0ADF  54            LD D,H
0AE0  42            LD B,D
0AE1  52            LD D,D
0AE2  42            LD B,D
0AE3  49            LD C,C
0AE4  53            LD D,E
0AE5  45            LD B,L
0AE6  53            LD D,E
0AE7  49            LD C,C
0AE8  42            LD B,D
0AE9  0D            DEC C
0AEA  42            LD B,D
0AEB  4B            LD C,E
0AEC  42            LD B,D
0AED  58            LD E,B
0AEE  42            LD B,D
0AEF  24            INC H
0AF0  42            LD B,D
0AF1  59            LD E,C
0AF2  42            LD B,D
0AF3  57            LD D,A
0AF4  42            LD B,D
0AF5  48            LD C,B
0AF6  42            LD B,D
0AF7  47            LD B,A
0AF8  42            LD B,D
0AF9  55            LD D,L
0AFA  42            LD B,D
0AFB  51            LD D,C
0AFC  42            LD B,D
0AFD  4D            LD C,L
0AFE  42            LD B,D
0AFF  44            LD B,H
0B00  42            LD B,D
0B01  4C            LD C,H
0B02  42            LD B,D
0B03  50            LD D,B
0B04  42            LD B,D
0B05  4E            LD C,(HL)
0B06  42            LD B,D
0B07  43            LD B,E
0B08  42            LD B,D
0B09  54            LD D,H
0B0A  42            LD B,D
0B0B  52            LD D,D
0B0C  42            LD B,D
0B0D  49            LD C,C
0B0E  53            LD D,E
0B0F  45            LD B,L
0B10  53            LD D,E
0B11  49            LD C,C
0B12  42            LD B,D
0B13  0D            DEC C
0B14  42            LD B,D
0B15  4B            LD C,E
0B16  42            LD B,D
0B17  58            LD E,B
0B18  42            LD B,D
0B19  24            INC H
0B1A  42            LD B,D
0B1B  59            LD E,C
0B1C  42            LD B,D
0B1D  57            LD D,A
0B1E  42            LD B,D
0B1F  48            LD C,B
0B20  42            LD B,D
0B21  47            LD B,A
0B22  42            LD B,D
0B23  55            LD D,L
0B24  42            LD B,D
0B25  51            LD D,C
0B26  42            LD B,D
0B27  4D            LD C,L
0B28  42            LD B,D
0B29  44            LD B,H
0B2A  42            LD B,D
0B2B  4C            LD C,H
0B2C  42            LD B,D
0B2D  50            LD D,B
0B2E  42            LD B,D
0B2F  4E            LD C,(HL)
0B30  42            LD B,D
0B31  43            LD B,E
0B32  42            LD B,D
0B33  54            LD D,H
0B34  42            LD B,D
0B35  52            LD D,D
0B36  42            LD B,D
0B37  49            LD C,C
0B38  53            LD D,E
0B39  45            LD B,L
0B3A  53            LD D,E
0B3B  49            LD C,C
0B3C  42            LD B,D
0B3D  0D            DEC C
0B3E  42            LD B,D
0B3F  4B            LD C,E
0B40  42            LD B,D
0B41  58            LD E,B
0B42  42            LD B,D
0B43  24            INC H
0B44  42            LD B,D
0B45  59            LD E,C
0B46  42            LD B,D
0B47  57            LD D,A
0B48  42            LD B,D
0B49  48            LD C,B
0B4A  42            LD B,D
0B4B  47            LD B,A
0B4C  42            LD B,D
0B4D  55            LD D,L
0B4E  42            LD B,D
0B4F  51            LD D,C
0B50  42            LD B,D
0B51  4D            LD C,L
0B52  42            LD B,D
0B53  44            LD B,H
0B54  42            LD B,D
0B55  4C            LD C,H
0B56  42            LD B,D
0B57  50            LD D,B
0B58  42            LD B,D
0B59  4E            LD C,(HL)
0B5A  42            LD B,D
0B5B  43            LD B,E
0B5C  42            LD B,D
0B5D  54            LD D,H
0B5E  42            LD B,D
0B5F  52            LD D,D
0B60  42            LD B,D
0B61  49            LD C,C
0B62  53            LD D,E
0B63  45            LD B,L
0B64  53            LD D,E
0B65  49            LD C,C
0B66  42            LD B,D
0B67  0D            DEC C
0B68  42            LD B,D
0B69  4B            LD C,E
0B6A  42            LD B,D
0B6B  58            LD E,B
0B6C  42            LD B,D
0B6D  24            INC H
0B6E  42            LD B,D
0B6F  59            LD E,C
0B70  42            LD B,D
0B71  57            LD D,A
0B72  42            LD B,D
0B73  48            LD C,B
0B74  42            LD B,D
0B75  47            LD B,A
0B76  42            LD B,D
0B77  55            LD D,L
0B78  42            LD B,D
0B79  51            LD D,C
0B7A  42            LD B,D
0B7B  4D            LD C,L
0B7C  42            LD B,D
0B7D  44            LD B,H
0B7E  42            LD B,D
0B7F  4C            LD C,H
0B80  42            LD B,D
0B81  50            LD D,B
0B82  42            LD B,D
0B83  4E            LD C,(HL)
0B84  42            LD B,D
0B85  43            LD B,E
0B86  42            LD B,D
0B87  54            LD D,H
0B88  42            LD B,D
0B89  52            LD D,D
0B8A  42            LD B,D
0B8B  49            LD C,C
0B8C  53            LD D,E
0B8D  45            LD B,L
0B8E  53            LD D,E
0B8F  49            LD C,C
0B90  42            LD B,D
0B91  0D            DEC C
0B92  42            LD B,D
0B93  4B            LD C,E
0B94  42            LD B,D
0B95  58            LD E,B
0B96  42            LD B,D
0B97  24            INC H
0B98  42            LD B,D
0B99  59            LD E,C
0B9A  42            LD B,D
0B9B  57            LD D,A
0B9C  42            LD B,D
0B9D  48            LD C,B
0B9E  42            LD B,D
0B9F  47            LD B,A
0BA0  42            LD B,D
0BA1  55            LD D,L
0BA2  42            LD B,D
0BA3  51            LD D,C
0BA4  42            LD B,D
0BA5  4D            LD C,L
0BA6  42            LD B,D
0BA7  44            LD B,H
0BA8  42            LD B,D
0BA9  4C            LD C,H
0BAA  42            LD B,D
0BAB  50            LD D,B
0BAC  42            LD B,D
0BAD  4E            LD C,(HL)
0BAE  42            LD B,D
0BAF  43            LD B,E
0BB0  42            LD B,D
0BB1  54            LD D,H
0BB2  42            LD B,D
0BB3  52            LD D,D
0BB4  42            LD B,D
0BB5  49            LD C,C
0BB6  53            LD D,E
0BB7  45            LD B,L
0BB8  53            LD D,E
0BB9  49            LD C,C
0BBA  42            LD B,D
0BBB  0D            DEC C
0BBC  0D            DEC C
0BBD  00            NOP

;--- fim do texto/tabela de autoteste; a partir daqui volta a haver
;    trechos de codigo real misturados com mais dados (ver 0BFEh)
0BBE  D9            EXX
0BBF  21 C6 EB      LD HL,EBC6h
0BC2  D9            EXX
0BC3  C3 44 3C      JP 3C44h
0BC6  C2 FB FD      JP NZ,FDFBh
0BC9  FB            EI
0BCA  FD FB         EI
0BCC  FD FB         EI
0BCE  FD FB         EI
0BD0  FD FB         EI
0BD2  FD FB         EI
0BD4  FD FB         EI
0BD6  FD FB         EI
0BD8  FD FB         EI
0BDA  FD C2 00 0E   JP NZ,0E00h
0BDE  C2 16 0D      JP NZ,0D16h
0BE1  31 96 1E      LD SP,1E96h
0BE4  C3 61 0C      JP 0C61h
0BE7  0E FA         LD C,FAh
0BE9  31 9E 1E      LD SP,1E9Eh
0BEC  C3 61 0C      JP 0C61h
0BEF  D9            EXX
0BF0  21 5A 00      LD HL,005Ah
0BF3  D9            EXX
0BF4  3E C6         LD A,C6h
0BF6  E6 C7         AND C7h
0BF8  47            LD B,A
0BF9  3E C6         LD A,C6h
0BFB  E6 38         AND 38h
0BFD  4F            LD C,A

;==============================================================================
; VARIANTE/SIMPLIFICACAO DA ROTINA DE TOQUE DE TECLA (0BFEh)
; Mesma ideia da rotina em 0586h (espera a linha C ficar ativa na
; Porta A, assere bit 6, espera terminar, libera com mascara C0h)
; porem SEM a logica extra de monitorar o bit0/status e sem repetir
; o pulso 2x. Possivelmente usada durante o autoteste (mais simples,
; ja que aqui nao ha por que ser tao robusto quanto na operacao real).
;==============================================================================
0BFE  DB 00         IN A,(00h)
0C00  E6 38         AND 38h
0C02  B9            CP C
0C03  20 F9         JR NZ,0BFEh
0C05  DB 00         IN A,(00h)
0C07  E6 38         AND 38h
0C09  B9            CP C
0C0A  20 F2         JR NZ,0BFEh
0C0C  78            LD A,B
0C0D  E6 BF         AND BFh
0C0F  D3 00         OUT (00h),A
0C11  DB 00         IN A,(00h)
0C13  E6 38         AND 38h
0C15  B9            CP C
0C16  28 F9         JR Z,0C11h
0C18  78            LD A,B
0C19  E6 C0         AND C0h
0C1B  D3 00         OUT (00h),A
0C1D  D9            EXX
0C1E  2B            DEC HL
0C1F  7D            LD A,L
0C20  B4            OR H
0C21  D9            EXX
0C22  20 DA         JR NZ,0BFEh
0C24  D9            EXX
0C25  21 2B EC      LD HL,EC2Bh
0C28  D9            EXX
0C29  18 19         JR 0C44h
0C2B  FE FB         CP FBh
0C2D  FD FA FB FD   JP M,FDFBh
0C31  FA FB FD      JP M,FDFBh
0C34  FA FB FD      JP M,FDFBh
0C37  FA FB FD      JP M,FDFBh
0C3A  FA FB FD      JP M,FDFBh
0C3D  FA FB FD      JP M,FDFBh
0C40  FA FF C2      JP M,C2FFh
0C43  00            NOP
0C44  31 91 16      LD SP,1691h
0C47  D9            EXX
0C48  79            LD A,C
0C49  F6 20         OR 20h
0C4B  4F            LD C,A
0C4C  7E            LD A,(HL)
0C4D  23            INC HL
0C4E  D9            EXX
0C4F  4F            LD C,A
0C50  FE 00         CP 00h
0C52  CA 58 3C      JP Z,3C58h
0C55  C3 61 3C      JP 3C61h
0C58  D9            EXX
0C59  4F            LD C,A
0C5A  E6 DF         AND DFh
0C5C  4F            LD C,A
0C5D  D9            EXX
0C5E  C3 E2 13      JP 13E2h
0C61  D9            EXX
0C62  79            LD A,C
0C63  E6 F0         AND F0h
0C65  F6 02         OR 02h
0C67  4F            LD C,A
0C68  D9            EXX
0C69  C3 25 15      JP 1525h
0C6C  C1            POP BC
0C6D  0E 5A         LD C,5Ah
0C6F  64            LD H,H
0C70  E2 E4 76      JP PO,76E4h
0C73  72            LD (HL),D
0C74  56            LD D,(HL)
0C75  52            LD D,D
0C76  2A 11 F1      LD HL,(F111h)
0C79  D1            POP DE
0C7A  D5            PUSH DE
0C7B  6E            LD L,(HL)
0C7C  D2 DE DA      JP NC,DADEh
0C7F  EE EA         XOR EAh
0C81  CE CA         ADC A,CAh
0C83  F6 F2         OR F2h
0C85  D6 51         SUB 51h
0C87  55            LD D,L
0C88  20 64         JR NZ,0CEEh
0C8A  60            LD H,B
0C8B  71            LD (HL),C
0C8C  5E            LD E,(HL)
0C8D  5B            LD E,E
0C8E  4D            LD C,L
0C8F  6D            LD L,L
0C90  6B            LD L,E
0C91  6C            LD L,H
0C92  6F            LD L,A
0C93  4B            LD C,E
0C94  4F            LD C,A
0C95  70            LD (HL),B
0C96  73            LD (HL),E
0C97  77            LD (HL),A
0C98  53            LD D,E
0C99  75            LD (HL),L
0C9A  49            LD C,C
0C9B  54            LD D,H
0C9C  50            LD D,B
0C9D  5C            LD E,H
0C9E  68            LD L,B
0C9F  5F            LD E,A
0CA0  4C            LD C,H
0CA1  74            LD (HL),H
0CA2  69            LD L,C
0CA3  58            LD E,B
0CA4  59            LD E,C
0CA5  48            LD C,B
0CA6  5D            LD E,L
0CA7  56            LD D,(HL)
0CA8  60            LD H,B
0CA9  52            LD D,D
0CAA  23            INC HL
0CAB  4A            LD C,D
0CAC  60            LD H,B
0CAD  DB CD         IN A,(CDh)
0CAF  ED EB         DB EDh,EBh
0CB1  EC EF CB      CALL PE,CBEFh
0CB4  CF            RST 08h
0CB5  F0            RET P
0CB6  F3            DI
0CB7  F7            RST 30h
0CB8  D3 F5         OUT (F5h),A
0CBA  C9            RET
0CBB  D4 D0 DC      CALL NC,DCD0h
0CBE  E8            RET PE
0CBF  DF            RST 18h
0CC0  CC F4 E9      CALL Z,E9F4h
0CC3  D8            RET C
0CC4  D9            EXX
0CC5  C8            RET Z
0CC6  DD 56 36      LD D,(IX+36h)
0CC9  52            LD D,D
0CCA  E3            EX (SP),HL
0CCB  00            NOP
0CCC  3E AF         LD A,AFh
0CCE  B7            OR A
0CCF  C9            RET
0CD0  C1            POP BC
0CD1  00            NOP
0CD2  00            NOP
0CD3  60            LD H,B
0CD4  5B            LD E,E
0CD5  00            NOP
0CD6  E0            RET PO
0CD7  5B            LD E,E
0CD8  00            NOP
0CD9  63            LD H,E
0CDA  5B            LD E,E
0CDB  00            NOP
0CDC  E3            EX (SP),HL
0CDD  5B            LD E,E
0CDE  00            NOP
0CDF  24            INC H
0CE0  5B            LD E,E
0CE1  00            NOP
0CE2  57            LD D,A
0CE3  00            NOP
0CE4  00            NOP
0CE5  60            LD H,B
0CE6  6C            LD L,H
0CE7  00            NOP
0CE8  E0            RET PO
0CE9  6C            LD L,H
0CEA  00            NOP
0CEB  63            LD H,E
0CEC  6C            LD L,H
0CED  00            NOP
0CEE  24            INC H
0CEF  6C            LD L,H
0CF0  00            NOP
0CF1  60            LD H,B
0CF2  70            LD (HL),B
0CF3  00            NOP
0CF4  E0            RET PO
0CF5  70            LD (HL),B
0CF6  00            NOP
0CF7  63            LD H,E
0CF8  70            LD (HL),B
0CF9  00            NOP
0CFA  24            INC H
0CFB  70            LD (HL),B
0CFC  00            NOP
0CFD  E3            EX (SP),HL
0CFE  49            LD C,C
0CFF  00            NOP
0D00  60            LD H,B
0D01  54            LD D,H
0D02  00            NOP
0D03  E0            RET PO
0D04  54            LD D,H
0D05  00            NOP
0D06  63            LD H,E
0D07  54            LD D,H
0D08  00            NOP
0D09  E3            EX (SP),HL
0D0A  54            LD D,H
0D0B  00            NOP
0D0C  24            INC H
0D0D  54            LD D,H
0D0E  00            NOP
0D0F  54            LD D,H
0D10  00            NOP
0D11  00            NOP
0D12  60            LD H,B
0D13  74            LD (HL),H
0D14  00            NOP
0D15  E0            RET PO
0D16  74            LD (HL),H
0D17  00            NOP
0D18  63            LD H,E
0D19  74            LD (HL),H
0D1A  00            NOP
0D1B  24            INC H
0D1C  74            LD (HL),H
0D1D  00            NOP
0D1E  24            INC H
0D1F  48            LD C,B
0D20  00            NOP
0D21  24            INC H
0D22  C1            POP BC
0D23  00            NOP
0D24  4E            LD C,(HL)
0D25  00            NOP
0D26  00            NOP
0D27  E0            RET PO
0D28  C1            POP BC
0D29  00            NOP
0D2A  6A            LD L,D
0D2B  00            NOP
0D2C  00            NOP
0D2D  D4 00 00      CALL NC,0000h
0D30  0E 00         LD C,00h
0D32  00            NOP
0D33  20 DB         JR NZ,0D10h
0D35  00            NOP
0D36  A0            AND B
0D37  DB 00         IN A,(00h)
0D39  23            INC HL
0D3A  DB 00         IN A,(00h)
0D3C  A3            AND E
0D3D  DB 00         IN A,(00h)
0D3F  24            INC H
0D40  DB 00         IN A,(00h)
0D42  D7            RST 10h
0D43  00            NOP
0D44  00            NOP
0D45  20 EC         JR NZ,0D33h
0D47  00            NOP
0D48  A0            AND B
0D49  EC 00 23      CALL PE,2300h
0D4C  EC 00 24      CALL PE,2400h
0D4F  EC 00 20      CALL PE,2000h
0D52  F0            RET P
0D53  00            NOP
0D54  A0            AND B
0D55  F0            RET P
0D56  00            NOP
0D57  23            INC HL
0D58  F0            RET P
0D59  00            NOP
0D5A  24            INC H
0D5B  F0            RET P
0D5C  00            NOP
0D5D  A3            AND E
0D5E  C9            RET
0D5F  00            NOP
0D60  20 D4         JR NZ,0D36h
0D62  00            NOP
0D63  A0            AND B
0D64  D4 00 23      CALL NC,2300h
0D67  D4 00 A3      CALL NC,A300h
0D6A  D4 00 24      CALL NC,2400h
0D6D  D4 00 D4      CALL NC,D400h
0D70  00            NOP
0D71  00            NOP
0D72  20 F4         JR NZ,0D68h
0D74  00            NOP
0D75  A0            AND B
0D76  F4 00 20      CALL P,2000h
0D79  F4 00 24      CALL P,2400h
0D7C  F4 00 24      CALL P,2400h
0D7F  C8            RET Z
0D80  00            NOP
0D81  4D            LD C,L
0D82  00            NOP
0D83  00            NOP
0D84  5E            LD E,(HL)
0D85  00            NOP
0D86  00            NOP
0D87  62            LD H,D
0D88  00            NOP
0D89  00            NOP
0D8A  71            LD (HL),C
0D8B  00            NOP
0D8C  00            NOP
0D8D  11 C6 4A      LD DE,4AC6h
0D90  A0            AND B
0D91  00            NOP
0D92  00            NOP
0D93  E0            RET PO
0D94  00            NOP
0D95  00            NOP
0D96  20 00         JR NZ,0D98h
0D98  00            NOP
0D99  60            LD H,B
0D9A  00            NOP
0D9B  00            NOP
0D9C  23            INC HL
0D9D  00            NOP
0D9E  00            NOP
0D9F  63            LD H,E
0DA0  00            NOP
0DA1  00            NOP
0DA2  A3            AND E
0DA3  00            NOP
0DA4  00            NOP
0DA5  E3            EX (SP),HL
0DA6  00            NOP
0DA7  00            NOP
0DA8  24            INC H
0DA9  00            NOP
0DAA  00            NOP
0DAB  63            LD H,E
0DAC  36 00         LD (HL),00h
0DAE  2E 00         LD L,00h
0DB0  00            NOP
0DB1  A2            AND D
0DB2  00            NOP
0DB3  00            NOP
0DB4  A4            AND H
0DB5  00            NOP
0DB6  00            NOP
0DB7  E3            EX (SP),HL
0DB8  1A            LD A,(DE)
0DB9  00            NOP
0DBA  48            LD C,B
0DBB  C6 D1         ADD A,D1h
0DBD  48            LD C,B
0DBE  C6 64         ADD A,64h
0DC0  A3            AND E
0DC1  64            LD H,H
0DC2  00            NOP
0DC3  64            LD H,H
0DC4  C6 6E         ADD A,6Eh
0DC6  91            SUB C
0DC7  C6 36         ADD A,36h
0DC9  54            LD D,H
0DCA  C6 D1         ADD A,D1h
0DCC  D4 C6 D1      CALL NC,D1C6h
0DCF  54            LD D,H
0DD0  C6 6E         ADD A,6Eh
0DD2  54            LD D,H
0DD3  C6 D9         ADD A,D9h
0DD5  D8            RET C
0DD6  00            NOP
0DD7  00            NOP
0DD8  D9            EXX
0DD9  00            NOP
0DDA  00            NOP
0DDB  C8            RET Z
0DDC  00            NOP
0DDD  00            NOP
0DDE  DD 00         NOP
0DE0  00            NOP
0DE1  56            LD D,(HL)
0DE2  00            NOP
0DE3  00            NOP
0DE4  36 00         LD (HL),00h
0DE6  00            NOP
0DE7  52            LD D,D
0DE8  00            NOP
0DE9  00            NOP
0DEA  A3            AND E
0DEB  C1            POP BC
0DEC  00            NOP
0DED  00            NOP
0DEE  00            NOP
0DEF  00            NOP
0DF0  F3            DI
0DF1  F1            POP AF
0DF2  DB 01         IN A,(01h)
0DF4  57            LD D,A
0DF5  D9            EXX
0DF6  7A            LD A,D
0DF7  F6 80         OR 80h
0DF9  57            LD D,A
0DFA  D9            EXX
0DFB  ED 4D         RETI
0DFD  C1            POP BC
0DFE  00            NOP
0DFF  00            NOP
0E00  36 00         LD (HL),00h
0E02  00            NOP
0E03  36 C6         LD (HL),C6h
0E05  ED 4E         IM 0/1
0E07  00            NOP
0E08  00            NOP
0E09  54            LD D,H
0E0A  C6 59         ADD A,59h
0E0C  48            LD C,B
0E0D  C6 D1         ADD A,D1h
0E0F  36 00         LD (HL),00h
0E11  00            NOP
0E12  6A            LD L,D
0E13  00            NOP
0E14  00            NOP
0E15  24            INC H
0E16  C1            POP BC
0E17  00            NOP
0E18  ED 00         DB EDh,00h
0E1A  00            NOP
0E1B  1E 00         LD E,00h
0E1D  00            NOP
0E1E  20 E0         JR NZ,0E00h
0E20  C1            POP BC
0E21  D1            POP DE
0E22  00            NOP
0E23  00            NOP
0E24  D1            POP DE
0E25  00            NOP
0E26  00            NOP
0E27  68            LD L,B
0E28  00            NOP
0E29  00            NOP
0E2A  D1            POP DE
0E2B  00            NOP
0E2C  00            NOP
0E2D  62            LD H,D
0E2E  00            NOP
0E2F  00            NOP
0E30  11 C6 4A      LD DE,4AC6h
0E33  A2            AND D
0E34  00            NOP
0E35  00            NOP
0E36  A4            AND H
0E37  00            NOP
0E38  00            NOP
0E39  60            LD H,B
0E3A  C1            POP BC
0E3B  00            NOP
0E3C  2E 00         LD L,00h
0E3E  00            NOP
0E3F  E3            EX (SP),HL
0E40  5A            LD E,D
0E41  00            NOP
0E42  20 A0         JR NZ,0DE4h
0E44  C1            POP BC
0E45  F1            POP AF
0E46  00            NOP
0E47  00            NOP
0E48  DE 00         SBC A,00h
0E4A  00            NOP
0E4B  62            LD H,D
0E4C  00            NOP
0E4D  00            NOP
0E4E  A0            AND B
0E4F  60            LD H,B
0E50  C1            POP BC
0E51  C1            POP BC
0E52  00            NOP
0E53  00            NOP
0E54  C1            POP BC
0E55  00            NOP
0E56  00            NOP
0E57  C1            POP BC
0E58  00            NOP
0E59  00            NOP
0E5A  71            LD (HL),C
0E5B  00            NOP
0E5C  00            NOP
0E5D  60            LD H,B
0E5E  5B            LD E,E
0E5F  00            NOP
0E60  E0            RET PO
0E61  5B            LD E,E
0E62  00            NOP
0E63  63            LD H,E
0E64  5B            LD E,E
0E65  00            NOP
0E66  E3            EX (SP),HL
0E67  5B            LD E,E
0E68  00            NOP
0E69  24            INC H
0E6A  5B            LD E,E
0E6B  00            NOP
0E6C  22 C6 5B      LD (5BC6h),HL
0E6F  5B            LD E,E
0E70  00            NOP
0E71  00            NOP
0E72  57            LD D,A
0E73  00            NOP
0E74  00            NOP
0E75  60            LD H,B
0E76  6C            LD L,H
0E77  00            NOP
0E78  E0            RET PO
0E79  6C            LD L,H
0E7A  00            NOP
0E7B  63            LD H,E
0E7C  6C            LD L,H
0E7D  00            NOP
0E7E  24            INC H
0E7F  6C            LD L,H
0E80  00            NOP
0E81  60            LD H,B
0E82  70            LD (HL),B
0E83  00            NOP
0E84  E0            RET PO
0E85  70            LD (HL),B
0E86  00            NOP
0E87  63            LD H,E
0E88  70            LD (HL),B
0E89  00            NOP
0E8A  24            INC H
0E8B  70            LD (HL),B
0E8C  00            NOP
0E8D  6B            LD L,E
0E8E  C6 D1         ADD A,D1h
0E90  E3            EX (SP),HL
0E91  49            LD C,C
0E92  00            NOP
0E93  60            LD H,B
0E94  54            LD D,H
0E95  00            NOP
0E96  E0            RET PO
0E97  54            LD D,H
0E98  00            NOP
0E99  63            LD H,E
0E9A  54            LD D,H
0E9B  00            NOP
0E9C  E3            EX (SP),HL
0E9D  54            LD D,H
0E9E  00            NOP
0E9F  24            INC H
0EA0  54            LD D,H
0EA1  00            NOP
0EA2  C1            POP BC
0EA3  00            NOP
0EA4  00            NOP
0EA5  6E            LD L,(HL)
0EA6  C6 92         ADD A,92h
0EA8  60            LD H,B
0EA9  74            LD (HL),H
0EAA  00            NOP
0EAB  E0            RET PO
0EAC  74            LD (HL),H
0EAD  00            NOP
0EAE  63            LD H,E
0EAF  74            LD (HL),H
0EB0  00            NOP
0EB1  24            INC H
0EB2  74            LD (HL),H
0EB3  00            NOP
0EB4  E0            RET PO
0EB5  48            LD C,B
0EB6  00            NOP
0EB7  50            LD D,B
0EB8  00            NOP
0EB9  00            NOP
0EBA  4D            LD C,L
0EBB  00            NOP
0EBC  00            NOP
0EBD  20 DB         JR NZ,0E9Ah
0EBF  00            NOP
0EC0  A0            AND B
0EC1  DB 00         IN A,(00h)
0EC3  23            INC HL
0EC4  DB 00         IN A,(00h)
0EC6  A3            AND E
0EC7  DB 00         IN A,(00h)
0EC9  24            INC H
0ECA  DB 00         IN A,(00h)
0ECC  22 C6 DB      LD (DBC6h),HL
0ECF  DB 00         IN A,(00h)
0ED1  00            NOP
0ED2  D7            RST 10h
0ED3  00            NOP
0ED4  00            NOP
0ED5  20 EC         JR NZ,0EC3h
0ED7  00            NOP
0ED8  A0            AND B
0ED9  EC 00 23      CALL PE,2300h
0EDC  EC 00 24      CALL PE,2400h
0EDF  EC 00 20      CALL PE,2000h
0EE2  F0            RET P
0EE3  00            NOP
0EE4  A0            AND B
0EE5  F0            RET P
0EE6  00            NOP
0EE7  23            INC HL
0EE8  F0            RET P
0EE9  00            NOP
0EEA  24            INC H
0EEB  F0            RET P
0EEC  00            NOP
0EED  EB            EX DE,HL
0EEE  C6 D1         ADD A,D1h
0EF0  A3            AND E
0EF1  C9            RET
0EF2  00            NOP
0EF3  20 D4         JR NZ,0EC9h
0EF5  00            NOP
0EF6  A0            AND B
0EF7  D4 00 23      CALL NC,2300h
0EFA  D4 00 A3      CALL NC,A300h
0EFD  D4 00 24      CALL NC,2400h

;==============================================================================
; TABELA DE VETORES DE INTERRUPCAO IM2 (0F00h em diante)
; Como I=0Fh (ver 0049h), o Z80 em modo IM2 busca o endereco do
; tratador em (0F00h + byte_de_vetor_da_PIO), 16 bits little-endian.
; Como esta area fica dentro da propria ROM (so-leitura), a tabela
; e fixa/imutavel - funciona pois os poucos vetores usados apontam
; sempre para os MESMOS tratadores fixos:
;   vetor 0 -> (0F00h)=00D4h = 'JP 013Eh' (trampolim p/ dispatcher
;               de reintentar deteccao)
;   vetor 2 -> (0F02h)=00C1h = 'INC L' (o famoso contador de pulsos
;               compartilhado com o loop de espera em 00BFh-00D1h)
; Os bytes seguintes (0F04h+) ja fazem parte da tabela de dados
; caractere->posicao-de-matriz (ver secao final do relatorio).
;==============================================================================
0F00  D4 00 C1      CALL NC,C100h
0F03  00            NOP
0F04  00            NOP
0F05  6E            LD L,(HL)
0F06  C6 94         ADD A,94h
0F08  20 F4         JR NZ,0EFEh
0F0A  00            NOP
0F0B  A0            AND B
0F0C  F4 00 23      CALL P,2300h
0F0F  F4 00 24      CALL P,2400h
0F12  F4 00 20      CALL P,2000h
0F15  C8            RET Z
0F16  00            NOP
0F17  D0            RET NC
0F18  00            NOP
0F19  00            NOP
0F1A  24            INC H
0F1B  C8            RET Z
0F1C  00            NOP
0F1D  FF            RST 38h
0F1E  FF            RST 38h
0F1F  FF            RST 38h
0F20  FF            RST 38h
0F21  FF            RST 38h
0F22  FF            RST 38h
0F23  FF            RST 38h
0F24  FF            RST 38h
0F25  FF            RST 38h
0F26  FF            RST 38h
0F27  FF            RST 38h
0F28  FF            RST 38h
0F29  FF            RST 38h
0F2A  FF            RST 38h
0F2B  FF            RST 38h
0F2C  FF            RST 38h
0F2D  FF            RST 38h
0F2E  FF            RST 38h
0F2F  FF            RST 38h
0F30  FF            RST 38h
0F31  FF            RST 38h
0F32  FF            RST 38h
0F33  FF            RST 38h
0F34  FF            RST 38h
0F35  FF            RST 38h
0F36  FF            RST 38h
0F37  FF            RST 38h
0F38  FF            RST 38h
0F39  FF            RST 38h
0F3A  FF            RST 38h
0F3B  FF            RST 38h
0F3C  FF            RST 38h
0F3D  FF            RST 38h
0F3E  FF            RST 38h
0F3F  FF            RST 38h
0F40  FF            RST 38h
0F41  FF            RST 38h
0F42  FF            RST 38h
0F43  FF            RST 38h
0F44  FF            RST 38h
0F45  FF            RST 38h
0F46  FF            RST 38h
0F47  FF            RST 38h
0F48  FF            RST 38h
0F49  FF            RST 38h
0F4A  FF            RST 38h
0F4B  FF            RST 38h
0F4C  FF            RST 38h
0F4D  FF            RST 38h
0F4E  FF            RST 38h
0F4F  FF            RST 38h
0F50  F0            RET P
0F51  AD            XOR L
0F52  C4 B2 0D      CALL NZ,0DB2h
0F55  A0            AND B
0F56  0A            LD A,(BC)
0F57  C0            RET NZ
0F58  2D            DEC L
0F59  B0            OR B
0F5A  3C            INC A
0F5B  A2            AND D
0F5C  82            ADD A,D
0F5D  F7            RST 30h
0F5E  24            INC H
0F5F  EC 00 20      CALL PE,2000h
0F62  F0            RET P
0F63  00            NOP
0F64  A0            AND B
0F65  F0            RET P
0F66  00            NOP
0F67  23            INC HL
0F68  F0            RET P
0F69  00            NOP
0F6A  24            INC H
0F6B  F0            RET P
0F6C  00            NOP
0F6D  EB            EX DE,HL
0F6E  C6 D1         ADD A,D1h
0F70  A3            AND E
0F71  C9            RET
0F72  00            NOP
0F73  20 D4         JR NZ,0F49h
0F75  00            NOP
0F76  A0            AND B
0F77  D4 00 23      CALL NC,2300h
0F7A  D4 00 A3      CALL NC,A300h
0F7D  D4 00 24      CALL NC,2400h
0F80  00            NOP
0F81  00            NOP
0F82  00            NOP
0F83  00            NOP
0F84  00            NOP
0F85  00            NOP
0F86  00            NOP
0F87  00            NOP
0F88  00            NOP
0F89  00            NOP
0F8A  00            NOP
0F8B  00            NOP
0F8C  00            NOP
0F8D  00            NOP
0F8E  00            NOP
0F8F  00            NOP
0F90  00            NOP
0F91  00            NOP
0F92  00            NOP
0F93  00            NOP
0F94  00            NOP
0F95  00            NOP
0F96  00            NOP
0F97  00            NOP
0F98  00            NOP
0F99  00            NOP
0F9A  00            NOP
0F9B  00            NOP
0F9C  00            NOP
0F9D  00            NOP
0F9E  00            NOP
0F9F  00            NOP
0FA0  00            NOP
0FA1  00            NOP
0FA2  00            NOP
0FA3  00            NOP
0FA4  00            NOP
0FA5  00            NOP
0FA6  00            NOP
0FA7  00            NOP
0FA8  00            NOP
0FA9  09            ADD HL,BC
0FAA  4E            LD C,(HL)
0FAB  C8            RET Z
0FAC  8A            ADC A,D
0FAD  4C            LD C,H
0FAE  20 8A         JR NZ,0F3Ah
0FB0  8C            ADC A,H
0FB1  8A            ADC A,D
0FB2  C8            RET Z
0FB3  49            LD C,C
0FB4  47            LD B,A
0FB5  49            LD C,C
0FB6  61            LD H,C
0FB7  8D            ADC A,L
0FB8  0E 0B         LD C,0Bh
0FBA  0A            LD A,(BC)
0FBB  20 0E         JR NZ,0FCBh
0FBD  8D            ADC A,L
0FBE  88            ADC A,B
0FBF  20 8A         JR NZ,0F4Bh
0FC1  20 0B         JR NZ,0FCEh
0FC3  8F            ADC A,A
0FC4  8E            ADC A,(HL)
0FC5  20 8C         JR NZ,0F53h
0FC7  C8            RET Z
0FC8  88            ADC A,B
0FC9  0A            LD A,(BC)
0FCA  0E 8D         LD C,8Dh
0FCC  C8            RET Z
0FCD  8A            ADC A,D
0FCE  49            LD C,C
0FCF  89            ADC A,C
0FD0  0A            LD A,(BC)
0FD1  4C            LD C,H
0FD2  20 61         JR NZ,1035h
0FD4  60            LD H,B
0FD5  49            LD C,C
0FD6  8A            ADC A,D
0FD7  C9            RET
0FD8  20 0C         JR NZ,0FE6h
0FDA  0A            LD A,(BC)
0FDB  49            LD C,C
0FDC  88            ADC A,B
0FDD  CB 0A         RRC D
0FDF  49            LD C,C
0FE0  8A            ADC A,D
0FE1  20 20         JR NZ,1003h
0FE3  A7            AND A
0FE4  20 49         JR NZ,102Fh
0FE6  8A            ADC A,D
0FE7  C9            RET
0FE8  20 4B         JR NZ,1035h
0FEA  8F            ADC A,A
0FEB  89            ADC A,C
0FEC  C8            RET Z
0FED  CB 0A         RRC D
0FEF  49            LD C,C
0FF0  8A            ADC A,D
0FF1  20 0A         JR NZ,0FFDh
0FF3  CA C8 8F      JP Z,8FC8h
0FF6  20 C8         JR NZ,0FC0h
0FF8  8A            ADC A,D
0FF9  4B            LD C,E
0FFA  C8            RET Z
0FFB  8A            ADC A,D

; 0FFCh-0FFDh: valor de checksum esperado (57h,0Fh = 0F57h) usado
;   pela rotina de autoteste de ROM em 000Dh
0FFC  57            LD D,A
0FFD  0F            RRCA
0FFE  2C            INC L

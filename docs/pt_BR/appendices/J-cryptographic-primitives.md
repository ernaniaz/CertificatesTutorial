# Apêndice J: Guia Completo de Primitivas Criptográficas

> **Para quem é este apêndice:** Este apêndice é uma referência para quem precisa entender o que são e para que servem os algoritmos e mecanismos criptográficos mencionados ao longo deste tutorial. A linguagem é deliberadamente acessível — o objetivo é que um administrador de sistemas sem formação em criptografia consiga distinguir entre os diferentes tipos de recurso e fazer escolhas informadas.

---

## J.1 Como Ler Este Apêndice

A criptografia moderna é construída a partir de peças menores chamadas **primitivas**. Cada primitiva resolve um problema específico:

| Problema | Primitiva | Analogia do Mundo Físico |
|----------|-----------|--------------------------|
| "Ninguém pode ler isto" | **Cifra simétrica** | Cofre com uma chave única |
| "Ninguém pode ler isto, mas eu não conheço o destinatário" | **Cifra assimétrica** | Caixa de correio: qualquer um deposita, só o dono abre |
| "Isto não foi adulterado" | **Hash** | Impressão digital de um documento |
| "Isto não foi adulterado E veio de quem diz" | **MAC** | Lacre de segurança com número de série |
| "Eu garanto que escrevi isto" | **Assinatura digital** | Assinatura de cartório com reconhecimento de firma |
| "Vamos combinar um segredo sem que ninguém ouça" | **Troca de chave** | Duas pessoas combinam uma cor misturando tintas em público |
| "Vamos derivar vários segredos de um só" | **KDF** | Máquina de fazer cópias de chave a partir de uma chave-mestra |

Cada seção abaixo explica uma categoria, lista os algoritmos mais relevantes e indica seu status atual (seguro, legado, quebrado).

---

## J.2 Cifras Simétricas — "A Mesma Chave Tranca e Destranca"

### O Conceito

Uma cifra simétrica usa **a mesma chave** para criptografar e descriptografar. É o tipo mais rápido de criptografia e protege a esmagadora maioria dos dados em trânsito (TLS, SSH, VPN) e em repouso (LUKS, BitLocker).

O desafio fundamental: como entregar a chave ao destinatário sem que um atacante a intercepte? Este problema é resolvido pela troca de chave (seção J.6).

### Cifras de Bloco vs Cifras de Fluxo

Cifras simétricas se dividem em dois tipos:

- **Cifra de bloco:** Processa os dados em blocos de tamanho fixo (ex: 128 bits). Se a mensagem é maior que um bloco, é necessário um **modo de operação** para encadear os blocos. Exemplos: AES, Camellia, 3DES.
- **Cifra de fluxo:** Gera um fluxo contínuo de bits pseudoaleatórios (keystream) que é combinado com os dados via XOR, bit a bit. Não precisa de modo de operação. Exemplos: ChaCha20, RC4.

### Algoritmos Simétricos

#### AES (Advanced Encryption Standard)

- **O que é:** Padrão mundial de criptografia simétrica desde 2001, selecionado pelo NIST em competição pública. Nome original: Rijndael.
- **Tamanhos de chave:** 128, 192 ou 256 bits.
- **Tamanho de bloco:** 128 bits.
- **Status:** Seguro. Nenhum ataque prático conhecido contra nenhuma variante. AES-256 é considerado resistente a computadores quânticos (ataque de Grover reduz a segurança efetiva para ~128 bits, ainda suficiente).
- **Onde aparece:** Em praticamente todo lugar — TLS, SSH, VPN, criptografia de disco, Wi-Fi (WPA2/WPA3), mensageiros (Signal, WhatsApp).
- **Vantagem especial:** Processadores modernos (Intel, AMD, ARM) possuem instruções de hardware dedicadas (AES-NI) que tornam AES extremamente rápido — ordens de magnitude mais rápido que implementação em software.

#### ChaCha20

- **O que é:** Cifra de fluxo criada por Daniel J. Bernstein em 2008. Variante melhorada do Salsa20.
- **Tamanho de chave:** 256 bits.
- **Status:** Seguro. Adotado pelo Google, Cloudflare e outros como alternativa ao AES.
- **Onde aparece:** TLS 1.3, SSH, WireGuard, protocolos do Google (QUIC).
- **Por que existe se já temos AES:** ChaCha20 é mais rápido que AES em dispositivos **sem** aceleração de hardware (smartphones ARM antigos, dispositivos IoT). Em servidores com AES-NI, AES é mais rápido.

#### Camellia

- **O que é:** Cifra de bloco desenvolvida pela Mitsubishi Electric e NTT (Japão) em 2000.
- **Tamanhos de chave:** 128, 192, 256 bits.
- **Tamanho de bloco:** 128 bits.
- **Status:** Seguro, mas pouco utilizado fora do Japão. Aprovado por NESSIE, CRYPTREC e ISO/IEC.
- **Onde aparece:** Algumas implementações TLS, especialmente em ambientes regulatórios japoneses.
- **Na prática:** Raramente necessário. As crypto-policies do RHEL incluem Camellia em DEFAULT mas o excluem de TLS.

#### 3DES (Triple DES)

- **O que é:** Aplicação tripla do DES original (3 × DES com 2 ou 3 chaves diferentes).
- **Tamanho de chave efetivo:** 112 bits (com 3 chaves) ou 80 bits (com 2 chaves).
- **Tamanho de bloco:** 64 bits.
- **Status:** **Legado/Depreciado.** O bloco de 64 bits torna-o vulnerável ao ataque Sweet32 — após ~32 GB de dados criptografados com a mesma chave, padrões repetitivos vazam informação. O NIST proibiu 3DES após 2023.
- **Onde aparece:** Sistemas legados, PKCS#12 antigo, S/MIME antigo, Active Directory muito antigo.
- **Recomendação:** Migrar para AES o mais rápido possível. Nas crypto-policies do RHEL, 3DES aparece apenas na política LEGACY.

#### DES (Data Encryption Standard)

- **O que é:** Cifra de bloco de 1977, primeiro padrão de criptografia do governo dos EUA.
- **Tamanho de chave:** 56 bits.
- **Tamanho de bloco:** 64 bits.
- **Status:** **Quebrado.** Uma chave DES pode ser forçada em horas com hardware moderno. O projeto DESCHALL quebrou DES em 1997.
- **Onde aparece:** Não deveria aparecer em nenhum lugar. Removido das bibliotecas criptográficas modernas.

#### RC4 (Rivest Cipher 4)

- **O que é:** Cifra de fluxo criada por Ron Rivest em 1987. Simples e rápida.
- **Tamanho de chave:** Variável (40–256 bits).
- **Status:** **Quebrado.** Múltiplos vieses estatísticos no keystream permitem recuperar texto claro. Proibido em TLS desde o RFC 7465 (2015).
- **Onde aparece:** Não deveria. WEP (Wi-Fi antigo) usava RC4 e foi quebrado por causa dele.

#### IDEA (International Data Encryption Algorithm)

- **O que é:** Cifra de bloco de 1991, usada no PGP original.
- **Tamanho de chave:** 128 bits.
- **Tamanho de bloco:** 64 bits.
- **Status:** Obsoleto. Patente expirada. Bloco de 64 bits é insuficiente.
- **Onde aparece:** Apenas em mensagens PGP muito antigas.

#### SEED

- **O que é:** Cifra de bloco padrão sul-coreano (1998).
- **Tamanho de chave:** 128 bits.
- **Tamanho de bloco:** 128 bits.
- **Status:** Seguro mas sem adoção fora da Coreia do Sul. Irrelevante na prática.

#### Blowfish / Twofish

- **O que são:** Cifras de bloco criadas por Bruce Schneier. Blowfish (1993, bloco de 64 bits) é o predecessor; Twofish (1998, bloco de 128 bits) foi finalista na competição AES.
- **Status:** Blowfish é legado (bloco de 64 bits). Twofish é seguro mas perdeu a competição AES e tem pouca adoção.
- **Onde aparece:** Blowfish sobrevive no `bcrypt` (hashing de senhas). Twofish aparece em algumas implementações de criptografia de disco.

### Modos de Operação — Como Encadear Blocos

Uma cifra de bloco como AES processa exatamente 128 bits de cada vez. Para criptografar uma mensagem maior, é necessário um **modo de operação** que define como os blocos são encadeados. A escolha do modo é tão importante quanto a cifra.

#### ECB (Electronic Codebook)

- **Como funciona:** Cada bloco é criptografado independentemente com a mesma chave.
- **Status:** **Inseguro.** Blocos idênticos de texto claro produzem blocos idênticos de texto cifrado, revelando padrões. O famoso "pinguim ECB" demonstra isto visualmente.
- **Uso correto:** Nenhum para dados gerais. Apenas para criptografar valores aleatórios de exatamente um bloco (ex: uma chave).

#### CBC (Cipher Block Chaining)

- **Como funciona:** Cada bloco de texto claro é XORado com o bloco cifrado anterior antes de ser criptografado. O primeiro bloco usa um Vetor de Inicialização (IV) aleatório.
- **Status:** Seguro se implementado corretamente, mas vulnerável a ataques de padding oracle (POODLE, Lucky13) quando o padding não é verificado em tempo constante.
- **Onde aparece:** TLS 1.2 (em desuso), SSH (depreciado em versões recentes), PKCS#12, S/MIME.
- **Nas crypto-policies:** DEFAULT desabilita CBC em SSH (`cipher@SSH = -*-CBC`) por vulnerabilidade a plaintext recovery.

#### CTR (Counter)

- **Como funciona:** Transforma a cifra de bloco em cifra de fluxo — criptografa um contador incrementado a cada bloco e faz XOR com o texto claro.
- **Status:** Seguro. Permite paralelismo e acesso aleatório.
- **Onde aparece:** SSH (AES-CTR é o modo padrão), Kerberos.
- **Cuidado:** O contador (nonce + counter) nunca pode se repetir com a mesma chave.

#### GCM (Galois/Counter Mode)

- **Como funciona:** Combina CTR (para confidencialidade) com multiplicação em campo de Galois (para integridade). Produz um tag de autenticação junto com o texto cifrado.
- **Status:** Seguro e eficiente. É um modo **AEAD** (Authenticated Encryption with Associated Data) — ver seção J.5.
- **Onde aparece:** TLS 1.2 e 1.3 (modo preferido), SSH, IPsec.
- **Vantagem:** Criptografa e autentica em uma única operação. Acelerado por hardware (CLMUL/PCLMULQDQ).
- **Nas crypto-policies:** AES-256-GCM é o primeiro cipher listado em todas as políticas.

#### CCM (Counter with CBC-MAC)

- **Como funciona:** Combina CTR (confidencialidade) com CBC-MAC (integridade). Modo AEAD.
- **Status:** Seguro mas mais lento que GCM (duas passagens sobre os dados em vez de uma).
- **Onde aparece:** TLS 1.2/1.3, Wi-Fi (WPA2/CCMP), Bluetooth.

#### OCB (Offset Codebook Mode)

- **Como funciona:** Modo AEAD de passagem única — mais rápido que GCM e CCM.
- **Status:** Seguro. Era patenteado até 2021, o que impediu sua adoção.
- **Onde aparece:** OpenPGP (Sequoia), limitado em TLS por causa da patente histórica.

#### EAX

- **Como funciona:** Modo AEAD baseado em CTR + OMAC. Não patenteado.
- **Status:** Seguro. Similar a CCM mas mais simples de implementar corretamente.
- **Onde aparece:** OpenPGP (Sequoia).

#### CFB (Cipher Feedback)

- **Como funciona:** Similar a CBC mas opera como cifra de fluxo — permite processar dados menores que um bloco.
- **Status:** Seguro mas sem vantagem sobre CTR ou GCM. Não provê autenticação.
- **Onde aparece:** OpenPGP (modo histórico obrigatório), GOST.

---

## J.3 Funções de Hash — "A Impressão Digital dos Dados"

### O Conceito

Uma função de hash pega dados de qualquer tamanho e produz uma saída de tamanho fixo (o **digest** ou **resumo**). As propriedades fundamentais:

1. **Determinística:** A mesma entrada sempre produz a mesma saída.
2. **Rápida:** Calcular o hash é computacionalmente barato.
3. **Irreversível (resistência a pré-imagem):** Dado um hash, é computacionalmente inviável encontrar a entrada que o produziu.
4. **Resistência a colisão:** É computacionalmente inviável encontrar duas entradas diferentes que produzam o mesmo hash.
5. **Efeito avalanche:** Uma mudança mínima na entrada (um bit) altera drasticamente a saída.

**Não confunda:** Hashes **não criptografam** — são operações de mão única. Não existe "descriptografar um hash". Se alguém diz "descriptografar o MD5", está falando de ataque de força bruta ou rainbow tables, não de reversão.

### Algoritmos de Hash

#### MD5 (Message Digest 5)

- **Criador:** Ron Rivest, 1991.
- **Tamanho da saída:** 128 bits (32 caracteres hexadecimais).
- **Status:** **Quebrado para integridade criptográfica.** Colisões podem ser geradas em segundos. Em 2008, pesquisadores criaram um certificado CA falso usando colisão MD5. A chama "Flame" (malware) explorava colisão MD5 em certificados da Microsoft.
- **Ainda aceitável para:** Checksums de integridade não-criptográfica (verificar se um download corrompeu, desde que o atacante não controle a fonte). Nunca para assinaturas ou autenticação.
- **Nas crypto-policies:** Excluído de todas as políticas, incluindo LEGACY.

#### SHA-1 (Secure Hash Algorithm 1)

- **Criador:** NSA, 1995.
- **Tamanho da saída:** 160 bits (40 caracteres hexadecimais).
- **Status:** **Quebrado.** O projeto SHAttered (Google, 2017) demonstrou colisão prática — dois PDFs diferentes com o mesmo SHA-1. O custo era ~$110.000 em computação na nuvem; hoje é menor. Em 2020, colisões chosen-prefix foram demonstradas por ~$45.000.
- **Ainda aceitável para:** HMAC-SHA1 (onde a chave secreta impede ataques de colisão — ver seção J.4). Git usa SHA-1 mas está migrando para SHA-256.
- **Nas crypto-policies:** DEFAULT permite SHA-1 apenas em HMAC e DNSSec; FUTURE remove SHA-1 completamente; LEGACY permite tudo.

#### Família SHA-2

Criada pela NSA, publicada entre 2001 e 2012. **Quatro variantes** com segurança proporcional ao tamanho da saída:

| Variante | Saída | Segurança contra colisão | Notas |
|----------|-------|--------------------------|-------|
| **SHA-224** | 224 bits | 112 bits | Versão truncada de SHA-256. Raramente usada. |
| **SHA-256** | 256 bits | 128 bits | **O padrão atual.** Usado em TLS, certificados X.509, Bitcoin, assinaturas de software. |
| **SHA-384** | 384 bits | 192 bits | Versão truncada de SHA-512. Usado em TLS 1.3, certificados de alta segurança. |
| **SHA-512** | 512 bits | 256 bits | Máxima segurança. Mais rápido que SHA-256 em processadores de 64 bits. |

- **Status:** Seguro. Nenhum ataque prático conhecido contra nenhuma variante.
- **Onde aparece:** Certificados X.509 (a vasta maioria usa SHA-256), TLS, SSH, assinaturas de pacotes, blockchain, verificação de integridade de arquivos.
- **Nas crypto-policies:** SHA-256, SHA-384 e SHA-512 são habilitados em todas as políticas.

#### Família SHA-3

Criada por Guido Bertoni, Joan Daemen, Michaël Peeters e Gilles Van Assche. Venceu a competição NIST em 2012. Nome original: Keccak. Usa construção interna completamente diferente de SHA-2 (esponja em vez de Merkle-Damgård).

| Variante | Saída | Segurança contra colisão |
|----------|-------|--------------------------|
| **SHA3-224** | 224 bits | 112 bits |
| **SHA3-256** | 256 bits | 128 bits |
| **SHA3-384** | 384 bits | 192 bits |
| **SHA3-512** | 512 bits | 256 bits |

- **Status:** Seguro. Fundamentalmente diferente de SHA-2, servindo como "seguro alternativo" caso SHA-2 seja comprometido.
- **Por que existem se SHA-2 é seguro:** Diversidade algorítmica. SHA-3 e SHA-2 usam construções matemáticas completamente diferentes. Se um ataque teórico comprometer a família SHA-2, SHA-3 provavelmente não será afetado. É a mesma lógica de ter ChaCha20 como alternativa ao AES.
- **Nas crypto-policies:** Habilitados em DEFAULT, FUTURE e FIPS.

#### SHAKE-128 / SHAKE-256

- **O que são:** Funções de hash de saída **variável** (XOF — Extendable Output Function) baseadas na construção Keccak/SHA-3. Em vez de produzir um digest de tamanho fixo, podem produzir saídas de qualquer tamanho.
- **Uso:** Derivação de chave, algoritmos pós-quânticos (SLH-DSA usa SHAKE), protocolos que precisam de quantidades arbitrárias de material pseudoaleatório.

#### BLAKE2 / BLAKE3

- **O que são:** Funções de hash alternativas de alto desempenho. BLAKE2 (2012) é mais rápido que MD5 mantendo segurança equivalente a SHA-3. BLAKE3 (2020) é ainda mais rápido e paralelizável.
- **Status:** Seguros. Usados em WireGuard, Argon2, vários sistemas de arquivos, mas não padronizados pelo NIST.
- **Nas crypto-policies:** Não suportados pelas crypto-policies do RHEL (não são usados em TLS/SSH/IPsec).

#### RIPEMD-160

- **O que é:** Função de hash europeia (1996), saída de 160 bits.
- **Status:** Seguro mas sem adoção significativa fora de Bitcoin (usado em endereços).
- **Nas crypto-policies:** Não suportado.

---

## J.4 MACs — "Lacre de Autenticidade"

### O Conceito

Um MAC (Message Authentication Code) garante duas coisas simultaneamente:

1. **Integridade:** A mensagem não foi alterada em trânsito.
2. **Autenticidade:** A mensagem veio de alguém que possui a chave secreta.

A diferença crucial em relação a um hash simples: o MAC usa uma **chave secreta**. Sem a chave, não é possível gerar nem verificar o MAC. Um hash simples (SHA-256) prova que os dados não foram corrompidos, mas qualquer pessoa pode recalculá-lo — não prova a origem.

### Algoritmos MAC

#### HMAC (Hash-based MAC)

- **O que é:** Construção genérica que transforma qualquer função de hash em um MAC. HMAC-SHA256 = HMAC usando SHA-256 por dentro.
- **Como funciona:** `HMAC(chave, mensagem) = Hash((chave ⊕ opad) || Hash((chave ⊕ ipad) || mensagem))`. Duas rodadas de hash com padding especial tornam o resultado dependente da chave de maneira criptograficamente segura.
- **Status:** Seguro. A segurança depende do hash subjacente, mas mesmo HMAC-SHA1 permanece seguro — ataques de colisão contra SHA-1 **não** comprometem HMAC-SHA1, porque o atacante não controla a chave.
- **Variantes comuns:**
  - **HMAC-SHA2-256:** Padrão em TLS e SSH.
  - **HMAC-SHA2-384 / HMAC-SHA2-512:** Alta segurança.
  - **HMAC-SHA1:** Legado mas seguro como MAC. DEFAULT do RHEL permite em TLS e SSH.
  - **HMAC-MD5:** Inseguro. Apenas em LEGACY.
- **Onde aparece:** TLS 1.2 (para ciphersuites não-AEAD), SSH, IPsec, APIs de autenticação (JWT, OAuth), verificação de integridade de pacotes.

#### CMAC (Cipher-based MAC)

- **O que é:** MAC baseado em cifra de bloco (geralmente AES) em vez de hash.
- **Onde aparece:** Wi-Fi (WPA2), Bluetooth, Kerberos.
- **Status:** Seguro. Alternativa ao HMAC quando AES está disponível em hardware mas hash não.

#### Poly1305

- **O que é:** MAC de alta velocidade criado por Daniel J. Bernstein. Usa aritmética modular em vez de hash ou cifra de bloco.
- **Status:** Seguro. Projetado para ser usado **uma vez por chave** — cada mensagem recebe uma chave diferente (derivada do ChaCha20).
- **Onde aparece:** Sempre combinado com ChaCha20 como ChaCha20-Poly1305 (modo AEAD). Nunca usado sozinho em protocolos modernos.

#### UMAC / UMAC-128

- **O que é:** MAC baseado em hashing universal, extremamente rápido.
- **Onde aparece:** SSH (especificamente `umac-64@openssh.com` e `umac-128-etm@openssh.com`).
- **Status:** Seguro. O `umac-64` tem tag de 64 bits (adequado apenas para SSH onde o número de pacotes é limitado).

#### GMAC (Galois MAC)

- **O que é:** A parte de autenticação do modo GCM, usada quando não há dados a criptografar (apenas autenticar).
- **Onde aparece:** Implicitamente em AES-GCM. Também usado em MACsec (criptografia de camada 2 em redes Ethernet).

### Encrypt-then-MAC vs Encrypt-and-MAC vs MAC-then-Encrypt

Quando uma cifra CBC (que não é AEAD) é usada com HMAC separado, a **ordem** das operações importa para a segurança:

| Abordagem | Descrição | Segurança |
|-----------|-----------|-----------|
| **Encrypt-then-MAC (EtM)** | Criptografa, depois calcula MAC do texto cifrado | **Segura.** O MAC protege o texto cifrado — qualquer adulteração é detectada antes da descriptografia. |
| **MAC-then-Encrypt (MtE)** | Calcula MAC do texto claro, depois criptografa ambos | **Vulnerável.** TLS 1.2 com CBC usa esta abordagem e é vulnerável a padding oracle (Lucky13, POODLE). |
| **Encrypt-and-MAC (E&M)** | Criptografa o texto claro e calcula MAC do texto claro separadamente | **Vulnerável.** O MAC pode vazar informação sobre o texto claro. SSH usava esta abordagem. |

O parâmetro `etm` das crypto-policies do RHEL controla exatamente isto para SSH: `DISABLE_NON_ETM` força Encrypt-then-MAC, `DISABLE_ETM` força o modo antigo (não recomendado).

---

## J.5 AEAD — "Criptografia e Autenticação Juntas"

### O Conceito

AEAD (Authenticated Encryption with Associated Data) combina **confidencialidade** e **integridade** em uma única operação atômica. Em vez de usar uma cifra (AES-CBC) + um MAC (HMAC-SHA256) separadamente — com todos os riscos de combiná-los errado — um modo AEAD faz tudo de uma vez.

"Associated Data" são dados que precisam ser **autenticados mas não criptografados** — por exemplo, cabeçalhos de protocolo que precisam ser legíveis mas não podem ser adulterados.

**TLS 1.3 aceita APENAS ciphersuites AEAD.** Modos não-AEAD (CBC + HMAC) foram banidos.

### Algoritmos AEAD

| Algoritmo | Cifra + Autenticação | Onde Aparece | Notas |
|-----------|---------------------|--------------|-------|
| **AES-256-GCM** | AES-256 (CTR) + GMAC | TLS, SSH, IPsec | Padrão dominante. Rápido com hardware AES-NI + CLMUL. |
| **AES-128-GCM** | AES-128 (CTR) + GMAC | TLS, SSH, IPsec | Seguro e mais rápido que AES-256-GCM. |
| **ChaCha20-Poly1305** | ChaCha20 + Poly1305 | TLS, SSH, WireGuard | Alternativa sem dependência de hardware AES. |
| **AES-256-CCM** | AES-256 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Mais lento que GCM (duas passagens). |
| **AES-128-CCM** | AES-128 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Idem. |
| **AES-256-OCB** | AES-256 + Offset Codebook | OpenPGP | Passagem única (mais rápido que GCM). |
| **AES-256-EAX** | AES-256 (CTR) + OMAC | OpenPGP | Sem patentes, simples de implementar. |

Na prática, os três AEADs dominantes são: **AES-GCM** (com hardware), **ChaCha20-Poly1305** (sem hardware) e **AES-CCM** (em protocolos que exigem).

---

## J.6 Criptografia Assimétrica — "Duas Chaves: Uma Pública, Uma Privada"

### O Conceito

Na criptografia assimétrica (ou de chave pública), cada participante possui um **par de chaves**:

- **Chave pública:** Pode ser distribuída livremente. Usada para criptografar dados destinados ao dono e para verificar assinaturas.
- **Chave privada:** Deve ser mantida em segredo absoluto. Usada para descriptografar dados e para criar assinaturas.

A relação matemática entre as duas chaves garante que dados criptografados com a chave pública **só podem** ser descriptografados pela chave privada correspondente, e vice-versa.

Criptografia assimétrica é **muito mais lenta** que simétrica (centenas a milhares de vezes). Por isso, na prática, ela é usada apenas para:
1. **Trocar chaves simétricas** de sessão (TLS handshake).
2. **Assinar** dados (certificados, pacotes de software).
3. **Autenticar** identidades.

A criptografia em massa dos dados sempre usa cifras simétricas.

### Algoritmos Assimétricos

#### RSA (Rivest-Shamir-Adleman)

- **O que é:** Primeiro sistema prático de criptografia de chave pública (1977). Baseado na dificuldade de fatorar o produto de dois números primos grandes.
- **Tamanhos de chave comuns:** 2048, 3072, 4096 bits.
- **Uso:** Assinatura (certificados X.509, pacotes), troca de chave (TLS 1.2 — depreciado), autenticação.
- **Status:** Seguro com chaves ≥ 2048 bits. Chaves de 1024 bits são consideradas inseguras desde ~2010. Vulnerável a computadores quânticos (algoritmo de Shor).
- **Nas crypto-policies:** DEFAULT exige `min_rsa_size = 2048`, FUTURE exige 3072.

**RSA-PKCS#1 v1.5 vs RSA-PSS:**

| Esquema | Descrição | Status |
|---------|-----------|--------|
| **RSA-PKCS#1 v1.5** | Esquema de padding original (1998). Determinístico para assinaturas. | Seguro para assinaturas, mas **inseguro para criptografia** (ataque Bleichenbacher). TLS mantém por compatibilidade mas está sendo eliminado. |
| **RSA-PSS** | Probabilistic Signature Scheme (2003). Padding aleatório torna cada assinatura diferente mesmo para a mesma mensagem. | **Recomendado.** Prova de segurança formal. TLS 1.3 exige PSS para assinaturas RSA. |
| **RSA-OAEP** | Optimal Asymmetric Encryption Padding. Para criptografia (não assinatura). | Seguro. Substituto de PKCS#1 v1.5 para criptografia. |

#### DSA (Digital Signature Algorithm)

- **O que é:** Algoritmo de assinatura baseado no problema do logaritmo discreto. Padrão NIST (FIPS 186, 1994).
- **Tamanhos de chave:** 1024, 2048, 3072 bits.
- **Status:** **Depreciado.** O NIST não recomenda mais DSA para novas implementações (FIPS 186-5, 2023). Vulnerável a computadores quânticos.
- **Nas crypto-policies:** DEFAULT não inclui DSA em `sign`. LEGACY inclui DSA-SHA1 e variantes.

#### Diffie-Hellman (DH)

- **O que é:** Primeiro protocolo de troca de chave de chave pública (1976). Permite que duas partes concordem em um segredo compartilhado sobre um canal inseguro.
- **Como funciona (simplificado):** Alice e Bob escolhem números grandes públicos (p, g). Cada um gera um segredo privado, calcula um valor público derivado e troca. Ambos podem então calcular o mesmo segredo compartilhado, mas um observador não consegue.
- **Variantes:**
  - **DH clássico (FFDHE):** Usa aritmética modular em campos finitos. Grupos padronizados: FFDHE-2048, FFDHE-3072, FFDHE-4096, etc. (RFC 7919).
  - **ECDH (Elliptic Curve DH):** Usa curvas elípticas. Muito mais eficiente — uma curva de 256 bits oferece segurança equivalente a DH de 3072 bits.
- **Status:** Seguro com parâmetros adequados. DH com 1024 bits é vulnerável ao ataque Logjam (2015). Vulnerável a computadores quânticos.
- **Nas crypto-policies:** DEFAULT exige `min_dh_size = 2048`. FUTURE exige 3072.

**DHE (Diffie-Hellman Ephemeral):** Versão em que chaves DH novas são geradas para cada sessão, fornecendo **forward secrecy** — mesmo que a chave privada de longo prazo do servidor seja comprometida no futuro, sessões passadas permanecem seguras.

#### ECDSA (Elliptic Curve Digital Signature Algorithm)

- **O que é:** Versão de curva elíptica do DSA. Assinaturas menores e mais rápidas para o mesmo nível de segurança.
- **Curvas comuns:** P-256 (NIST), P-384, P-521.
- **Status:** Seguro. Padrão para certificados modernos (especialmente em mobile/IoT por causa do tamanho menor).
- **Cuidado crítico:** ECDSA requer um nonce aleatório para cada assinatura. Se o gerador de números aleatórios falhar e o nonce se repetir, a chave privada é **imediatamente** recuperável. Isto aconteceu na PlayStation 3 (2010) e em carteiras Bitcoin.
- **Nas crypto-policies:** ECDSA-SHA2-256/384/512 são incluídos em todas as políticas.

#### EdDSA (Edwards-curve Digital Signature Algorithm)

- **O que é:** Algoritmo de assinatura baseado em curvas de Edwards torcidas. Criado por Daniel J. Bernstein e colaboradores.
- **Variantes:**
  - **Ed25519:** Usa curva Curve25519. Chave de 256 bits, ~128 bits de segurança. Assinaturas de 512 bits.
  - **Ed448:** Usa curva Goldilocks. Chave de 448 bits, ~224 bits de segurança. Assinaturas de 912 bits.
- **Status:** Seguro. Projetado para ser resistente a ataques de canal lateral e não depende de nonce aleatório (usa hash determinístico).
- **Vantagem sobre ECDSA:** Determinístico — não depende de RNG para gerar assinaturas, eliminando a classe de vulnerabilidades de nonce repetido.
- **Onde aparece:** SSH (chave preferida), TLS 1.3, WireGuard, Signal.
- **Nas crypto-policies:** Ed25519 e Ed448 são incluídos em DEFAULT, FUTURE e FIPS.

---

## J.7 Curvas Elípticas — "Mais Segurança com Menos Bits"

### O Conceito

A Criptografia de Curvas Elípticas (ECC) usa as propriedades matemáticas de curvas elípticas sobre campos finitos para criar sistemas criptográficos. A vantagem principal é **eficiência**: uma chave ECC de 256 bits oferece segurança comparável a uma chave RSA de 3072 bits.

| Segurança (bits) | RSA/DH (bits) | ECC (bits) | Fator de redução |
|-------------------|---------------|------------|------------------|
| 80 | 1024 | 160 | 6,4× |
| 112 | 2048 | 224 | 9,1× |
| 128 | 3072 | 256 | 12× |
| 192 | 7680 | 384 | 20× |
| 256 | 15360 | 512 | 30× |

### Curvas Comuns

#### Curvas NIST (P-256, P-384, P-521)

- **O que são:** Curvas padronizadas pelo NIST (FIPS 186-4). Usam a forma curta de Weierstrass.
- **P-256 (secp256r1):** 128 bits de segurança. A curva mais usada em certificados TLS.
- **P-384 (secp384r1):** 192 bits de segurança. Usada por governos e ambientes de alta segurança.
- **P-521 (secp521r1):** 256 bits de segurança. Raramente necessária.
- **Controvérsia:** Os seeds usados para gerar os parâmetros das curvas NIST nunca foram totalmente explicados, gerando desconfiança de que a NSA possa ter escolhido parâmetros com uma backdoor. Nenhuma vulnerabilidade foi encontrada, mas a desconfiança motivou a criação das curvas Bernstein.

#### Curve25519 / X25519

- **O que é:** Curva de Montgomery criada por Daniel J. Bernstein (2006). O nome X25519 refere-se à função de troca de chave; Curve25519 é a curva subjacente.
- **Segurança:** ~128 bits.
- **Vantagens:** Projetada para ser resistente a ataques de canal lateral, com implementação de tempo constante. Parâmetros completamente transparentes (o número primo é 2²⁵⁵ − 19, justificando o nome).
- **Onde aparece:** TLS 1.3 (grupo preferido), SSH, WireGuard, Signal, QUIC.
- **Nas crypto-policies:** Presente em DEFAULT, FUTURE e FIPS (nos grupos).

#### Curve448 / X448

- **O que é:** Curva "Goldilocks" criada por Mike Hamburg (2014). Versão de alta segurança do X25519.
- **Segurança:** ~224 bits.
- **Onde aparece:** TLS 1.3, SSH.

#### Ed25519 / Ed448

- **O que são:** Curvas de Edwards usadas para assinaturas (EdDSA). Ed25519 usa o isomorfismo de Curve25519. Ed448 usa Curve448.
- **Ver seção J.6** para detalhes de uso em assinaturas.

#### Curvas Brainpool

- **O que são:** Curvas alternativas geradas pelo grupo de trabalho ECC Brainpool (consórcio europeu). Parâmetros gerados de forma verificável a partir de constantes de hash.
- **Variantes:** brainpoolP256r1, brainpoolP384r1, brainpoolP512r1.
- **Onde aparece:** TLS (europeu), regulamentações BSI (Alemanha).
- **Nas crypto-policies:** Suportadas pelo código-fonte mas não incluídas nas políticas padrão do RHEL.

---

## J.8 Troca de Chave — "Combinar um Segredo em Público"

### O Conceito

O problema fundamental da criptografia simétrica é: como Alice e Bob compartilham a chave sem que um atacante a intercepte? A troca de chave resolve isto permitindo que duas partes concordem em um segredo compartilhado sobre um canal público.

### Métodos de Troca de Chave

#### ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)

- **O que é:** Diffie-Hellman sobre curvas elípticas, com chaves efêmeras (novas a cada sessão).
- **Status:** **Padrão atual.** Forward secrecy. Rápido. Chaves pequenas.
- **Onde aparece:** TLS 1.2 e 1.3, SSH, IPsec.
- **Nas crypto-policies:** Primeiro ou segundo na lista de `key_exchange` em todas as políticas.

#### DHE (Diffie-Hellman Ephemeral)

- **O que é:** DH clássico com chaves efêmeras, usando grupos FFDHE padronizados (RFC 7919).
- **Status:** Seguro com grupos ≥ 2048 bits. Mais lento que ECDHE.
- **Onde aparece:** TLS 1.2, SSH, IPsec.
- **Nas crypto-policies:** Presente em todas as políticas, com `min_dh_size` controlando o tamanho mínimo.

#### RSA Key Transport (Transporte de Chave RSA)

- **O que é:** O cliente gera o segredo de sessão, criptografa com a chave pública RSA do servidor, e envia.
- **Status:** **Depreciado.** Sem forward secrecy — se a chave privada do servidor for comprometida, todas as sessões passadas podem ser descriptografadas. Removido do TLS 1.3.
- **Nas crypto-policies:** DEFAULT mantém `RSA` em `key_exchange` por compatibilidade; FUTURE o remove.

#### PSK (Pre-Shared Key)

- **O que é:** Chave previamente compartilhada entre as partes (configurada manualmente ou derivada de sessão anterior).
- **Variantes:** PSK puro, DHE-PSK (com forward secrecy), ECDHE-PSK.
- **Onde aparece:** IoT, TLS resumption, VPNs ponto-a-ponto.

#### KEM (Key Encapsulation Mechanism)

- **O que é:** Mecanismo mais recente para troca de chave, onde uma parte "encapsula" uma chave em um ciphertext que só o destinatário pode "desencapsular". Diferente de DH onde ambos contribuem.
- **Onde aparece:** Algoritmos pós-quânticos (ML-KEM/Kyber). Ver seção J.10.

---

## J.9 Assinaturas Digitais — "Cartório Matemático"

### O Conceito

Uma assinatura digital prova três coisas:

1. **Autenticidade:** A mensagem veio do dono da chave privada.
2. **Integridade:** A mensagem não foi alterada após a assinatura.
3. **Não-repúdio:** O signatário não pode negar ter assinado (porque só ele possui a chave privada).

O processo:
1. O signatário calcula o hash da mensagem.
2. O hash é "criptografado" com a chave privada (na verdade, é uma operação matemática específica de assinatura).
3. Qualquer pessoa com a chave pública pode verificar a assinatura.

### Esquemas de Assinatura nas Crypto-Policies

As crypto-policies nomeiam assinaturas como `ALGORITMO-HASH`. Exemplos:

| Nome na Política | Significado |
|------------------|-------------|
| `RSA-SHA2-256` | Assinatura RSA (PKCS#1 v1.5) com hash SHA-256 |
| `RSA-PSS-SHA2-256` | Assinatura RSA-PSS com hash SHA-256 |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS com chave no formato RSAE (retrocompatível) |
| `ECDSA-SHA2-256` | Assinatura ECDSA com hash SHA-256 |
| `ECDSA-SHA2-384` | Assinatura ECDSA com hash SHA-384 |
| `EDDSA-ED25519` | Assinatura EdDSA usando curva Ed25519 (hash é intrínseco) |
| `EDDSA-ED448` | Assinatura EdDSA usando curva Ed448 |
| `DSA-SHA1` | Assinatura DSA com hash SHA-1 (legado) |
| `RSA-SHA1` | Assinatura RSA com hash SHA-1 (legado) |
| `ECDSA-SHA1` | Assinatura ECDSA com hash SHA-1 (legado) |

**Regra prática:** Se o nome contém `SHA1`, a assinatura é legado e está sendo eliminada. Se contém `PSS`, é a variante moderna de RSA. Se começa com `EDDSA`, é a opção mais moderna.

---

## J.10 Criptografia Pós-Quântica — "Preparando-se Para o Futuro"

### O Problema

Computadores quânticos suficientemente poderosos poderão:

- **Quebrar RSA** usando o algoritmo de Shor (fatoração).
- **Quebrar ECC/DH** usando o algoritmo de Shor (logaritmo discreto).
- **Enfraquecer hashes e cifras simétricas** usando o algoritmo de Grover (busca) — reduz a segurança pela metade (AES-256 cai para ~128 bits, ainda seguro; AES-128 cai para ~64 bits, inseguro).

A ameaça "harvest now, decrypt later" (HNDL) já é real: adversários podem capturar tráfego criptografado hoje e armazená-lo para descriptografar quando computadores quânticos estiverem disponíveis.

### Algoritmos Padronizados pelo NIST (2024)

#### ML-KEM (Module-Lattice-Based Key Encapsulation Mechanism)

- **Nome anterior:** CRYSTALS-Kyber.
- **Tipo:** Troca de chave (KEM).
- **Problema matemático:** Learning With Errors em reticulados (lattice).
- **Variantes:**
  - **ML-KEM-512:** ~128 bits de segurança (NIST nível 1).
  - **ML-KEM-768:** ~192 bits de segurança (NIST nível 3).
  - **ML-KEM-1024:** ~256 bits de segurança (NIST nível 5).
- **Uso nas crypto-policies:** Em modo **híbrido** — combinado com algoritmo clássico para manter segurança mesmo se o PQ for quebrado:
  - `MLKEM768-X25519` — ML-KEM-768 + X25519
  - `P256-MLKEM768` — ML-KEM-768 + NIST P-256
  - `P384-MLKEM1024` — ML-KEM-1024 + NIST P-384
- **Status:** Presente em DEFAULT do RHEL como primeiro grupo na lista (maior prioridade).

#### ML-DSA (Module-Lattice-Based Digital Signature Algorithm)

- **Nome anterior:** CRYSTALS-Dilithium.
- **Tipo:** Assinatura digital.
- **Problema matemático:** Learning With Errors em reticulados.
- **Variantes:**
  - **ML-DSA-44 (MLDSA44):** NIST nível 2. Presente em DEFAULT.
  - **ML-DSA-65 (MLDSA65):** NIST nível 3. Presente em DEFAULT.
  - **ML-DSA-87 (MLDSA87):** NIST nível 5. Presente em DEFAULT.
- **Tamanho das assinaturas:** Significativamente maiores que ECDSA (~2.4 KB para ML-DSA-44 vs ~64 bytes para ECDSA-P256).

#### SLH-DSA (Stateless Hash-Based Digital Signature Algorithm)

- **Nome anterior:** SPHINCS+.
- **Tipo:** Assinatura digital baseada em hash (não em reticulados).
- **Vantagem:** Segurança baseada apenas na segurança de funções de hash — entendidas há décadas. É o "plano B" caso os esquemas baseados em reticulados sejam quebrados.
- **Desvantagem:** Assinaturas grandes (~7–49 KB) e lentas.
- **Variantes nas crypto-policies:** `SLHDSA-SHAKE-128S`, `SLHDSA-SHAKE-128F`, `SLHDSA-SHAKE-256S` — presentes em DEFAULT para Sequoia/RPM (OpenPGP).

### Outros Algoritmos PQ (Experimentais)

| Algoritmo | Tipo | Status |
|-----------|------|--------|
| **FALCON** | Assinatura (NTRU lattice) | NIST round 4. Assinaturas menores que ML-DSA mas implementação complexa. |
| **NTRU Prime (SNTRUP761)** | KEM | Usado em SSH (`sntrup761x25519-sha512@openssh.com`). Alternativa ao ML-KEM. |

### O Conceito de Abordagem Híbrida

A migração PQ está sendo feita em modo **híbrido**: cada operação criptográfica combina um algoritmo clássico (ex: X25519) com um algoritmo PQ (ex: ML-KEM-768). Se o algoritmo PQ se revelar inseguro, a segurança clássica permanece. Se o computador quântico chegar, o PQ protege.

---

## J.11 Funções de Derivação de Chave (KDF) — "Fabricar Chaves a Partir de Segredos"

### O Conceito

Uma KDF (Key Derivation Function) transforma um segredo de entrada (que pode ser fraco, como uma senha, ou forte, como o resultado de uma troca de chave) em uma ou mais chaves criptográficas adequadas para uso.

### KDFs Comuns

#### HKDF (HMAC-based Key Derivation Function)

- **O que é:** KDF padronizada (RFC 5869) baseada em HMAC. Duas fases: Extract (comprime entropia) + Expand (gera material de chave).
- **Onde aparece:** TLS 1.3 (derivação de todas as chaves de sessão), Signal Protocol, WireGuard.
- **Status:** Padrão para derivação de chave a partir de segredos de alta entropia.

#### PBKDF2 (Password-Based Key Derivation Function 2)

- **O que é:** KDF projetada para derivar chaves a partir de **senhas** (segredos de baixa entropia). Aplica HMAC repetidamente para tornar ataques de força bruta lentos.
- **Parâmetro:** Número de iterações (recomendado ≥ 600.000 para SHA-256 em 2024).
- **Onde aparece:** WPA2 (Wi-Fi), LUKS1 (criptografia de disco Linux), PKCS#12, armazenamento de senhas.
- **Status:** Seguro mas inferior a Argon2. Vulnerável a ataques com GPU/ASIC (a operação HMAC é eficiente em hardware paralelo).

#### bcrypt

- **O que é:** Função de hashing de senhas baseada no Blowfish (1999). Custo computacional ajustável.
- **Onde aparece:** Armazenamento de senhas em bancos de dados, `/etc/shadow` em muitos sistemas.
- **Status:** Seguro. Resistente a GPU por design (requer acesso aleatório a memória).

#### scrypt

- **O que é:** KDF que exige grandes quantidades de memória além de CPU, tornando ataques com hardware especializado mais caros.
- **Onde aparece:** Algumas criptomoedas, LUKS2 (opcional).

#### Argon2

- **O que é:** Vencedor da Password Hashing Competition (2015). Três variantes: Argon2d (resistente a GPU), Argon2i (resistente a side-channel), Argon2id (híbrido, recomendado).
- **Onde aparece:** LUKS2 (padrão), armazenamento moderno de senhas.
- **Status:** **Recomendado para novas implementações.** Superior a PBKDF2, bcrypt e scrypt em todos os critérios.

---

## J.12 Protocolos de Transporte Seguro — "O Envelope Completo"

### O Conceito

Os protocolos de transporte seguro combinam todas as primitivas anteriores em um sistema completo de comunicação segura. Um protocolo TLS, por exemplo, usa troca de chave (ECDHE) para estabelecer um segredo, KDF (HKDF) para derivar chaves de sessão, cifra AEAD (AES-GCM) para criptografar dados, assinatura digital (ECDSA) para autenticar o servidor, e hash (SHA-256) para integridade.

### TLS (Transport Layer Security)

| Versão | Status | Notas |
|--------|--------|-------|
| **SSL 2.0** (1995) | **Removido** | Múltiplas vulnerabilidades fatais. Removido das bibliotecas. |
| **SSL 3.0** (1996) | **Removido** | Vulnerável a POODLE. Removido das bibliotecas. |
| **TLS 1.0** (1999) | **Depreciado** | Vulnerável a BEAST. Desabilitado em DEFAULT. |
| **TLS 1.1** (2006) | **Depreciado** | Sem vulnerabilidades específicas conhecidas, mas sem ciphersuites AEAD. Desabilitado em DEFAULT. |
| **TLS 1.2** (2008) | **Seguro** | Suporta AEAD (AES-GCM). Ampla compatibilidade. Requer configuração cuidadosa. |
| **TLS 1.3** (2018) | **Recomendado** | Apenas AEAD. Handshake mais rápido (1-RTT). Forward secrecy obrigatório. Sem RSA key transport. |

**Ciphersuite TLS 1.3:** O nome completo (ex: `TLS_AES_256_GCM_SHA384`) indica: protocolo (TLS), cifra AEAD (AES-256-GCM), hash para HKDF (SHA-384). Troca de chave não faz parte do nome porque é sempre ECDHE ou DHE.

### DTLS (Datagram TLS)

- **O que é:** TLS adaptado para UDP (transporte sem conexão). Necessário porque TLS assume TCP (entrega ordenada e confiável).
- **Versões:** DTLS 1.0 (baseado em TLS 1.1), DTLS 1.2 (baseado em TLS 1.2).
- **Onde aparece:** VoIP (SRTP), VPN (OpenConnect), IoT (CoAP).

### IKE (Internet Key Exchange)

| Versão | Status | Notas |
|--------|--------|-------|
| **IKEv1** | **Depreciado** | Complexo, múltiplos modos de operação, vulnerabilidades. |
| **IKEv2** | **Recomendado** | Simplificado, mais seguro, suporta MOBIKE (mobilidade). |

IKE é o protocolo usado pelo IPsec (VPN) para negociar parâmetros criptográficos e estabelecer Security Associations.

---

## J.13 Níveis de Segurança — "O Que Significa 128 Bits de Segurança"

### O Conceito

Quando dizemos que um sistema tem **N bits de segurança**, significa que o melhor ataque conhecido requer aproximadamente **2^N** operações. Para referência:

| Bits | Operações | Viabilidade |
|------|-----------|-------------|
| 64 | 2⁶⁴ ≈ 1,8 × 10¹⁹ | Quebrável com hardware dedicado em meses |
| 80 | 2⁸⁰ ≈ 1,2 × 10²⁴ | Marginal — agências podem ter capacidade |
| 112 | 2¹¹² ≈ 5,2 × 10³³ | Seguro para uso atual |
| 128 | 2¹²⁸ ≈ 3,4 × 10³⁸ | **Padrão mínimo recomendado.** Inquebrável com tecnologia clássica previsível |
| 192 | 2¹⁹² ≈ 6,3 × 10⁵⁷ | Margem de segurança para décadas |
| 256 | 2²⁵⁶ ≈ 1,2 × 10⁷⁷ | Seguro mesmo contra computadores quânticos (para cifras simétricas) |

### Equivalência Entre Algoritmos

| Nível de Segurança | Cifra Simétrica | Hash | RSA/DH | ECC | Política RHEL |
|--------------------|-----------------|------|--------|-----|---------------|
| 80 bits | 3DES | SHA-1 | 1024 | 160 | — |
| 112 bits | AES-128 | SHA-224 | 2048 | 224 | DEFAULT |
| 128 bits | AES-128 | SHA-256 | 3072 | 256 | FUTURE |
| 192 bits | AES-192 | SHA-384 | 7680 | 384 | — |
| 256 bits | AES-256 | SHA-512 | 15360 | 512 | — |

A política DEFAULT do RHEL visa 112 bits de segurança. A política FUTURE visa 128 bits.

---

## J.14 Resumo Visual — Quando Usar O Quê

```
┌─────────────────────────────────────────────────────────────────┐
│                    ESCOLHENDO A PRIMITIVA                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Preciso CRIPTOGRAFAR dados em massa?                            │
│  └─→ AES-256-GCM (com hardware) ou ChaCha20-Poly1305 (sem)     │
│                                                                  │
│  Preciso verificar INTEGRIDADE sem chave?                        │
│  └─→ SHA-256 (ou SHA-512 em 64-bit)                             │
│                                                                  │
│  Preciso verificar integridade COM autenticação?                 │
│  └─→ HMAC-SHA256 (ou use AEAD que já inclui)                    │
│                                                                  │
│  Preciso ASSINAR um documento/certificado?                       │
│  └─→ Ed25519 (preferido) ou ECDSA-P256 ou RSA-PSS-SHA256       │
│                                                                  │
│  Preciso TROCAR CHAVE com alguém?                                │
│  └─→ ECDHE com X25519 (ou MLKEM768-X25519 para PQ)             │
│                                                                  │
│  Preciso derivar chave de uma SENHA?                             │
│  └─→ Argon2id (preferido) ou PBKDF2-SHA256                      │
│                                                                  │
│  Preciso derivar chaves de um SEGREDO forte?                     │
│  └─→ HKDF-SHA256                                                 │
│                                                                  │
│  Preciso de resistência a COMPUTADORES QUÂNTICOS?                │
│  └─→ Abordagem híbrida: ML-KEM + ECDHE para troca de chave,     │
│      ML-DSA para assinaturas, AES-256 para criptografia          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## J.15 Tabela de Referência Rápida — Status de Cada Algoritmo

### Cifras Simétricas

| Algoritmo | Seguro? | Nas Crypto-Policies? | Recomendação |
|-----------|---------|---------------------|--------------|
| AES-256-GCM | Sim | Todas | Preferido |
| AES-128-GCM | Sim | DEFAULT, LEGACY, FIPS | Aceitável |
| ChaCha20-Poly1305 | Sim | DEFAULT, FUTURE, LEGACY | Alternativa ao AES |
| AES-256-CBC | Sim (com EtM) | DEFAULT, LEGACY, FIPS (não em SSH/TLS) | Legado, preferir GCM |
| AES-128-CBC | Sim (com EtM) | DEFAULT, LEGACY, FIPS (não em SSH) | Legado, preferir GCM |
| Camellia-256-GCM | Sim | DEFAULT (não em TLS) | Raro |
| 3DES-CBC | Fraco | Apenas LEGACY | Migrar para AES |
| RC4 | Quebrado | Nenhuma | Nunca usar |
| DES | Quebrado | Nenhuma | Nunca usar |

### Hashes

| Algoritmo | Seguro? | Nas Crypto-Policies? | Recomendação |
|-----------|---------|---------------------|--------------|
| SHA-256 | Sim | Todas | Padrão |
| SHA-384 | Sim | Todas | Alta segurança |
| SHA-512 | Sim | Todas | Máxima segurança |
| SHA3-256 | Sim | Todas | Alternativa a SHA-256 |
| SHA-1 | Colisões | LEGACY (geral), DEFAULT (apenas HMAC/DNSSec) | Apenas HMAC |
| MD5 | Quebrado | Apenas LEGACY (PKCS12/SMIME) | Nunca para segurança |

### Assinaturas

| Algoritmo | Seguro? | Nas Crypto-Policies? | Recomendação |
|-----------|---------|---------------------|--------------|
| Ed25519 | Sim | DEFAULT, FUTURE, FIPS | Preferido (SSH) |
| ECDSA-SHA2-256 | Sim | Todas | Preferido (certificados) |
| RSA-PSS-SHA2-256 | Sim | Todas | Preferido (RSA) |
| RSA-SHA2-256 | Sim | Todas | Aceitável |
| ML-DSA-65 | Sim (PQ) | Todas | Futuro |
| RSA-SHA1 | Fraco | LEGACY, DEFAULT (DNSSec) | Migrar |
| DSA-SHA1 | Fraco | Apenas LEGACY | Nunca |

### Troca de Chave

| Método | Forward Secrecy? | PQ-Seguro? | Recomendação |
|--------|:----------------:|:----------:|--------------|
| ECDHE (X25519) | Sim | Não | Padrão atual |
| MLKEM768-X25519 | Sim | Sim (híbrido) | Futuro |
| DHE (FFDHE-3072+) | Sim | Não | Aceitável |
| RSA key transport | Não | Não | Depreciado |

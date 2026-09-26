# Apêndice I: Crypto-Policies — Arquitetura Interna, Subpolíticas e Referência Completa de Parâmetros

> **Escopo:** Este apêndice documenta o funcionamento interno do framework `crypto-policies` do RHEL 8/9/10 — desde a definição de políticas até a geração dos arquivos de configuração de cada back-end. Cobre todos os parâmetros da linguagem de políticas, o sistema de escopos, a criação de subpolíticas `.pmod`, políticas completas `.pol`, as irregularidades de cada back-end e o fluxo real do `update-crypto-policies`.

---

## I.1 Por Que Este Apêndice Existe

Os capítulos 10, 23 e 31 deste tutorial apresentam o que as crypto-policies fazem, como alternar entre elas e como diagnosticar problemas. Este apêndice vai além: descreve **como** o sistema funciona internamente, qual a sintaxe exata aceita nos arquivos `.pol` e `.pmod`, quais parâmetros existem, como cada um afeta cada back-end e quais armadilhas concretas esperam o administrador que cria políticas customizadas.

---

## I.2 Arquitetura Interna — O Pipeline Completo

O comando `update-crypto-policies` é um wrapper shell (`/usr/bin/update-crypto-policies`) que invoca o script Python `update-crypto-policies.py`. Todo o processamento real ocorre em Python, usando os módulos `cryptopolicies` (parsing da política) e `policygenerators` (geração de back-ends).

Quando o administrador executa `update-crypto-policies --set DEFAULT:NO-SHA1`, o sistema percorre as seguintes etapas:

```
┌──────────────────────────────────────────────────────────────────┐
│  1. LEITURA DA POLÍTICA BASE                                     │
│     A classe UnscopedCryptoPolicy busca DEFAULT.pol nesta ordem: │
│       1. Diretório atual                                         │
│       2. policies/ (relativo)                                    │
│       3. /etc/crypto-policies/policies/                          │
│       4. /usr/share/crypto-policies/policies/                    │
│     O primeiro arquivo encontrado é usado.                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. LEITURA E CONCATENAÇÃO DAS SUBPOLÍTICAS                      │
│     Busca NO-SHA1.pmod em modules/ nos mesmos caminhos acima.    │
│                                                                  │
│     As diretivas de DEFAULT.pol e NO-SHA1.pmod são concatenadas  │
│     em uma lista sequencial de objetos Directive(prop_name,      │
│     scope, operation, value).                                    │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. PRÉ-PROCESSAMENTO (preprocess_text)                          │
│     Antes do parsing, o texto bruto passa por:                   │
│     a) Remoção de comentários (#)                                │
│     b) Resolução de continuações de linha (\)                    │
│     c) Normalização de espaços                                   │
│     d) Conversão de parâmetros depreciados para equivalentes     │
│        modernos (ex: min_tls_version=TLS1.2 →                    │
│        protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1)           │
│     e) Renomeação de valores (ex: X25519-MLKEM768 →              │
│        MLKEM768-X25519)                                          │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. PARSING (parse_line → parse_rhs)                             │
│     Cada linha é convertida em Directives com operações:         │
│     - RESET:    "cipher ="          → limpa a lista              │
│     - APPEND:   "cipher = AES-*"    → adiciona ao final          │
│     - PREPEND:  "cipher = +AES-*"   → insere no início           │
│     - OMIT:     "cipher = -RC4-*"   → remove da lista            │
│     - SET_INT:  "min_rsa_size=2048" → define inteiro             │
│     - SET_ENUM: "__ems = ENFORCE"   → define enumeração          │
│     Wildcards (*) são expandidos contra as listas conhecidas     │
│     de algoritmos (alg_lists.py).                                │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  5. RESOLUÇÃO ESCOPADA (ScopedPolicy)                            │
│     Para cada back-end, a lista de Directives é avaliada com     │
│     os escopos relevantes daquele back-end. Uma diretiva só      │
│     tem efeito se seu ScopeSelector corresponder aos escopos     │
│     do back-end. Ex: cipher@SSH só afeta {'ssh','openssh'}.      │
│     O resultado são listas de algoritmos .enabled e .disabled    │
│     mais os valores de .integers e .enums.                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  6. GERAÇÃO DOS BACK-ENDS (PolicyGenerators)                     │
│     13 classes geradoras convertem a ScopedPolicy em configs:    │
│                                                                  │
│     ┌─────────────────────────┬────────────────────────────┐     │
│     │ Classe Geradora         │ Arquivo .config            │     │
│     ├─────────────────────────┼────────────────────────────┤     │
│     │ OpenSSLGenerator        │ opensslcnf.config          │     │
│     │ OpenSSLFIPSGenerator    │ openssl_fips.config        │     │
│     │ GnuTLSGenerator         │ gnutls.config              │     │
│     │ NSSGenerator            │ nss.config                 │     │
│     │ OpenSSHClientGenerator  │ openssh.config             │     │
│     │ OpenSSHServerGenerator  │ opensshserver.config       │     │
│     │ LibsshGenerator         │ libssh.config              │     │
│     │ KRB5Generator           │ krb5.config                │     │
│     │ LibreswanGenerator      │ libreswan.config           │     │
│     │ BindGenerator           │ bind.config                │     │
│     │ JavaGenerator           │ java.config                │     │
│     │ SequoiaGenerator        │ sequoia.config             │     │
│     │ RPMSequoiaGenerator     │ rpm-sequoia.config         │     │
│     └─────────────────────────┴────────────────────────────┘     │
│     Cada gerador traduz os nomes genéricos de algoritmos para    │
│     os nomes específicos da biblioteca usando tabelas de         │
│     mapeamento (cipher_map, sign_map, group_map, etc.).          │
│     Cada gerador também TESTA a config gerada executando o       │
│     binário real da biblioteca (openssl ciphers, gnutls-cli -l,  │
│     ssh -G, sshd -T) para validar que não há erros.              │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. GERAÇÃO DOS BACK-ENDS                                        │
│     Para cada biblioteca/aplicação suportada, um gerador de      │
│     configuração específico (policy generator) converte a        │
│     política efetiva em um formato que a biblioteca entende:     │
│                                                                  │
│     ┌────────────┬──────────────────────────────────────────┐    │
│     │ Back-end   │ Arquivo gerado                           │    │
│     ├────────────┼──────────────────────────────────────────┤    │
│     │ OpenSSL    │ opensslcnf.config                        │    │
│     │ GnuTLS     │ gnutls.config                            │    │
│     │ NSS        │ nss.config                               │    │
│     │ OpenSSH    │ openssh.config, opensshserver.config     │    │
│     │ libssh     │ libssh.config                            │    │
│     │ Kerberos   │ krb5.config                              │    │
│     │ Libreswan  │ libreswan.config                         │    │
│     │ BIND       │ bind.config                              │    │
│     │ Java/JDK   │ java.config                              │    │
│     │ Sequoia    │ sequoia.config                           │    │
│     │ RPM-Seqoia │ rpm-sequoia.config                       │    │
│     └────────────┴──────────────────────────────────────────┘    │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  7. INSTALAÇÃO DOS BACK-ENDS                                     │
│     Os arquivos gerados são escritos atomicamente em:            │
│       /etc/crypto-policies/back-ends/                            │
│     (via mkstemp + os.rename para evitar corrupção)              │
│                                                                  │
│     Se a política não usa subpolíticas E não existe local.d/,    │
│     um SYMLINK é criado para os back-ends pré-gerados em         │
│     /usr/share/crypto-policies/<POLICY>/ (otimização).           │
│                                                                  │
│     Se existir conteúdo em /etc/crypto-policies/local.d/,        │
│     ele é CONCATENADO ao final do back-end correspondente.       │
│                                                                  │
│     O arquivo /etc/crypto-policies/config é atualizado.          │
│     O arquivo /etc/crypto-policies/state/CURRENT.pol recebe      │
│     o dump legível da política efetiva expandida.                │
│     O arquivo /etc/crypto-policies/state/current recebe o        │
│     nome da política ativa (ex: "DEFAULT:NO-SHA1").              │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  8. RELOAD DOS SERVIÇOS                                          │
│     Se --no-reload NÃO foi usado, o script executa               │
│     /usr/share/crypto-policies/reload-cmds.sh que contém         │
│     comandos de reload para cada serviço afetado.                │
│     Exemplo: "systemctl try-restart sshd.service" para SSH.      │
│     Outras bibliotecas (OpenSSL, GnuTLS, NSS) só aplicam         │
│     a nova política quando a aplicação é reiniciada.             │
└──────────────────────────────────────────────────────────────────┘
```

**Ponto crítico:** As aplicações (Apache, NGINX, Postfix, etc.) não leem a política diretamente. Elas usam bibliotecas (OpenSSL, GnuTLS, NSS) que por sua vez leem os arquivos de back-end. A mudança de política só tem efeito quando o processo que usa a biblioteca é reiniciado.

---

## I.3 Hierarquia Completa de Arquivos

```
/usr/share/crypto-policies/
├── policies/                          # Políticas base do pacote
│   ├── DEFAULT.pol
│   ├── LEGACY.pol
│   ├── FUTURE.pol
│   ├── FIPS.pol
│   ├── BSI.pol
│   ├── EMPTY.pol
│   ├── NEXT.pol                       # Alias para DEFAULT
│   └── modules/                       # Subpolíticas do pacote
│       ├── AD-SUPPORT.pmod
│       ├── NO-SHA1.pmod
│       ├── NO-CAMELLIA.pmod
│       ├── NO-ENFORCE-EMS.pmod
│       ├── GOST.pmod
│       └── ...
├── DEFAULT/                           # Back-ends pré-gerados para DEFAULT
│   ├── opensslcnf.config
│   ├── gnutls.config
│   ├── nss.config
│   └── ...
├── LEGACY/                            # Back-ends pré-gerados para LEGACY
│   └── ...
├── FUTURE/                            # Back-ends pré-gerados para FUTURE
│   └── ...
└── FIPS/                              # Back-ends pré-gerados para FIPS
    └── ...

/etc/crypto-policies/
├── config                             # Texto com nome da política ativa
│                                      # Ex: "DEFAULT:NO-SHA1"
├── back-ends/                         # Back-ends ativos (links ou cópias)
│   ├── opensslcnf.config
│   ├── openssl_fips.config            # Configuração do módulo FIPS do OpenSSL
│   ├── gnutls.config
│   ├── nss.config
│   ├── openssh.config
│   ├── opensshserver.config
│   ├── libssh.config
│   ├── krb5.config
│   ├── libreswan.config
│   ├── bind.config
│   ├── java.config
│   ├── sequoia.config
│   └── rpm-sequoia.config
├── local.d/                           # Overrides locais por back-end
│   ├── opensslcnf-extra.config        # Concatenado ao opensslcnf.config
│   ├── gnutls-extra.config
│   └── ...
├── state/
│   └── current -> /usr/share/crypto-policies/DEFAULT  # Link simbólico
├── policies/                          # Políticas customizadas locais
│   ├── MYPOLICY.pol                   # Política customizada completa
│   └── modules/                       # Subpolíticas customizadas locais
│       └── MY-MODULE.pmod
└── state/
    └── CURRENT.pol                    # Política efetiva expandida
```

**Prioridade de busca:** Quando `update-crypto-policies` procura um arquivo `.pol` ou `.pmod`, ele verifica primeiro `/etc/crypto-policies/policies/` e depois `/usr/share/crypto-policies/policies/`. Isto permite sobrescrever políticas do pacote localmente.

---

## I.4 Formato de Definição de Política — Sintaxe Completa

Os arquivos `.pol` e `.pmod` usam uma sintaxe INI simples: `chave = valor`.

### I.4.1 Regras Gerais de Sintaxe

```ini
# Comentários começam com '#'
# Tudo após '#' na linha é ignorado

# Continuação de linha com '\'
cipher = AES-256-GCM AES-128-GCM \
         CHACHA20-POLY1305

# Atribuição direta — define a lista completa
cipher = AES-256-GCM AES-128-GCM CHACHA20-POLY1305

# Modificação incremental — adiciona e remove da lista existente
# '+' no início = prepend (inserir no começo da lista, maior prioridade)
# sem prefixo no final = append (inserir no final da lista)
# '-' = remover da lista
cipher = +AES-256-GCM -CAMELLIA-256-GCM AES-128-CCM+

# Lista vazia — desabilita tudo nessa categoria
cipher =

# Valores inteiros
min_rsa_size = 3072

# Valores booleanos (0 ou 1)
sha1_in_certs = 0
```

**Regra fundamental da modificação incremental:**

| Prefixo/Sufixo | Significado | Exemplo |
|-----------------|-------------|---------|
| `+VALOR` (prefixo `+`) | Prepend — insere no início da lista (maior prioridade) | `cipher = +AES-256-GCM` |
| `VALOR+` (sufixo `+`) | Append — insere no final da lista (menor prioridade) | `cipher = AES-128-CCM+` |
| `-VALOR` (prefixo `-`) | Remove — retira da lista | `cipher = -CAMELLIA-256-GCM` |
| `VALOR` (sem prefixo, atribuição direta) | Reset — substitui a lista inteira | `cipher = AES-256-GCM AES-128-GCM` |

**Atribuição direta e modificação incremental NÃO podem ser combinadas na mesma diretiva.**

### I.4.2 Wildcards

O caractere `*` serve como curinga para correspondência em nomes de algoritmos:

```ini
# Remover TODOS os algoritmos SHA1 de assinatura
sign = -*-SHA1

# Remover todos os ciphers AES-128
cipher = -AES-128-*

# Remover todas as cifras Camellia
cipher = -CAMELLIA-*
```

**Cuidado:** Wildcards em diretivas de adição (`+`) podem habilitar algoritmos futuros que ainda não existem na versão atual. Use wildcards com `-` (remoção) por segurança.

### I.4.3 Escopos (@scope) — Diretivas Por Back-end

Escopos permitem que uma diretiva afete apenas back-ends específicos:

```ini
# Sintaxe: opção@escopo = valor

# Apenas para SSH
cipher@SSH = -AES-128-CBC

# Apenas para TLS
protocol@TLS = TLS1.3 TLS1.2

# Apenas para IKE (IPsec)
protocol@IKE = IKEv2

# Múltiplos escopos
cipher@{SSH,TLS} = -CAMELLIA-*

# Negação de escopo — aplica a todos EXCETO o especificado
cipher@!SSH = -AES-128-CBC

# Negação com múltiplos escopos
cipher@!{SSH,Kerberos} = -AES-128-CBC
```

**Escopos disponíveis** (lista completa extraída do código-fonte, `ALL_SCOPES`):

| Escopo | Back-ends afetados | Notas |
|--------|-------------------|-------|
| `tls`, `ssl` | OpenSSL, GnuTLS, NSS (nss-tls), Java | Sinônimos |
| `openssl` | Apenas OpenSSL | Mais específico que `tls` |
| `gnutls` | Apenas GnuTLS | Mais específico que `tls` |
| `java-tls` | Apenas Java/OpenJDK | Mais específico que `tls` |
| `nss` | NSS (todos os sub-escopos) | Escopo raiz NSS |
| `nss-tls` | NSS para TLS | Herda de `nss` |
| `ssh` | OpenSSH (client+server), libssh | Escopo genérico SSH |
| `openssh` | OpenSSH (client+server) | Mais específico que `ssh` |
| `openssh-client` | Apenas OpenSSH cliente | Herda de `openssh` |
| `openssh-server` | Apenas OpenSSH servidor | Herda de `openssh` |
| `libssh` | Apenas libssh | Mais específico que `ssh` |
| `ipsec`, `ike` | Libreswan | Sinônimos |
| `libreswan` | Apenas Libreswan | Mais específico que `ipsec` |
| `kerberos`, `krb5` | MIT Kerberos | Sinônimos |
| `dnssec`, `bind` | BIND | Sinônimos |
| `sequoia` | Sequoia PGP | OpenPGP |
| `rpm`, `rpm-sequoia` | RPM via Sequoia | Verificação de pacotes RPM |
| `pkcs12` | NSS — PKCS#12 | Herda de `nss` |
| `pkcs12-import` | NSS — importação PKCS#12 | Herda de `nss-pkcs12` |
| `nss-pkcs12` | NSS — PKCS#12 | Sinônimo funcional |
| `nss-pkcs12-import` | NSS — importação PKCS#12 | Mais permissivo |
| `smime` | NSS — S/MIME | Herda de `nss` |
| `smime-import` | NSS — importação S/MIME | Herda de `nss-smime` |
| `nss-smime` | NSS — S/MIME | Sinônimo funcional |
| `nss-smime-import` | NSS — importação S/MIME | Mais permissivo |

Seletores de escopo são **case-insensitive**. Suportam globbing (`*`) e negação (`!`). Múltiplos escopos em chaves: `@{SSH,TLS}`. Negação múltipla: `@!{SSH,Kerberos}`.

**Hierarquia de herança:** Ver seção I.13 para a hierarquia completa de escopos com relações pai-filho.

---

## I.5 Referência Completa de Parâmetros

### I.5.1 Parâmetros de Lista (múltiplos valores)

#### `cipher` — Cifras Simétricas

Define quais algoritmos de criptografia simétrica (e modos de operação) são permitidos.

```ini
cipher = AES-256-GCM AES-256-CCM AES-256-CBC \
         AES-128-GCM AES-128-CCM AES-128-CBC \
         CHACHA20-POLY1305
```

**Valores reconhecidos:**

| Valor | Descrição | Tamanho Chave |
|-------|-----------|---------------|
| `AES-256-GCM` | AES 256-bit, modo Galois/Counter (autenticado) | 256 bits |
| `AES-256-CCM` | AES 256-bit, modo Counter with CBC-MAC | 256 bits |
| `AES-256-CBC` | AES 256-bit, modo Cipher Block Chaining | 256 bits |
| `AES-256-CTR` | AES 256-bit, modo Counter | 256 bits |
| `AES-128-GCM` | AES 128-bit, modo GCM | 128 bits |
| `AES-128-CCM` | AES 128-bit, modo CCM | 128 bits |
| `AES-128-CBC` | AES 128-bit, modo CBC | 128 bits |
| `AES-128-CTR` | AES 128-bit, modo CTR | 128 bits |
| `CHACHA20-POLY1305` | ChaCha20 com Poly1305 AEAD | 256 bits |
| `CAMELLIA-256-GCM` | Camellia 256-bit, modo GCM | 256 bits |
| `CAMELLIA-256-CBC` | Camellia 256-bit, modo CBC | 256 bits |
| `CAMELLIA-128-GCM` | Camellia 128-bit, modo GCM | 128 bits |
| `CAMELLIA-128-CBC` | Camellia 128-bit, modo CBC | 128 bits |
| `AES-192-GCM` | AES 192-bit, modo GCM | 192 bits |
| `AES-192-CCM` | AES 192-bit, modo CCM | 192 bits |
| `AES-192-CBC` | AES 192-bit, modo CBC | 192 bits |
| `AES-192-CTR` | AES 192-bit, modo CTR | 192 bits |
| `AES-256-OCB` | AES 256-bit, modo OCB (Sequoia) | 256 bits |
| `AES-128-OCB` | AES 128-bit, modo OCB (Sequoia) | 128 bits |
| `AES-256-EAX` | AES 256-bit, modo EAX (Sequoia) | 256 bits |
| `AES-128-EAX` | AES 128-bit, modo EAX (Sequoia) | 128 bits |
| `AES-256-CFB` | AES 256-bit, modo CFB (Sequoia/RPM) | 256 bits |
| `AES-128-CFB` | AES 128-bit, modo CFB (Sequoia/RPM) | 128 bits |
| `3DES-CBC` | Triple DES, modo CBC | 168 bits (efetivo: 112) |
| `RC4-128` | RC4 stream cipher | 128 bits |
| `RC4-40` | RC4 com chave de 40 bits | 40 bits |
| `RC2-CBC` | RC2 modo CBC | Variável |
| `DES-CBC` | DES modo CBC | 56 bits |
| `DES40-CBC` | DES modo CBC com chave de 40 bits | 40 bits |
| `IDEA-CBC` | IDEA modo CBC | 128 bits |
| `SEED-CBC` | SEED modo CBC | 128 bits |
| `NULL` | Sem criptografia (apenas integridade) | 0 bits |

**Nota:** Algoritmos como `AES-*-OCB`, `AES-*-EAX` e `AES-*-CFB` são usados principalmente pelos back-ends Sequoia e RPM (OpenPGP). Algoritmos como `DES-CBC`, `RC4-40`, `RC2-CBC`, `DES40-CBC`, `IDEA-CBC` e `SEED-CBC` existem apenas para suporte de importação de arquivos PKCS#12 legado na política LEGACY.

**Impacto por back-end:**

- **OpenSSL:** Traduzido em lista de `Ciphersuites` e `CipherString` no `opensslcnf.config`. A remoção de `AES-128-GCM` desabilita TODOS os ciphers AES-128 (não é possível desabilitar seletivamente um modo isolado).
- **GnuTLS:** Lista de cifras na priority string do `gnutls.config`.
- **NSS:** Lista de ciphersuites no `nss.config`.
- **OpenSSH:** Lista de `Ciphers` no `openssh.config` e `opensshserver.config`.
- **Kerberos:** Tipos de criptografia permitidos (`permitted_enctypes`) no `krb5.config`.

#### `mac` — Algoritmos MAC

Define quais Message Authentication Codes são permitidos.

```ini
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 \
      HMAC-SHA1 AEAD \
      UMAC-128 UMAC-64
```

**Valores reconhecidos:**

| Valor | Descrição |
|-------|-----------|
| `HMAC-SHA2-256` | HMAC com SHA-256 |
| `HMAC-SHA2-384` | HMAC com SHA-384 |
| `HMAC-SHA2-512` | HMAC com SHA-512 |
| `HMAC-SHA1` | HMAC com SHA-1 |
| `AEAD` | MACs integrados a cifras AEAD (GCM, Poly1305) |
| `UMAC-64` | UMAC com tag de 64 bits (SSH) |
| `UMAC-128` | UMAC com tag de 128 bits (SSH) |
| `HMAC-MD5` | HMAC com MD5 (inseguro — apenas legado) |

**Impacto por back-end:**

- **OpenSSH:** Gera lista `MACs` (`hmac-sha2-256`, `hmac-sha2-512`, `umac-128-etm@openssh.com`, etc.).
- **OpenSSL:** Afeta indiretamente — ciphers CBC requerem `HMAC-SHA1` e `AES-256-CBC` na lista para serem habilitados.
- **GnuTLS:** `HMAC-SHA2-256` e `HMAC-SHA2-384` como MACs standalone estão desabilitados devido a preocupações com implementação constant-time; apenas `AEAD` é usado na prática para TLS 1.3.

#### `hash` — Algoritmos de Hash (Message Digest)

Define quais funções de hash criptográficas são permitidos para uso geral (diferente de assinaturas).

```ini
hash = SHA2-256 SHA2-384 SHA2-512 \
       SHA3-256 SHA3-384 SHA3-512 \
       SHA2-224 SHA1
```

**Valores reconhecidos:**

| Valor | Saída (bits) | Uso Comum |
|-------|-------------|-----------|
| `SHA1` | 160 | Legado (inseguro para assinaturas) |
| `SHA2-224` | 224 | Raro |
| `SHA2-256` | 256 | Padrão moderno |
| `SHA2-384` | 384 | TLS 1.3, certificados |
| `SHA2-512` | 512 | Alta segurança |
| `SHA3-256` | 256 | Padrão NIST alternativo |
| `SHA3-384` | 384 | Padrão NIST alternativo |
| `SHA3-512` | 512 | Padrão NIST alternativo |
| `SHA3-224` | 224 | SHA-3 com saída reduzida |
| `SHAKE-128` | Variável | Função extensível (XOF) |
| `SHAKE-256` | Variável | Função extensível (XOF) |
| `MD5` | 128 | Inseguro — apenas legado extremo |

**Relação hash vs sign:** O parâmetro `hash` controla uso geral (HMAC, derivação de chave, DNSSec). Para controlar quais hashes são aceitos em *assinaturas*, use `sign`.

#### `sign` — Algoritmos de Assinatura

Define quais combinações de algoritmo+hash de assinatura são permitidas.

```ini
sign = RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448
```

**Valores reconhecidos:**

| Valor | Descrição |
|-------|-----------|
| `RSA-SHA1` | RSA PKCS#1 v1.5 com SHA-1 |
| `RSA-SHA2-224` | RSA PKCS#1 v1.5 com SHA-224 |
| `RSA-SHA2-256` | RSA PKCS#1 v1.5 com SHA-256 |
| `RSA-SHA2-384` | RSA PKCS#1 v1.5 com SHA-384 |
| `RSA-SHA2-512` | RSA PKCS#1 v1.5 com SHA-512 |
| `RSA-PSS-SHA2-256` | RSA-PSS com SHA-256 |
| `RSA-PSS-SHA2-384` | RSA-PSS com SHA-384 |
| `RSA-PSS-SHA2-512` | RSA-PSS com SHA-512 |
| `ECDSA-SHA1` | ECDSA com SHA-1 |
| `ECDSA-SHA2-224` | ECDSA com SHA-224 |
| `ECDSA-SHA2-256` | ECDSA com SHA-256 |
| `ECDSA-SHA2-384` | ECDSA com SHA-384 |
| `ECDSA-SHA2-512` | ECDSA com SHA-512 |
| `EDDSA-ED25519` | EdDSA usando curva Ed25519 |
| `EDDSA-ED448` | EdDSA usando curva Ed448 |
| `DSA-SHA1` | DSA com SHA-1 (legado) |
| `DSA-SHA2-256` | DSA com SHA-256 |
| `ECDSA-SHA2-256-FIDO` | ECDSA com SHA-256 via FIDO (WebAuthn) |
| `EDDSA-ED25519-FIDO` | EdDSA Ed25519 via FIDO (WebAuthn) |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS (chave RSAE) com SHA-256 |
| `RSA-PSS-RSAE-SHA2-384` | RSA-PSS (chave RSAE) com SHA-384 |
| `RSA-PSS-RSAE-SHA2-512` | RSA-PSS (chave RSAE) com SHA-512 |
| `RSA-SHA3-256` | RSA PKCS#1 v1.5 com SHA3-256 |
| `RSA-PSS-SHA3-256` | RSA-PSS com SHA3-256 |
| `ECDSA-SHA3-256` | ECDSA com SHA3-256 |
| `MLDSA44` | ML-DSA-44 (pós-quântico NIST, nível 2) |
| `MLDSA65` | ML-DSA-65 (pós-quântico NIST, nível 3) |
| `MLDSA87` | ML-DSA-87 (pós-quântico NIST, nível 5) |
| `MLDSA65-ED25519` | ML-DSA-65 + Ed25519 híbrido (OpenPGP RFC 9980) |
| `MLDSA87-ED448` | ML-DSA-87 + Ed448 híbrido (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128S` | SLH-DSA com SHAKE-128 small (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128F` | SLH-DSA com SHAKE-128 fast (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-256S` | SLH-DSA com SHAKE-256 small (OpenPGP RFC 9980) |

**Impacto prático:** Se um certificado X.509 foi assinado com `RSA-SHA1` e a política ativa não inclui `RSA-SHA1` em `sign`, a verificação da cadeia de confiança do certificado falhará. Isto é a causa mais comum de "certificate verify failed" após mudar de LEGACY para DEFAULT.

**Nota PQ:** Os algoritmos ML-DSA são incluídos por padrão em DEFAULT, FUTURE e FIPS. Os algoritmos híbridos e SLH-DSA são incluídos apenas para os escopos `sequoia` e `RPM` (OpenPGP), conforme RFC 9980.

#### `key_exchange` — Métodos de Troca de Chave

```ini
key_exchange = ECDHE DHE RSA PSK DHE-RSA DHE-DSS
```

| Valor | Descrição | Forward Secrecy |
|-------|-----------|:---------------:|
| `ECDHE` | Elliptic Curve Diffie-Hellman Ephemeral | Sim |
| `DHE` | Diffie-Hellman Ephemeral | Sim |
| `DHE-RSA` | DHE autenticado com RSA | Sim |
| `DHE-DSS` | DHE autenticado com DSS/DSA | Sim |
| `RSA` | Troca de chave RSA estática | Não |
| `PSK` | Pre-Shared Key | Depende |
| `ECDHE-GSS` | ECDHE com GSSAPI (SSH) | Sim |
| `DHE-GSS` | DHE com GSSAPI (SSH) | Sim |
| `KEM-ECDH` | Key Encapsulation Mechanism com ECDH (pós-quântico) | Sim |
| `SNTRUP` | NTRU Prime com X25519 (SSH pós-quântico) | Sim |
| `RSA-PSK` | Pre-Shared Key com autenticação RSA | Não |
| `ECDHE-PSK` | ECDHE com Pre-Shared Key | Sim |
| `DHE-PSK` | DHE com Pre-Shared Key | Sim |

**Nota:** A política FUTURE remove `RSA` e `DHE-DSS` da troca de chave — isto significa que servidores usando certificados com chaves DSA não conseguirão estabelecer conexões.

**Nota sobre Libreswan:** O parâmetro `key_exchange` **não afeta** a configuração gerada para Libreswan. Para limitar DH/ECDH no IPsec, use o parâmetro `group`.

#### `group` — Grupos/Curvas para Troca de Chave

Define quais curvas elípticas e grupos Diffie-Hellman são permitidos.

```ini
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192
```

**Grupos pós-quânticos (híbridos):**

| Valor | Tipo | Descrição |
|-------|------|-----------|
| `MLKEM768-X25519` | PQ Híbrido | ML-KEM-768 combinado com X25519 |
| `P256-MLKEM768` | PQ Híbrido | ML-KEM-768 combinado com NIST P-256 |
| `P384-MLKEM1024` | PQ Híbrido | ML-KEM-1024 combinado com NIST P-384 |
| `MLKEM1024-X448` | PQ Híbrido | ML-KEM-1024 combinado com X448 |

**Grupos clássicos:**

| Valor | Tipo | Tamanho | Descrição |
|-------|------|---------|-----------|
| `X25519` | Curva Bernstein | ~128-bit seg. | Curva moderna, rápida |
| `X448` | Curva Goldilocks | ~224-bit seg. | Curva moderna, alta segurança |
| `SECP256R1` | NIST P-256 | 256 bits | Curva NIST padrão |
| `SECP384R1` | NIST P-384 | 384 bits | Curva NIST alta segurança |
| `SECP521R1` | NIST P-521 | 521 bits | Curva NIST máxima segurança |
| `FFDHE-1024` | Finite Field DH | 1024 bits | Grupo DH legado (apenas LEGACY) |
| `FFDHE-1536` | Finite Field DH | 1536 bits | Grupo DH (apenas LEGACY) |
| `FFDHE-2048` | Finite Field DH | 2048 bits | Grupo DH padronizado (RFC 7919) |
| `FFDHE-3072` | Finite Field DH | 3072 bits | Grupo DH padronizado |
| `FFDHE-4096` | Finite Field DH | 4096 bits | Grupo DH padronizado |
| `FFDHE-6144` | Finite Field DH | 6144 bits | Grupo DH padronizado |
| `FFDHE-8192` | Finite Field DH | 8192 bits | Grupo DH padronizado |

**Nota sobre OpenSSL:** A ordem dos valores de `group` só é respeitada dentro das "classes" PQ (pós-quântico) e clássica. Todos os grupos PQ são automaticamente ordenados acima dos clássicos. No `opensslcnf.config`, o formato é `Groups = *pq_group1:pq_group2/*classic_group1:classic_group2` onde `*` indica classes de grupos e `/` separa classes.

**Nota sobre NSS:** A ordem dos valores de `group` é **ignorada** — NSS usa sua ordem interna embutida.

**Nota sobre FIPS e PQ:** Na política FIPS, ML-KEM é suportado para grupos TLS mas desabilitado por escopo para OpenSSL (não suportado no FIPS provider), Sequoia/RPM e parcialmente OpenSSH.

#### `protocol` — Versões de Protocolo Permitidas

```ini
protocol = TLS1.3 TLS1.2 DTLS1.2 IKEv2
```

| Valor | Descrição |
|-------|-----------|
| `SSL3.0` | SSLv3 (removido das bibliotecas — não pode ser habilitado) |
| `TLS1.0` | TLS 1.0 |
| `TLS1.1` | TLS 1.1 |
| `TLS1.2` | TLS 1.2 |
| `TLS1.3` | TLS 1.3 |
| `DTLS0.9` | DTLS 0.9 |
| `DTLS1.0` | DTLS 1.0 |
| `DTLS1.2` | DTLS 1.2 |
| `IKEv1` | IKE versão 1 (IPsec legado) |
| `IKEv2` | IKE versão 2 (IPsec moderno) |

**Limitação:** Alguns back-ends (OpenSSL, NSS) não permitem desabilitar versões de protocolo seletivamente — eles usam a versão mais antiga da lista como limite inferior. Desabilitar todas as versões TLS e/ou DTLS resulta nos padrões da biblioteca sendo aplicados.

### I.5.2 Parâmetros Inteiros

| Parâmetro | Descrição | Exemplo | Impacto |
|-----------|-----------|---------|---------|
| `min_rsa_size` | Tamanho mínimo de chave RSA em bits | `2048` | Conexões com chaves RSA menores são rejeitadas. Afeta TODOS os back-ends. |
| `min_dh_size` | Tamanho mínimo de parâmetros DH em bits | `2048` | Troca de chave DH com parâmetros menores é rejeitada. |
| `min_dsa_size` | Tamanho mínimo de chave DSA em bits | `2048` | Chaves DSA menores são rejeitadas. |
| `min_ec_size` | Tamanho mínimo de chave EC em bits | `256` | **Aplica-se apenas ao back-end Java/OpenJDK.** |

**Como OpenSSL aplica tamanhos mínimos:** OpenSSL não tem granularidade fina para tamanhos mínimos — ele usa o mecanismo `@SECLEVEL` que define faixas de segurança. `min_rsa_size = 2048` corresponde a `@SECLEVEL=2`. `min_rsa_size = 3072` corresponde a `@SECLEVEL=3`. Isto significa que nem todos os valores arbitrários são possíveis.

| SECLEVEL | RSA mín | DH mín | ECC mín | Hash mín | Segurança |
|----------|---------|--------|---------|----------|-----------|
| 0 | 0 | 0 | 0 | - | Tudo permitido |
| 1 | 1024 | 1024 | 160 | SHA-1 | 80 bits |
| 2 | 2048 | 2048 | 224 | SHA-224 | 112 bits |
| 3 | 3072 | 3072 | 256 | SHA-256 | 128 bits |
| 4 | 7680 | 7680 | 384 | SHA-384 | 192 bits |
| 5 | 15360 | 15360 | 512 | SHA-512 | 256 bits |

### I.5.3 Parâmetros Booleanos (0 ou 1)

| Parâmetro | Descrição | Padrão (DEFAULT) | Impacto |
|-----------|-----------|------------------|---------|
| `sha1_in_certs` | Permite SHA-1 em assinaturas de certificados | `0` | **Aplica-se apenas ao back-end GnuTLS.** Se `0`, certificados assinados com SHA-1 são rejeitados na validação de cadeia. |
| `arbitrary_dh_groups` | Permite grupos DH arbitrários (não padronizados) | `0` | Se `0`, apenas grupos FFDHE padronizados (RFC 7919) são aceitos. Se `1`, aceita parâmetros DH arbitrários gerados pelo servidor. |
| `ssh_certs` | Permite autenticação por certificados OpenSSH | `1` | Se `0`, desabilita o mecanismo de certificados do OpenSSH (não confundir com certificados X.509). |

### I.5.4 Parâmetros de Enumeração

| Parâmetro | Valores | Descrição |
|-----------|---------|-----------|
| `etm` | `ANY`, `DISABLE_ETM`, `DISABLE_NON_ETM` | Controla Encrypt-then-MAC vs Encrypt-and-MAC. **Implementado apenas para SSH.** Use com escopo `@SSH`. `ANY` permite ambos. `DISABLE_ETM` força Encrypt-and-MAC (E&M). `DISABLE_NON_ETM` força Encrypt-then-MAC (EtM). |
| `__ems` | `DEFAULT`, `ENFORCE`, `RELAX` | **Interno.** Controla Extended Master Secret (RFC 7627). `ENFORCE` é usado pela política FIPS para forçar EMS. `RELAX` desabilita o requisito (subpolítica NO-ENFORCE-EMS). **Afeta OpenSSL e GnuTLS.** Ver seção I.14 para detalhes. |

### I.5.5 Parâmetros Depreciados

Os seguintes parâmetros ainda funcionam mas devem ser migrados. O código-fonte (`preprocess_text` em `cryptopolicies.py`) faz a conversão automaticamente e emite um `FutureWarning`:

| Depreciado | Conversão Automática Exata | Motivo |
|------------|---------------------------|--------|
| `min_tls_version = TLS1.2` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1` | Substituído por remoção incremental |
| `min_tls_version = TLS1.3` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1 -TLS1.2` | Idem |
| `min_dtls_version = DTLS1.2` | `protocol@TLS = -DTLS0.9 -DTLS1.0` | Idem |
| `ike_protocol = IKEv2` | `protocol@IKE = IKEv2` | Renomeação para escopo |
| `tls_cipher = ...` | `cipher@TLS = ...` | Renomeação para escopo |
| `ssh_cipher = ...` | `cipher@SSH = ...` | Renomeação para escopo |
| `ssh_group = ...` | `group@SSH = ...` | Renomeação para escopo |
| `sha1_in_dnssec = 0` | `hash@DNSSec = -SHA1` + `sign@DNSSec = -RSA-SHA1 -ECDSA-SHA1` | Separação em dois parâmetros |
| `sha1_in_dnssec = 1` | `hash@DNSSec = SHA1+` + `sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+` | Idem |
| `ssh_etm = 0` | `etm@SSH = DISABLE_ETM` | Renomeação para enum |
| `ssh_etm = 1` | `etm@SSH = ANY` | Idem |
| `ssh_etm@<scope> = 0` | `etm@<scope> = DISABLE_ETM` | Suporta escopo |

Além disso, o valor `X25519-MLKEM768` é automaticamente convertido para `MLKEM768-X25519` (renomeação de algoritmo, RHEL-99813).

O parâmetro `protocol` (sem escopo) ainda funciona mas emite warning — deve ser substituído por `protocol@TLS`.

---

## I.6 Diferença Entre `.pol` e `.pmod`

### Arquivo `.pol` — Política Completa

- Define **todos** os parâmetros do zero.
- Usada como política base.
- Aplicada com `update-crypto-policies --set MYPOLICY`.
- Deve conter valores para todas as opções relevantes (caso contrário, ficam vazias/padrão da biblioteca).
- **Não evolui** com atualizações do pacote `crypto-policies` — se a Red Hat adicionar novos back-ends ou parâmetros, sua política customizada não os incluirá automaticamente.

### Arquivo `.pmod` — Subpolítica/Módulo Modificador

- Modifica **seletivamente** uma política base existente.
- Não precisa definir todos os parâmetros — apenas os que quer alterar.
- Aplicada com `update-crypto-policies --set BASE:MYPOLICY`.
- **Evolui** com atualizações — como apenas modifica a base, quando a base é atualizada pelo pacote, as modificações permanecem e se aplicam sobre a nova versão.
- **Múltiplos módulos** podem ser empilhados: `--set DEFAULT:MOD1:MOD2:MOD3`.

**A Red Hat recomenda fortemente o uso de subpolíticas (`.pmod`) em vez de políticas completas (`.pol`) customizadas.** Isto garante que atualizações de segurança nas políticas base se propaguem automaticamente.

### Mecanismo de Concatenação

Quando a política efetiva é `DEFAULT:NO-SHA1:MY-MODULE`, o sistema concatena os arquivos nesta ordem:

```
DEFAULT.pol + NO-SHA1.pmod + MY-MODULE.pmod
```

Cada diretiva posterior sobrescreve ou modifica a anterior. Se `DEFAULT.pol` define:

```ini
hash = SHA2-256 SHA2-384 SHA2-512 SHA1
```

E `NO-SHA1.pmod` define:

```ini
hash = -SHA1
sign = -RSA-SHA1 -RSA-PSS-SHA1 -ECDSA-SHA1
```

A política efetiva resultante terá `hash` sem `SHA1` e `sign` sem qualquer algoritmo baseado em SHA-1.

---

## I.7 Criando Subpolíticas Customizadas — Guia Passo a Passo

### Exemplo 1: Exigir Chaves RSA de 4096 bits Mínimo

```bash
sudo tee /etc/crypto-policies/policies/modules/RSA-4096.pmod << 'EOF'
min_rsa_size = 4096
min_dh_size = 4096
EOF

sudo update-crypto-policies --set DEFAULT:RSA-4096
```

**Efeito:** Qualquer certificado com chave RSA menor que 4096 bits será rejeitado. Qualquer troca de chave DH com parâmetros menores que 4096 bits será rejeitada. Isto é extremamente restritivo — a maioria dos certificados comerciais usa 2048 ou 4096 bits.

### Exemplo 2: Política para Ambiente Apenas TLS 1.3

```bash
sudo tee /etc/crypto-policies/policies/modules/TLS13-ONLY.pmod << 'EOF'
protocol@TLS = TLS1.3
protocol@!TLS = -TLS1.0 -TLS1.1
cipher@TLS = AES-256-GCM AES-128-GCM CHACHA20-POLY1305
key_exchange = ECDHE
EOF

sudo update-crypto-policies --set DEFAULT:TLS13-ONLY
```

**Efeito:** Apenas TLS 1.3 é permitido para conexões TLS. Apenas cifras AEAD (as únicas que TLS 1.3 suporta). Troca de chave apenas por ECDHE.

### Exemplo 3: Compatibilidade com Active Directory

```bash
sudo tee /etc/crypto-policies/policies/modules/AD-COMPAT.pmod << 'EOF'
cipher@Kerberos = +AES-128-CBC +AES-256-CBC +RC4-128
hash = SHA1 SHA2-256 SHA2-384 SHA2-512+
group = +FFDHE-1024
min_dh_size = 1024
sha1_in_certs = 1
EOF

sudo update-crypto-policies --set DEFAULT:AD-COMPAT
```

**Efeito:** Habilita ciphers necessários para Kerberos com AD legado, permite SHA-1 em certificados (necessário para DCs antigos), aceita parâmetros DH de 1024 bits.

### Exemplo 4: Segurança Máxima para Ambiente Financeiro

```bash
sudo tee /etc/crypto-policies/policies/modules/FINANCE-SEC.pmod << 'EOF'
protocol@TLS = TLS1.3 TLS1.2
cipher = AES-256-GCM CHACHA20-POLY1305
cipher@SSH = AES-256-GCM AES-256-CTR CHACHA20-POLY1305
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 AEAD
hash = SHA2-256 SHA2-384 SHA2-512
sign = RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448
key_exchange = ECDHE DHE
group = X25519 X448 SECP384R1 SECP521R1 FFDHE-4096 FFDHE-8192
min_rsa_size = 4096
min_dh_size = 4096
sha1_in_certs = 0
arbitrary_dh_groups = 0
ssh_certs = 1
etm@SSH = DISABLE_NON_ETM
EOF

sudo update-crypto-policies --set FUTURE:FINANCE-SEC
```

### Exemplo 5: Módulo para Desabilitar CBC em Tudo

```bash
sudo tee /etc/crypto-policies/policies/modules/NO-CBC.pmod << 'EOF'
cipher = -AES-256-CBC -AES-128-CBC -CAMELLIA-256-CBC -CAMELLIA-128-CBC
EOF

sudo update-crypto-policies --set DEFAULT:NO-CBC
```

---

## I.8 Criando uma Política Completa (.pol) do Zero

Para cenários onde nenhuma política base atende e subpolíticas não são suficientes:

```bash
sudo cp /usr/share/crypto-policies/policies/DEFAULT.pol \
        /etc/crypto-policies/policies/MYORG.pol

sudo vi /etc/crypto-policies/policies/MYORG.pol
```

Exemplo de política completa:

```ini
# /etc/crypto-policies/policies/MYORG.pol
# Política organizacional customizada

# Protocolos permitidos
protocol = TLS1.3 TLS1.2 DTLS1.2 IKEv2

# Cifras simétricas
cipher = AES-256-GCM AES-128-GCM CHACHA20-POLY1305
cipher@Kerberos = AES-256-CBC AES-128-CBC+

# MACs
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 AEAD UMAC-128
mac@SSH = HMAC-SHA2-256 HMAC-SHA2-512 AEAD UMAC-128

# Hashes
hash = SHA2-256 SHA2-384 SHA2-512

# Assinaturas
sign = ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448

# Troca de chave
key_exchange = ECDHE DHE

# Grupos/Curvas
group = X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Tamanhos mínimos de chave
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Opções booleanas
sha1_in_certs = 0
arbitrary_dh_groups = 0
ssh_certs = 1
```

Aplicar:

```bash
sudo update-crypto-policies --set MYORG
```

**Atenção:** Com uma política `.pol` customizada, atualizações futuras do pacote `crypto-policies` que melhorem a política `DEFAULT` **não** se propagarão para `MYORG`. Você é responsável por manter sua política atualizada.

---

## I.9 O Mecanismo `local.d` — Overrides Por Back-end

O diretório `/etc/crypto-policies/local.d/` permite adicionar configuração **extra** que é concatenada ao final do arquivo de back-end gerado. Isto NÃO modifica a política — modifica diretamente o arquivo de configuração da biblioteca.

```bash
# Exemplo: Adicionar configuração extra ao OpenSSL
sudo tee /etc/crypto-policies/local.d/opensslcnf-extra.config << 'EOF'
# Configuração extra concatenada ao opensslcnf.config
# (Formato de configuração OpenSSL, não formato de política)
EOF
```

**Convenção de nomes:** O arquivo deve seguir o padrão `<backend>-<sufixo>.config`, onde `<backend>` corresponde ao nome do back-end (sem a extensão `.config`).

**Uso recomendado:** Situações extremas onde a política não oferece o controle necessário sobre um back-end específico. Isto é um mecanismo de último recurso — prefira subpolíticas.

---

## I.10 Como Cada Back-end Consome a Política

### OpenSSL (`OpenSSLGenerator` + `OpenSSLFIPSGenerator`)

O gerador cria dois arquivos: `opensslcnf.config` (configuração geral) e `openssl_fips.config` (configuração do módulo FIPS). O OpenSSL lê `/etc/crypto-policies/back-ends/opensslcnf.config` durante a inicialização via a diretiva `.include` no arquivo `openssl.cnf` principal. Os escopos aplicados são `{'tls', 'ssl', 'openssl'}`.

**Tradução de parâmetros:**

| Parâmetro de Política | Configuração OpenSSL |
|-----------------------|---------------------|
| `cipher` | `Ciphersuites` (TLS 1.3) e `CipherString` (TLS 1.2) |
| `min_rsa_size`, `min_dh_size` | `@SECLEVEL=N` no início de `CipherString` |
| `protocol` | `TLS.MinProtocol`, `TLS.MaxProtocol`, `DTLS.MinProtocol`, `DTLS.MaxProtocol` |
| `group` | `Groups` (PQ e clássico separados por `/`) |
| `sign` | `SignatureAlgorithms` (com prefixo `?` para tolerância a algoritmos desconhecidos) |
| `__ems` | `Options = RHNoEnforceEMSinFIPS` se `RELAX` |
| `__openssl_block_sha1_signatures` | `rh-allow-sha1-signatures = yes/no` |
| `min_rsa_size` | `default_bits` na seção `[req]` (mínimo 2048) |

**Irregularidades OpenSSL:**

1. A lista de ciphers TLS 1.2 (`CipherString`) é gerada por **subtração** — começa listando os `key_exchange` habilitados, depois remove os ciphers, key exchanges e MACs da lista de *desabilitados*. Isto é diferente do modelo de allowlist usado pelo GnuTLS.
2. A `CipherString` sempre exclui `-SHA384`, `-CAMELLIA`, `-ARIA`, `-AESCCM8` e `-CBC` (quando todos os CBC estão desabilitados) por hardcoding no gerador.
3. Para desabilitar ciphers CCM, tanto `AES-128-CCM` quanto `AES-256-CCM` precisam ser removidos; o gerador usa a keyword `-AESCCM`.
4. Todos os `SignatureAlgorithms` são prefixados com `?` (`?RSA+SHA256`) para que o OpenSSL tolere algoritmos que não conhece (ex: pós-quânticos em versões antigas).

### GnuTLS (`GnuTLSGenerator`)

O gerador cria um arquivo de configuração em modo **allowlist** (não mais priority strings como em versões antigas). Os escopos aplicados são `{'tls', 'ssl', 'gnutls'}`. A configuração é lida de `/etc/crypto-policies/back-ends/gnutls.config` via a variável `GNUTLS_SYSTEM_PRIORITY_FILE` (ou o caminho padrão compilado).

**Tradução:**

| Parâmetro de Política | Configuração GnuTLS |
|-----------------------|--------------------|
| `cipher` | `tls-enabled-cipher = AES-256-GCM`, etc. |
| `mac` | `tls-enabled-mac = AEAD`, `tls-enabled-mac = SHA512` |
| `hash` | `secure-hash = SHA256`, etc. |
| `sign` | `secure-sig = RSA-SHA256` + `secure-sig-for-cert = RSA-SHA256` |
| `sha1_in_certs` | `secure-sig-for-cert = rsa-sha1/dsa-sha1/ecdsa-sha1` adicionais |
| `group` | `tls-enabled-group = GROUP-X25519` + `enabled-curve = X25519` |
| `key_exchange` | `tls-enabled-kx = ECDHE-RSA`, `tls-enabled-kx = ECDHE-ECDSA` |
| `protocol` | `enabled-version = TLS1.3`, etc. |
| `min_rsa_size`, `min_dh_size` | `min-verification-profile` |
| `__ems` | `tls-session-hash = require/request` |

**Irregularidades GnuTLS:**

1. `sha1_in_certs` é o **único** back-end que respeita este parâmetro diretamente (adicionando SHA-1 apenas a `secure-sig-for-cert`).
2. `HMAC-SHA2-256` e `HMAC-SHA2-384` como MACs standalone são **mapeados para `None`** no código e portanto nunca habilitados, por preocupações de vulnerabilidade a Lucky13 (ver [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503)). Apenas `AEAD` e `HMAC-SHA2-512` funcionam.
3. PSK key exchanges (`PSK`, `DHE-PSK`, `ECDHE-PSK`, `RSA-PSK`) estão **comentados** no gerador e portanto nunca habilitados via crypto-policies, mesmo que a política os liste.
4. O `ECDHE` key exchange é expandido em **dois** kex types: `ECDHE-RSA` e `ECDHE-ECDSA` no gerador.
5. Curvas precisam ser habilitadas separadamente dos grupos. O gerador extrai as curvas dos grupos e das assinaturas (ex: EdDSA-Ed25519 → `enabled-curve = Ed25519`).

### NSS (Network Security Services)

O gerador cria um arquivo de política NSS em `/etc/crypto-policies/back-ends/nss.config`.

**Irregularidades NSS:**

1. A ordem de `group` é **ignorada** — NSS usa sua ordem interna.
2. É o **único** back-end que respeita escopos `pkcs12`, `pkcs12-import`, `smime` e `smime-import`.
3. `pkcs12` implica `pkcs12-import` — não é possível permitir exportação sem permitir importação.
4. Esses escopos não podem habilitar algoritmos de assinatura que não foram habilitados na configuração geral.
5. Desabilitar todas as versões TLS/DTLS resulta nos padrões da biblioteca.

### OpenSSH (`OpenSSHClientGenerator` + `OpenSSHServerGenerator`)

O gerador cria dois arquivos separados com escopos diferentes:
- **Cliente:** `openssh.config` — escopos `{'ssh', 'openssh', 'openssh-client'}`
- **Servidor:** `opensshserver.config` — escopos `{'ssh', 'openssh', 'openssh-server'}`

**Tradução:**

| Parâmetro de Política | Configuração OpenSSH |
|-----------------------|---------------------|
| `cipher@SSH` | `Ciphers` |
| `mac@SSH` + `etm` | `MACs` (EtM e não-EtM em ordem conforme enum `etm`) |
| `key_exchange` × `group` × `hash` | `KexAlgorithms` (produto cartesiano filtrado pela tabela `kx_map`) |
| `key_exchange` × `hash` + `arbitrary_dh_groups` | `KexAlgorithms` via `gx_map` (group exchange) |
| `sign` | `PubkeyAcceptedAlgorithms`, `HostbasedAcceptedAlgorithms`, `CASignatureAlgorithms` |
| `sign` (servidor) | `HostKeyAlgorithms` (apenas servidor) |
| `ssh_certs` + `sign` | Sufixos `-cert-v01@openssh.com` adicionados a `PubkeyAcceptedAlgorithms` |
| `min_rsa_size` | `RequiredRSASize` (se > 0) |
| `key_exchange` (GSS) | `GSSAPIKexAlgorithms` ou `GSSAPIKeyExchange no` |

**Irregularidades OpenSSH:**

1. DH group 1 (1024 bits) é **sempre** removido no servidor, mesmo que a política permita DH de 1024 bits. O código do servidor explicitamente faz `del local_kx_map[('DHE', 'FFDHE-1024', 'SHA1')]`.
2. `HostKeyAlgorithms` é definido **apenas** para o servidor. Configurá-lo no cliente quebraria o manuseio de entradas `known_hosts` existentes.
3. O `KexAlgorithms` é construído por um **produto cartesiano** de (`key_exchange`, `group`, `hash`), filtrado contra a tabela `kx_map`. Apenas combinações com mapeamento definido produzem saída.
4. `GSSAPIKeyExchange no` é emitido se nenhum GSS kex é habilitado pela política.
5. `CASignatureAlgorithms` não inclui variantes de certificado, apenas algoritmos base.
6. Quando `ssh_certs = 1`, o gerador adiciona certificados incluindo o novo `ssh-mldsa44-ed25519@openssh.com` (pós-quântico).
7. O comando de reload do servidor é `systemctl try-restart sshd.service` (restart, não reload, porque o systemd precisa re-ler opções de linha de comando).

### Libreswan (IPsec/IKE)

**Irregularidades Libreswan:**

1. O parâmetro `key_exchange` **não afeta** a configuração gerada para Libreswan.
2. Para controlar DH vs ECDH no IPsec, use o parâmetro `group`.

### Kerberos (MIT krb5)

O gerador cria `/etc/crypto-policies/back-ends/krb5.config` com a lista `permitted_enctypes`.

**Tradução:** Ciphers são mapeados para enctypes Kerberos (`aes256-cts-hmac-sha384-192`, `aes128-cts-hmac-sha256-128`, etc.).

### Java/OpenJDK

O gerador cria `/etc/crypto-policies/back-ends/java.config` que configura o Java Security Properties.

**Nota:** O parâmetro `min_ec_size` **aplica-se apenas** ao back-end Java.

---

## I.11 Algoritmos Removidos vs Desabilitados

Há uma distinção fundamental entre algoritmos **removidos** das bibliotecas e algoritmos **desabilitados** pelas políticas:

### Removidos Completamente das Bibliotecas Core

Estes algoritmos foram removidos do código-fonte das bibliotecas criptográficas e **não podem ser habilitados** por nenhuma política, nem mesmo LEGACY:

| Algoritmo/Protocolo | Motivo |
|---------------------|--------|
| DES (não 3DES) | Completamente inseguro (56 bits) |
| Export-grade cipher suites | Inseguros por design |
| MD5 em assinaturas | Colisões demonstradas |
| SSLv2 | Múltiplas vulnerabilidades fatais |
| SSLv3 | Vulnerável a POODLE |
| Curvas ECC < 224 bits | Inseguras |
| Curvas ECC de campo binário | Não padronizadas / suspeitas |

### Desabilitados em TODAS as Políticas Pré-definidas (mas disponíveis)

Estes algoritmos existem nas bibliotecas mas estão desabilitados em todas as políticas. Uma política customizada `.pol` **poderia** habilitá-los (não recomendado):

| Algoritmo/Protocolo | Risco |
|---------------------|-------|
| DH com parâmetros < 1024 bits | Ataque Logjam |
| RSA com chave < 1024 bits | Fatorável com hardware moderno |
| Camellia | Não amplamente testado |
| RC4 | Múltiplos vieses conhecidos |
| ARIA | Uso limitado, pouca auditoria |
| SEED | Uso limitado fora da Coreia |
| IDEA | Obsoleto |
| Ciphersuites de integridade apenas | Sem criptografia |
| TLS CBC com HMAC SHA-384 | Implementações problemáticas |
| AES-CCM8 (tag curto) | Tag de autenticação insuficiente |
| Curvas ECC incompatíveis com TLS 1.3 (incluindo secp256k1) | Fora do padrão TLS 1.3 |
| IKEv1 | Substituído por IKEv2 |

---

## I.12 Aplicações e Bibliotecas NÃO Cobertas

As crypto-policies cobrem apenas **dados em trânsito** (data-in-transit). As seguintes situações **não são** controladas:

| Não Coberto | Motivo |
|-------------|--------|
| Aplicações Go | A runtime Go não lê as crypto-policies do sistema |
| GnuPG-2 | Usa seu próprio sistema de configuração |
| Dados em repouso (disk encryption) | LUKS, dm-crypt têm configuração independente |
| Localizações de certificados | Gerenciado por cada serviço individualmente |
| CA trust store | Gerenciado por `update-ca-trust`, não por `crypto-policies` |
| Emissão de certificados | Não controlado (CA/certmonger/certbot) |
| Aplicações que forçam suas próprias configurações | Se a app define ciphers explicitamente no código, a política do sistema é ignorada |

---

## I.13 Hierarquia de Escopos — Visão do Código-Fonte

O código-fonte (`cryptopolicies.py`) define uma hierarquia de escopos onde cada back-end recebe um conjunto de escopos e opcionalmente herda de um escopo pai. A seguinte tabela mostra exatamente quais escopos são aplicados para cada back-end ao gerar sua configuração:

| Back-end (dumpável) | Escopo pai | Conjunto de escopos aplicados |
|---------------------|------------|-------------------------------|
| `bind` | — | `bind`, `dnssec` |
| `gnutls` | — | `gnutls`, `tls`, `ssl` |
| `java-tls` | — | `java-tls`, `tls`, `ssl` |
| `krb5` | — | `krb5`, `kerberos` |
| `libreswan` | — | `ipsec`, `ike`, `libreswan` |
| `libssh` | — | `libssh`, `ssh` |
| `nss` | — | `nss` |
| `nss-tls` | `nss` | `nss`, `nss-tls`, `tls`, `ssl` |
| `nss-pkcs12` | `nss` | `nss`, `pkcs12`, `nss-pkcs12` |
| `nss-pkcs12-import` | `nss-pkcs12` | `nss`, `pkcs12`, `pkcs12-import`, `nss-pkcs12`, `nss-pkcs12-import` |
| `nss-smime` | `nss` | `nss`, `smime`, `nss-smime` |
| `nss-smime-import` | `nss-smime` | `nss`, `smime`, `smime-import`, `nss-smime`, `nss-smime-import` |
| `openssh` | — | `openssh`, `ssh` |
| `openssh-client` | `openssh` | `openssh-client`, `openssh`, `ssh` |
| `openssh-server` | `openssh` | `openssh-server`, `openssh`, `ssh` |
| `openssl` | — | `openssl`, `tls`, `ssl` |
| `sequoia` | — | `sequoia` |
| `rpm` | — | `rpm`, `rpm-sequoia` |

**Como funciona:** Quando o gerador do OpenSSH servidor solicita a configuração, ele passa o conjunto `{'ssh', 'openssh', 'openssh-server'}` para o `ScopedPolicy`. Cada diretiva na política é avaliada contra esses escopos: `cipher@SSH` corresponde (porque `ssh` está no conjunto), `cipher@TLS` não corresponde, `cipher@!SSH` não corresponde. A diretiva `cipher@{SSH,TLS}` corresponderia porque `ssh` está no conjunto.

**Herança pai-filho:** Quando o dump da política é gerado para `CURRENT.pol`, o sistema mostra propriedades específicas de escopo apenas se diferem do escopo pai. Por exemplo, `cipher@openssh-server` só aparece se difere de `cipher@openssh`.

---

## I.14 Parâmetros Internos (Não Documentados Publicamente)

O código-fonte define parâmetros com prefixo `__` (double underscore) que são usados internamente pelas políticas fornecidas pelo sistema. Estes parâmetros não são documentados na man page e não devem ser usados em políticas customizadas, mas entendê-los é importante para compreender o comportamento real:

### `__openssl_block_sha1_signatures`

```python
INT_DEFAULTS = {
    ...
    '__openssl_block_sha1_signatures': 1,
}
```

Controla se o OpenSSL bloqueia verificação de assinaturas SHA-1. Valor padrão `1` (bloquear). No gerador do OpenSSL, isto é traduzido para a diretiva `rh-allow-sha1-signatures = yes/no` na seção `[evp_properties]` do `opensslcnf.config`. Esta é uma **extensão específica da Red Hat** ao OpenSSL, não presente no OpenSSL upstream.

A política LEGACY define `__openssl_block_sha1_signatures = 0`, permitindo verificação de assinaturas SHA-1 no OpenSSL. Todas as outras políticas mantêm o valor `1`.

### `__ems` (Extended Master Secret)

```python
ENUMS = {
    'etm': ('ANY', 'DISABLE_ETM', 'DISABLE_NON_ETM'),
    '__ems': ('DEFAULT', 'ENFORCE', 'RELAX'),
}
```

Controla o requisito de Extended Master Secret (RFC 7627) no TLS. Três valores possíveis:

| Valor | Efeito no OpenSSL | Efeito no GnuTLS |
|-------|-------------------|-------------------|
| `DEFAULT` | Sem ação (biblioteca decide) | Sem ação (`tls-session-hash` não configurado) |
| `ENFORCE` | Sem ação (FIPS já força) | `tls-session-hash = require` |
| `RELAX` | `Options = RHNoEnforceEMSinFIPS` + config FIPS com `tls1-prf-ems-check = 0` | `tls-session-hash = request` |

A política FIPS define `__ems = ENFORCE`. A subpolítica NO-ENFORCE-EMS define `__ems = RELAX`.

O gerador OpenSSL também cria um arquivo separado `openssl_fips.config` que configura o módulo FIPS do OpenSSL:

```ini
[fips_sect]
tls1-prf-ems-check = 1  # ou 0 se __ems == RELAX
activate = 1
```

---

## I.15 Algoritmos Pós-Quânticos no Código-Fonte

O código-fonte (`alg_lists.py`) já define listas extensas de algoritmos pós-quânticos, marcados como experimentais:

### Grupos (Key Encapsulation — ML-KEM)

Os seguintes grupos pós-quânticos estão definidos nas políticas atuais (DEFAULT, FUTURE, FIPS, LEGACY):

| Grupo | Tipo | Descrição |
|-------|------|-----------|
| `MLKEM768-X25519` | Híbrido | ML-KEM-768 com X25519 (padrão NIST + clássico) |
| `P256-MLKEM768` | Híbrido | ML-KEM-768 com NIST P-256 |
| `P384-MLKEM1024` | Híbrido | ML-KEM-1024 com NIST P-384 |
| `MLKEM1024-X448` | Híbrido | ML-KEM-1024 com X448 |

Grupos marcados como experimentais (presentes no código mas não nas políticas padrão):

| Grupo | Status |
|-------|--------|
| `MLKEM512`, `X25519-MLKEM512`, `P256-MLKEM512` | Experimentais |
| `MLKEM768`, `X448-MLKEM768` | Experimentais (variantes solo/alternativas) |
| `MLKEM1024`, `P521-MLKEM1024` | Experimentais |

### Assinaturas (ML-DSA, FALCON, SPHINCS+, SLH-DSA)

Assinaturas pós-quânticas nas políticas padrão:

| Algoritmo | Presente em DEFAULT | Presente em FIPS |
|-----------|:-------------------:|:----------------:|
| `MLDSA44` (ML-DSA-44) | Sim | Sim |
| `MLDSA65` (ML-DSA-65) | Sim | Sim |
| `MLDSA87` (ML-DSA-87) | Sim | Sim |

Assinaturas experimentais no código (não nas políticas padrão):

```
P256-MLDSA44, RSA3072-MLDSA44, MLDSA44-PSS2048, MLDSA44-RSA2048,
MLDSA44-ED25519, MLDSA44-P256, MLDSA44-BP256,
P384-MLDSA65, MLDSA65-PSS3072, MLDSA65-RSA3072,
FALCON512, FALCONPADDED512, FALCON1024, FALCONPADDED1024,
SPHINCSSHA2128FSIMPLE, SPHINCSSHA2128SSIMPLE, SPHINCSSHAKE128FSIMPLE,
... e mais variantes híbridas
```

Assinaturas PQ para OpenPGP (Sequoia/RPM), adicionadas com `sign@{sequoia,RPM}` em todas as políticas padrão:

```
MLDSA65-ED25519, MLDSA87-ED448,
SLHDSA-SHAKE-128S, SLHDSA-SHAKE-128F, SLHDSA-SHAKE-256S
```

**Como o OpenSSL lida com grupos PQ:** O gerador do OpenSSL separa os grupos em duas classes — PQ e clássica — e os formata como `*pq_groups/classic_groups` na diretiva `Groups`. Isto faz com que servidores prefiram qualquer grupo PQ sobre qualquer grupo clássico quando ambos são suportados, e clientes enviem key shares para o grupo PQ de maior prioridade E o grupo clássico de maior prioridade.

---

## I.16 FIPS Auto-Bind-Mount — O Mecanismo de Boot

Quando o kernel é iniciado com `fips=1`, um módulo dracut e/ou um serviço systemd automaticamente fazem bind-mount de:

```
/usr/share/crypto-policies/back-ends/FIPS/  →  /etc/crypto-policies/back-ends/
/usr/share/crypto-policies/default-fips-config  →  /etc/crypto-policies/config
```

Isto garante que a política FIPS esteja ativa desde o primeiro momento do boot, antes mesmo que `update-crypto-policies` possa ser executado.

O script `update-crypto-policies.py` detecta esta situação verificando `/proc/self/mountinfo`:

```
is_fips_auto_bind_mounted():
  Verifica se /etc/crypto-policies/config está montado de
  .../crypto-policies/default-fips-config
  E se /etc/crypto-policies/back-ends está montado de
  .../crypto-policies/back-ends/FIPS
```

**Comportamento quando auto-bind está ativo:**

- `--show`: Funciona normalmente (lê o conteúdo montado).
- `--set FIPS:SUBPOLICY`: Desmonta os bind-mounts com `umount` e então aplica a nova política com a subpolítica. Isto permite customizar FIPS com subpolíticas.
- `--set DEFAULT` (ou outra não-FIPS): Emite aviso de que o sistema não será mais FIPS-compliant, desmonta e aplica.
- Sem `--set`: Avisa que arquivos em `local.d/` serão ignorados enquanto o auto-bind estiver ativo.

**Implicação prática:** Se você precisa de FIPS com uma subpolítica (ex: `FIPS:NO-ENFORCE-EMS`), execute `update-crypto-policies --set FIPS:NO-ENFORCE-EMS` — isto remove o bind-mount automático e aplica uma política FIPS customizada persistente.

---

## I.17 O Que Cada Política Realmente Define — Anotação do Código-Fonte

As seguintes anotações são extraídas diretamente dos arquivos `.pol` do repositório upstream.

### DEFAULT.pol — Anotações

```ini
# Segurança de 112 bits com exceção de SHA-1 em DNSSec

# Inclui ML-KEM e ML-DSA (pós-quânticos) nos primeiros lugares das listas
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 SECP256R1 X448 SECP521R1 SECP384R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# SHA-1 e DSA-SHA1 permitidos apenas em DNSSec e RPM (por escopo)
hash@DNSSec = SHA1+
sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+
sign@RPM = DSA-SHA1+
hash@RPM = SHA1+
min_dsa_size@RPM = 1024   # RPM precisa aceitar pacotes antigos com DSA 1024

# CBC desabilitado em SSH por escopo (vulnerável a plaintext recovery)
cipher@SSH = -*-CBC

# RSA está ANTES de DHE em key_exchange por questão de interoperabilidade
key_exchange = KEM-ECDH ECDHE RSA DHE DHE-RSA PSK DHE-PSK ECDHE-PSK RSA-PSK \
               ECDHE-GSS DHE-GSS

# arbitrary_dh_groups = 1 → aceita parâmetros DH do servidor
# (necessário para compatibilidade com servidores que não usam FFDHE)
arbitrary_dh_groups = 1
```

### FUTURE.pol — Diferenças em Relação a DEFAULT

```ini
# Segurança de 128 bits — preparação para pós-quântico

# HMAC-SHA1 REMOVIDO da lista de MACs
mac = AEAD HMAC-SHA2-256 UMAC-128 HMAC-SHA2-384 HMAC-SHA2-512
# (DEFAULT inclui HMAC-SHA1)

# SHA2-224 e SHA3-224 REMOVIDOS de hash
hash = SHA2-256 SHA2-384 SHA2-512 SHA3-256 SHA3-384 SHA3-512 SHAKE-256

# Sem SHA-1 em NENHUM escopo (sem exceção para DNSSec)
# SHA-224 REMOVIDO de sign
# RSA REMOVIDO de key_exchange (sem troca de chave RSA estática)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK ECDHE-GSS DHE-GSS

# Apenas cifras de 256 bits e AEAD em TLS
cipher@TLS = AES-256-GCM AES-256-CCM CHACHA20-POLY1305

# FFDHE-2048 REMOVIDO (mínimo 3072)
group = ... FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Tamanhos mínimos aumentados
min_dh_size = 3072
min_dsa_size = 3072
min_rsa_size = 3072
```

### LEGACY.pol — Diferenças em Relação a DEFAULT

```ini
# Segurança de 64 bits — máxima compatibilidade

# SHA1 incluído em hash (para uso geral, não apenas DNSSec)
hash = ... SHA1

# DSA e SHA-1 PERMITIDOS em assinaturas
sign = ... DSA-SHA2-256 DSA-SHA2-384 DSA-SHA2-512 DSA-SHA2-224 \
       ECDSA-SHA1 RSA-PSS-SHA1 RSA-SHA1 DSA-SHA1

# 3DES-CBC habilitado em cipher e cipher@TLS
cipher = ... 3DES-CBC
cipher@TLS = ... 3DES-CBC

# CBC HABILITADO em SSH (diferente de DEFAULT/FUTURE/FIPS)
cipher@SSH = AES-256-GCM CHACHA20-POLY1305 AES-256-CTR AES-256-CBC \
    AES-128-GCM AES-128-CTR AES-128-CBC 3DES-CBC

# DHE-DSS habilitado, FFDHE-1536 incluído, FFDHE-1024 para SSH
group@SSH = FFDHE-1024+
key_exchange = ... DHE-DSS ...

# TLS 1.0 e 1.1 habilitados, DTLS 1.0 habilitado
protocol@TLS = TLS1.3 TLS1.2 TLS1.1 TLS1.0 DTLS1.2 DTLS1.0

# Tamanhos mínimos reduzidos
min_dh_size = 1024
min_dsa_size = 1024
min_rsa_size = 1024

# SHA-1 permitido em certificados (GnuTLS)
sha1_in_certs = 1

# OpenSSL NÃO bloqueia assinaturas SHA-1
__openssl_block_sha1_signatures = 0

# PKCS#12 aceita DES, RC4, RC2, SEED (legado extremo)
cipher@pkcs12 = AES-256-CBC AES-192-CBC AES-128-CBC \
    CAMELLIA-256-CBC ... 3DES-CBC DES-CBC RC4-128 DES40-CBC RC2-CBC SEED-CBC
```

### FIPS.pol — Diferenças em Relação a DEFAULT

```ini
# Conformidade FIPS 140 — NÃO garante FIPS por si só

# Sem CHACHA20-POLY1305 (não aprovado FIPS)
cipher@TLS = AES-256-GCM AES-256-CCM AES-256-CBC \
    AES-128-GCM AES-128-CCM AES-128-CBC

# Sem X25519 e X448 nos grupos (não aprovados FIPS como curvas standalone)
# ML-KEM bloqueado para OpenSSL (não suportado no FIPS provider ainda)
# ML-KEM bloqueado para Sequoia/RPM
group@openssl = +P256-MLKEM768  # deprioritize X25519-MLKEM768
group@{sequoia,rpm} = -MLKEM768-X25519 -P256-MLKEM768 -P384-MLKEM1024
group@openssh = -MLKEM768-X25519

# Sem EdDSA, sem FIDO, sem SHA-224 em assinaturas
# Sem RSA-PSS-RSAE variantes SHA3

# PSK sem RSA-PSK (não aprovado)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK

# Extended Master Secret obrigatório
__ems = ENFORCE
```

---

## I.18 Mapeamento de Algoritmos nos Geradores — Tabelas do Código-Fonte

### OpenSSH: Mapeamento de Cifras

O gerador `openssh.py` mapeia nomes genéricos de cifras para os nomes usados pelo OpenSSH:

| Política | OpenSSH |
|----------|---------|
| `AES-256-GCM` | `aes256-gcm@openssh.com` |
| `AES-256-CTR` | `aes256-ctr` |
| `AES-128-GCM` | `aes128-gcm@openssh.com` |
| `AES-128-CTR` | `aes128-ctr` |
| `CHACHA20-POLY1305` | `chacha20-poly1305@openssh.com` |
| `AES-256-CBC` | `aes256-cbc` |
| `AES-128-CBC` | `aes128-cbc` |
| `3DES-CBC` | `3des-cbc` |
| `AES-256-CCM` | *(não suportado)* |
| `CAMELLIA-*` | *(não suportado)* |

Cifras sem mapeamento no OpenSSH são silenciosamente ignoradas.

### OpenSSH: Mapeamento de Key Exchange

O gerador constrói a lista `KexAlgorithms` a partir de combinações (`key_exchange`, `group`, `hash`):

| Combinação (key_exchange, group, hash) | KexAlgorithm SSH |
|----------------------------------------|-----------------|
| `ECDHE`, `X25519`, `SHA2-256` | `curve25519-sha256`, `curve25519-sha256@libssh.org` |
| `ECDHE`, `SECP256R1`, `SHA2-256` | `ecdh-sha2-nistp256` |
| `ECDHE`, `SECP384R1`, `SHA2-384` | `ecdh-sha2-nistp384` |
| `ECDHE`, `SECP521R1`, `SHA2-512` | `ecdh-sha2-nistp521` |
| `DHE`, `FFDHE-2048`, `SHA2-256` | `diffie-hellman-group14-sha256` |
| `DHE`, `FFDHE-4096`, `SHA2-512` | `diffie-hellman-group16-sha512` |
| `DHE`, `FFDHE-8192`, `SHA2-512` | `diffie-hellman-group18-sha512` |
| `KEM-ECDH`, `MLKEM768-X25519`, `SHA2-256` | `mlkem768x25519-sha256` |
| `KEM-ECDH`, `P256-MLKEM768`, `SHA2-256` | `mlkem768nistp256-sha256` |
| `KEM-ECDH`, `P384-MLKEM1024`, `SHA2-384` | `mlkem1024nistp384-sha384` |

O servidor **sempre remove** `('DHE', 'FFDHE-1024', 'SHA1')` (diffie-hellman-group1-sha1), mesmo que a política o permita.

### OpenSSL: Mecanismo de SECLEVEL

O gerador do OpenSSL (`openssl.py`) determina o `@SECLEVEL` diretamente dos parâmetros `min_dh_size` e `min_rsa_size`:

```python
if min_dh_size < 1023 or min_rsa_size < 1023:
    s = '@SECLEVEL=0'
elif min_dh_size < 2048 or min_rsa_size < 2048:
    s = '@SECLEVEL=1'
elif min_dh_size < 3072 or min_rsa_size < 3072:
    s = '@SECLEVEL=2'
else:
    s = '@SECLEVEL=3'
```

Isto significa que se `min_rsa_size = 2048` e `min_dh_size = 2048`, o OpenSSL receberá `@SECLEVEL=2`. Não há como definir um valor intermediário (ex: RSA 2048 mas DH 3072 resultaria em SECLEVEL=2 por causa do RSA).

### OpenSSL: Geração de Ciphers TLS 1.3

O gerador constrói a diretiva `Ciphersuites` (TLS 1.3) separadamente da `CipherString` (TLS 1.2). Para TLS 1.3, existe um mapeamento direto:

| Ciphersuite | Requer `cipher` | Requer `hash` |
|-------------|----------------|---------------|
| `TLS_AES_256_GCM_SHA384` | `AES-256-GCM` | `SHA2-384` |
| `TLS_AES_128_GCM_SHA256` | `AES-128-GCM` | `SHA2-256` |
| `TLS_CHACHA20_POLY1305_SHA256` | `CHACHA20-POLY1305` | `SHA2-256` |
| `TLS_AES_128_CCM_SHA256` | `AES-128-CCM` | `SHA2-256` |

### OpenSSL: SHA-1 e a Seção `rh-allow-sha1-signatures`

O gerador sempre adiciona uma seção especial ao `opensslcnf.config`:

```ini
[openssl_init]
alg_section = evp_properties

[evp_properties]
rh-allow-sha1-signatures = no   # ou yes para LEGACY
```

Esta é uma extensão Red Hat que controla se o OpenSSL aceita verificar assinaturas baseadas em SHA-1. A lógica no código é:

```python
sha1_sig = not policy.integers['__openssl_block_sha1_signatures']
s += RH_SHA1_SECTION.format('yes' if sha1_sig else 'no')
```

Apenas a política LEGACY define `__openssl_block_sha1_signatures = 0`.

### GnuTLS: Modo Allowlist

O gerador do GnuTLS (`gnutls.py`) gera configuração em modo **allowlist** (lista branca):

```ini
[global]
override-mode = allowlist

[overrides]
secure-hash = SHA256
secure-hash = SHA384
...
tls-enabled-mac = AEAD
tls-enabled-mac = SHA512
...
tls-enabled-group = GROUP-X25519
tls-enabled-group = GROUP-SECP256R1
...
secure-sig = RSA-SHA256
secure-sig = ECDSA-SHA256
...
secure-sig-for-cert = RSA-SHA256
...
enabled-curve = X25519
enabled-curve = SECP256R1
...
tls-enabled-cipher = AES-256-GCM
...
tls-enabled-kx = ECDHE-RSA
tls-enabled-kx = ECDHE-ECDSA
...
enabled-version = TLS1.3
enabled-version = TLS1.2
...
min-verification-profile = medium   # ou high, ultra, etc.

[priorities]
SYSTEM=NONE
```

O `min-verification-profile` é derivado dos tamanhos mínimos de chave:

| `min_dh_size` / `min_rsa_size` | Profile |
|-------------------------------|---------|
| ≤ 768 | `very_weak` |
| ≤ 1024 | `low` |
| ≤ 2048 | `medium` |
| ≤ 3072 | `high` |
| ≤ 8192 | `ultra` |
| > 8192 | `future` |

Quando `sha1_in_certs = 1`, o gerador adiciona explicitamente:

```ini
secure-sig-for-cert = rsa-sha1
secure-sig-for-cert = dsa-sha1
secure-sig-for-cert = ecdsa-sha1
```

### GnuTLS: MACs Desabilitados por Segurança

O `mac_map` do GnuTLS mapeia `HMAC-SHA2-256` e `HMAC-SHA2-384` para `None`:

```python
mac_map = {
    'HMAC-SHA2-256': None,  # not allowlisted over concerns that
    'HMAC-SHA2-384': None,  # implementation might be vulnerable to Lucky13
    'HMAC-SHA2-512': 'SHA512',
}
```

Isto significa que mesmo que a política habilite `HMAC-SHA2-256`, o GnuTLS não o ativará como MAC standalone. Apenas `HMAC-SHA2-512` e `AEAD` funcionam como MACs TLS no GnuTLS. A referência no código aponta para [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503).

---

## I.19 Validação no Gerador — Testes Automáticos de Configuração

Cada gerador contém um método `test_config()` que valida a configuração gerada executando o binário real da biblioteca. Isto acontece durante o `update-crypto-policies`:

| Gerador | Comando de Teste | O que Valida |
|---------|-----------------|--------------|
| `OpenSSLGenerator` | `openssl ciphers <CipherString>` | Verifica se a CipherString é válida e não contém ADH |
| `GnuTLSGenerator` | `gnutls-cli -l` (com `GNUTLS_SYSTEM_PRIORITY_FILE` apontando para o config) | Verifica se a priority string é válida |
| `OpenSSHClientGenerator` | `ssh -G -F <config> bogus_server` | Verifica se as opções SSH são válidas |
| `OpenSSHServerGenerator` | `sshd -T -h <hostkey> -f <config>` | Gera uma host key RSA 3072 temporária e testa o sshd |

Se o binário da biblioteca não estiver instalado, o teste é silenciosamente pulado. Variáveis de ambiente `OLD_OPENSSH=1` e `OLD_GNUTLS=1` também pulam os testes (para compatibilidade com versões antigas durante builds).

---

## I.20 Escrita Atômica e Otimização de Symlinks

O script `update-crypto-policies.py` usa escrita atômica para evitar corrupção:

1. Cria um arquivo temporário com `mkstemp()` no diretório destino.
2. Escreve o conteúdo, faz `fsync()`, define permissões `0o644`.
3. Faz `os.rename()` do temporário para o nome final (operação atômica no mesmo filesystem).

**Otimização de symlinks:** Se a política não tem subpolíticas E não existem arquivos em `local.d/`, o script cria um **symlink** de `/etc/crypto-policies/back-ends/<backend>.config` para `/usr/share/crypto-policies/<POLICY>/<backend>.txt` em vez de copiar o conteúdo. Isto economiza espaço e permite que atualizações do pacote se propaguem automaticamente para políticas simples (sem módulos).

Se existirem arquivos `local.d/`, o symlink não pode ser usado porque o conteúdo precisa ser concatenado. Nesse caso, o arquivo é escrito diretamente e o conteúdo de `local.d/` é appended.

---

## I.21 Verificação e Diagnóstico da Política Efetiva

### Comandos de Verificação

```bash
# Política ativa (nome)
update-crypto-policies --show

# Verificar se a política está realmente aplicada
# (compara timestamps e conteúdo de state/current vs config,
#  e verifica se não há FIPS auto-bind-mount ativo)
update-crypto-policies --is-applied

# Verificar se os arquivos gerados correspondem à política configurada
# (regenera em diretório temporário e compara byte a byte)
update-crypto-policies --check

# Política efetiva expandida (resultado da concatenação base + submódulos)
cat /etc/crypto-policies/state/CURRENT.pol

# Conteúdo do arquivo de config de cada back-end
cat /etc/crypto-policies/back-ends/opensslcnf.config
cat /etc/crypto-policies/back-ends/gnutls.config
cat /etc/crypto-policies/back-ends/nss.config
cat /etc/crypto-policies/back-ends/openssh.config
cat /etc/crypto-policies/back-ends/opensshserver.config

# Data da última mudança de política
ls -l /etc/crypto-policies/back-ends/
ls -l /etc/crypto-policies/config

# Ciphers disponíveis no OpenSSL sob a política atual
openssl ciphers -v

# Testar conexão TLS real e verificar cipher negociado
openssl s_client -connect localhost:443

# Verificar se algum serviço está sobrescrevendo a política
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/ 2>/dev/null
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/ 2>/dev/null
```

### Validando uma Subpolítica Antes de Aplicar

```bash
# Verificar sintaxe — update-crypto-policies reportará erros
sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE 2>&1

# Se houver erro de sintaxe, a saída indicará o problema

# Comparar back-ends antes/depois
diff <(cat /etc/crypto-policies/back-ends/opensslcnf.config) \
     <(sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE && \
       cat /etc/crypto-policies/back-ends/opensslcnf.config)

# Verificar a política efetiva expandida
cat /etc/crypto-policies/state/CURRENT.pol
```

---

## I.22 Diferenças Entre Versões do RHEL

| Aspecto | RHEL 8 | RHEL 9 | RHEL 10 |
|---------|--------|--------|---------|
| OpenSSL | 1.1.1 | 3.0.x / 3.2.x | 3.x |
| Subpolíticas `.pmod` | Introduzidas no RHEL 8.2 | Totalmente suportadas | Totalmente suportadas |
| Escopos `@scope` | Básicos (RHEL 8.5+) | Completos | Completos |
| Wildcards `*` | RHEL 8.2+ | Sim | Sim |
| Negação de escopo `@!scope` | Limitado | Sim | Sim |
| Política BSI | Não | Sim (Fedora/RHEL 9+) | Sim |
| Pós-quântico (ML-KEM, ML-DSA) | Não | Parcial (tardio) | Sim |
| DEFAULT bloqueia SHA-1 | Em assinaturas (exceto DNSSec) | Mais agressivo | Mais agressivo |
| Política FIPS | FIPS 140-2 | FIPS 140-3 | FIPS 140-3 |
| NEXT como alias de DEFAULT | Não | Sim | Sim |
| Sequoia/RPM back-ends | Não | Sim | Sim |

---

## I.23 Subpolíticas Fornecidas pelo Sistema

As seguintes subpolíticas vêm instaladas com o pacote `crypto-policies`:

### `NO-SHA1`

```ini
hash = -SHA1
sign = -RSA-PSS-SHA1 -RSA-SHA1 -ECDSA-SHA1 -EDDSA-ED25519
```

Remove SHA-1 de hashes e assinaturas. Bloqueio total de SHA-1 no sistema.

### `AD-SUPPORT`

Habilita algoritmos necessários para interoperabilidade com Active Directory e ambientes Windows legados.

### `NO-CAMELLIA`

```ini
cipher = -CAMELLIA-*
```

Remove todas as cifras Camellia.

### `NO-ENFORCE-EMS` (RHEL 9+)

Desabilita o requisito de Extended Master Secret (EMS) em TLS. Necessário para compatibilidade com bibliotecas TLS antigas que não suportam RFC 7627.

### `GOST`

Habilita algoritmos criptográficos GOST (padrão russo GOST R 34.10-2012, GOST R 34.11-2012). Necessário para conformidade com padrões de criptografia da Federação Russa.

---

## I.24 Exemplos Práticos de Diagnóstico

### "certificate verify failed" Após Mudança de Política

```
Causa provável:
  - Certificado assinado com SHA-1 → sign não inclui RSA-SHA1/ECDSA-SHA1
  - Certificado com chave RSA 1024-bit → min_rsa_size rejeita
  - CA intermediária com SHA-1 → sha1_in_certs = 0 (GnuTLS)

Diagnóstico:
  openssl x509 -in cert.pem -noout -text | grep "Signature Algorithm"
  openssl x509 -in cert.pem -noout -text | grep "Public-Key"
  update-crypto-policies --show
  cat /etc/crypto-policies/state/CURRENT.pol | grep -E "sign|min_rsa|sha1"

Correção:
  Se for certificado legado → reemitir com SHA-256 e RSA 2048+
  Se for temporário → criar subpolítica permitindo o algoritmo necessário
```

### SSH Recusa Conexão com "no matching cipher found"

```
Causa provável:
  - Servidor ou cliente oferece apenas ciphers CBC e a política os desabilitou
  - Cliente antigo suporta apenas AES-128-CBC

Diagnóstico:
  ssh -vvv user@host 2>&1 | grep -i cipher
  cat /etc/crypto-policies/back-ends/openssh.config
  cat /etc/crypto-policies/back-ends/opensshserver.config

Correção:
  Criar subpolítica que re-habilita o cipher necessário:
  cipher@SSH = +AES-128-CBC
```

### IPsec/VPN Falha ao Negociar

```
Causa provável:
  - Grupo DH da outra ponta não está na lista 'group'
  - Protocolo IKEv1 bloqueado

Diagnóstico:
  cat /etc/crypto-policies/back-ends/libreswan.config
  journalctl -u ipsec | grep -i "no proposal"

Correção:
  group = +FFDHE-1024   # Se a outra ponta usa DH 1024
  protocol@IKE = IKEv1 IKEv2+  # Se a outra ponta usa IKEv1
```

---

## I.25 Matriz Resumo: Parâmetro × Back-end

| Parâmetro | OpenSSL | GnuTLS | NSS | OpenSSH | libssh | Kerberos | Libreswan | BIND | Java |
|-----------|:-------:|:------:|:---:|:-------:|:------:|:--------:|:---------:|:----:|:----:|
| `cipher` | Sim | Sim | Sim | Sim | Sim | Sim | Sim | - | Sim |
| `mac` | Parcial | Parcial | - | Sim | Sim | - | - | - | - |
| `hash` | Sim | Sim | Sim | - | - | - | Sim | Sim | Sim |
| `sign` | Sim | Sim | Sim | Sim | Sim | - | Sim | Sim | Sim |
| `key_exchange` | Sim | Sim | Sim | Sim | Sim | - | **Não** | - | Sim |
| `group` | Sim | Sim | Sim | Sim | Sim | - | Sim | - | Sim |
| `protocol` | Sim | Sim | Sim | - | - | - | Sim | - | Sim |
| `min_rsa_size` | SECLEVEL | Profile | Sim | - | - | - | - | - | Sim |
| `min_dh_size` | SECLEVEL | Profile | Sim | - | - | - | - | - | Sim |
| `min_dsa_size` | SECLEVEL | Profile | Sim | - | - | - | - | - | Sim |
| `min_ec_size` | - | - | - | - | - | - | - | - | **Sim** |
| `sha1_in_certs` | - | **Sim** | - | - | - | - | - | - | - |
| `arbitrary_dh_groups` | Sim | Sim | - | - | - | - | - | - | - |
| `ssh_certs` | - | - | - | Sim | - | - | - | - | - |
| `etm` | - | - | - | Sim | Sim | - | - | - | - |
| `__ems` | Sim | Sim | - | - | - | - | - | - | - |
| `__openssl_block_sha1_signatures` | Sim | - | - | - | - | - | - | - | - |

Legenda: **Sim** = totalmente implementado, **Parcial** = implementação indireta ou limitada, **Não** = explicitamente não afeta, **-** = não aplicável.

**Nota:** Os parâmetros com prefixo `__` são internos e não documentados publicamente. Ver seção I.14 para detalhes.

---

## I.26 Recomendações de Arquitetura

### Quando Usar Cada Abordagem

| Necessidade | Abordagem | Motivo |
|-------------|-----------|--------|
| Ajuste fino sobre política existente | Subpolítica `.pmod` sobre `DEFAULT` | Evolui com atualizações |
| Controle total | Política `.pol` customizada | Nenhuma evolução automática — responsabilidade do admin |
| Override de uma aplicação apenas | `local.d/` ou configuração explícita na app | Não afeta o resto do sistema |
| Compatibilidade temporária | `LEGACY` por tempo limitado | Risco de segurança — documentar e planejar saída |
| Conformidade regulatória | `FIPS` + subpolítica se necessário | Automatizado por `fips-mode-setup` |

### Fluxo de Decisão para Política Customizada

```
Preciso mudar configurações criptográficas?
    │
    ├─ Apenas uma aplicação específica?
    │   └─ Sim → Configurar direto na app OU usar local.d/
    │
    ├─ Quero desabilitar algo system-wide?
    │   └─ Sim → Criar .pmod com diretivas '-'
    │           Aplicar com DEFAULT:MY-MODULE
    │
    ├─ Quero habilitar algo que DEFAULT bloqueia?
    │   └─ Sim → Criar .pmod com diretivas '+'
    │           Aplicar com DEFAULT:MY-MODULE
    │           ⚠️ Documentar por que é necessário
    │
    ├─ Quero controle absoluto de tudo?
    │   └─ Sim → Criar .pol completa (copiar de DEFAULT.pol)
    │           ⚠️ Responsável por manutenção contínua
    │
    └─ Nenhuma das anteriores?
        └─ Usar DEFAULT e não mexer
```

---

## I.27 Referência de Arquivos e Comandos

### Comandos Essenciais

```bash
# Ver política ativa
update-crypto-policies --show

# Mudar política
sudo update-crypto-policies --set <POLÍTICA>[:MÓDULO1][:MÓDULO2]

# Listar políticas base disponíveis
ls /usr/share/crypto-policies/policies/*.pol

# Listar subpolíticas disponíveis
ls /usr/share/crypto-policies/policies/modules/*.pmod

# Listar subpolíticas locais
ls /etc/crypto-policies/policies/modules/*.pmod 2>/dev/null

# Ver política efetiva (expandida)
cat /etc/crypto-policies/state/CURRENT.pol

# Ver back-end de uma biblioteca específica
cat /etc/crypto-policies/back-ends/<backend>.config

# Verificar se mudou recentemente
stat /etc/crypto-policies/config
```

### Resumo de Diretórios

| Diretório | Propósito | Quem Gerencia |
|-----------|-----------|---------------|
| `/usr/share/crypto-policies/policies/` | Políticas base do pacote RPM | Pacote `crypto-policies` |
| `/usr/share/crypto-policies/policies/modules/` | Subpolíticas do pacote RPM | Pacote `crypto-policies` |
| `/etc/crypto-policies/policies/` | Políticas customizadas locais | Administrador |
| `/etc/crypto-policies/policies/modules/` | Subpolíticas customizadas locais | Administrador |
| `/etc/crypto-policies/back-ends/` | Configs geradas para cada biblioteca | `update-crypto-policies` |
| `/etc/crypto-policies/local.d/` | Overrides extras por back-end | Administrador |
| `/etc/crypto-policies/state/` | Estado atual (link simbólico, política expandida) | `update-crypto-policies` |
| `/etc/crypto-policies/config` | Nome textual da política ativa | `update-crypto-policies` |

---

## I.28 Fontes e Referências

### Documentação

- **Man page oficial:** `man 7 crypto-policies` — fonte primária e canônica para todos os parâmetros, escopos e comportamentos documentados neste apêndice.
- **Man page:** `man 8 update-crypto-policies` — uso do comando.
- **Documentação de políticas em disco:** `/usr/share/doc/crypto-policies/`
- **Red Hat Developer:** [Enhance security with system-wide crypto policies in RHEL 9](https://developers.redhat.com/articles/2024/10/09/enhance-security-system-wide-crypto-policies-rhel-9)
- **FOSDEM 2020:** [Custom crypto policies](https://archive.fosdem.org/2020/schedule/event/security_custom_crypto_policies/) — apresentação do mantenedor original, Tomáš Mráz.
- **Red Hat Knowledge Base:** [Article 3642912](https://access.redhat.com/articles/3642912) — referência para crypto-policies.
- **RFC 7457:** Summarizing Known Attacks on Transport Layer Security (TLS) — motivação para depreciação de algoritmos.
- **RFC 7627:** Transport Layer Security (TLS) Session Hash and Extended Master Secret Extension.
- **RFC 9980:** Post-Quantum Public Key Algorithm Extension for the OpenPGP Standard (ML-DSA, SLH-DSA).

### Código-Fonte (Repositório Upstream)

- **Repositório principal:** [gitlab.com/redhat-crypto/fedora-crypto-policies](https://gitlab.com/redhat-crypto/fedora-crypto-policies) (branch `master`)
- **Motor de parsing:** [`python/cryptopolicies/cryptopolicies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/cryptopolicies.py) — Classes `UnscopedCryptoPolicy`, `ScopedPolicy`, `ScopeSelector`, enum `Operation`, funções `parse_line`, `parse_rhs`, `preprocess_text`.
- **Listas de algoritmos:** [`python/cryptopolicies/alg_lists.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/alg_lists.py) — `ALL_CIPHERS`, `ALL_MACS`, `ALL_HASHES`, `ALL_GROUPS`, `ALL_SIGN`, `ALL_KEY_EXCHANGES`, `ALL_PROTOCOLS`, `EXPERIMENTAL_GROUPS`, `EXPERIMENTAL_SIGN`.
- **Script principal:** [`python/update-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/update-crypto-policies.py) — Lógica de `--set`, `--show`, `--is-applied`, `--check`, FIPS auto-bind-mount, escrita atômica, symlinks.
- **Build de políticas:** [`python/build-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/build-crypto-policies.py) — Gera todas as políticas para todos os back-ends (usado no build do RPM).
- **Gerador OpenSSL:** [`python/policygenerators/openssl.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssl.py) — `OpenSSLGenerator`, `OpenSSLFIPSGenerator`.
- **Gerador GnuTLS:** [`python/policygenerators/gnutls.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/gnutls.py) — `GnuTLSGenerator` (modo allowlist).
- **Gerador OpenSSH:** [`python/policygenerators/openssh.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssh.py) — `OpenSSHClientGenerator`, `OpenSSHServerGenerator`.
- **Classe base dos geradores:** [`python/policygenerators/configgenerator.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/configgenerator.py) — `ConfigGenerator`.
- **Políticas base:** [`policies/DEFAULT.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/DEFAULT.pol), [`policies/FUTURE.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FUTURE.pol), [`policies/LEGACY.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/LEGACY.pol), [`policies/FIPS.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FIPS.pol).

### Licença

O projeto `fedora-crypto-policies` é distribuído sob a licença **LGPL-2.1-or-later**. Copyright © 2019 Red Hat, Inc. — Tomáš Mráz e colaboradores.

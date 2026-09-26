# Appendix I: Crypto-Policies — Internal Architecture, Subpolicies, and Complete Parameter Reference

> **Scope:** This appendix documents the internal workings of the RHEL 8/9/10 `crypto-policies` framework — from policy definition to the generation of configuration files for each back-end. It covers all parameters of the policy language, the scope system, the creation of `.pmod` subpolicies and `.pol` full policies, the quirks of each back-end, and the actual flow of `update-crypto-policies`.

---

## I.1 Why This Appendix Exists

Chapters 10, 23, and 31 of this tutorial present what crypto-policies do, how to switch between them, and how to diagnose problems. This appendix goes further: it describes **how** the system works internally, the exact syntax accepted in `.pol` and `.pmod` files, which parameters exist, how each one affects each back-end, and which concrete pitfalls await the administrator who creates custom policies.

---

## I.2 Internal Architecture — The Complete Pipeline

The `update-crypto-policies` command is a shell wrapper (`/usr/bin/update-crypto-policies`) that invokes the Python script `update-crypto-policies.py`. All actual processing occurs in Python, using the `cryptopolicies` (policy parsing) and `policygenerators` (back-end generation) modules.

When the administrator runs `update-crypto-policies --set DEFAULT:NO-SHA1`, the system goes through the following steps:

```
┌──────────────────────────────────────────────────────────────────┐
│  1. READING THE BASE POLICY                                      │
│     The UnscopedCryptoPolicy class looks for DEFAULT.pol in      │
│     this order:                                                  │
│       1. Current directory                                       │
│       2. policies/ (relative)                                    │
│       3. /etc/crypto-policies/policies/                          │
│       4. /usr/share/crypto-policies/policies/                    │
│     The first file found is used.                                │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. READING AND CONCATENATING SUBPOLICIES                        │
│     Looks for NO-SHA1.pmod in modules/ in the same paths above.  │
│                                                                  │
│     The directives from DEFAULT.pol and NO-SHA1.pmod are         │
│     concatenated into a sequential list of Directive(prop_name,  │
│     scope, operation, value) objects.                            │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. PREPROCESSING (preprocess_text)                              │
│     Before parsing, the raw text goes through:                   │
│     a) Comment removal (#)                                       │
│     b) Line continuation resolution (\)                          │
│     c) Whitespace normalization                                  │
│     d) Conversion of deprecated parameters to modern equivalents │
│        (e.g.: min_tls_version=TLS1.2 →                           │
│        protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1)           │
│     e) Value renaming (e.g.: X25519-MLKEM768 →                   │
│        MLKEM768-X25519)                                          │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. PARSING (parse_line → parse_rhs)                             │
│     Each line is converted into Directives with operations:      │
│     - RESET:    "cipher ="          → clears the list            │
│     - APPEND:   "cipher = AES-*"    → adds to the end            │
│     - PREPEND:  "cipher = +AES-*"   → inserts at the beginning   │
│     - OMIT:     "cipher = -RC4-*"   → removes from the list      │
│     - SET_INT:  "min_rsa_size=2048" → sets integer               │
│     - SET_ENUM: "__ems = ENFORCE"   → sets enumeration           │
│     Wildcards (*) are expanded against the known algorithm       │
│     lists (alg_lists.py).                                        │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  5. SCOPED RESOLUTION (ScopedPolicy)                             │
│     For each back-end, the list of Directives is evaluated with  │
│     the relevant scopes of that back-end. A directive only takes │
│     effect if its ScopeSelector matches the back-end's scopes.   │
│     E.g.: cipher@SSH only affects {'ssh','openssh'}.             │
│     The result is lists of algorithms .enabled and .disabled     │
│     plus .integers and .enums values.                            │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  6. BACK-END GENERATION (PolicyGenerators)                       │
│     13 generator classes convert the ScopedPolicy into configs:  │
│                                                                  │
│     ┌─────────────────────────┬────────────────────────────┐     │
│     │ Generator Class         │ .config File               │     │
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
│     Each generator translates the generic algorithm names to     │
│     the library-specific names using mapping tables              │
│     (cipher_map, sign_map, group_map, etc.).                     │
│     Each generator also TESTS the generated config by running    │
│     the library's actual binary (openssl ciphers, gnutls-cli -l, │
│     ssh -G, sshd -T) to validate there are no errors.            │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. BACK-END GENERATION                                          │
│     For each supported library/application, a specific           │
│     configuration generator (policy generator) converts the      │
│     effective policy into a format the library understands:      │
│                                                                  │
│     ┌────────────┬──────────────────────────────────────────┐    │
│     │ Back-end   │ Generated File                           │    │
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
│  7. BACK-END INSTALLATION                                        │
│     The generated files are atomically written to:               │
│       /etc/crypto-policies/back-ends/                            │
│     (via mkstemp + os.rename to prevent corruption)              │
│                                                                  │
│     If the policy does not use subpolicies AND no local.d/       │
│     exists, a SYMLINK is created to the pre-generated back-ends  │
│     in /usr/share/crypto-policies/<POLICY>/ (optimization).      │
│                                                                  │
│     If content exists in /etc/crypto-policies/local.d/,          │
│     it is CONCATENATED to the end of the corresponding back-end. │
│                                                                  │
│     The file /etc/crypto-policies/config is updated.             │
│     The file /etc/crypto-policies/state/CURRENT.pol receives     │
│     the human-readable dump of the expanded effective policy.    │
│     The file /etc/crypto-policies/state/current receives the     │
│     name of the active policy (e.g.: "DEFAULT:NO-SHA1").         │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  8. SERVICE RELOAD                                               │
│     If --no-reload was NOT used, the script executes             │
│     /usr/share/crypto-policies/reload-cmds.sh which contains     │
│     reload commands for each affected service.                   │
│     Example: "systemctl try-restart sshd.service" for SSH.       │
│     Other libraries (OpenSSL, GnuTLS, NSS) only apply            │
│     the new policy when the application is restarted.            │
└──────────────────────────────────────────────────────────────────┘
```

**Critical point:** Applications (Apache, NGINX, Postfix, etc.) do not read the policy directly. They use libraries (OpenSSL, GnuTLS, NSS) which in turn read the back-end files. The policy change only takes effect when the process using the library is restarted.

---

## I.3 Complete File Hierarchy

```
/usr/share/crypto-policies/
├── policies/                          # Package base policies
│   ├── DEFAULT.pol
│   ├── LEGACY.pol
│   ├── FUTURE.pol
│   ├── FIPS.pol
│   ├── BSI.pol
│   ├── EMPTY.pol
│   ├── NEXT.pol                       # Alias for DEFAULT
│   └── modules/                       # Package subpolicies
│       ├── AD-SUPPORT.pmod
│       ├── NO-SHA1.pmod
│       ├── NO-CAMELLIA.pmod
│       ├── NO-ENFORCE-EMS.pmod
│       ├── GOST.pmod
│       └── ...
├── DEFAULT/                           # Pre-generated back-ends for DEFAULT
│   ├── opensslcnf.config
│   ├── gnutls.config
│   ├── nss.config
│   └── ...
├── LEGACY/                            # Pre-generated back-ends for LEGACY
│   └── ...
├── FUTURE/                            # Pre-generated back-ends for FUTURE
│   └── ...
└── FIPS/                              # Pre-generated back-ends for FIPS
    └── ...

/etc/crypto-policies/
├── config                             # Text with name of the active policy
│                                      # E.g.: "DEFAULT:NO-SHA1"
├── back-ends/                         # Active back-ends (links or copies)
│   ├── opensslcnf.config
│   ├── openssl_fips.config            # OpenSSL FIPS module configuration
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
├── local.d/                           # Local per-back-end overrides
│   ├── opensslcnf-extra.config        # Concatenated to opensslcnf.config
│   ├── gnutls-extra.config
│   └── ...
├── state/
│   └── current -> /usr/share/crypto-policies/DEFAULT  # Symbolic link
├── policies/                          # Local custom policies
│   ├── MYPOLICY.pol                   # Full custom policy
│   └── modules/                       # Local custom subpolicies
│       └── MY-MODULE.pmod
└── state/
    └── CURRENT.pol                    # Expanded effective policy
```

**Search priority:** When `update-crypto-policies` looks for a `.pol` or `.pmod` file, it checks `/etc/crypto-policies/policies/` first and then `/usr/share/crypto-policies/policies/`. This allows overriding package policies locally.

---

## I.4 Policy Definition Format — Complete Syntax

The `.pol` and `.pmod` files use a simple INI-like syntax: `key = value`.

### I.4.1 General Syntax Rules

```ini
# Comments start with '#'
# Everything after '#' on the line is ignored

# Line continuation with '\'
cipher = AES-256-GCM AES-128-GCM \
         CHACHA20-POLY1305

# Direct assignment — sets the complete list
cipher = AES-256-GCM AES-128-GCM CHACHA20-POLY1305

# Incremental modification — adds and removes from the existing list
# '+' at the beginning = prepend (insert at the start of the list, higher priority)
# no prefix at the end = append (insert at the end of the list)
# '-' = remove from the list
cipher = +AES-256-GCM -CAMELLIA-256-GCM AES-128-CCM+

# Empty list — disables everything in this category
cipher =

# Integer values
min_rsa_size = 3072

# Boolean values (0 or 1)
sha1_in_certs = 0
```

**Fundamental rule of incremental modification:**

| Prefix/Suffix | Meaning | Example |
|---------------|---------|---------| 
| `+VALUE` (prefix `+`) | Prepend — inserts at the beginning of the list (higher priority) | `cipher = +AES-256-GCM` |
| `VALUE+` (suffix `+`) | Append — inserts at the end of the list (lower priority) | `cipher = AES-128-CCM+` |
| `-VALUE` (prefix `-`) | Remove — takes out of the list | `cipher = -CAMELLIA-256-GCM` |
| `VALUE` (no prefix, direct assignment) | Reset — replaces the entire list | `cipher = AES-256-GCM AES-128-GCM` |

**Direct assignment and incremental modification CANNOT be combined in the same directive.**

### I.4.2 Wildcards

The `*` character serves as a wildcard for matching algorithm names:

```ini
# Remove ALL SHA1 signature algorithms
sign = -*-SHA1

# Remove all AES-128 ciphers
cipher = -AES-128-*

# Remove all Camellia ciphers
cipher = -CAMELLIA-*
```

**Caution:** Wildcards in addition directives (`+`) may enable future algorithms that do not yet exist in the current version. Use wildcards with `-` (removal) for safety.

### I.4.3 Scopes (@scope) — Per-Back-end Directives

Scopes allow a directive to affect only specific back-ends:

```ini
# Syntax: option@scope = value

# SSH only
cipher@SSH = -AES-128-CBC

# TLS only
protocol@TLS = TLS1.3 TLS1.2

# IKE (IPsec) only
protocol@IKE = IKEv2

# Multiple scopes
cipher@{SSH,TLS} = -CAMELLIA-*

# Scope negation — applies to all EXCEPT the specified one
cipher@!SSH = -AES-128-CBC

# Negation with multiple scopes
cipher@!{SSH,Kerberos} = -AES-128-CBC
```

**Available scopes** (complete list extracted from source code, `ALL_SCOPES`):

| Scope | Affected Back-ends | Notes |
|-------|-------------------|-------|
| `tls`, `ssl` | OpenSSL, GnuTLS, NSS (nss-tls), Java | Synonyms |
| `openssl` | OpenSSL only | More specific than `tls` |
| `gnutls` | GnuTLS only | More specific than `tls` |
| `java-tls` | Java/OpenJDK only | More specific than `tls` |
| `nss` | NSS (all sub-scopes) | NSS root scope |
| `nss-tls` | NSS for TLS | Inherits from `nss` |
| `ssh` | OpenSSH (client+server), libssh | Generic SSH scope |
| `openssh` | OpenSSH (client+server) | More specific than `ssh` |
| `openssh-client` | OpenSSH client only | Inherits from `openssh` |
| `openssh-server` | OpenSSH server only | Inherits from `openssh` |
| `libssh` | libssh only | More specific than `ssh` |
| `ipsec`, `ike` | Libreswan | Synonyms |
| `libreswan` | Libreswan only | More specific than `ipsec` |
| `kerberos`, `krb5` | MIT Kerberos | Synonyms |
| `dnssec`, `bind` | BIND | Synonyms |
| `sequoia` | Sequoia PGP | OpenPGP |
| `rpm`, `rpm-sequoia` | RPM via Sequoia | RPM package verification |
| `pkcs12` | NSS — PKCS#12 | Inherits from `nss` |
| `pkcs12-import` | NSS — PKCS#12 import | Inherits from `nss-pkcs12` |
| `nss-pkcs12` | NSS — PKCS#12 | Functional synonym |
| `nss-pkcs12-import` | NSS — PKCS#12 import | More permissive |
| `smime` | NSS — S/MIME | Inherits from `nss` |
| `smime-import` | NSS — S/MIME import | Inherits from `nss-smime` |
| `nss-smime` | NSS — S/MIME | Functional synonym |
| `nss-smime-import` | NSS — S/MIME import | More permissive |

Scope selectors are **case-insensitive**. They support globbing (`*`) and negation (`!`). Multiple scopes in braces: `@{SSH,TLS}`. Multiple negation: `@!{SSH,Kerberos}`.

**Inheritance hierarchy:** See section I.13 for the complete scope hierarchy with parent-child relationships.

---

## I.5 Complete Parameter Reference

### I.5.1 List Parameters (multiple values)

#### `cipher` — Symmetric Ciphers

Defines which symmetric encryption algorithms (and modes of operation) are allowed.

```ini
cipher = AES-256-GCM AES-256-CCM AES-256-CBC \
         AES-128-GCM AES-128-CCM AES-128-CBC \
         CHACHA20-POLY1305
```

**Recognized values:**

| Value | Description | Key Size |
|-------|-------------|----------|
| `AES-256-GCM` | AES 256-bit, Galois/Counter mode (authenticated) | 256 bits |
| `AES-256-CCM` | AES 256-bit, Counter with CBC-MAC mode | 256 bits |
| `AES-256-CBC` | AES 256-bit, Cipher Block Chaining mode | 256 bits |
| `AES-256-CTR` | AES 256-bit, Counter mode | 256 bits |
| `AES-128-GCM` | AES 128-bit, GCM mode | 128 bits |
| `AES-128-CCM` | AES 128-bit, CCM mode | 128 bits |
| `AES-128-CBC` | AES 128-bit, CBC mode | 128 bits |
| `AES-128-CTR` | AES 128-bit, CTR mode | 128 bits |
| `CHACHA20-POLY1305` | ChaCha20 with Poly1305 AEAD | 256 bits |
| `CAMELLIA-256-GCM` | Camellia 256-bit, GCM mode | 256 bits |
| `CAMELLIA-256-CBC` | Camellia 256-bit, CBC mode | 256 bits |
| `CAMELLIA-128-GCM` | Camellia 128-bit, GCM mode | 128 bits |
| `CAMELLIA-128-CBC` | Camellia 128-bit, CBC mode | 128 bits |
| `AES-192-GCM` | AES 192-bit, GCM mode | 192 bits |
| `AES-192-CCM` | AES 192-bit, CCM mode | 192 bits |
| `AES-192-CBC` | AES 192-bit, CBC mode | 192 bits |
| `AES-192-CTR` | AES 192-bit, CTR mode | 192 bits |
| `AES-256-OCB` | AES 256-bit, OCB mode (Sequoia) | 256 bits |
| `AES-128-OCB` | AES 128-bit, OCB mode (Sequoia) | 128 bits |
| `AES-256-EAX` | AES 256-bit, EAX mode (Sequoia) | 256 bits |
| `AES-128-EAX` | AES 128-bit, EAX mode (Sequoia) | 128 bits |
| `AES-256-CFB` | AES 256-bit, CFB mode (Sequoia/RPM) | 256 bits |
| `AES-128-CFB` | AES 128-bit, CFB mode (Sequoia/RPM) | 128 bits |
| `3DES-CBC` | Triple DES, CBC mode | 168 bits (effective: 112) |
| `RC4-128` | RC4 stream cipher | 128 bits |
| `RC4-40` | RC4 with 40-bit key | 40 bits |
| `RC2-CBC` | RC2 CBC mode | Variable |
| `DES-CBC` | DES CBC mode | 56 bits |
| `DES40-CBC` | DES CBC mode with 40-bit key | 40 bits |
| `IDEA-CBC` | IDEA CBC mode | 128 bits |
| `SEED-CBC` | SEED CBC mode | 128 bits |
| `NULL` | No encryption (integrity only) | 0 bits |

**Note:** Algorithms like `AES-*-OCB`, `AES-*-EAX`, and `AES-*-CFB` are primarily used by the Sequoia and RPM (OpenPGP) back-ends. Algorithms like `DES-CBC`, `RC4-40`, `RC2-CBC`, `DES40-CBC`, `IDEA-CBC`, and `SEED-CBC` exist only to support legacy PKCS#12 file import in the LEGACY policy.

**Impact by back-end:**

- **OpenSSL:** Translated into a `Ciphersuites` and `CipherString` list in `opensslcnf.config`. Removing `AES-128-GCM` disables ALL AES-128 ciphers (it is not possible to selectively disable an isolated mode).
- **GnuTLS:** Cipher list in the priority string of `gnutls.config`.
- **NSS:** Ciphersuite list in `nss.config`.
- **OpenSSH:** `Ciphers` list in `openssh.config` and `opensshserver.config`.
- **Kerberos:** Allowed encryption types (`permitted_enctypes`) in `krb5.config`.

#### `mac` — MAC Algorithms

Defines which Message Authentication Codes are allowed.

```ini
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 \
      HMAC-SHA1 AEAD \
      UMAC-128 UMAC-64
```

**Recognized values:**

| Value | Description |
|-------|-------------|
| `HMAC-SHA2-256` | HMAC with SHA-256 |
| `HMAC-SHA2-384` | HMAC with SHA-384 |
| `HMAC-SHA2-512` | HMAC with SHA-512 |
| `HMAC-SHA1` | HMAC with SHA-1 |
| `AEAD` | MACs integrated into AEAD ciphers (GCM, Poly1305) |
| `UMAC-64` | UMAC with 64-bit tag (SSH) |
| `UMAC-128` | UMAC with 128-bit tag (SSH) |
| `HMAC-MD5` | HMAC with MD5 (insecure — legacy only) |

**Impact by back-end:**

- **OpenSSH:** Generates `MACs` list (`hmac-sha2-256`, `hmac-sha2-512`, `umac-128-etm@openssh.com`, etc.).
- **OpenSSL:** Indirectly affected — CBC ciphers require `HMAC-SHA1` and `AES-256-CBC` in the list to be enabled.
- **GnuTLS:** `HMAC-SHA2-256` and `HMAC-SHA2-384` as standalone MACs are disabled due to concerns about constant-time implementation; only `AEAD` is used in practice for TLS 1.3.

#### `hash` — Hash Algorithms (Message Digest)

Defines which cryptographic hash functions are allowed for general use (different from signatures).

```ini
hash = SHA2-256 SHA2-384 SHA2-512 \
       SHA3-256 SHA3-384 SHA3-512 \
       SHA2-224 SHA1
```

**Recognized values:**

| Value | Output (bits) | Common Use |
|-------|--------------|------------|
| `SHA1` | 160 | Legacy (insecure for signatures) |
| `SHA2-224` | 224 | Rare |
| `SHA2-256` | 256 | Modern standard |
| `SHA2-384` | 384 | TLS 1.3, certificates |
| `SHA2-512` | 512 | High security |
| `SHA3-256` | 256 | Alternative NIST standard |
| `SHA3-384` | 384 | Alternative NIST standard |
| `SHA3-512` | 512 | Alternative NIST standard |
| `SHA3-224` | 224 | SHA-3 with reduced output |
| `SHAKE-128` | Variable | Extendable-output function (XOF) |
| `SHAKE-256` | Variable | Extendable-output function (XOF) |
| `MD5` | 128 | Insecure — extreme legacy only |

**hash vs sign relationship:** The `hash` parameter controls general use (HMAC, key derivation, DNSSec). To control which hashes are accepted in *signatures*, use `sign`.

#### `sign` — Signature Algorithms

Defines which algorithm+hash signature combinations are allowed.

```ini
sign = RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448
```

**Recognized values:**

| Value | Description |
|-------|-------------|
| `RSA-SHA1` | RSA PKCS#1 v1.5 with SHA-1 |
| `RSA-SHA2-224` | RSA PKCS#1 v1.5 with SHA-224 |
| `RSA-SHA2-256` | RSA PKCS#1 v1.5 with SHA-256 |
| `RSA-SHA2-384` | RSA PKCS#1 v1.5 with SHA-384 |
| `RSA-SHA2-512` | RSA PKCS#1 v1.5 with SHA-512 |
| `RSA-PSS-SHA2-256` | RSA-PSS with SHA-256 |
| `RSA-PSS-SHA2-384` | RSA-PSS with SHA-384 |
| `RSA-PSS-SHA2-512` | RSA-PSS with SHA-512 |
| `ECDSA-SHA1` | ECDSA with SHA-1 |
| `ECDSA-SHA2-224` | ECDSA with SHA-224 |
| `ECDSA-SHA2-256` | ECDSA with SHA-256 |
| `ECDSA-SHA2-384` | ECDSA with SHA-384 |
| `ECDSA-SHA2-512` | ECDSA with SHA-512 |
| `EDDSA-ED25519` | EdDSA using Ed25519 curve |
| `EDDSA-ED448` | EdDSA using Ed448 curve |
| `DSA-SHA1` | DSA with SHA-1 (legacy) |
| `DSA-SHA2-256` | DSA with SHA-256 |
| `ECDSA-SHA2-256-FIDO` | ECDSA with SHA-256 via FIDO (WebAuthn) |
| `EDDSA-ED25519-FIDO` | EdDSA Ed25519 via FIDO (WebAuthn) |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS (RSAE key) with SHA-256 |
| `RSA-PSS-RSAE-SHA2-384` | RSA-PSS (RSAE key) with SHA-384 |
| `RSA-PSS-RSAE-SHA2-512` | RSA-PSS (RSAE key) with SHA-512 |
| `RSA-SHA3-256` | RSA PKCS#1 v1.5 with SHA3-256 |
| `RSA-PSS-SHA3-256` | RSA-PSS with SHA3-256 |
| `ECDSA-SHA3-256` | ECDSA with SHA3-256 |
| `MLDSA44` | ML-DSA-44 (NIST post-quantum, level 2) |
| `MLDSA65` | ML-DSA-65 (NIST post-quantum, level 3) |
| `MLDSA87` | ML-DSA-87 (NIST post-quantum, level 5) |
| `MLDSA65-ED25519` | ML-DSA-65 + Ed25519 hybrid (OpenPGP RFC 9980) |
| `MLDSA87-ED448` | ML-DSA-87 + Ed448 hybrid (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128S` | SLH-DSA with SHAKE-128 small (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128F` | SLH-DSA with SHAKE-128 fast (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-256S` | SLH-DSA with SHAKE-256 small (OpenPGP RFC 9980) |

**Practical impact:** If an X.509 certificate was signed with `RSA-SHA1` and the active policy does not include `RSA-SHA1` in `sign`, the certificate chain of trust verification will fail. This is the most common cause of "certificate verify failed" after switching from LEGACY to DEFAULT.

**PQ note:** The ML-DSA algorithms are included by default in DEFAULT, FUTURE, and FIPS. The hybrid algorithms and SLH-DSA are included only for the `sequoia` and `RPM` (OpenPGP) scopes, per RFC 9980.

#### `key_exchange` — Key Exchange Methods

```ini
key_exchange = ECDHE DHE RSA PSK DHE-RSA DHE-DSS
```

| Value | Description | Forward Secrecy |
|-------|-------------|:---------------:|
| `ECDHE` | Elliptic Curve Diffie-Hellman Ephemeral | Yes |
| `DHE` | Diffie-Hellman Ephemeral | Yes |
| `DHE-RSA` | DHE authenticated with RSA | Yes |
| `DHE-DSS` | DHE authenticated with DSS/DSA | Yes |
| `RSA` | Static RSA key exchange | No |
| `PSK` | Pre-Shared Key | Depends |
| `ECDHE-GSS` | ECDHE with GSSAPI (SSH) | Yes |
| `DHE-GSS` | DHE with GSSAPI (SSH) | Yes |
| `KEM-ECDH` | Key Encapsulation Mechanism with ECDH (post-quantum) | Yes |
| `SNTRUP` | NTRU Prime with X25519 (SSH post-quantum) | Yes |
| `RSA-PSK` | Pre-Shared Key with RSA authentication | No |
| `ECDHE-PSK` | ECDHE with Pre-Shared Key | Yes |
| `DHE-PSK` | DHE with Pre-Shared Key | Yes |

**Note:** The FUTURE policy removes `RSA` and `DHE-DSS` from key exchange — this means that servers using certificates with DSA keys will not be able to establish connections.

**Note on Libreswan:** The `key_exchange` parameter **does not affect** the generated configuration for Libreswan. To limit DH/ECDH in IPsec, use the `group` parameter.

#### `group` — Groups/Curves for Key Exchange

Defines which elliptic curves and Diffie-Hellman groups are allowed.

```ini
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192
```

**Post-quantum groups (hybrid):**

| Value | Type | Description |
|-------|------|-------------|
| `MLKEM768-X25519` | PQ Hybrid | ML-KEM-768 combined with X25519 |
| `P256-MLKEM768` | PQ Hybrid | ML-KEM-768 combined with NIST P-256 |
| `P384-MLKEM1024` | PQ Hybrid | ML-KEM-1024 combined with NIST P-384 |
| `MLKEM1024-X448` | PQ Hybrid | ML-KEM-1024 combined with X448 |

**Classic groups:**

| Value | Type | Size | Description |
|-------|------|------|-------------|
| `X25519` | Bernstein curve | ~128-bit sec. | Modern, fast curve |
| `X448` | Goldilocks curve | ~224-bit sec. | Modern, high-security curve |
| `SECP256R1` | NIST P-256 | 256 bits | NIST standard curve |
| `SECP384R1` | NIST P-384 | 384 bits | NIST high-security curve |
| `SECP521R1` | NIST P-521 | 521 bits | NIST maximum-security curve |
| `FFDHE-1024` | Finite Field DH | 1024 bits | Legacy DH group (LEGACY only) |
| `FFDHE-1536` | Finite Field DH | 1536 bits | DH group (LEGACY only) |
| `FFDHE-2048` | Finite Field DH | 2048 bits | Standardized DH group (RFC 7919) |
| `FFDHE-3072` | Finite Field DH | 3072 bits | Standardized DH group |
| `FFDHE-4096` | Finite Field DH | 4096 bits | Standardized DH group |
| `FFDHE-6144` | Finite Field DH | 6144 bits | Standardized DH group |
| `FFDHE-8192` | Finite Field DH | 8192 bits | Standardized DH group |

**Note on OpenSSL:** The order of `group` values is only respected within PQ (post-quantum) and classic "classes." All PQ groups are automatically ordered above classic ones. In `opensslcnf.config`, the format is `Groups = *pq_group1:pq_group2/*classic_group1:classic_group2` where `*` indicates group classes and `/` separates classes.

**Note on NSS:** The order of `group` values is **ignored** — NSS uses its internal built-in order.

**Note on FIPS and PQ:** In the FIPS policy, ML-KEM is supported for TLS groups but disabled by scope for OpenSSL (not supported in the FIPS provider), Sequoia/RPM, and partially OpenSSH.

#### `protocol` — Allowed Protocol Versions

```ini
protocol = TLS1.3 TLS1.2 DTLS1.2 IKEv2
```

| Value | Description |
|-------|-------------|
| `SSL3.0` | SSLv3 (removed from libraries — cannot be enabled) |
| `TLS1.0` | TLS 1.0 |
| `TLS1.1` | TLS 1.1 |
| `TLS1.2` | TLS 1.2 |
| `TLS1.3` | TLS 1.3 |
| `DTLS0.9` | DTLS 0.9 |
| `DTLS1.0` | DTLS 1.0 |
| `DTLS1.2` | DTLS 1.2 |
| `IKEv1` | IKE version 1 (legacy IPsec) |
| `IKEv2` | IKE version 2 (modern IPsec) |

**Limitation:** Some back-ends (OpenSSL, NSS) do not allow selectively disabling protocol versions — they use the oldest version in the list as the lower bound. Disabling all TLS and/or DTLS versions results in the library defaults being applied.

### I.5.2 Integer Parameters

| Parameter | Description | Example | Impact |
|-----------|-------------|---------|--------|
| `min_rsa_size` | Minimum RSA key size in bits | `2048` | Connections with smaller RSA keys are rejected. Affects ALL back-ends. |
| `min_dh_size` | Minimum DH parameter size in bits | `2048` | DH key exchange with smaller parameters is rejected. |
| `min_dsa_size` | Minimum DSA key size in bits | `2048` | Smaller DSA keys are rejected. |
| `min_ec_size` | Minimum EC key size in bits | `256` | **Applies only to the Java/OpenJDK back-end.** |

**How OpenSSL applies minimum sizes:** OpenSSL does not have fine granularity for minimum sizes — it uses the `@SECLEVEL` mechanism that defines security ranges. `min_rsa_size = 2048` corresponds to `@SECLEVEL=2`. `min_rsa_size = 3072` corresponds to `@SECLEVEL=3`. This means that not all arbitrary values are possible.

| SECLEVEL | RSA min | DH min | ECC min | Hash min | Security |
|----------|---------|--------|---------|----------|----------|
| 0 | 0 | 0 | 0 | - | Everything allowed |
| 1 | 1024 | 1024 | 160 | SHA-1 | 80 bits |
| 2 | 2048 | 2048 | 224 | SHA-224 | 112 bits |
| 3 | 3072 | 3072 | 256 | SHA-256 | 128 bits |
| 4 | 7680 | 7680 | 384 | SHA-384 | 192 bits |
| 5 | 15360 | 15360 | 512 | SHA-512 | 256 bits |

### I.5.3 Boolean Parameters (0 or 1)

| Parameter | Description | Default (DEFAULT) | Impact |
|-----------|-------------|-------------------|--------|
| `sha1_in_certs` | Allows SHA-1 in certificate signatures | `0` | **Applies only to the GnuTLS back-end.** If `0`, certificates signed with SHA-1 are rejected during chain validation. |
| `arbitrary_dh_groups` | Allows arbitrary (non-standardized) DH groups | `0` | If `0`, only standardized FFDHE groups (RFC 7919) are accepted. If `1`, accepts arbitrary DH parameters generated by the server. |
| `ssh_certs` | Allows OpenSSH certificate authentication | `1` | If `0`, disables the OpenSSH certificate mechanism (not to be confused with X.509 certificates). |

### I.5.4 Enumeration Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `etm` | `ANY`, `DISABLE_ETM`, `DISABLE_NON_ETM` | Controls Encrypt-then-MAC vs Encrypt-and-MAC. **Implemented only for SSH.** Use with scope `@SSH`. `ANY` allows both. `DISABLE_ETM` forces Encrypt-and-MAC (E&M). `DISABLE_NON_ETM` forces Encrypt-then-MAC (EtM). |
| `__ems` | `DEFAULT`, `ENFORCE`, `RELAX` | **Internal.** Controls Extended Master Secret (RFC 7627). `ENFORCE` is used by the FIPS policy to force EMS. `RELAX` disables the requirement (NO-ENFORCE-EMS subpolicy). **Affects OpenSSL and GnuTLS.** See section I.14 for details. |

### I.5.5 Deprecated Parameters

The following parameters still work but should be migrated. The source code (`preprocess_text` in `cryptopolicies.py`) performs the conversion automatically and emits a `FutureWarning`:

| Deprecated | Exact Automatic Conversion | Reason |
|------------|---------------------------|--------|
| `min_tls_version = TLS1.2` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1` | Replaced by incremental removal |
| `min_tls_version = TLS1.3` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1 -TLS1.2` | Same |
| `min_dtls_version = DTLS1.2` | `protocol@TLS = -DTLS0.9 -DTLS1.0` | Same |
| `ike_protocol = IKEv2` | `protocol@IKE = IKEv2` | Renamed to scope |
| `tls_cipher = ...` | `cipher@TLS = ...` | Renamed to scope |
| `ssh_cipher = ...` | `cipher@SSH = ...` | Renamed to scope |
| `ssh_group = ...` | `group@SSH = ...` | Renamed to scope |
| `sha1_in_dnssec = 0` | `hash@DNSSec = -SHA1` + `sign@DNSSec = -RSA-SHA1 -ECDSA-SHA1` | Split into two parameters |
| `sha1_in_dnssec = 1` | `hash@DNSSec = SHA1+` + `sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+` | Same |
| `ssh_etm = 0` | `etm@SSH = DISABLE_ETM` | Renamed to enum |
| `ssh_etm = 1` | `etm@SSH = ANY` | Same |
| `ssh_etm@<scope> = 0` | `etm@<scope> = DISABLE_ETM` | Supports scope |

Additionally, the value `X25519-MLKEM768` is automatically converted to `MLKEM768-X25519` (algorithm rename, RHEL-99813).

The `protocol` parameter (without scope) still works but emits a warning — it should be replaced by `protocol@TLS`.

---

## I.6 Difference Between `.pol` and `.pmod`

### `.pol` File — Full Policy

- Defines **all** parameters from scratch.
- Used as the base policy.
- Applied with `update-crypto-policies --set MYPOLICY`.
- Must contain values for all relevant options (otherwise, they remain empty/library defaults).
- **Does not evolve** with `crypto-policies` package updates — if Red Hat adds new back-ends or parameters, your custom policy will not include them automatically.

### `.pmod` File — Subpolicy/Modifier Module

- **Selectively** modifies an existing base policy.
- Does not need to define all parameters — only the ones it wants to change.
- Applied with `update-crypto-policies --set BASE:MYPOLICY`.
- **Evolves** with updates — since it only modifies the base, when the base is updated by the package, the modifications remain and apply over the new version.
- **Multiple modules** can be stacked: `--set DEFAULT:MOD1:MOD2:MOD3`.

**Red Hat strongly recommends using subpolicies (`.pmod`) instead of custom full policies (`.pol`).** This ensures that security updates to base policies propagate automatically.

### Concatenation Mechanism

When the effective policy is `DEFAULT:NO-SHA1:MY-MODULE`, the system concatenates the files in this order:

```
DEFAULT.pol + NO-SHA1.pmod + MY-MODULE.pmod
```

Each subsequent directive overrides or modifies the previous one. If `DEFAULT.pol` defines:

```ini
hash = SHA2-256 SHA2-384 SHA2-512 SHA1
```

And `NO-SHA1.pmod` defines:

```ini
hash = -SHA1
sign = -RSA-SHA1 -RSA-PSS-SHA1 -ECDSA-SHA1
```

The resulting effective policy will have `hash` without `SHA1` and `sign` without any SHA-1-based algorithm.

---

## I.7 Creating Custom Subpolicies — Step-by-Step Guide

### Example 1: Require Minimum 4096-bit RSA Keys

```bash
sudo tee /etc/crypto-policies/policies/modules/RSA-4096.pmod << 'EOF'
min_rsa_size = 4096
min_dh_size = 4096
EOF

sudo update-crypto-policies --set DEFAULT:RSA-4096
```

**Effect:** Any certificate with an RSA key smaller than 4096 bits will be rejected. Any DH key exchange with parameters smaller than 4096 bits will be rejected. This is extremely restrictive — most commercial certificates use 2048 or 4096 bits.

### Example 2: Policy for TLS 1.3-Only Environment

```bash
sudo tee /etc/crypto-policies/policies/modules/TLS13-ONLY.pmod << 'EOF'
protocol@TLS = TLS1.3
protocol@!TLS = -TLS1.0 -TLS1.1
cipher@TLS = AES-256-GCM AES-128-GCM CHACHA20-POLY1305
key_exchange = ECDHE
EOF

sudo update-crypto-policies --set DEFAULT:TLS13-ONLY
```

**Effect:** Only TLS 1.3 is allowed for TLS connections. Only AEAD ciphers (the only ones TLS 1.3 supports). Key exchange via ECDHE only.

### Example 3: Active Directory Compatibility

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

**Effect:** Enables ciphers needed for Kerberos with legacy AD, allows SHA-1 in certificates (needed for old DCs), accepts 1024-bit DH parameters.

### Example 4: Maximum Security for Financial Environment

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

### Example 5: Module to Disable CBC in Everything

```bash
sudo tee /etc/crypto-policies/policies/modules/NO-CBC.pmod << 'EOF'
cipher = -AES-256-CBC -AES-128-CBC -CAMELLIA-256-CBC -CAMELLIA-128-CBC
EOF

sudo update-crypto-policies --set DEFAULT:NO-CBC
```

---

## I.8 Creating a Full Policy (.pol) from Scratch

For scenarios where no base policy fits and subpolicies are not sufficient:

```bash
sudo cp /usr/share/crypto-policies/policies/DEFAULT.pol \
        /etc/crypto-policies/policies/MYORG.pol

sudo vi /etc/crypto-policies/policies/MYORG.pol
```

Full policy example:

```ini
# /etc/crypto-policies/policies/MYORG.pol
# Custom organizational policy

# Allowed protocols
protocol = TLS1.3 TLS1.2 DTLS1.2 IKEv2

# Symmetric ciphers
cipher = AES-256-GCM AES-128-GCM CHACHA20-POLY1305
cipher@Kerberos = AES-256-CBC AES-128-CBC+

# MACs
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 AEAD UMAC-128
mac@SSH = HMAC-SHA2-256 HMAC-SHA2-512 AEAD UMAC-128

# Hashes
hash = SHA2-256 SHA2-384 SHA2-512

# Signatures
sign = ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448

# Key exchange
key_exchange = ECDHE DHE

# Groups/Curves
group = X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Minimum key sizes
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Boolean options
sha1_in_certs = 0
arbitrary_dh_groups = 0
ssh_certs = 1
```

Apply:

```bash
sudo update-crypto-policies --set MYORG
```

**Warning:** With a custom `.pol` policy, future updates to the `crypto-policies` package that improve the `DEFAULT` policy will **not** propagate to `MYORG`. You are responsible for keeping your policy up to date.

---

## I.9 The `local.d` Mechanism — Per-Back-end Overrides

The `/etc/crypto-policies/local.d/` directory allows adding **extra** configuration that is concatenated to the end of the generated back-end file. This does NOT modify the policy — it directly modifies the library's configuration file.

```bash
# Example: Add extra configuration to OpenSSL
sudo tee /etc/crypto-policies/local.d/opensslcnf-extra.config << 'EOF'
# Extra configuration concatenated to opensslcnf.config
# (OpenSSL configuration format, not policy format)
EOF
```

**Naming convention:** The file must follow the pattern `<backend>-<suffix>.config`, where `<backend>` corresponds to the back-end name (without the `.config` extension).

**Recommended use:** Extreme situations where the policy does not offer the necessary control over a specific back-end. This is a last-resort mechanism — prefer subpolicies.

---

## I.10 How Each Back-end Consumes the Policy

### OpenSSL (`OpenSSLGenerator` + `OpenSSLFIPSGenerator`)

The generator creates two files: `opensslcnf.config` (general configuration) and `openssl_fips.config` (FIPS module configuration). OpenSSL reads `/etc/crypto-policies/back-ends/opensslcnf.config` during initialization via the `.include` directive in the main `openssl.cnf` file. The applied scopes are `{'tls', 'ssl', 'openssl'}`.

**Parameter translation:**

| Policy Parameter | OpenSSL Configuration |
|-----------------|----------------------|
| `cipher` | `Ciphersuites` (TLS 1.3) and `CipherString` (TLS 1.2) |
| `min_rsa_size`, `min_dh_size` | `@SECLEVEL=N` at the beginning of `CipherString` |
| `protocol` | `TLS.MinProtocol`, `TLS.MaxProtocol`, `DTLS.MinProtocol`, `DTLS.MaxProtocol` |
| `group` | `Groups` (PQ and classic separated by `/`) |
| `sign` | `SignatureAlgorithms` (with `?` prefix for tolerance of unknown algorithms) |
| `__ems` | `Options = RHNoEnforceEMSinFIPS` if `RELAX` |
| `__openssl_block_sha1_signatures` | `rh-allow-sha1-signatures = yes/no` |
| `min_rsa_size` | `default_bits` in the `[req]` section (minimum 2048) |

**OpenSSL quirks:**

1. The TLS 1.2 cipher list (`CipherString`) is generated by **subtraction** — it starts by listing the enabled `key_exchange`, then removes the ciphers, key exchanges, and MACs from the *disabled* list. This differs from the allowlist model used by GnuTLS.
2. The `CipherString` always excludes `-SHA384`, `-CAMELLIA`, `-ARIA`, `-AESCCM8`, and `-CBC` (when all CBC are disabled) through hardcoding in the generator.
3. To disable CCM ciphers, both `AES-128-CCM` and `AES-256-CCM` need to be removed; the generator uses the keyword `-AESCCM`.
4. All `SignatureAlgorithms` are prefixed with `?` (`?RSA+SHA256`) so that OpenSSL tolerates algorithms it does not know (e.g.: post-quantum in older versions).

### GnuTLS (`GnuTLSGenerator`)

The generator creates a configuration file in **allowlist** mode (no longer priority strings as in older versions). The applied scopes are `{'tls', 'ssl', 'gnutls'}`. The configuration is read from `/etc/crypto-policies/back-ends/gnutls.config` via the `GNUTLS_SYSTEM_PRIORITY_FILE` variable (or the compiled-in default path).

**Translation:**

| Policy Parameter | GnuTLS Configuration |
|-----------------|---------------------|
| `cipher` | `tls-enabled-cipher = AES-256-GCM`, etc. |
| `mac` | `tls-enabled-mac = AEAD`, `tls-enabled-mac = SHA512` |
| `hash` | `secure-hash = SHA256`, etc. |
| `sign` | `secure-sig = RSA-SHA256` + `secure-sig-for-cert = RSA-SHA256` |
| `sha1_in_certs` | Additional `secure-sig-for-cert = rsa-sha1/dsa-sha1/ecdsa-sha1` |
| `group` | `tls-enabled-group = GROUP-X25519` + `enabled-curve = X25519` |
| `key_exchange` | `tls-enabled-kx = ECDHE-RSA`, `tls-enabled-kx = ECDHE-ECDSA` |
| `protocol` | `enabled-version = TLS1.3`, etc. |
| `min_rsa_size`, `min_dh_size` | `min-verification-profile` |
| `__ems` | `tls-session-hash = require/request` |

**GnuTLS quirks:**

1. `sha1_in_certs` is the **only** back-end that respects this parameter directly (adding SHA-1 only to `secure-sig-for-cert`).
2. `HMAC-SHA2-256` and `HMAC-SHA2-384` as standalone MACs are **mapped to `None`** in the code and therefore never enabled, due to Lucky13 vulnerability concerns (see [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503)). Only `AEAD` and `HMAC-SHA2-512` work.
3. PSK key exchanges (`PSK`, `DHE-PSK`, `ECDHE-PSK`, `RSA-PSK`) are **commented out** in the generator and therefore never enabled via crypto-policies, even if the policy lists them.
4. The `ECDHE` key exchange is expanded into **two** kex types: `ECDHE-RSA` and `ECDHE-ECDSA` in the generator.
5. Curves need to be enabled separately from groups. The generator extracts curves from groups and signatures (e.g.: EdDSA-Ed25519 → `enabled-curve = Ed25519`).

### NSS (Network Security Services)

The generator creates an NSS policy file at `/etc/crypto-policies/back-ends/nss.config`.

**NSS quirks:**

1. The order of `group` is **ignored** — NSS uses its internal order.
2. It is the **only** back-end that respects scopes `pkcs12`, `pkcs12-import`, `smime`, and `smime-import`.
3. `pkcs12` implies `pkcs12-import` — it is not possible to allow export without allowing import.
4. These scopes cannot enable signature algorithms that were not enabled in the general configuration.
5. Disabling all TLS/DTLS versions results in the library defaults.

### OpenSSH (`OpenSSHClientGenerator` + `OpenSSHServerGenerator`)

The generator creates two separate files with different scopes:
- **Client:** `openssh.config` — scopes `{'ssh', 'openssh', 'openssh-client'}`
- **Server:** `opensshserver.config` — scopes `{'ssh', 'openssh', 'openssh-server'}`

**Translation:**

| Policy Parameter | OpenSSH Configuration |
|-----------------------|---------------------|
| `cipher@SSH` | `Ciphers` |
| `mac@SSH` + `etm` | `MACs` (EtM and non-EtM in order according to the `etm` enum) |
| `key_exchange` × `group` × `hash` | `KexAlgorithms` (Cartesian product filtered by the `kx_map` table) |
| `key_exchange` × `hash` + `arbitrary_dh_groups` | `KexAlgorithms` via `gx_map` (group exchange) |
| `sign` | `PubkeyAcceptedAlgorithms`, `HostbasedAcceptedAlgorithms`, `CASignatureAlgorithms` |
| `sign` (server) | `HostKeyAlgorithms` (server only) |
| `ssh_certs` + `sign` | `-cert-v01@openssh.com` suffixes added to `PubkeyAcceptedAlgorithms` |
| `min_rsa_size` | `RequiredRSASize` (if > 0) |
| `key_exchange` (GSS) | `GSSAPIKexAlgorithms` or `GSSAPIKeyExchange no` |

**OpenSSH quirks:**

1. DH group 1 (1024 bits) is **always** removed on the server, even if the policy allows 1024-bit DH. The server code explicitly does `del local_kx_map[('DHE', 'FFDHE-1024', 'SHA1')]`.
2. `HostKeyAlgorithms` is defined **only** for the server. Setting it on the client would break handling of existing `known_hosts` entries.
3. `KexAlgorithms` is built by a **Cartesian product** of (`key_exchange`, `group`, `hash`), filtered against the `kx_map` table. Only combinations with a defined mapping produce output.
4. `GSSAPIKeyExchange no` is emitted if no GSS kex is enabled by the policy.
5. `CASignatureAlgorithms` does not include certificate variants, only base algorithms.
6. When `ssh_certs = 1`, the generator adds certificates including the new `ssh-mldsa44-ed25519@openssh.com` (post-quantum).
7. The server reload command is `systemctl try-restart sshd.service` (restart, not reload, because systemd needs to re-read command-line options).

### Libreswan (IPsec/IKE)

**Libreswan quirks:**

1. The `key_exchange` parameter **does not affect** the generated configuration for Libreswan.
2. To control DH vs ECDH in IPsec, use the `group` parameter.

### Kerberos (MIT krb5)

The generator creates `/etc/crypto-policies/back-ends/krb5.config` with the `permitted_enctypes` list.

**Translation:** Ciphers are mapped to Kerberos enctypes (`aes256-cts-hmac-sha384-192`, `aes128-cts-hmac-sha256-128`, etc.).

### Java/OpenJDK

The generator creates `/etc/crypto-policies/back-ends/java.config` which configures Java Security Properties.

**Note:** The `min_ec_size` parameter **applies only** to the Java back-end.

---

## I.11 Removed vs Disabled Algorithms

There is a fundamental distinction between algorithms **removed** from libraries and algorithms **disabled** by policies:

### Completely Removed from Core Libraries

These algorithms have been removed from the source code of cryptographic libraries and **cannot be enabled** by any policy, not even LEGACY:

| Algorithm/Protocol | Reason |
|---------------------|--------|
| DES (not 3DES) | Completely insecure (56 bits) |
| Export-grade cipher suites | Insecure by design |
| MD5 in signatures | Demonstrated collisions |
| SSLv2 | Multiple fatal vulnerabilities |
| SSLv3 | Vulnerable to POODLE |
| ECC curves < 224 bits | Insecure |
| Binary field ECC curves | Non-standardized / suspect |

### Disabled in ALL Pre-defined Policies (but available)

These algorithms exist in the libraries but are disabled in all policies. A custom `.pol` policy **could** enable them (not recommended):

| Algorithm/Protocol | Risk |
|---------------------|-------|
| DH with parameters < 1024 bits | Logjam attack |
| RSA with key < 1024 bits | Factorable with modern hardware |
| Camellia | Not widely tested |
| RC4 | Multiple known biases |
| ARIA | Limited use, little auditing |
| SEED | Limited use outside Korea |
| IDEA | Obsolete |
| Integrity-only ciphersuites | No encryption |
| TLS CBC with HMAC SHA-384 | Problematic implementations |
| AES-CCM8 (short tag) | Insufficient authentication tag |
| ECC curves incompatible with TLS 1.3 (including secp256k1) | Outside the TLS 1.3 standard |
| IKEv1 | Replaced by IKEv2 |

---

## I.12 Applications and Libraries NOT Covered

Crypto-policies cover only **data in transit** (data-in-transit). The following situations are **not** controlled:

| Not Covered | Reason |
|-------------|--------|
| Go applications | The Go runtime does not read system crypto-policies |
| GnuPG-2 | Uses its own configuration system |
| Data at rest (disk encryption) | LUKS, dm-crypt have independent configuration |
| Certificate locations | Managed by each service individually |
| CA trust store | Managed by `update-ca-trust`, not by `crypto-policies` |
| Certificate issuance | Not controlled (CA/certmonger/certbot) |
| Applications that force their own configurations | If the app defines ciphers explicitly in code, the system policy is ignored |

---

## I.13 Scope Hierarchy — Source Code View

The source code (`cryptopolicies.py`) defines a scope hierarchy where each back-end receives a set of scopes and optionally inherits from a parent scope. The following table shows exactly which scopes are applied for each back-end when generating its configuration:

| Back-end (dumpable) | Parent scope | Set of applied scopes |
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

**How it works:** When the OpenSSH server generator requests the configuration, it passes the set `{'ssh', 'openssh', 'openssh-server'}` to the `ScopedPolicy`. Each directive in the policy is evaluated against these scopes: `cipher@SSH` matches (because `ssh` is in the set), `cipher@TLS` does not match, `cipher@!SSH` does not match. The directive `cipher@{SSH,TLS}` would match because `ssh` is in the set.

**Parent-child inheritance:** When the policy dump is generated for `CURRENT.pol`, the system shows scope-specific properties only if they differ from the parent scope. For example, `cipher@openssh-server` only appears if it differs from `cipher@openssh`.

---

## I.14 Internal Parameters (Not Publicly Documented)

The source code defines parameters with a `__` (double underscore) prefix that are used internally by the system-provided policies. These parameters are not documented in the man page and should not be used in custom policies, but understanding them is important for comprehending the actual behavior:

### `__openssl_block_sha1_signatures`

```python
INT_DEFAULTS = {
    ...
    '__openssl_block_sha1_signatures': 1,
}
```

Controls whether OpenSSL blocks SHA-1 signature verification. Default value `1` (block). In the OpenSSL generator, this is translated to the `rh-allow-sha1-signatures = yes/no` directive in the `[evp_properties]` section of `opensslcnf.config`. This is a **Red Hat-specific extension** to OpenSSL, not present in upstream OpenSSL.

The LEGACY policy defines `__openssl_block_sha1_signatures = 0`, allowing SHA-1 signature verification in OpenSSL. All other policies maintain the value `1`.

### `__ems` (Extended Master Secret)

```python
ENUMS = {
    'etm': ('ANY', 'DISABLE_ETM', 'DISABLE_NON_ETM'),
    '__ems': ('DEFAULT', 'ENFORCE', 'RELAX'),
}
```

Controls the Extended Master Secret (RFC 7627) requirement in TLS. Three possible values:

| Value | Effect on OpenSSL | Effect on GnuTLS |
|-------|-------------------|-------------------|
| `DEFAULT` | No action (library decides) | No action (`tls-session-hash` not configured) |
| `ENFORCE` | No action (FIPS already forces it) | `tls-session-hash = require` |
| `RELAX` | `Options = RHNoEnforceEMSinFIPS` + FIPS config with `tls1-prf-ems-check = 0` | `tls-session-hash = request` |

The FIPS policy defines `__ems = ENFORCE`. The NO-ENFORCE-EMS subpolicy defines `__ems = RELAX`.

The OpenSSL generator also creates a separate file `openssl_fips.config` that configures the OpenSSL FIPS module:

```ini
[fips_sect]
tls1-prf-ems-check = 1  # or 0 if __ems == RELAX
activate = 1
```

---

## I.15 Post-Quantum Algorithms in the Source Code

The source code (`alg_lists.py`) already defines extensive lists of post-quantum algorithms, marked as experimental:

### Groups (Key Encapsulation — ML-KEM)

The following post-quantum groups are defined in the current policies (DEFAULT, FUTURE, FIPS, LEGACY):

| Group | Type | Description |
|-------|------|-----------|
| `MLKEM768-X25519` | Hybrid | ML-KEM-768 with X25519 (NIST standard + classic) |
| `P256-MLKEM768` | Hybrid | ML-KEM-768 with NIST P-256 |
| `P384-MLKEM1024` | Hybrid | ML-KEM-1024 with NIST P-384 |
| `MLKEM1024-X448` | Hybrid | ML-KEM-1024 with X448 |

Groups marked as experimental (present in the code but not in default policies):

| Group | Status |
|-------|--------|
| `MLKEM512`, `X25519-MLKEM512`, `P256-MLKEM512` | Experimental |
| `MLKEM768`, `X448-MLKEM768` | Experimental (solo/alternative variants) |
| `MLKEM1024`, `P521-MLKEM1024` | Experimental |

### Signatures (ML-DSA, FALCON, SPHINCS+, SLH-DSA)

Post-quantum signatures in default policies:

| Algorithm | Present in DEFAULT | Present in FIPS |
|-----------|:-------------------:|:----------------:|
| `MLDSA44` (ML-DSA-44) | Yes | Yes |
| `MLDSA65` (ML-DSA-65) | Yes | Yes |
| `MLDSA87` (ML-DSA-87) | Yes | Yes |

Experimental signatures in the code (not in default policies):

```
P256-MLDSA44, RSA3072-MLDSA44, MLDSA44-PSS2048, MLDSA44-RSA2048,
MLDSA44-ED25519, MLDSA44-P256, MLDSA44-BP256,
P384-MLDSA65, MLDSA65-PSS3072, MLDSA65-RSA3072,
FALCON512, FALCONPADDED512, FALCON1024, FALCONPADDED1024,
SPHINCSSHA2128FSIMPLE, SPHINCSSHA2128SSIMPLE, SPHINCSSHAKE128FSIMPLE,
... and more hybrid variants
```

PQ signatures for OpenPGP (Sequoia/RPM), added with `sign@{sequoia,RPM}` in all default policies:

```
MLDSA65-ED25519, MLDSA87-ED448,
SLHDSA-SHAKE-128S, SLHDSA-SHAKE-128F, SLHDSA-SHAKE-256S
```

**How OpenSSL handles PQ groups:** The OpenSSL generator separates groups into two classes — PQ and classic — and formats them as `*pq_groups/classic_groups` in the `Groups` directive. This causes servers to prefer any PQ group over any classic group when both are supported, and clients to send key shares for the highest-priority PQ group AND the highest-priority classic group.

---

## I.16 FIPS Auto-Bind-Mount — The Boot Mechanism

When the kernel is started with `fips=1`, a dracut module and/or a systemd service automatically bind-mount:

```
/usr/share/crypto-policies/back-ends/FIPS/  →  /etc/crypto-policies/back-ends/
/usr/share/crypto-policies/default-fips-config  →  /etc/crypto-policies/config
```

This ensures that the FIPS policy is active from the very first moment of boot, even before `update-crypto-policies` can be executed.

The `update-crypto-policies.py` script detects this situation by checking `/proc/self/mountinfo`:

```
is_fips_auto_bind_mounted():
  Checks if /etc/crypto-policies/config is mounted from
  .../crypto-policies/default-fips-config
  AND if /etc/crypto-policies/back-ends is mounted from
  .../crypto-policies/back-ends/FIPS
```

**Behavior when auto-bind is active:**

- `--show`: Works normally (reads the mounted content).
- `--set FIPS:SUBPOLICY`: Unmounts the bind-mounts with `umount` and then applies the new policy with the subpolicy. This allows customizing FIPS with subpolicies.
- `--set DEFAULT` (or other non-FIPS): Issues a warning that the system will no longer be FIPS-compliant, unmounts and applies.
- Without `--set`: Warns that files in `local.d/` will be ignored while auto-bind is active.

**Practical implication:** If you need FIPS with a subpolicy (e.g.: `FIPS:NO-ENFORCE-EMS`), run `update-crypto-policies --set FIPS:NO-ENFORCE-EMS` — this removes the automatic bind-mount and applies a persistent custom FIPS policy.

---

## I.17 What Each Policy Actually Defines — Source Code Annotations

The following annotations are extracted directly from the `.pol` files of the upstream repository.

### DEFAULT.pol — Annotations

```ini
# 112-bit security with SHA-1 exception in DNSSec

# Includes ML-KEM and ML-DSA (post-quantum) at the top of the lists
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 SECP256R1 X448 SECP521R1 SECP384R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# SHA-1 and DSA-SHA1 allowed only in DNSSec and RPM (by scope)
hash@DNSSec = SHA1+
sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+
sign@RPM = DSA-SHA1+
hash@RPM = SHA1+
min_dsa_size@RPM = 1024   # RPM needs to accept old packages with DSA 1024

# CBC disabled in SSH by scope (vulnerable to plaintext recovery)
cipher@SSH = -*-CBC

# RSA is BEFORE DHE in key_exchange for interoperability reasons
key_exchange = KEM-ECDH ECDHE RSA DHE DHE-RSA PSK DHE-PSK ECDHE-PSK RSA-PSK \
               ECDHE-GSS DHE-GSS

# arbitrary_dh_groups = 1 → accepts DH parameters from the server
# (necessary for compatibility with servers that don't use FFDHE)
arbitrary_dh_groups = 1
```

### FUTURE.pol — Differences from DEFAULT

```ini
# 128-bit security — post-quantum preparation

# HMAC-SHA1 REMOVED from the MAC list
mac = AEAD HMAC-SHA2-256 UMAC-128 HMAC-SHA2-384 HMAC-SHA2-512
# (DEFAULT includes HMAC-SHA1)

# SHA2-224 and SHA3-224 REMOVED from hash
hash = SHA2-256 SHA2-384 SHA2-512 SHA3-256 SHA3-384 SHA3-512 SHAKE-256

# No SHA-1 in ANY scope (no exception for DNSSec)
# SHA-224 REMOVED from sign
# RSA REMOVED from key_exchange (no static RSA key exchange)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK ECDHE-GSS DHE-GSS

# Only 256-bit ciphers and AEAD in TLS
cipher@TLS = AES-256-GCM AES-256-CCM CHACHA20-POLY1305

# FFDHE-2048 REMOVED (minimum 3072)
group = ... FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Minimum sizes increased
min_dh_size = 3072
min_dsa_size = 3072
min_rsa_size = 3072
```

### LEGACY.pol — Differences from DEFAULT

```ini
# 64-bit security — maximum compatibility

# SHA1 included in hash (for general use, not just DNSSec)
hash = ... SHA1

# DSA and SHA-1 ALLOWED in signatures
sign = ... DSA-SHA2-256 DSA-SHA2-384 DSA-SHA2-512 DSA-SHA2-224 \
       ECDSA-SHA1 RSA-PSS-SHA1 RSA-SHA1 DSA-SHA1

# 3DES-CBC enabled in cipher and cipher@TLS
cipher = ... 3DES-CBC
cipher@TLS = ... 3DES-CBC

# CBC ENABLED in SSH (different from DEFAULT/FUTURE/FIPS)
cipher@SSH = AES-256-GCM CHACHA20-POLY1305 AES-256-CTR AES-256-CBC \
    AES-128-GCM AES-128-CTR AES-128-CBC 3DES-CBC

# DHE-DSS enabled, FFDHE-1536 included, FFDHE-1024 for SSH
group@SSH = FFDHE-1024+
key_exchange = ... DHE-DSS ...

# TLS 1.0 and 1.1 enabled, DTLS 1.0 enabled
protocol@TLS = TLS1.3 TLS1.2 TLS1.1 TLS1.0 DTLS1.2 DTLS1.0

# Minimum sizes reduced
min_dh_size = 1024
min_dsa_size = 1024
min_rsa_size = 1024

# SHA-1 allowed in certificates (GnuTLS)
sha1_in_certs = 1

# OpenSSL does NOT block SHA-1 signatures
__openssl_block_sha1_signatures = 0

# PKCS#12 accepts DES, RC4, RC2, SEED (extreme legacy)
cipher@pkcs12 = AES-256-CBC AES-192-CBC AES-128-CBC \
    CAMELLIA-256-CBC ... 3DES-CBC DES-CBC RC4-128 DES40-CBC RC2-CBC SEED-CBC
```

### FIPS.pol — Differences from DEFAULT

```ini
# FIPS 140 compliance — does NOT guarantee FIPS by itself

# No CHACHA20-POLY1305 (not FIPS-approved)
cipher@TLS = AES-256-GCM AES-256-CCM AES-256-CBC \
    AES-128-GCM AES-128-CCM AES-128-CBC

# No X25519 and X448 in groups (not FIPS-approved as standalone curves)
# ML-KEM blocked for OpenSSL (not supported in the FIPS provider yet)
# ML-KEM blocked for Sequoia/RPM
group@openssl = +P256-MLKEM768  # deprioritize X25519-MLKEM768
group@{sequoia,rpm} = -MLKEM768-X25519 -P256-MLKEM768 -P384-MLKEM1024
group@openssh = -MLKEM768-X25519

# No EdDSA, no FIDO, no SHA-224 in signatures
# No RSA-PSS-RSAE SHA3 variants

# PSK without RSA-PSK (not approved)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK

# Extended Master Secret mandatory
__ems = ENFORCE
```

---

## I.18 Algorithm Mapping in Generators — Source Code Tables

### OpenSSH: Cipher Mapping

The `openssh.py` generator maps generic cipher names to the names used by OpenSSH:

| Policy | OpenSSH |
|----------|---------|
| `AES-256-GCM` | `aes256-gcm@openssh.com` |
| `AES-256-CTR` | `aes256-ctr` |
| `AES-128-GCM` | `aes128-gcm@openssh.com` |
| `AES-128-CTR` | `aes128-ctr` |
| `CHACHA20-POLY1305` | `chacha20-poly1305@openssh.com` |
| `AES-256-CBC` | `aes256-cbc` |
| `AES-128-CBC` | `aes128-cbc` |
| `3DES-CBC` | `3des-cbc` |
| `AES-256-CCM` | *(not supported)* |
| `CAMELLIA-*` | *(not supported)* |

Ciphers without a mapping in OpenSSH are silently ignored.

### OpenSSH: Key Exchange Mapping

The generator builds the `KexAlgorithms` list from combinations (`key_exchange`, `group`, `hash`):

| Combination (key_exchange, group, hash) | SSH KexAlgorithm |
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

The server **always removes** `('DHE', 'FFDHE-1024', 'SHA1')` (diffie-hellman-group1-sha1), even if the policy allows it.

### OpenSSL: SECLEVEL Mechanism

The OpenSSL generator (`openssl.py`) determines the `@SECLEVEL` directly from the `min_dh_size` and `min_rsa_size` parameters:

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

This means that if `min_rsa_size = 2048` and `min_dh_size = 2048`, OpenSSL will receive `@SECLEVEL=2`. There is no way to define an intermediate value (e.g.: RSA 2048 but DH 3072 would result in SECLEVEL=2 because of the RSA).

### OpenSSL: TLS 1.3 Cipher Generation

The generator builds the `Ciphersuites` directive (TLS 1.3) separately from the `CipherString` (TLS 1.2). For TLS 1.3, there is a direct mapping:

| Ciphersuite | Requires `cipher` | Requires `hash` |
|-------------|----------------|---------------|
| `TLS_AES_256_GCM_SHA384` | `AES-256-GCM` | `SHA2-384` |
| `TLS_AES_128_GCM_SHA256` | `AES-128-GCM` | `SHA2-256` |
| `TLS_CHACHA20_POLY1305_SHA256` | `CHACHA20-POLY1305` | `SHA2-256` |
| `TLS_AES_128_CCM_SHA256` | `AES-128-CCM` | `SHA2-256` |

### OpenSSL: SHA-1 and the `rh-allow-sha1-signatures` Section

The generator always adds a special section to `opensslcnf.config`:

```ini
[openssl_init]
alg_section = evp_properties

[evp_properties]
rh-allow-sha1-signatures = no   # or yes for LEGACY
```

This is a Red Hat extension that controls whether OpenSSL accepts verifying SHA-1-based signatures. The logic in the code is:

```python
sha1_sig = not policy.integers['__openssl_block_sha1_signatures']
s += RH_SHA1_SECTION.format('yes' if sha1_sig else 'no')
```

Only the LEGACY policy defines `__openssl_block_sha1_signatures = 0`.

### GnuTLS: Allowlist Mode

The GnuTLS generator (`gnutls.py`) generates configuration in **allowlist** mode:

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
min-verification-profile = medium   # or high, ultra, etc.

[priorities]
SYSTEM=NONE
```

The `min-verification-profile` is derived from minimum key sizes:

| `min_dh_size` / `min_rsa_size` | Profile |
|-------------------------------|---------|
| ≤ 768 | `very_weak` |
| ≤ 1024 | `low` |
| ≤ 2048 | `medium` |
| ≤ 3072 | `high` |
| ≤ 8192 | `ultra` |
| > 8192 | `future` |

When `sha1_in_certs = 1`, the generator explicitly adds:

```ini
secure-sig-for-cert = rsa-sha1
secure-sig-for-cert = dsa-sha1
secure-sig-for-cert = ecdsa-sha1
```

### GnuTLS: MACs Disabled for Security

The GnuTLS `mac_map` maps `HMAC-SHA2-256` and `HMAC-SHA2-384` to `None`:

```python
mac_map = {
    'HMAC-SHA2-256': None,  # not allowlisted over concerns that
    'HMAC-SHA2-384': None,  # implementation might be vulnerable to Lucky13
    'HMAC-SHA2-512': 'SHA512',
}
```

This means that even if the policy enables `HMAC-SHA2-256`, GnuTLS will not activate it as a standalone MAC. Only `HMAC-SHA2-512` and `AEAD` work as TLS MACs in GnuTLS. The reference in the code points to [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503).

---

## I.19 Generator Validation — Automatic Configuration Tests

Each generator contains a `test_config()` method that validates the generated configuration by executing the library's actual binary. This happens during `update-crypto-policies`:

| Generator | Test Command | What It Validates |
|---------|-----------------|--------------|
| `OpenSSLGenerator` | `openssl ciphers <CipherString>` | Verifies that the CipherString is valid and does not contain ADH |
| `GnuTLSGenerator` | `gnutls-cli -l` (with `GNUTLS_SYSTEM_PRIORITY_FILE` pointing to the config) | Verifies that the priority string is valid |
| `OpenSSHClientGenerator` | `ssh -G -F <config> bogus_server` | Verifies that the SSH options are valid |
| `OpenSSHServerGenerator` | `sshd -T -h <hostkey> -f <config>` | Generates a temporary 3072-bit RSA host key and tests sshd |

If the library binary is not installed, the test is silently skipped. Environment variables `OLD_OPENSSH=1` and `OLD_GNUTLS=1` also skip the tests (for compatibility with old versions during builds).

---

## I.20 Atomic Writing and Symlink Optimization

The `update-crypto-policies.py` script uses atomic writing to prevent corruption:

1. Creates a temporary file with `mkstemp()` in the destination directory.
2. Writes the content, performs `fsync()`, sets permissions `0o644`.
3. Does `os.rename()` from temporary to final name (atomic operation on the same filesystem).

**Symlink optimization:** If the policy has no subpolicies AND no files exist in `local.d/`, the script creates a **symlink** from `/etc/crypto-policies/back-ends/<backend>.config` to `/usr/share/crypto-policies/<POLICY>/<backend>.txt` instead of copying the content. This saves space and allows package updates to propagate automatically for simple policies (without modules).

If `local.d/` files exist, the symlink cannot be used because the content needs to be concatenated. In that case, the file is written directly and the content of `local.d/` is appended.

---

## I.21 Effective Policy Verification and Diagnosis

### Verification Commands

```bash
# Active policy (name)
update-crypto-policies --show

# Verify if the policy is actually applied
# (compares timestamps and content of state/current vs config,
#  and checks if there is no active FIPS auto-bind-mount)
update-crypto-policies --is-applied

# Verify if the generated files match the configured policy
# (regenerates in a temporary directory and compares byte by byte)
update-crypto-policies --check

# Expanded effective policy (result of base + submodule concatenation)
cat /etc/crypto-policies/state/CURRENT.pol

# Content of each back-end's config file
cat /etc/crypto-policies/back-ends/opensslcnf.config
cat /etc/crypto-policies/back-ends/gnutls.config
cat /etc/crypto-policies/back-ends/nss.config
cat /etc/crypto-policies/back-ends/openssh.config
cat /etc/crypto-policies/back-ends/opensshserver.config

# Date of last policy change
ls -l /etc/crypto-policies/back-ends/
ls -l /etc/crypto-policies/config

# Available ciphers in OpenSSL under the current policy
openssl ciphers -v

# Test a real TLS connection and verify negotiated cipher
openssl s_client -connect localhost:443

# Check if any service is overriding the policy
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/ 2>/dev/null
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/ 2>/dev/null
```

### Validating a Subpolicy Before Applying

```bash
# Check syntax — update-crypto-policies will report errors
sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE 2>&1

# If there is a syntax error, the output will indicate the problem

# Compare back-ends before/after
diff <(cat /etc/crypto-policies/back-ends/opensslcnf.config) \
     <(sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE && \
       cat /etc/crypto-policies/back-ends/opensslcnf.config)

# Verify the expanded effective policy
cat /etc/crypto-policies/state/CURRENT.pol
```

---

## I.22 Differences Between RHEL Versions

| Aspect | RHEL 8 | RHEL 9 | RHEL 10 |
|---------|--------|--------|---------|
| OpenSSL | 1.1.1 | 3.0.x / 3.2.x | 3.x |
| `.pmod` subpolicies | Introduced in RHEL 8.2 | Fully supported | Fully supported |
| `@scope` scopes | Basic (RHEL 8.5+) | Complete | Complete |
| Wildcards `*` | RHEL 8.2+ | Yes | Yes |
| Scope negation `@!scope` | Limited | Yes | Yes |
| BSI policy | No | Yes (Fedora/RHEL 9+) | Yes |
| Post-quantum (ML-KEM, ML-DSA) | No | Partial (late) | Yes |
| DEFAULT blocks SHA-1 | In signatures (except DNSSec) | More aggressive | More aggressive |
| FIPS policy | FIPS 140-2 | FIPS 140-3 | FIPS 140-3 |
| NEXT as alias for DEFAULT | No | Yes | Yes |
| Sequoia/RPM back-ends | No | Yes | Yes |

---

## I.23 System-Provided Subpolicies

The following subpolicies come installed with the `crypto-policies` package:

### `NO-SHA1`

```ini
hash = -SHA1
sign = -RSA-PSS-SHA1 -RSA-SHA1 -ECDSA-SHA1 -EDDSA-ED25519
```

Removes SHA-1 from hashes and signatures. Total SHA-1 blocking system-wide.

### `AD-SUPPORT`

Enables algorithms needed for interoperability with Active Directory and legacy Windows environments.

### `NO-CAMELLIA`

```ini
cipher = -CAMELLIA-*
```

Removes all Camellia ciphers.

### `NO-ENFORCE-EMS` (RHEL 9+)

Disables the Extended Master Secret (EMS) requirement in TLS. Needed for compatibility with old TLS libraries that do not support RFC 7627.

### `GOST`

Enables GOST cryptographic algorithms (Russian standard GOST R 34.10-2012, GOST R 34.11-2012). Needed for compliance with Russian Federation cryptography standards.

---

## I.24 Practical Diagnostic Examples

### "certificate verify failed" After Policy Change

```
Probable cause:
  - Certificate signed with SHA-1 → sign does not include RSA-SHA1/ECDSA-SHA1
  - Certificate with 1024-bit RSA key → min_rsa_size rejects it
  - Intermediate CA with SHA-1 → sha1_in_certs = 0 (GnuTLS)

Diagnosis:
  openssl x509 -in cert.pem -noout -text | grep "Signature Algorithm"
  openssl x509 -in cert.pem -noout -text | grep "Public-Key"
  update-crypto-policies --show
  cat /etc/crypto-policies/state/CURRENT.pol | grep -E "sign|min_rsa|sha1"

Fix:
  If legacy certificate → reissue with SHA-256 and RSA 2048+
  If temporary → create subpolicy allowing the needed algorithm
```

### SSH Refuses Connection with "no matching cipher found"

```
Probable cause:
  - Server or client offers only CBC ciphers and the policy disabled them
  - Old client only supports AES-128-CBC

Diagnosis:
  ssh -vvv user@host 2>&1 | grep -i cipher
  cat /etc/crypto-policies/back-ends/openssh.config
  cat /etc/crypto-policies/back-ends/opensshserver.config

Fix:
  Create subpolicy that re-enables the needed cipher:
  cipher@SSH = +AES-128-CBC
```

### IPsec/VPN Fails to Negotiate

```
Probable cause:
  - DH group of the other endpoint is not in the 'group' list
  - IKEv1 protocol blocked

Diagnosis:
  cat /etc/crypto-policies/back-ends/libreswan.config
  journalctl -u ipsec | grep -i "no proposal"

Fix:
  group = +FFDHE-1024   # If the other endpoint uses DH 1024
  protocol@IKE = IKEv1 IKEv2+  # If the other endpoint uses IKEv1
```

---

## I.25 Summary Matrix: Parameter × Back-end

| Parameter | OpenSSL | GnuTLS | NSS | OpenSSH | libssh | Kerberos | Libreswan | BIND | Java |
|-----------|:-------:|:------:|:---:|:-------:|:------:|:--------:|:---------:|:----:|:----:|
| `cipher` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | - | Yes |
| `mac` | Partial | Partial | - | Yes | Yes | - | - | - | - |
| `hash` | Yes | Yes | Yes | - | - | - | Yes | Yes | Yes |
| `sign` | Yes | Yes | Yes | Yes | Yes | - | Yes | Yes | Yes |
| `key_exchange` | Yes | Yes | Yes | Yes | Yes | - | **No** | - | Yes |
| `group` | Yes | Yes | Yes | Yes | Yes | - | Yes | - | Yes |
| `protocol` | Yes | Yes | Yes | - | - | - | Yes | - | Yes |
| `min_rsa_size` | SECLEVEL | Profile | Yes | - | - | - | - | - | Yes |
| `min_dh_size` | SECLEVEL | Profile | Yes | - | - | - | - | - | Yes |
| `min_dsa_size` | SECLEVEL | Profile | Yes | - | - | - | - | - | Yes |
| `min_ec_size` | - | - | - | - | - | - | - | - | **Yes** |
| `sha1_in_certs` | - | **Yes** | - | - | - | - | - | - | - |
| `arbitrary_dh_groups` | Yes | Yes | - | - | - | - | - | - | - |
| `ssh_certs` | - | - | - | Yes | - | - | - | - | - |
| `etm` | - | - | - | Yes | Yes | - | - | - | - |
| `__ems` | Yes | Yes | - | - | - | - | - | - | - |
| `__openssl_block_sha1_signatures` | Yes | - | - | - | - | - | - | - | - |

Legend: **Yes** = fully implemented, **Partial** = indirect or limited implementation, **No** = explicitly does not affect, **-** = not applicable.

**Note:** Parameters with the `__` prefix are internal and not publicly documented. See section I.14 for details.

---

## I.26 Architecture Recommendations

### When to Use Each Approach

| Need | Approach | Reason |
|-------------|-----------|--------|
| Fine-tuning over existing policy | `.pmod` subpolicy over `DEFAULT` | Evolves with updates |
| Total control | Custom `.pol` policy | No automatic evolution — admin's responsibility |
| Override for one application only | `local.d/` or explicit configuration in the app | Does not affect the rest of the system |
| Temporary compatibility | `LEGACY` for a limited time | Security risk — document and plan exit |
| Regulatory compliance | `FIPS` + subpolicy if needed | Automated by `fips-mode-setup` |

### Decision Flow for Custom Policy

```
Do I need to change cryptographic settings?
    │
    ├─ Only a specific application?
    │   └─ Yes → Configure directly in the app OR use local.d/
    │
    ├─ Do I want to disable something system-wide?
    │   └─ Yes → Create .pmod with '-' directives
    │           Apply with DEFAULT:MY-MODULE
    │
    ├─ Do I want to enable something that DEFAULT blocks?
    │   └─ Yes → Create .pmod with '+' directives
    │           Apply with DEFAULT:MY-MODULE
    │           ⚠️ Document why it is needed
    │
    ├─ Do I want absolute control of everything?
    │   └─ Yes → Create a full .pol (copy from DEFAULT.pol)
    │           ⚠️ Responsible for ongoing maintenance
    │
    └─ None of the above?
        └─ Use DEFAULT and don't touch it
```

---

## I.27 File and Command Reference

### Essential Commands

```bash
# View active policy
update-crypto-policies --show

# Change policy
sudo update-crypto-policies --set <POLICY>[:MODULE1][:MODULE2]

# List available base policies
ls /usr/share/crypto-policies/policies/*.pol

# List available subpolicies
ls /usr/share/crypto-policies/policies/modules/*.pmod

# List local subpolicies
ls /etc/crypto-policies/policies/modules/*.pmod 2>/dev/null

# View effective policy (expanded)
cat /etc/crypto-policies/state/CURRENT.pol

# View a specific library's back-end
cat /etc/crypto-policies/back-ends/<backend>.config

# Check if it changed recently
stat /etc/crypto-policies/config
```

### Directory Summary

| Directory | Purpose | Who Manages |
|-----------|-----------|---------------|
| `/usr/share/crypto-policies/policies/` | RPM package base policies | `crypto-policies` package |
| `/usr/share/crypto-policies/policies/modules/` | RPM package subpolicies | `crypto-policies` package |
| `/etc/crypto-policies/policies/` | Local custom policies | Administrator |
| `/etc/crypto-policies/policies/modules/` | Local custom subpolicies | Administrator |
| `/etc/crypto-policies/back-ends/` | Generated configs for each library | `update-crypto-policies` |
| `/etc/crypto-policies/local.d/` | Per-back-end extra overrides | Administrator |
| `/etc/crypto-policies/state/` | Current state (symbolic link, expanded policy) | `update-crypto-policies` |
| `/etc/crypto-policies/config` | Text name of the active policy | `update-crypto-policies` |

---

## I.28 Sources and References

### Documentation

- **Official man page:** `man 7 crypto-policies` — primary and canonical source for all parameters, scopes, and behaviors documented in this appendix.
- **Man page:** `man 8 update-crypto-policies` — command usage.
- **On-disk policy documentation:** `/usr/share/doc/crypto-policies/`
- **Red Hat Developer:** [Enhance security with system-wide crypto policies in RHEL 9](https://developers.redhat.com/articles/2024/10/09/enhance-security-system-wide-crypto-policies-rhel-9)
- **FOSDEM 2020:** [Custom crypto policies](https://archive.fosdem.org/2020/schedule/event/security_custom_crypto_policies/) — presentation by the original maintainer, Tomas Mraz.
- **Red Hat Knowledge Base:** [Article 3642912](https://access.redhat.com/articles/3642912) — crypto-policies reference.
- **RFC 7457:** Summarizing Known Attacks on Transport Layer Security (TLS) — motivation for algorithm deprecation.
- **RFC 7627:** Transport Layer Security (TLS) Session Hash and Extended Master Secret Extension.
- **RFC 9980:** Post-Quantum Public Key Algorithm Extension for the OpenPGP Standard (ML-DSA, SLH-DSA).

### Source Code (Upstream Repository)

- **Main repository:** [gitlab.com/redhat-crypto/fedora-crypto-policies](https://gitlab.com/redhat-crypto/fedora-crypto-policies) (branch `master`)
- **Parsing engine:** [`python/cryptopolicies/cryptopolicies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/cryptopolicies.py) — Classes `UnscopedCryptoPolicy`, `ScopedPolicy`, `ScopeSelector`, enum `Operation`, functions `parse_line`, `parse_rhs`, `preprocess_text`.
- **Algorithm lists:** [`python/cryptopolicies/alg_lists.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/alg_lists.py) — `ALL_CIPHERS`, `ALL_MACS`, `ALL_HASHES`, `ALL_GROUPS`, `ALL_SIGN`, `ALL_KEY_EXCHANGES`, `ALL_PROTOCOLS`, `EXPERIMENTAL_GROUPS`, `EXPERIMENTAL_SIGN`.
- **Main script:** [`python/update-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/update-crypto-policies.py) — Logic for `--set`, `--show`, `--is-applied`, `--check`, FIPS auto-bind-mount, atomic writing, symlinks.
- **Policy build:** [`python/build-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/build-crypto-policies.py) — Generates all policies for all back-ends (used in RPM build).
- **OpenSSL generator:** [`python/policygenerators/openssl.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssl.py) — `OpenSSLGenerator`, `OpenSSLFIPSGenerator`.
- **GnuTLS generator:** [`python/policygenerators/gnutls.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/gnutls.py) — `GnuTLSGenerator` (allowlist mode).
- **OpenSSH generator:** [`python/policygenerators/openssh.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssh.py) — `OpenSSHClientGenerator`, `OpenSSHServerGenerator`.
- **Generator base class:** [`python/policygenerators/configgenerator.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/configgenerator.py) — `ConfigGenerator`.
- **Base policies:** [`policies/DEFAULT.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/DEFAULT.pol), [`policies/FUTURE.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FUTURE.pol), [`policies/LEGACY.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/LEGACY.pol), [`policies/FIPS.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FIPS.pol).

### License

The `fedora-crypto-policies` project is distributed under the **LGPL-2.1-or-later** license. Copyright © 2019 Red Hat, Inc. — Tomas Mraz and contributors.

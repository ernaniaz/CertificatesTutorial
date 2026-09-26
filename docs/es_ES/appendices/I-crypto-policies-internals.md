# Apéndice I: Crypto-Policies — Arquitectura Interna, Subpolíticas y Referencia Completa de Parámetros

> **Alcance:** Este apéndice documenta el funcionamiento interno del framework `crypto-policies` de RHEL 8/9/10 — desde la definición de políticas hasta la generación de los archivos de configuración de cada back-end. Cubre todos los parámetros del lenguaje de políticas, el sistema de ámbitos, la creación de subpolíticas `.pmod`, políticas completas `.pol`, las irregularidades de cada back-end y el flujo real del `update-crypto-policies`.

---

## I.1 Por Qué Existe Este Apéndice

Los capítulos 10, 23 y 31 de este tutorial presentan lo que las crypto-policies hacen, cómo alternar entre ellas y cómo diagnosticar problemas. Este apéndice va más allá: describe **cómo** funciona el sistema internamente, cuál es la sintaxis exacta aceptada en los archivos `.pol` y `.pmod`, qué parámetros existen, cómo cada uno afecta a cada back-end y qué trampas concretas esperan al administrador que crea políticas personalizadas.

---

## I.2 Arquitectura Interna — El Pipeline Completo

El comando `update-crypto-policies` es un wrapper shell (`/usr/bin/update-crypto-policies`) que invoca el script Python `update-crypto-policies.py`. Todo el procesamiento real ocurre en Python, usando los módulos `cryptopolicies` (parsing de la política) y `policygenerators` (generación de back-ends).

Cuando el administrador ejecuta `update-crypto-policies --set DEFAULT:NO-SHA1`, el sistema recorre las siguientes etapas:

```
┌──────────────────────────────────────────────────────────────────┐
│  1. LECTURA DE LA POLÍTICA BASE                                  │
│     La clase UnscopedCryptoPolicy busca DEFAULT.pol en este      │
│     orden:                                                       │
│       1. Directorio actual                                       │
│       2. policies/ (relativo)                                    │
│       3. /etc/crypto-policies/policies/                          │
│       4. /usr/share/crypto-policies/policies/                    │
│     El primer archivo encontrado es usado.                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. LECTURA Y CONCATENACIÓN DE LAS SUBPOLÍTICAS                  │
│     Busca NO-SHA1.pmod en modules/ en las mismas rutas de        │
│     arriba.                                                      │
│                                                                  │
│     Las directivas de DEFAULT.pol y NO-SHA1.pmod se concatenan   │
│     en una lista secuencial de objetos Directive(prop_name,      │
│     scope, operation, value).                                    │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. PREPROCESAMIENTO (preprocess_text)                           │
│     Antes del parsing, el texto bruto pasa por:                  │
│     a) Eliminación de comentarios (#)                            │
│     b) Resolución de continuaciones de línea (\)                 │
│     c) Normalización de espacios                                 │
│     d) Conversión de parámetros obsoletos a equivalentes         │
│        modernos (ej: min_tls_version=TLS1.2 →                    │
│        protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1)           │
│     e) Renombramiento de valores (ej: X25519-MLKEM768 →          │
│        MLKEM768-X25519)                                          │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. PARSING (parse_line → parse_rhs)                             │
│     Cada línea se convierte en Directives con operaciones:       │
│     - RESET:    "cipher ="          → limpia la lista            │
│     - APPEND:   "cipher = AES-*"    → añade al final             │
│     - PREPEND:  "cipher = +AES-*"   → inserta al inicio          │
│     - OMIT:     "cipher = -RC4-*"   → elimina de la lista        │
│     - SET_INT:  "min_rsa_size=2048" → define entero              │
│     - SET_ENUM: "__ems = ENFORCE"   → define enumeración         │
│     Los wildcards (*) se expanden contra las listas conocidas    │
│     de algoritmos (alg_lists.py).                                │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  5. RESOLUCIÓN POR ÁMBITOS (ScopedPolicy)                        │
│     Para cada back-end, la lista de Directives se evalúa con     │
│     los ámbitos relevantes de ese back-end. Una directiva solo   │
│     tiene efecto si su ScopeSelector corresponde a los ámbitos   │
│     del back-end. Ej: cipher@SSH solo afecta a {'ssh','openssh'}.│
│     El resultado son listas de algoritmos .enabled y .disabled   │
│     más los valores de .integers y .enums.                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  6. GENERACIÓN DE LOS BACK-ENDS (PolicyGenerators)               │
│     13 clases generadoras convierten la ScopedPolicy en configs: │
│                                                                  │
│     ┌─────────────────────────┬────────────────────────────┐     │
│     │ Clase Generadora        │ Archivo .config            │     │
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
│     Cada generador traduce los nombres genéricos de algoritmos   │
│     a los nombres específicos de la biblioteca usando tablas de  │
│     mapeo (cipher_map, sign_map, group_map, etc.).               │
│     Cada generador también PRUEBA la config generada ejecutando  │
│     el binario real de la biblioteca (openssl ciphers,           │
│     gnutls-cli -l, ssh -G, sshd -T) para validar que no hay      │
│     errores.                                                     │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. GENERACIÓN DE LOS BACK-ENDS                                  │
│     Para cada biblioteca/aplicación soportada, un generador de   │
│     configuración específico (policy generator) convierte la     │
│     política efectiva en un formato que la biblioteca entiende:  │
│                                                                  │
│     ┌────────────┬──────────────────────────────────────────┐    │
│     │ Back-end   │ Archivo generado                         │    │
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
│  7. INSTALACIÓN DE LOS BACK-ENDS                                 │
│     Los archivos generados se escriben atómicamente en:          │
│       /etc/crypto-policies/back-ends/                            │
│     (vía mkstemp + os.rename para evitar corrupción)             │
│                                                                  │
│     Si la política no usa subpolíticas Y no existe local.d/,     │
│     se crea un SYMLINK hacia los back-ends pregenerados en       │
│     /usr/share/crypto-policies/<POLICY>/ (optimización).         │
│                                                                  │
│     Si existe contenido en /etc/crypto-policies/local.d/,        │
│     se CONCATENA al final del back-end correspondiente.          │
│                                                                  │
│     El archivo /etc/crypto-policies/config se actualiza.         │
│     El archivo /etc/crypto-policies/state/CURRENT.pol recibe     │
│     el volcado legible de la política efectiva expandida.        │
│     El archivo /etc/crypto-policies/state/current recibe el      │
│     nombre de la política activa (ej: "DEFAULT:NO-SHA1").        │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  8. RECARGA DE LOS SERVICIOS                                     │
│     Si --no-reload NO fue utilizado, el script ejecuta           │
│     /usr/share/crypto-policies/reload-cmds.sh que contiene       │
│     comandos de recarga para cada servicio afectado.             │
│     Ejemplo: "systemctl try-restart sshd.service" para SSH.      │
│     Otras bibliotecas (OpenSSL, GnuTLS, NSS) solo aplican        │
│     la nueva política cuando la aplicación se reinicia.          │
└──────────────────────────────────────────────────────────────────┘
```

**Punto crítico:** Las aplicaciones (Apache, NGINX, Postfix, etc.) no leen la política directamente. Utilizan bibliotecas (OpenSSL, GnuTLS, NSS) que a su vez leen los archivos de back-end. El cambio de política solo tiene efecto cuando el proceso que usa la biblioteca se reinicia.

---

## I.3 Jerarquía Completa de Archivos

```
/usr/share/crypto-policies/
├── policies/                          # Políticas base del paquete
│   ├── DEFAULT.pol
│   ├── LEGACY.pol
│   ├── FUTURE.pol
│   ├── FIPS.pol
│   ├── BSI.pol
│   ├── EMPTY.pol
│   ├── NEXT.pol                       # Alias para DEFAULT
│   └── modules/                       # Subpolíticas del paquete
│       ├── AD-SUPPORT.pmod
│       ├── NO-SHA1.pmod
│       ├── NO-CAMELLIA.pmod
│       ├── NO-ENFORCE-EMS.pmod
│       ├── GOST.pmod
│       └── ...
├── DEFAULT/                           # Back-ends pregenerados para DEFAULT
│   ├── opensslcnf.config
│   ├── gnutls.config
│   ├── nss.config
│   └── ...
├── LEGACY/                            # Back-ends pregenerados para LEGACY
│   └── ...
├── FUTURE/                            # Back-ends pregenerados para FUTURE
│   └── ...
└── FIPS/                              # Back-ends pregenerados para FIPS
    └── ...

/etc/crypto-policies/
├── config                             # Texto con nombre de la política activa
│                                      # Ej: "DEFAULT:NO-SHA1"
├── back-ends/                         # Back-ends activos (enlaces o copias)
│   ├── opensslcnf.config
│   ├── openssl_fips.config            # Configuración del módulo FIPS de OpenSSL
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
├── local.d/                           # Overrides locales por back-end
│   ├── opensslcnf-extra.config        # Concatenado al opensslcnf.config
│   ├── gnutls-extra.config
│   └── ...
├── state/
│   └── current -> /usr/share/crypto-policies/DEFAULT  # Enlace simbólico
├── policies/                          # Políticas personalizadas locales
│   ├── MYPOLICY.pol                   # Política personalizada completa
│   └── modules/                       # Subpolíticas personalizadas locales
│       └── MY-MODULE.pmod
└── state/
    └── CURRENT.pol                    # Política efectiva expandida
```

**Prioridad de búsqueda:** Cuando `update-crypto-policies` busca un archivo `.pol` o `.pmod`, verifica primero `/etc/crypto-policies/policies/` y después `/usr/share/crypto-policies/policies/`. Esto permite sobrescribir políticas del paquete localmente.

---

## I.4 Formato de Definición de Política — Sintaxis Completa

Los archivos `.pol` y `.pmod` usan una sintaxis INI simple: `clave = valor`.

### I.4.1 Reglas Generales de Sintaxis

```ini
# Los comentarios comienzan con '#'
# Todo lo que aparece después de '#' en la línea se ignora

# Continuación de línea con '\'
cipher = AES-256-GCM AES-128-GCM \
         CHACHA20-POLY1305

# Asignación directa — define la lista completa
cipher = AES-256-GCM AES-128-GCM CHACHA20-POLY1305

# Modificación incremental — añade y elimina de la lista existente
# '+' al inicio = prepend (insertar al comienzo de la lista, mayor prioridad)
# sin prefijo al final = append (insertar al final de la lista)
# '-' = eliminar de la lista
cipher = +AES-256-GCM -CAMELLIA-256-GCM AES-128-CCM+

# Lista vacía — deshabilita todo en esa categoría
cipher =

# Valores enteros
min_rsa_size = 3072

# Valores booleanos (0 o 1)
sha1_in_certs = 0
```

**Regla fundamental de la modificación incremental:**

| Prefijo/Sufijo | Significado | Ejemplo |
|-----------------|-------------|---------|
| `+VALOR` (prefijo `+`) | Prepend — inserta al inicio de la lista (mayor prioridad) | `cipher = +AES-256-GCM` |
| `VALOR+` (sufijo `+`) | Append — inserta al final de la lista (menor prioridad) | `cipher = AES-128-CCM+` |
| `-VALOR` (prefijo `-`) | Remove — retira de la lista | `cipher = -CAMELLIA-256-GCM` |
| `VALOR` (sin prefijo, asignación directa) | Reset — sustituye la lista entera | `cipher = AES-256-GCM AES-128-GCM` |

**Asignación directa y modificación incremental NO pueden combinarse en la misma directiva.**

### I.4.2 Wildcards

El carácter `*` sirve como comodín para coincidencia en nombres de algoritmos:

```ini
# Eliminar TODOS los algoritmos SHA1 de firma
sign = -*-SHA1

# Eliminar todos los ciphers AES-128
cipher = -AES-128-*

# Eliminar todas las cifras Camellia
cipher = -CAMELLIA-*
```

**Precaución:** Los wildcards en directivas de adición (`+`) pueden habilitar algoritmos futuros que aún no existen en la versión actual. Utilice wildcards con `-` (eliminación) por seguridad.

### I.4.3 Ámbitos (@scope) — Directivas Por Back-end

Los ámbitos permiten que una directiva afecte solo a back-ends específicos:

```ini
# Sintaxis: opción@ámbito = valor

# Solo para SSH
cipher@SSH = -AES-128-CBC

# Solo para TLS
protocol@TLS = TLS1.3 TLS1.2

# Solo para IKE (IPsec)
protocol@IKE = IKEv2

# Múltiples ámbitos
cipher@{SSH,TLS} = -CAMELLIA-*

# Negación de ámbito — aplica a todos EXCEPTO el especificado
cipher@!SSH = -AES-128-CBC

# Negación con múltiples ámbitos
cipher@!{SSH,Kerberos} = -AES-128-CBC
```

**Ámbitos disponibles** (lista completa extraída del código fuente, `ALL_SCOPES`):

| Ámbito | Back-ends afectados | Notas |
|--------|-------------------|-------|
| `tls`, `ssl` | OpenSSL, GnuTLS, NSS (nss-tls), Java | Sinónimos |
| `openssl` | Solo OpenSSL | Más específico que `tls` |
| `gnutls` | Solo GnuTLS | Más específico que `tls` |
| `java-tls` | Solo Java/OpenJDK | Más específico que `tls` |
| `nss` | NSS (todos los subámbitos) | Ámbito raíz NSS |
| `nss-tls` | NSS para TLS | Hereda de `nss` |
| `ssh` | OpenSSH (client+server), libssh | Ámbito genérico SSH |
| `openssh` | OpenSSH (client+server) | Más específico que `ssh` |
| `openssh-client` | Solo OpenSSH cliente | Hereda de `openssh` |
| `openssh-server` | Solo OpenSSH servidor | Hereda de `openssh` |
| `libssh` | Solo libssh | Más específico que `ssh` |
| `ipsec`, `ike` | Libreswan | Sinónimos |
| `libreswan` | Solo Libreswan | Más específico que `ipsec` |
| `kerberos`, `krb5` | MIT Kerberos | Sinónimos |
| `dnssec`, `bind` | BIND | Sinónimos |
| `sequoia` | Sequoia PGP | OpenPGP |
| `rpm`, `rpm-sequoia` | RPM vía Sequoia | Verificación de paquetes RPM |
| `pkcs12` | NSS — PKCS#12 | Hereda de `nss` |
| `pkcs12-import` | NSS — importación PKCS#12 | Hereda de `nss-pkcs12` |
| `nss-pkcs12` | NSS — PKCS#12 | Sinónimo funcional |
| `nss-pkcs12-import` | NSS — importación PKCS#12 | Más permisivo |
| `smime` | NSS — S/MIME | Hereda de `nss` |
| `smime-import` | NSS — importación S/MIME | Hereda de `nss-smime` |
| `nss-smime` | NSS — S/MIME | Sinónimo funcional |
| `nss-smime-import` | NSS — importación S/MIME | Más permisivo |

Los selectores de ámbito son **case-insensitive**. Soportan globbing (`*`) y negación (`!`). Múltiples ámbitos entre llaves: `@{SSH,TLS}`. Negación múltiple: `@!{SSH,Kerberos}`.

**Jerarquía de herencia:** Ver sección I.13 para la jerarquía completa de ámbitos con relaciones padre-hijo.

---

## I.5 Referencia Completa de Parámetros

### I.5.1 Parámetros de Lista (múltiples valores)

#### `cipher` — Cifras Simétricas

Define qué algoritmos de criptografía simétrica (y modos de operación) están permitidos.

```ini
cipher = AES-256-GCM AES-256-CCM AES-256-CBC \
         AES-128-GCM AES-128-CCM AES-128-CBC \
         CHACHA20-POLY1305
```

**Valores reconocidos:**

| Valor | Descripción | Tamaño Clave |
|-------|-----------|---------------|
| `AES-256-GCM` | AES 256-bit, modo Galois/Counter (autenticado) | 256 bits |
| `AES-256-CCM` | AES 256-bit, modo Counter with CBC-MAC | 256 bits |
| `AES-256-CBC` | AES 256-bit, modo Cipher Block Chaining | 256 bits |
| `AES-256-CTR` | AES 256-bit, modo Counter | 256 bits |
| `AES-128-GCM` | AES 128-bit, modo GCM | 128 bits |
| `AES-128-CCM` | AES 128-bit, modo CCM | 128 bits |
| `AES-128-CBC` | AES 128-bit, modo CBC | 128 bits |
| `AES-128-CTR` | AES 128-bit, modo CTR | 128 bits |
| `CHACHA20-POLY1305` | ChaCha20 con Poly1305 AEAD | 256 bits |
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
| `3DES-CBC` | Triple DES, modo CBC | 168 bits (efectivo: 112) |
| `RC4-128` | RC4 stream cipher | 128 bits |
| `RC4-40` | RC4 con clave de 40 bits | 40 bits |
| `RC2-CBC` | RC2 modo CBC | Variable |
| `DES-CBC` | DES modo CBC | 56 bits |
| `DES40-CBC` | DES modo CBC con clave de 40 bits | 40 bits |
| `IDEA-CBC` | IDEA modo CBC | 128 bits |
| `SEED-CBC` | SEED modo CBC | 128 bits |
| `NULL` | Sin cifrado (solo integridad) | 0 bits |

**Nota:** Algoritmos como `AES-*-OCB`, `AES-*-EAX` y `AES-*-CFB` se usan principalmente por los back-ends Sequoia y RPM (OpenPGP). Algoritmos como `DES-CBC`, `RC4-40`, `RC2-CBC`, `DES40-CBC`, `IDEA-CBC` y `SEED-CBC` existen solo para soporte de importación de archivos PKCS#12 heredados en la política LEGACY.

**Impacto por back-end:**

- **OpenSSL:** Traducido en lista de `Ciphersuites` y `CipherString` en el `opensslcnf.config`. La eliminación de `AES-128-GCM` deshabilita TODOS los ciphers AES-128 (no es posible deshabilitar selectivamente un modo aislado).
- **GnuTLS:** Lista de cifras en la priority string del `gnutls.config`.
- **NSS:** Lista de ciphersuites en el `nss.config`.
- **OpenSSH:** Lista de `Ciphers` en el `openssh.config` y `opensshserver.config`.
- **Kerberos:** Tipos de cifrado permitidos (`permitted_enctypes`) en el `krb5.config`.

#### `mac` — Algoritmos MAC

Define qué Message Authentication Codes están permitidos.

```ini
mac = HMAC-SHA2-256 HMAC-SHA2-384 HMAC-SHA2-512 \
      HMAC-SHA1 AEAD \
      UMAC-128 UMAC-64
```

**Valores reconocidos:**

| Valor | Descripción |
|-------|-----------|
| `HMAC-SHA2-256` | HMAC con SHA-256 |
| `HMAC-SHA2-384` | HMAC con SHA-384 |
| `HMAC-SHA2-512` | HMAC con SHA-512 |
| `HMAC-SHA1` | HMAC con SHA-1 |
| `AEAD` | MACs integrados en cifras AEAD (GCM, Poly1305) |
| `UMAC-64` | UMAC con tag de 64 bits (SSH) |
| `UMAC-128` | UMAC con tag de 128 bits (SSH) |
| `HMAC-MD5` | HMAC con MD5 (inseguro — solo heredado) |

**Impacto por back-end:**

- **OpenSSH:** Genera lista `MACs` (`hmac-sha2-256`, `hmac-sha2-512`, `umac-128-etm@openssh.com`, etc.).
- **OpenSSL:** Afecta indirectamente — ciphers CBC requieren `HMAC-SHA1` y `AES-256-CBC` en la lista para estar habilitados.
- **GnuTLS:** `HMAC-SHA2-256` y `HMAC-SHA2-384` como MACs standalone están deshabilitados debido a preocupaciones con la implementación constant-time; solo `AEAD` se usa en la práctica para TLS 1.3.

#### `hash` — Algoritmos de Hash (Message Digest)

Define qué funciones de hash criptográficas están permitidas para uso general (diferente de firmas).

```ini
hash = SHA2-256 SHA2-384 SHA2-512 \
       SHA3-256 SHA3-384 SHA3-512 \
       SHA2-224 SHA1
```

**Valores reconocidos:**

| Valor | Salida (bits) | Uso Común |
|-------|-------------|-----------|
| `SHA1` | 160 | Heredado (inseguro para firmas) |
| `SHA2-224` | 224 | Raro |
| `SHA2-256` | 256 | Estándar moderno |
| `SHA2-384` | 384 | TLS 1.3, certificados |
| `SHA2-512` | 512 | Alta seguridad |
| `SHA3-256` | 256 | Estándar NIST alternativo |
| `SHA3-384` | 384 | Estándar NIST alternativo |
| `SHA3-512` | 512 | Estándar NIST alternativo |
| `SHA3-224` | 224 | SHA-3 con salida reducida |
| `SHAKE-128` | Variable | Función extensible (XOF) |
| `SHAKE-256` | Variable | Función extensible (XOF) |
| `MD5` | 128 | Inseguro — solo heredado extremo |

**Relación hash vs sign:** El parámetro `hash` controla el uso general (HMAC, derivación de clave, DNSSec). Para controlar qué hashes se aceptan en *firmas*, use `sign`.

#### `sign` — Algoritmos de Firma

Define qué combinaciones de algoritmo+hash de firma están permitidas.

```ini
sign = RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448
```

**Valores reconocidos:**

| Valor | Descripción |
|-------|-----------|
| `RSA-SHA1` | RSA PKCS#1 v1.5 con SHA-1 |
| `RSA-SHA2-224` | RSA PKCS#1 v1.5 con SHA-224 |
| `RSA-SHA2-256` | RSA PKCS#1 v1.5 con SHA-256 |
| `RSA-SHA2-384` | RSA PKCS#1 v1.5 con SHA-384 |
| `RSA-SHA2-512` | RSA PKCS#1 v1.5 con SHA-512 |
| `RSA-PSS-SHA2-256` | RSA-PSS con SHA-256 |
| `RSA-PSS-SHA2-384` | RSA-PSS con SHA-384 |
| `RSA-PSS-SHA2-512` | RSA-PSS con SHA-512 |
| `ECDSA-SHA1` | ECDSA con SHA-1 |
| `ECDSA-SHA2-224` | ECDSA con SHA-224 |
| `ECDSA-SHA2-256` | ECDSA con SHA-256 |
| `ECDSA-SHA2-384` | ECDSA con SHA-384 |
| `ECDSA-SHA2-512` | ECDSA con SHA-512 |
| `EDDSA-ED25519` | EdDSA usando curva Ed25519 |
| `EDDSA-ED448` | EdDSA usando curva Ed448 |
| `DSA-SHA1` | DSA con SHA-1 (heredado) |
| `DSA-SHA2-256` | DSA con SHA-256 |
| `ECDSA-SHA2-256-FIDO` | ECDSA con SHA-256 vía FIDO (WebAuthn) |
| `EDDSA-ED25519-FIDO` | EdDSA Ed25519 vía FIDO (WebAuthn) |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS (clave RSAE) con SHA-256 |
| `RSA-PSS-RSAE-SHA2-384` | RSA-PSS (clave RSAE) con SHA-384 |
| `RSA-PSS-RSAE-SHA2-512` | RSA-PSS (clave RSAE) con SHA-512 |
| `RSA-SHA3-256` | RSA PKCS#1 v1.5 con SHA3-256 |
| `RSA-PSS-SHA3-256` | RSA-PSS con SHA3-256 |
| `ECDSA-SHA3-256` | ECDSA con SHA3-256 |
| `MLDSA44` | ML-DSA-44 (postcuántico NIST, nivel 2) |
| `MLDSA65` | ML-DSA-65 (postcuántico NIST, nivel 3) |
| `MLDSA87` | ML-DSA-87 (postcuántico NIST, nivel 5) |
| `MLDSA65-ED25519` | ML-DSA-65 + Ed25519 híbrido (OpenPGP RFC 9980) |
| `MLDSA87-ED448` | ML-DSA-87 + Ed448 híbrido (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128S` | SLH-DSA con SHAKE-128 small (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-128F` | SLH-DSA con SHAKE-128 fast (OpenPGP RFC 9980) |
| `SLHDSA-SHAKE-256S` | SLH-DSA con SHAKE-256 small (OpenPGP RFC 9980) |

**Impacto práctico:** Si un certificado X.509 fue firmado con `RSA-SHA1` y la política activa no incluye `RSA-SHA1` en `sign`, la verificación de la cadena de confianza del certificado fallará. Esta es la causa más común de "certificate verify failed" tras cambiar de LEGACY a DEFAULT.

**Nota PQ:** Los algoritmos ML-DSA se incluyen por defecto en DEFAULT, FUTURE y FIPS. Los algoritmos híbridos y SLH-DSA se incluyen solo para los ámbitos `sequoia` y `RPM` (OpenPGP), conforme a RFC 9980.

#### `key_exchange` — Métodos de Intercambio de Claves

```ini
key_exchange = ECDHE DHE RSA PSK DHE-RSA DHE-DSS
```

| Valor | Descripción | Forward Secrecy |
|-------|-----------|:---------------:|
| `ECDHE` | Elliptic Curve Diffie-Hellman Ephemeral | Sí |
| `DHE` | Diffie-Hellman Ephemeral | Sí |
| `DHE-RSA` | DHE autenticado con RSA | Sí |
| `DHE-DSS` | DHE autenticado con DSS/DSA | Sí |
| `RSA` | Intercambio de clave RSA estático | No |
| `PSK` | Pre-Shared Key | Depende |
| `ECDHE-GSS` | ECDHE con GSSAPI (SSH) | Sí |
| `DHE-GSS` | DHE con GSSAPI (SSH) | Sí |
| `KEM-ECDH` | Key Encapsulation Mechanism con ECDH (postcuántico) | Sí |
| `SNTRUP` | NTRU Prime con X25519 (SSH postcuántico) | Sí |
| `RSA-PSK` | Pre-Shared Key con autenticación RSA | No |
| `ECDHE-PSK` | ECDHE con Pre-Shared Key | Sí |
| `DHE-PSK` | DHE con Pre-Shared Key | Sí |

**Nota:** La política FUTURE elimina `RSA` y `DHE-DSS` del intercambio de claves — esto significa que servidores usando certificados con claves DSA no podrán establecer conexiones.

**Nota sobre Libreswan:** El parámetro `key_exchange` **no afecta** la configuración generada para Libreswan. Para limitar DH/ECDH en IPsec, use el parámetro `group`.

#### `group` — Grupos/Curvas para Intercambio de Claves

Define qué curvas elípticas y grupos Diffie-Hellman están permitidos.

```ini
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192
```

**Grupos postcuánticos (híbridos):**

| Valor | Tipo | Descripción |
|-------|------|-----------|
| `MLKEM768-X25519` | PQ Híbrido | ML-KEM-768 combinado con X25519 |
| `P256-MLKEM768` | PQ Híbrido | ML-KEM-768 combinado con NIST P-256 |
| `P384-MLKEM1024` | PQ Híbrido | ML-KEM-1024 combinado con NIST P-384 |
| `MLKEM1024-X448` | PQ Híbrido | ML-KEM-1024 combinado con X448 |

**Grupos clásicos:**

| Valor | Tipo | Tamaño | Descripción |
|-------|------|---------|-----------|
| `X25519` | Curva Bernstein | ~128-bit seg. | Curva moderna, rápida |
| `X448` | Curva Goldilocks | ~224-bit seg. | Curva moderna, alta seguridad |
| `SECP256R1` | NIST P-256 | 256 bits | Curva NIST estándar |
| `SECP384R1` | NIST P-384 | 384 bits | Curva NIST alta seguridad |
| `SECP521R1` | NIST P-521 | 521 bits | Curva NIST máxima seguridad |
| `FFDHE-1024` | Finite Field DH | 1024 bits | Grupo DH heredado (solo LEGACY) |
| `FFDHE-1536` | Finite Field DH | 1536 bits | Grupo DH (solo LEGACY) |
| `FFDHE-2048` | Finite Field DH | 2048 bits | Grupo DH estandarizado (RFC 7919) |
| `FFDHE-3072` | Finite Field DH | 3072 bits | Grupo DH estandarizado |
| `FFDHE-4096` | Finite Field DH | 4096 bits | Grupo DH estandarizado |
| `FFDHE-6144` | Finite Field DH | 6144 bits | Grupo DH estandarizado |
| `FFDHE-8192` | Finite Field DH | 8192 bits | Grupo DH estandarizado |

**Nota sobre OpenSSL:** El orden de los valores de `group` solo se respeta dentro de las "clases" PQ (postcuántico) y clásica. Todos los grupos PQ se ordenan automáticamente por encima de los clásicos. En el `opensslcnf.config`, el formato es `Groups = *pq_group1:pq_group2/*classic_group1:classic_group2` donde `*` indica clases de grupos y `/` separa clases.

**Nota sobre NSS:** El orden de los valores de `group` es **ignorado** — NSS usa su orden interno incorporado.

**Nota sobre FIPS y PQ:** En la política FIPS, ML-KEM es soportado para grupos TLS pero deshabilitado por ámbito para OpenSSL (no soportado en el FIPS provider), Sequoia/RPM y parcialmente OpenSSH.

#### `protocol` — Versiones de Protocolo Permitidas

```ini
protocol = TLS1.3 TLS1.2 DTLS1.2 IKEv2
```

| Valor | Descripción |
|-------|-----------|
| `SSL3.0` | SSLv3 (eliminado de las bibliotecas — no puede habilitarse) |
| `TLS1.0` | TLS 1.0 |
| `TLS1.1` | TLS 1.1 |
| `TLS1.2` | TLS 1.2 |
| `TLS1.3` | TLS 1.3 |
| `DTLS0.9` | DTLS 0.9 |
| `DTLS1.0` | DTLS 1.0 |
| `DTLS1.2` | DTLS 1.2 |
| `IKEv1` | IKE versión 1 (IPsec heredado) |
| `IKEv2` | IKE versión 2 (IPsec moderno) |

**Limitación:** Algunos back-ends (OpenSSL, NSS) no permiten deshabilitar versiones de protocolo selectivamente — usan la versión más antigua de la lista como límite inferior. Deshabilitar todas las versiones TLS y/o DTLS resulta en los valores predeterminados de la biblioteca siendo aplicados.

### I.5.2 Parámetros Enteros

| Parámetro | Descripción | Ejemplo | Impacto |
|-----------|-----------|---------|---------|
| `min_rsa_size` | Tamaño mínimo de clave RSA en bits | `2048` | Conexiones con claves RSA menores son rechazadas. Afecta a TODOS los back-ends. |
| `min_dh_size` | Tamaño mínimo de parámetros DH en bits | `2048` | Intercambio de claves DH con parámetros menores es rechazado. |
| `min_dsa_size` | Tamaño mínimo de clave DSA en bits | `2048` | Claves DSA menores son rechazadas. |
| `min_ec_size` | Tamaño mínimo de clave EC en bits | `256` | **Se aplica solo al back-end Java/OpenJDK.** |

**Cómo OpenSSL aplica tamaños mínimos:** OpenSSL no tiene granularidad fina para tamaños mínimos — usa el mecanismo `@SECLEVEL` que define rangos de seguridad. `min_rsa_size = 2048` corresponde a `@SECLEVEL=2`. `min_rsa_size = 3072` corresponde a `@SECLEVEL=3`. Esto significa que no todos los valores arbitrarios son posibles.

| SECLEVEL | RSA mín | DH mín | ECC mín | Hash mín | Seguridad |
|----------|---------|--------|---------|----------|-----------|
| 0 | 0 | 0 | 0 | - | Todo permitido |
| 1 | 1024 | 1024 | 160 | SHA-1 | 80 bits |
| 2 | 2048 | 2048 | 224 | SHA-224 | 112 bits |
| 3 | 3072 | 3072 | 256 | SHA-256 | 128 bits |
| 4 | 7680 | 7680 | 384 | SHA-384 | 192 bits |
| 5 | 15360 | 15360 | 512 | SHA-512 | 256 bits |

### I.5.3 Parámetros Booleanos (0 o 1)

| Parámetro | Descripción | Predeterminado (DEFAULT) | Impacto |
|-----------|-----------|------------------|---------|
| `sha1_in_certs` | Permite SHA-1 en firmas de certificados | `0` | **Se aplica solo al back-end GnuTLS.** Si `0`, los certificados firmados con SHA-1 son rechazados en la validación de cadena. |
| `arbitrary_dh_groups` | Permite grupos DH arbitrarios (no estandarizados) | `0` | Si `0`, solo se aceptan grupos FFDHE estandarizados (RFC 7919). Si `1`, acepta parámetros DH arbitrarios generados por el servidor. |
| `ssh_certs` | Permite autenticación por certificados OpenSSH | `1` | Si `0`, deshabilita el mecanismo de certificados de OpenSSH (no confundir con certificados X.509). |

### I.5.4 Parámetros de Enumeración

| Parámetro | Valores | Descripción |
|-----------|---------|-----------|
| `etm` | `ANY`, `DISABLE_ETM`, `DISABLE_NON_ETM` | Controla Encrypt-then-MAC vs Encrypt-and-MAC. **Implementado solo para SSH.** Úselo con ámbito `@SSH`. `ANY` permite ambos. `DISABLE_ETM` fuerza Encrypt-and-MAC (E&M). `DISABLE_NON_ETM` fuerza Encrypt-then-MAC (EtM). |
| `__ems` | `DEFAULT`, `ENFORCE`, `RELAX` | **Interno.** Controla Extended Master Secret (RFC 7627). `ENFORCE` es usado por la política FIPS para forzar EMS. `RELAX` deshabilita el requisito (subpolítica NO-ENFORCE-EMS). **Afecta a OpenSSL y GnuTLS.** Ver sección I.14 para detalles. |

### I.5.5 Parámetros Obsoletos

Los siguientes parámetros aún funcionan pero deben ser migrados. El código fuente (`preprocess_text` en `cryptopolicies.py`) hace la conversión automáticamente y emite un `FutureWarning`:

| Obsoleto | Conversión Automática Exacta | Motivo |
|------------|---------------------------|--------|
| `min_tls_version = TLS1.2` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1` | Sustituido por eliminación incremental |
| `min_tls_version = TLS1.3` | `protocol@TLS = -SSL2.0 -SSL3.0 -TLS1.0 -TLS1.1 -TLS1.2` | Ídem |
| `min_dtls_version = DTLS1.2` | `protocol@TLS = -DTLS0.9 -DTLS1.0` | Ídem |
| `ike_protocol = IKEv2` | `protocol@IKE = IKEv2` | Renombrado a ámbito |
| `tls_cipher = ...` | `cipher@TLS = ...` | Renombrado a ámbito |
| `ssh_cipher = ...` | `cipher@SSH = ...` | Renombrado a ámbito |
| `ssh_group = ...` | `group@SSH = ...` | Renombrado a ámbito |
| `sha1_in_dnssec = 0` | `hash@DNSSec = -SHA1` + `sign@DNSSec = -RSA-SHA1 -ECDSA-SHA1` | Separación en dos parámetros |
| `sha1_in_dnssec = 1` | `hash@DNSSec = SHA1+` + `sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+` | Ídem |
| `ssh_etm = 0` | `etm@SSH = DISABLE_ETM` | Renombrado a enum |
| `ssh_etm = 1` | `etm@SSH = ANY` | Ídem |
| `ssh_etm@<scope> = 0` | `etm@<scope> = DISABLE_ETM` | Soporta ámbito |

Además, el valor `X25519-MLKEM768` se convierte automáticamente a `MLKEM768-X25519` (renombramiento de algoritmo, RHEL-99813).

El parámetro `protocol` (sin ámbito) aún funciona pero emite warning — debe ser sustituido por `protocol@TLS`.

---

## I.6 Diferencia Entre `.pol` y `.pmod`

### Archivo `.pol` — Política Completa

- Define **todos** los parámetros desde cero.
- Se usa como política base.
- Se aplica con `update-crypto-policies --set MYPOLICY`.
- Debe contener valores para todas las opciones relevantes (en caso contrario, quedan vacías/predeterminadas de la biblioteca).
- **No evoluciona** con actualizaciones del paquete `crypto-policies` — si Red Hat añade nuevos back-ends o parámetros, su política personalizada no los incluirá automáticamente.

### Archivo `.pmod` — Subpolítica/Módulo Modificador

- Modifica **selectivamente** una política base existente.
- No necesita definir todos los parámetros — solo los que quiere alterar.
- Se aplica con `update-crypto-policies --set BASE:MYPOLICY`.
- **Evoluciona** con actualizaciones — como solo modifica la base, cuando la base se actualiza por el paquete, las modificaciones permanecen y se aplican sobre la nueva versión.
- **Múltiples módulos** pueden apilarse: `--set DEFAULT:MOD1:MOD2:MOD3`.

**Red Hat recomienda encarecidamente el uso de subpolíticas (`.pmod`) en vez de políticas completas (`.pol`) personalizadas.** Esto garantiza que las actualizaciones de seguridad en las políticas base se propaguen automáticamente.

### Mecanismo de Concatenación

Cuando la política efectiva es `DEFAULT:NO-SHA1:MY-MODULE`, el sistema concatena los archivos en este orden:

```
DEFAULT.pol + NO-SHA1.pmod + MY-MODULE.pmod
```

Cada directiva posterior sobrescribe o modifica la anterior. Si `DEFAULT.pol` define:

```ini
hash = SHA2-256 SHA2-384 SHA2-512 SHA1
```

Y `NO-SHA1.pmod` define:

```ini
hash = -SHA1
sign = -RSA-SHA1 -RSA-PSS-SHA1 -ECDSA-SHA1
```

La política efectiva resultante tendrá `hash` sin `SHA1` y `sign` sin ningún algoritmo basado en SHA-1.

---

## I.7 Creando Subpolíticas Personalizadas — Guía Paso a Paso

### Ejemplo 1: Exigir Claves RSA de 4096 bits Mínimo

```bash
sudo tee /etc/crypto-policies/policies/modules/RSA-4096.pmod << 'EOF'
min_rsa_size = 4096
min_dh_size = 4096
EOF

sudo update-crypto-policies --set DEFAULT:RSA-4096
```

**Efecto:** Cualquier certificado con clave RSA menor que 4096 bits será rechazado. Cualquier intercambio de claves DH con parámetros menores que 4096 bits será rechazado. Esto es extremadamente restrictivo — la mayoría de los certificados comerciales usa 2048 o 4096 bits.

### Ejemplo 2: Política para Entorno Solo TLS 1.3

```bash
sudo tee /etc/crypto-policies/policies/modules/TLS13-ONLY.pmod << 'EOF'
protocol@TLS = TLS1.3
protocol@!TLS = -TLS1.0 -TLS1.1
cipher@TLS = AES-256-GCM AES-128-GCM CHACHA20-POLY1305
key_exchange = ECDHE
EOF

sudo update-crypto-policies --set DEFAULT:TLS13-ONLY
```

**Efecto:** Solo TLS 1.3 está permitido para conexiones TLS. Solo cifras AEAD (las únicas que TLS 1.3 soporta). Intercambio de claves solo por ECDHE.

### Ejemplo 3: Compatibilidad con Active Directory

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

**Efecto:** Habilita ciphers necesarios para Kerberos con AD heredado, permite SHA-1 en certificados (necesario para DCs antiguos), acepta parámetros DH de 1024 bits.

### Ejemplo 4: Seguridad Máxima para Entorno Financiero

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

### Ejemplo 5: Módulo para Deshabilitar CBC en Todo

```bash
sudo tee /etc/crypto-policies/policies/modules/NO-CBC.pmod << 'EOF'
cipher = -AES-256-CBC -AES-128-CBC -CAMELLIA-256-CBC -CAMELLIA-128-CBC
EOF

sudo update-crypto-policies --set DEFAULT:NO-CBC
```

---

## I.8 Creando una Política Completa (.pol) Desde Cero

Para escenarios donde ninguna política base satisface y las subpolíticas no son suficientes:

```bash
sudo cp /usr/share/crypto-policies/policies/DEFAULT.pol \
        /etc/crypto-policies/policies/MYORG.pol

sudo vi /etc/crypto-policies/policies/MYORG.pol
```

Ejemplo de política completa:

```ini
# /etc/crypto-policies/policies/MYORG.pol
# Política organizacional personalizada

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

# Firmas
sign = ECDSA-SHA2-256 ECDSA-SHA2-384 ECDSA-SHA2-512 \
       RSA-PSS-SHA2-256 RSA-PSS-SHA2-384 RSA-PSS-SHA2-512 \
       RSA-SHA2-256 RSA-SHA2-384 RSA-SHA2-512 \
       EDDSA-ED25519 EDDSA-ED448

# Intercambio de claves
key_exchange = ECDHE DHE

# Grupos/Curvas
group = X25519 X448 SECP256R1 SECP384R1 SECP521R1 \
        FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Tamaños mínimos de clave
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Opciones booleanas
sha1_in_certs = 0
arbitrary_dh_groups = 0
ssh_certs = 1
```

Aplicar:

```bash
sudo update-crypto-policies --set MYORG
```

**Atención:** Con una política `.pol` personalizada, las actualizaciones futuras del paquete `crypto-policies` que mejoren la política `DEFAULT` **no** se propagarán a `MYORG`. Usted es responsable de mantener su política actualizada.

---

## I.9 El Mecanismo `local.d` — Overrides Por Back-end

El directorio `/etc/crypto-policies/local.d/` permite añadir configuración **extra** que se concatena al final del archivo de back-end generado. Esto NO modifica la política — modifica directamente el archivo de configuración de la biblioteca.

```bash
# Ejemplo: Añadir configuración extra a OpenSSL
sudo tee /etc/crypto-policies/local.d/opensslcnf-extra.config << 'EOF'
# Configuración extra concatenada al opensslcnf.config
# (Formato de configuración OpenSSL, no formato de política)
EOF
```

**Convención de nombres:** El archivo debe seguir el patrón `<backend>-<sufijo>.config`, donde `<backend>` corresponde al nombre del back-end (sin la extensión `.config`).

**Uso recomendado:** Situaciones extremas donde la política no ofrece el control necesario sobre un back-end específico. Este es un mecanismo de último recurso — prefiera subpolíticas.

---

## I.10 Cómo Cada Back-end Consume la Política

### OpenSSL (`OpenSSLGenerator` + `OpenSSLFIPSGenerator`)

El generador crea dos archivos: `opensslcnf.config` (configuración general) y `openssl_fips.config` (configuración del módulo FIPS). OpenSSL lee `/etc/crypto-policies/back-ends/opensslcnf.config` durante la inicialización vía la directiva `.include` en el archivo `openssl.cnf` principal. Los ámbitos aplicados son `{'tls', 'ssl', 'openssl'}`.

**Traducción de parámetros:**

| Parámetro de Política | Configuración OpenSSL |
|-----------------------|---------------------|
| `cipher` | `Ciphersuites` (TLS 1.3) y `CipherString` (TLS 1.2) |
| `min_rsa_size`, `min_dh_size` | `@SECLEVEL=N` al inicio de `CipherString` |
| `protocol` | `TLS.MinProtocol`, `TLS.MaxProtocol`, `DTLS.MinProtocol`, `DTLS.MaxProtocol` |
| `group` | `Groups` (PQ y clásico separados por `/`) |
| `sign` | `SignatureAlgorithms` (con prefijo `?` para tolerancia a algoritmos desconocidos) |
| `__ems` | `Options = RHNoEnforceEMSinFIPS` si `RELAX` |
| `__openssl_block_sha1_signatures` | `rh-allow-sha1-signatures = yes/no` |
| `min_rsa_size` | `default_bits` en la sección `[req]` (mínimo 2048) |

**Irregularidades OpenSSL:**

1. La lista de ciphers TLS 1.2 (`CipherString`) se genera por **sustracción** — comienza listando los `key_exchange` habilitados, después elimina los ciphers, key exchanges y MACs de la lista de *deshabilitados*. Esto difiere del modelo de allowlist usado por GnuTLS.
2. La `CipherString` siempre excluye `-SHA384`, `-CAMELLIA`, `-ARIA`, `-AESCCM8` y `-CBC` (cuando todos los CBC están deshabilitados) por hardcoding en el generador.
3. Para deshabilitar ciphers CCM, tanto `AES-128-CCM` como `AES-256-CCM` necesitan ser eliminados; el generador usa la keyword `-AESCCM`.
4. Todos los `SignatureAlgorithms` se prefijan con `?` (`?RSA+SHA256`) para que OpenSSL tolere algoritmos que no conoce (ej: postcuánticos en versiones antiguas).

### GnuTLS (`GnuTLSGenerator`)

El generador crea un archivo de configuración en modo **allowlist** (ya no priority strings como en versiones antiguas). Los ámbitos aplicados son `{'tls', 'ssl', 'gnutls'}`. La configuración se lee de `/etc/crypto-policies/back-ends/gnutls.config` vía la variable `GNUTLS_SYSTEM_PRIORITY_FILE` (o la ruta predeterminada compilada).

**Traducción:**

| Parámetro de Política | Configuración GnuTLS |
|-----------------------|--------------------|
| `cipher` | `tls-enabled-cipher = AES-256-GCM`, etc. |
| `mac` | `tls-enabled-mac = AEAD`, `tls-enabled-mac = SHA512` |
| `hash` | `secure-hash = SHA256`, etc. |
| `sign` | `secure-sig = RSA-SHA256` + `secure-sig-for-cert = RSA-SHA256` |
| `sha1_in_certs` | `secure-sig-for-cert = rsa-sha1/dsa-sha1/ecdsa-sha1` adicionales |
| `group` | `tls-enabled-group = GROUP-X25519` + `enabled-curve = X25519` |
| `key_exchange` | `tls-enabled-kx = ECDHE-RSA`, `tls-enabled-kx = ECDHE-ECDSA` |
| `protocol` | `enabled-version = TLS1.3`, etc. |
| `min_rsa_size`, `min_dh_size` | `min-verification-profile` |
| `__ems` | `tls-session-hash = require/request` |

**Irregularidades GnuTLS:**

1. `sha1_in_certs` es el **único** back-end que respeta este parámetro directamente (añadiendo SHA-1 solo a `secure-sig-for-cert`).
2. `HMAC-SHA2-256` y `HMAC-SHA2-384` como MACs standalone están **mapeados a `None`** en el código y por tanto nunca se habilitan, por preocupaciones de vulnerabilidad a Lucky13 (ver [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503)). Solo `AEAD` y `HMAC-SHA2-512` funcionan.
3. Los PSK key exchanges (`PSK`, `DHE-PSK`, `ECDHE-PSK`, `RSA-PSK`) están **comentados** en el generador y por tanto nunca se habilitan vía crypto-policies, aunque la política los liste.
4. El `ECDHE` key exchange se expande en **dos** tipos kex: `ECDHE-RSA` y `ECDHE-ECDSA` en el generador.
5. Las curvas necesitan habilitarse por separado de los grupos. El generador extrae las curvas de los grupos y de las firmas (ej: EdDSA-Ed25519 → `enabled-curve = Ed25519`).

### NSS (Network Security Services)

El generador crea un archivo de política NSS en `/etc/crypto-policies/back-ends/nss.config`.

**Irregularidades NSS:**

1. El orden de `group` es **ignorado** — NSS usa su orden interno.
2. Es el **único** back-end que respeta los ámbitos `pkcs12`, `pkcs12-import`, `smime` y `smime-import`.
3. `pkcs12` implica `pkcs12-import` — no es posible permitir exportación sin permitir importación.
4. Esos ámbitos no pueden habilitar algoritmos de firma que no fueron habilitados en la configuración general.
5. Deshabilitar todas las versiones TLS/DTLS resulta en los valores predeterminados de la biblioteca.

### OpenSSH (`OpenSSHClientGenerator` + `OpenSSHServerGenerator`)

El generador crea dos archivos separados con ámbitos diferentes:
- **Cliente:** `openssh.config` — ámbitos `{'ssh', 'openssh', 'openssh-client'}`
- **Servidor:** `opensshserver.config` — ámbitos `{'ssh', 'openssh', 'openssh-server'}`

**Traducción:**

| Parámetro de Política | Configuración OpenSSH |
|-----------------------|---------------------|
| `cipher@SSH` | `Ciphers` |
| `mac@SSH` + `etm` | `MACs` (EtM y no-EtM en orden según enum `etm`) |
| `key_exchange` × `group` × `hash` | `KexAlgorithms` (producto cartesiano filtrado por la tabla `kx_map`) |
| `key_exchange` × `hash` + `arbitrary_dh_groups` | `KexAlgorithms` vía `gx_map` (group exchange) |
| `sign` | `PubkeyAcceptedAlgorithms`, `HostbasedAcceptedAlgorithms`, `CASignatureAlgorithms` |
| `sign` (servidor) | `HostKeyAlgorithms` (solo servidor) |
| `ssh_certs` + `sign` | Sufijos `-cert-v01@openssh.com` añadidos a `PubkeyAcceptedAlgorithms` |
| `min_rsa_size` | `RequiredRSASize` (si > 0) |
| `key_exchange` (GSS) | `GSSAPIKexAlgorithms` o `GSSAPIKeyExchange no` |

**Irregularidades OpenSSH:**

1. DH group 1 (1024 bits) es **siempre** eliminado en el servidor, aunque la política permita DH de 1024 bits. El código del servidor explícitamente hace `del local_kx_map[('DHE', 'FFDHE-1024', 'SHA1')]`.
2. `HostKeyAlgorithms` se define **solo** para el servidor. Configurarlo en el cliente rompería el manejo de entradas `known_hosts` existentes.
3. El `KexAlgorithms` se construye mediante un **producto cartesiano** de (`key_exchange`, `group`, `hash`), filtrado contra la tabla `kx_map`. Solo las combinaciones con mapeo definido producen salida.
4. `GSSAPIKeyExchange no` se emite si ningún GSS kex es habilitado por la política.
5. `CASignatureAlgorithms` no incluye variantes de certificado, solo algoritmos base.
6. Cuando `ssh_certs = 1`, el generador añade certificados incluyendo el nuevo `ssh-mldsa44-ed25519@openssh.com` (postcuántico).
7. El comando de recarga del servidor es `systemctl try-restart sshd.service` (restart, no reload, porque systemd necesita releer opciones de línea de comando).

### Libreswan (IPsec/IKE)

**Irregularidades Libreswan:**

1. El parámetro `key_exchange` **no afecta** la configuración generada para Libreswan.
2. Para controlar DH vs ECDH en IPsec, use el parámetro `group`.

### Kerberos (MIT krb5)

El generador crea `/etc/crypto-policies/back-ends/krb5.config` con la lista `permitted_enctypes`.

**Traducción:** Los ciphers se mapean a enctypes Kerberos (`aes256-cts-hmac-sha384-192`, `aes128-cts-hmac-sha256-128`, etc.).

### Java/OpenJDK

El generador crea `/etc/crypto-policies/back-ends/java.config` que configura las Java Security Properties.

**Nota:** El parámetro `min_ec_size` **se aplica solo** al back-end Java.

---

## I.11 Algoritmos Eliminados vs Deshabilitados

Hay una distinción fundamental entre algoritmos **eliminados** de las bibliotecas y algoritmos **deshabilitados** por las políticas:

### Eliminados Completamente de las Bibliotecas Core

Estos algoritmos fueron eliminados del código fuente de las bibliotecas criptográficas y **no pueden habilitarse** por ninguna política, ni siquiera LEGACY:

| Algoritmo/Protocolo | Motivo |
|---------------------|--------|
| DES (no 3DES) | Completamente inseguro (56 bits) |
| Export-grade cipher suites | Inseguros por diseño |
| MD5 en firmas | Colisiones demostradas |
| SSLv2 | Múltiples vulnerabilidades fatales |
| SSLv3 | Vulnerable a POODLE |
| Curvas ECC < 224 bits | Inseguras |
| Curvas ECC de campo binario | No estandarizadas / sospechosas |

### Deshabilitados en TODAS las Políticas Predefinidas (pero disponibles)

Estos algoritmos existen en las bibliotecas pero están deshabilitados en todas las políticas. Una política personalizada `.pol` **podría** habilitarlos (no recomendado):

| Algoritmo/Protocolo | Riesgo |
|---------------------|-------|
| DH con parámetros < 1024 bits | Ataque Logjam |
| RSA con clave < 1024 bits | Factorizable con hardware moderno |
| Camellia | No ampliamente probado |
| RC4 | Múltiples sesgos conocidos |
| ARIA | Uso limitado, poca auditoría |
| SEED | Uso limitado fuera de Corea |
| IDEA | Obsoleto |
| Ciphersuites de solo integridad | Sin cifrado |
| TLS CBC con HMAC SHA-384 | Implementaciones problemáticas |
| AES-CCM8 (tag corto) | Tag de autenticación insuficiente |
| Curvas ECC incompatibles con TLS 1.3 (incluida secp256k1) | Fuera del estándar TLS 1.3 |
| IKEv1 | Sustituido por IKEv2 |

---

## I.12 Aplicaciones y Bibliotecas NO Cubiertas

Las crypto-policies cubren solo **datos en tránsito** (data-in-transit). Las siguientes situaciones **no están** controladas:

| No Cubierto | Motivo |
|-------------|--------|
| Aplicaciones Go | El runtime Go no lee las crypto-policies del sistema |
| GnuPG-2 | Usa su propio sistema de configuración |
| Datos en reposo (disk encryption) | LUKS, dm-crypt tienen configuración independiente |
| Ubicaciones de certificados | Gestionado por cada servicio individualmente |
| CA trust store | Gestionado por `update-ca-trust`, no por `crypto-policies` |
| Emisión de certificados | No controlado (CA/certmonger/certbot) |
| Aplicaciones que fuerzan sus propias configuraciones | Si la app define ciphers explícitamente en el código, la política del sistema se ignora |

---

## I.13 Jerarquía de Ámbitos — Visión del Código Fuente

El código fuente (`cryptopolicies.py`) define una jerarquía de ámbitos donde cada back-end recibe un conjunto de ámbitos y opcionalmente hereda de un ámbito padre. La siguiente tabla muestra exactamente qué ámbitos se aplican para cada back-end al generar su configuración:

| Back-end (volcable) | Ámbito padre | Conjunto de ámbitos aplicados |
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

**Cómo funciona:** Cuando el generador del servidor OpenSSH solicita la configuración, pasa el conjunto `{'ssh', 'openssh', 'openssh-server'}` al `ScopedPolicy`. Cada directiva en la política se evalúa contra esos ámbitos: `cipher@SSH` coincide (porque `ssh` está en el conjunto), `cipher@TLS` no coincide, `cipher@!SSH` no coincide. La directiva `cipher@{SSH,TLS}` coincidiría porque `ssh` está en el conjunto.

**Herencia padre-hijo:** Cuando el volcado de la política se genera para `CURRENT.pol`, el sistema muestra propiedades específicas de ámbito solo si difieren del ámbito padre. Por ejemplo, `cipher@openssh-server` solo aparece si difiere de `cipher@openssh`.

---

## I.14 Parámetros Internos (No Documentados Públicamente)

El código fuente define parámetros con prefijo `__` (double underscore) que se usan internamente por las políticas proporcionadas por el sistema. Estos parámetros no están documentados en la man page y no deben usarse en políticas personalizadas, pero entenderlos es importante para comprender el comportamiento real:

### `__openssl_block_sha1_signatures`

```python
INT_DEFAULTS = {
    ...
    '__openssl_block_sha1_signatures': 1,
}
```

Controla si OpenSSL bloquea la verificación de firmas SHA-1. Valor predeterminado `1` (bloquear). En el generador de OpenSSL, esto se traduce a la directiva `rh-allow-sha1-signatures = yes/no` en la sección `[evp_properties]` del `opensslcnf.config`. Esta es una **extensión específica de Red Hat** de OpenSSL, no presente en el OpenSSL upstream.

La política LEGACY define `__openssl_block_sha1_signatures = 0`, permitiendo la verificación de firmas SHA-1 en OpenSSL. Todas las demás políticas mantienen el valor `1`.

### `__ems` (Extended Master Secret)

```python
ENUMS = {
    'etm': ('ANY', 'DISABLE_ETM', 'DISABLE_NON_ETM'),
    '__ems': ('DEFAULT', 'ENFORCE', 'RELAX'),
}
```

Controla el requisito de Extended Master Secret (RFC 7627) en TLS. Tres valores posibles:

| Valor | Efecto en OpenSSL | Efecto en GnuTLS |
|-------|-------------------|-------------------|
| `DEFAULT` | Sin acción (biblioteca decide) | Sin acción (`tls-session-hash` no configurado) |
| `ENFORCE` | Sin acción (FIPS ya fuerza) | `tls-session-hash = require` |
| `RELAX` | `Options = RHNoEnforceEMSinFIPS` + config FIPS con `tls1-prf-ems-check = 0` | `tls-session-hash = request` |

La política FIPS define `__ems = ENFORCE`. La subpolítica NO-ENFORCE-EMS define `__ems = RELAX`.

El generador OpenSSL también crea un archivo separado `openssl_fips.config` que configura el módulo FIPS de OpenSSL:

```ini
[fips_sect]
tls1-prf-ems-check = 1  # o 0 si __ems == RELAX
activate = 1
```

---

## I.15 Algoritmos Postcuánticos en el Código Fuente

El código fuente (`alg_lists.py`) ya define listas extensas de algoritmos postcuánticos, marcados como experimentales:

### Grupos (Key Encapsulation — ML-KEM)

Los siguientes grupos postcuánticos están definidos en las políticas actuales (DEFAULT, FUTURE, FIPS, LEGACY):

| Grupo | Tipo | Descripción |
|-------|------|-----------|
| `MLKEM768-X25519` | Híbrido | ML-KEM-768 con X25519 (estándar NIST + clásico) |
| `P256-MLKEM768` | Híbrido | ML-KEM-768 con NIST P-256 |
| `P384-MLKEM1024` | Híbrido | ML-KEM-1024 con NIST P-384 |
| `MLKEM1024-X448` | Híbrido | ML-KEM-1024 con X448 |

Grupos marcados como experimentales (presentes en el código pero no en las políticas estándar):

| Grupo | Estado |
|-------|--------|
| `MLKEM512`, `X25519-MLKEM512`, `P256-MLKEM512` | Experimentales |
| `MLKEM768`, `X448-MLKEM768` | Experimentales (variantes solo/alternativas) |
| `MLKEM1024`, `P521-MLKEM1024` | Experimentales |

### Firmas (ML-DSA, FALCON, SPHINCS+, SLH-DSA)

Firmas postcuánticas en las políticas estándar:

| Algoritmo | Presente en DEFAULT | Presente en FIPS |
|-----------|:-------------------:|:----------------:|
| `MLDSA44` (ML-DSA-44) | Sí | Sí |
| `MLDSA65` (ML-DSA-65) | Sí | Sí |
| `MLDSA87` (ML-DSA-87) | Sí | Sí |

Firmas experimentales en el código (no en las políticas estándar):

```
P256-MLDSA44, RSA3072-MLDSA44, MLDSA44-PSS2048, MLDSA44-RSA2048,
MLDSA44-ED25519, MLDSA44-P256, MLDSA44-BP256,
P384-MLDSA65, MLDSA65-PSS3072, MLDSA65-RSA3072,
FALCON512, FALCONPADDED512, FALCON1024, FALCONPADDED1024,
SPHINCSSHA2128FSIMPLE, SPHINCSSHA2128SSIMPLE, SPHINCSSHAKE128FSIMPLE,
... y más variantes híbridas
```

Firmas PQ para OpenPGP (Sequoia/RPM), añadidas con `sign@{sequoia,RPM}` en todas las políticas estándar:

```
MLDSA65-ED25519, MLDSA87-ED448,
SLHDSA-SHAKE-128S, SLHDSA-SHAKE-128F, SLHDSA-SHAKE-256S
```

**Cómo OpenSSL gestiona grupos PQ:** El generador de OpenSSL separa los grupos en dos clases — PQ y clásica — y los formatea como `*pq_groups/classic_groups` en la directiva `Groups`. Esto hace que los servidores prefieran cualquier grupo PQ sobre cualquier grupo clásico cuando ambos son soportados, y los clientes envíen key shares para el grupo PQ de mayor prioridad Y el grupo clásico de mayor prioridad.

---

## I.16 FIPS Auto-Bind-Mount — El Mecanismo de Arranque

Cuando el kernel se inicia con `fips=1`, un módulo dracut y/o un servicio systemd automáticamente hacen bind-mount de:

```
/usr/share/crypto-policies/back-ends/FIPS/  →  /etc/crypto-policies/back-ends/
/usr/share/crypto-policies/default-fips-config  →  /etc/crypto-policies/config
```

Esto garantiza que la política FIPS esté activa desde el primer momento del arranque, antes incluso de que `update-crypto-policies` pueda ejecutarse.

El script `update-crypto-policies.py` detecta esta situación verificando `/proc/self/mountinfo`:

```
is_fips_auto_bind_mounted():
  Verifica si /etc/crypto-policies/config está montado desde
  .../crypto-policies/default-fips-config
  Y si /etc/crypto-policies/back-ends está montado desde
  .../crypto-policies/back-ends/FIPS
```

**Comportamiento cuando el auto-bind está activo:**

- `--show`: Funciona normalmente (lee el contenido montado).
- `--set FIPS:SUBPOLICY`: Desmonta los bind-mounts con `umount` y entonces aplica la nueva política con la subpolítica. Esto permite personalizar FIPS con subpolíticas.
- `--set DEFAULT` (u otra no-FIPS): Emite aviso de que el sistema ya no será FIPS-compliant, desmonta y aplica.
- Sin `--set`: Avisa que los archivos en `local.d/` serán ignorados mientras el auto-bind esté activo.

**Implicación práctica:** Si necesita FIPS con una subpolítica (ej: `FIPS:NO-ENFORCE-EMS`), ejecute `update-crypto-policies --set FIPS:NO-ENFORCE-EMS` — esto elimina el bind-mount automático y aplica una política FIPS personalizada persistente.

---

## I.17 Lo Que Cada Política Realmente Define — Anotación del Código Fuente

Las siguientes anotaciones se extraen directamente de los archivos `.pol` del repositorio upstream.

### DEFAULT.pol — Anotaciones

```ini
# Seguridad de 112 bits con excepción de SHA-1 en DNSSec

# Incluye ML-KEM y ML-DSA (postcuánticos) en los primeros lugares de las listas
group = MLKEM768-X25519 P256-MLKEM768 P384-MLKEM1024 MLKEM1024-X448 \
        X25519 SECP256R1 X448 SECP521R1 SECP384R1 \
        FFDHE-2048 FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# SHA-1 y DSA-SHA1 permitidos solo en DNSSec y RPM (por ámbito)
hash@DNSSec = SHA1+
sign@DNSSec = RSA-SHA1+ ECDSA-SHA1+
sign@RPM = DSA-SHA1+
hash@RPM = SHA1+
min_dsa_size@RPM = 1024   # RPM necesita aceptar paquetes antiguos con DSA 1024

# CBC deshabilitado en SSH por ámbito (vulnerable a plaintext recovery)
cipher@SSH = -*-CBC

# RSA está ANTES de DHE en key_exchange por cuestión de interoperabilidad
key_exchange = KEM-ECDH ECDHE RSA DHE DHE-RSA PSK DHE-PSK ECDHE-PSK RSA-PSK \
               ECDHE-GSS DHE-GSS

# arbitrary_dh_groups = 1 → acepta parámetros DH del servidor
# (necesario para compatibilidad con servidores que no usan FFDHE)
arbitrary_dh_groups = 1
```

### FUTURE.pol — Diferencias Respecto a DEFAULT

```ini
# Seguridad de 128 bits — preparación para postcuántico

# HMAC-SHA1 ELIMINADO de la lista de MACs
mac = AEAD HMAC-SHA2-256 UMAC-128 HMAC-SHA2-384 HMAC-SHA2-512
# (DEFAULT incluye HMAC-SHA1)

# SHA2-224 y SHA3-224 ELIMINADOS de hash
hash = SHA2-256 SHA2-384 SHA2-512 SHA3-256 SHA3-384 SHA3-512 SHAKE-256

# Sin SHA-1 en NINGÚN ámbito (sin excepción para DNSSec)
# SHA-224 ELIMINADO de sign
# RSA ELIMINADO de key_exchange (sin intercambio de clave RSA estático)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK ECDHE-GSS DHE-GSS

# Solo cifras de 256 bits y AEAD en TLS
cipher@TLS = AES-256-GCM AES-256-CCM CHACHA20-POLY1305

# FFDHE-2048 ELIMINADO (mínimo 3072)
group = ... FFDHE-3072 FFDHE-4096 FFDHE-6144 FFDHE-8192

# Tamaños mínimos aumentados
min_dh_size = 3072
min_dsa_size = 3072
min_rsa_size = 3072
```

### LEGACY.pol — Diferencias Respecto a DEFAULT

```ini
# Seguridad de 64 bits — máxima compatibilidad

# SHA1 incluido en hash (para uso general, no solo DNSSec)
hash = ... SHA1

# DSA y SHA-1 PERMITIDOS en firmas
sign = ... DSA-SHA2-256 DSA-SHA2-384 DSA-SHA2-512 DSA-SHA2-224 \
       ECDSA-SHA1 RSA-PSS-SHA1 RSA-SHA1 DSA-SHA1

# 3DES-CBC habilitado en cipher y cipher@TLS
cipher = ... 3DES-CBC
cipher@TLS = ... 3DES-CBC

# CBC HABILITADO en SSH (diferente de DEFAULT/FUTURE/FIPS)
cipher@SSH = AES-256-GCM CHACHA20-POLY1305 AES-256-CTR AES-256-CBC \
    AES-128-GCM AES-128-CTR AES-128-CBC 3DES-CBC

# DHE-DSS habilitado, FFDHE-1536 incluido, FFDHE-1024 para SSH
group@SSH = FFDHE-1024+
key_exchange = ... DHE-DSS ...

# TLS 1.0 y 1.1 habilitados, DTLS 1.0 habilitado
protocol@TLS = TLS1.3 TLS1.2 TLS1.1 TLS1.0 DTLS1.2 DTLS1.0

# Tamaños mínimos reducidos
min_dh_size = 1024
min_dsa_size = 1024
min_rsa_size = 1024

# SHA-1 permitido en certificados (GnuTLS)
sha1_in_certs = 1

# OpenSSL NO bloquea firmas SHA-1
__openssl_block_sha1_signatures = 0

# PKCS#12 acepta DES, RC4, RC2, SEED (heredado extremo)
cipher@pkcs12 = AES-256-CBC AES-192-CBC AES-128-CBC \
    CAMELLIA-256-CBC ... 3DES-CBC DES-CBC RC4-128 DES40-CBC RC2-CBC SEED-CBC
```

### FIPS.pol — Diferencias Respecto a DEFAULT

```ini
# Conformidad FIPS 140 — NO garantiza FIPS por sí solo

# Sin CHACHA20-POLY1305 (no aprobado FIPS)
cipher@TLS = AES-256-GCM AES-256-CCM AES-256-CBC \
    AES-128-GCM AES-128-CCM AES-128-CBC

# Sin X25519 y X448 en los grupos (no aprobados FIPS como curvas standalone)
# ML-KEM bloqueado para OpenSSL (no soportado en el FIPS provider aún)
# ML-KEM bloqueado para Sequoia/RPM
group@openssl = +P256-MLKEM768  # despriorizar X25519-MLKEM768
group@{sequoia,rpm} = -MLKEM768-X25519 -P256-MLKEM768 -P384-MLKEM1024
group@openssh = -MLKEM768-X25519

# Sin EdDSA, sin FIDO, sin SHA-224 en firmas
# Sin variantes RSA-PSS-RSAE SHA3

# PSK sin RSA-PSK (no aprobado)
key_exchange = KEM-ECDH ECDHE DHE DHE-RSA PSK DHE-PSK ECDHE-PSK

# Extended Master Secret obligatorio
__ems = ENFORCE
```

---

## I.18 Mapeo de Algoritmos en los Generadores — Tablas del Código Fuente

### OpenSSH: Mapeo de Cifras

El generador `openssh.py` mapea nombres genéricos de cifras a los nombres usados por OpenSSH:

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
| `AES-256-CCM` | *(no soportado)* |
| `CAMELLIA-*` | *(no soportado)* |

Las cifras sin mapeo en OpenSSH se ignoran silenciosamente.

### OpenSSH: Mapeo de Key Exchange

El generador construye la lista `KexAlgorithms` a partir de combinaciones (`key_exchange`, `group`, `hash`):

| Combinación (key_exchange, group, hash) | KexAlgorithm SSH |
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

El servidor **siempre elimina** `('DHE', 'FFDHE-1024', 'SHA1')` (diffie-hellman-group1-sha1), aunque la política lo permita.

### OpenSSL: Mecanismo de SECLEVEL

El generador de OpenSSL (`openssl.py`) determina el `@SECLEVEL` directamente de los parámetros `min_dh_size` y `min_rsa_size`:

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

Esto significa que si `min_rsa_size = 2048` y `min_dh_size = 2048`, OpenSSL recibirá `@SECLEVEL=2`. No hay forma de definir un valor intermedio (ej: RSA 2048 pero DH 3072 resultaría en SECLEVEL=2 por causa del RSA).

### OpenSSL: Generación de Ciphers TLS 1.3

El generador construye la directiva `Ciphersuites` (TLS 1.3) por separado de la `CipherString` (TLS 1.2). Para TLS 1.3, existe un mapeo directo:

| Ciphersuite | Requiere `cipher` | Requiere `hash` |
|-------------|----------------|---------------|
| `TLS_AES_256_GCM_SHA384` | `AES-256-GCM` | `SHA2-384` |
| `TLS_AES_128_GCM_SHA256` | `AES-128-GCM` | `SHA2-256` |
| `TLS_CHACHA20_POLY1305_SHA256` | `CHACHA20-POLY1305` | `SHA2-256` |
| `TLS_AES_128_CCM_SHA256` | `AES-128-CCM` | `SHA2-256` |

### OpenSSL: SHA-1 y la Sección `rh-allow-sha1-signatures`

El generador siempre añade una sección especial al `opensslcnf.config`:

```ini
[openssl_init]
alg_section = evp_properties

[evp_properties]
rh-allow-sha1-signatures = no   # o yes para LEGACY
```

Esta es una extensión Red Hat que controla si OpenSSL acepta verificar firmas basadas en SHA-1. La lógica en el código es:

```python
sha1_sig = not policy.integers['__openssl_block_sha1_signatures']
s += RH_SHA1_SECTION.format('yes' if sha1_sig else 'no')
```

Solo la política LEGACY define `__openssl_block_sha1_signatures = 0`.

### GnuTLS: Modo Allowlist

El generador de GnuTLS (`gnutls.py`) genera configuración en modo **allowlist** (lista blanca):

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
min-verification-profile = medium   # o high, ultra, etc.

[priorities]
SYSTEM=NONE
```

El `min-verification-profile` se deriva de los tamaños mínimos de clave:

| `min_dh_size` / `min_rsa_size` | Profile |
|-------------------------------|---------|
| ≤ 768 | `very_weak` |
| ≤ 1024 | `low` |
| ≤ 2048 | `medium` |
| ≤ 3072 | `high` |
| ≤ 8192 | `ultra` |
| > 8192 | `future` |

Cuando `sha1_in_certs = 1`, el generador añade explícitamente:

```ini
secure-sig-for-cert = rsa-sha1
secure-sig-for-cert = dsa-sha1
secure-sig-for-cert = ecdsa-sha1
```

### GnuTLS: MACs Deshabilitados por Seguridad

El `mac_map` de GnuTLS mapea `HMAC-SHA2-256` y `HMAC-SHA2-384` a `None`:

```python
mac_map = {
    'HMAC-SHA2-256': None,  # not allowlisted over concerns that
    'HMAC-SHA2-384': None,  # implementation might be vulnerable to Lucky13
    'HMAC-SHA2-512': 'SHA512',
}
```

Esto significa que aunque la política habilite `HMAC-SHA2-256`, GnuTLS no lo activará como MAC standalone. Solo `HMAC-SHA2-512` y `AEAD` funcionan como MACs TLS en GnuTLS. La referencia en el código apunta a [GnuTLS issue #503](https://gitlab.com/gnutls/gnutls/-/issues/503).

---

## I.19 Validación en el Generador — Pruebas Automáticas de Configuración

Cada generador contiene un método `test_config()` que valida la configuración generada ejecutando el binario real de la biblioteca. Esto ocurre durante el `update-crypto-policies`:

| Generador | Comando de Prueba | Qué Valida |
|---------|-----------------|--------------|
| `OpenSSLGenerator` | `openssl ciphers <CipherString>` | Verifica si la CipherString es válida y no contiene ADH |
| `GnuTLSGenerator` | `gnutls-cli -l` (con `GNUTLS_SYSTEM_PRIORITY_FILE` apuntando al config) | Verifica si la priority string es válida |
| `OpenSSHClientGenerator` | `ssh -G -F <config> bogus_server` | Verifica si las opciones SSH son válidas |
| `OpenSSHServerGenerator` | `sshd -T -h <hostkey> -f <config>` | Genera una host key RSA 3072 temporal y prueba sshd |

Si el binario de la biblioteca no está instalado, la prueba se omite silenciosamente. Las variables de entorno `OLD_OPENSSH=1` y `OLD_GNUTLS=1` también omiten las pruebas (para compatibilidad con versiones antiguas durante builds).

---

## I.20 Escritura Atómica y Optimización de Symlinks

El script `update-crypto-policies.py` usa escritura atómica para evitar corrupción:

1. Crea un archivo temporal con `mkstemp()` en el directorio destino.
2. Escribe el contenido, hace `fsync()`, define permisos `0o644`.
3. Hace `os.rename()` del temporal al nombre final (operación atómica en el mismo filesystem).

**Optimización de symlinks:** Si la política no tiene subpolíticas Y no existen archivos en `local.d/`, el script crea un **symlink** de `/etc/crypto-policies/back-ends/<backend>.config` a `/usr/share/crypto-policies/<POLICY>/<backend>.txt` en vez de copiar el contenido. Esto ahorra espacio y permite que las actualizaciones del paquete se propaguen automáticamente para políticas simples (sin módulos).

Si existen archivos `local.d/`, el symlink no puede usarse porque el contenido necesita concatenarse. En ese caso, el archivo se escribe directamente y el contenido de `local.d/` se añade al final.

---

## I.21 Verificación y Diagnóstico de la Política Efectiva

### Comandos de Verificación

```bash
# Política activa (nombre)
update-crypto-policies --show

# Verificar si la política está realmente aplicada
# (compara timestamps y contenido de state/current vs config,
#  y verifica si no hay FIPS auto-bind-mount activo)
update-crypto-policies --is-applied

# Verificar si los archivos generados corresponden a la política configurada
# (regenera en directorio temporal y compara byte a byte)
update-crypto-policies --check

# Política efectiva expandida (resultado de la concatenación base + submódulos)
cat /etc/crypto-policies/state/CURRENT.pol

# Contenido del archivo de config de cada back-end
cat /etc/crypto-policies/back-ends/opensslcnf.config
cat /etc/crypto-policies/back-ends/gnutls.config
cat /etc/crypto-policies/back-ends/nss.config
cat /etc/crypto-policies/back-ends/openssh.config
cat /etc/crypto-policies/back-ends/opensshserver.config

# Fecha del último cambio de política
ls -l /etc/crypto-policies/back-ends/
ls -l /etc/crypto-policies/config

# Ciphers disponibles en OpenSSL bajo la política actual
openssl ciphers -v

# Probar conexión TLS real y verificar cipher negociado
openssl s_client -connect localhost:443

# Verificar si algún servicio está sobrescribiendo la política
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/ 2>/dev/null
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/ 2>/dev/null
```

### Validando una Subpolítica Antes de Aplicar

```bash
# Verificar sintaxis — update-crypto-policies reportará errores
sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE 2>&1

# Si hay error de sintaxis, la salida indicará el problema

# Comparar back-ends antes/después
diff <(cat /etc/crypto-policies/back-ends/opensslcnf.config) \
     <(sudo update-crypto-policies --set DEFAULT:MY-NEW-MODULE && \
       cat /etc/crypto-policies/back-ends/opensslcnf.config)

# Verificar la política efectiva expandida
cat /etc/crypto-policies/state/CURRENT.pol
```

---

## I.22 Diferencias Entre Versiones de RHEL

| Aspecto | RHEL 8 | RHEL 9 | RHEL 10 |
|---------|--------|--------|---------|
| OpenSSL | 1.1.1 | 3.0.x / 3.2.x | 3.x |
| Subpolíticas `.pmod` | Introducidas en RHEL 8.2 | Totalmente soportadas | Totalmente soportadas |
| Ámbitos `@scope` | Básicos (RHEL 8.5+) | Completos | Completos |
| Wildcards `*` | RHEL 8.2+ | Sí | Sí |
| Negación de ámbito `@!scope` | Limitado | Sí | Sí |
| Política BSI | No | Sí (Fedora/RHEL 9+) | Sí |
| Postcuántico (ML-KEM, ML-DSA) | No | Parcial (tardío) | Sí |
| DEFAULT bloquea SHA-1 | En firmas (excepto DNSSec) | Más agresivo | Más agresivo |
| Política FIPS | FIPS 140-2 | FIPS 140-3 | FIPS 140-3 |
| NEXT como alias de DEFAULT | No | Sí | Sí |
| Sequoia/RPM back-ends | No | Sí | Sí |

---

## I.23 Subpolíticas Proporcionadas por el Sistema

Las siguientes subpolíticas vienen instaladas con el paquete `crypto-policies`:

### `NO-SHA1`

```ini
hash = -SHA1
sign = -RSA-PSS-SHA1 -RSA-SHA1 -ECDSA-SHA1 -EDDSA-ED25519
```

Elimina SHA-1 de hashes y firmas. Bloqueo total de SHA-1 en el sistema.

### `AD-SUPPORT`

Habilita algoritmos necesarios para interoperabilidad con Active Directory y entornos Windows heredados.

### `NO-CAMELLIA`

```ini
cipher = -CAMELLIA-*
```

Elimina todas las cifras Camellia.

### `NO-ENFORCE-EMS` (RHEL 9+)

Deshabilita el requisito de Extended Master Secret (EMS) en TLS. Necesario para compatibilidad con bibliotecas TLS antiguas que no soportan RFC 7627.

### `GOST`

Habilita algoritmos criptográficos GOST (estándar ruso GOST R 34.10-2012, GOST R 34.11-2012). Necesario para conformidad con estándares de criptografía de la Federación Rusa.

---

## I.24 Ejemplos Prácticos de Diagnóstico

### "certificate verify failed" Tras Cambio de Política

```
Causa probable:
  - Certificado firmado con SHA-1 → sign no incluye RSA-SHA1/ECDSA-SHA1
  - Certificado con clave RSA 1024-bit → min_rsa_size rechaza
  - CA intermedia con SHA-1 → sha1_in_certs = 0 (GnuTLS)

Diagnóstico:
  openssl x509 -in cert.pem -noout -text | grep "Signature Algorithm"
  openssl x509 -in cert.pem -noout -text | grep "Public-Key"
  update-crypto-policies --show
  cat /etc/crypto-policies/state/CURRENT.pol | grep -E "sign|min_rsa|sha1"

Corrección:
  Si es certificado heredado → reemitir con SHA-256 y RSA 2048+
  Si es temporal → crear subpolítica permitiendo el algoritmo necesario
```

### SSH Rechaza Conexión con "no matching cipher found"

```
Causa probable:
  - Servidor o cliente ofrece solo ciphers CBC y la política los deshabilitó
  - Cliente antiguo soporta solo AES-128-CBC

Diagnóstico:
  ssh -vvv user@host 2>&1 | grep -i cipher
  cat /etc/crypto-policies/back-ends/openssh.config
  cat /etc/crypto-policies/back-ends/opensshserver.config

Corrección:
  Crear subpolítica que rehabilita el cipher necesario:
  cipher@SSH = +AES-128-CBC
```

### IPsec/VPN Falla al Negociar

```
Causa probable:
  - Grupo DH del otro extremo no está en la lista 'group'
  - Protocolo IKEv1 bloqueado

Diagnóstico:
  cat /etc/crypto-policies/back-ends/libreswan.config
  journalctl -u ipsec | grep -i "no proposal"

Corrección:
  group = +FFDHE-1024   # Si el otro extremo usa DH 1024
  protocol@IKE = IKEv1 IKEv2+  # Si el otro extremo usa IKEv1
```

---

## I.25 Matriz Resumen: Parámetro × Back-end

| Parámetro | OpenSSL | GnuTLS | NSS | OpenSSH | libssh | Kerberos | Libreswan | BIND | Java |
|-----------|:-------:|:------:|:---:|:-------:|:------:|:--------:|:---------:|:----:|:----:|
| `cipher` | Sí | Sí | Sí | Sí | Sí | Sí | Sí | - | Sí |
| `mac` | Parcial | Parcial | - | Sí | Sí | - | - | - | - |
| `hash` | Sí | Sí | Sí | - | - | - | Sí | Sí | Sí |
| `sign` | Sí | Sí | Sí | Sí | Sí | - | Sí | Sí | Sí |
| `key_exchange` | Sí | Sí | Sí | Sí | Sí | - | **No** | - | Sí |
| `group` | Sí | Sí | Sí | Sí | Sí | - | Sí | - | Sí |
| `protocol` | Sí | Sí | Sí | - | - | - | Sí | - | Sí |
| `min_rsa_size` | SECLEVEL | Profile | Sí | - | - | - | - | - | Sí |
| `min_dh_size` | SECLEVEL | Profile | Sí | - | - | - | - | - | Sí |
| `min_dsa_size` | SECLEVEL | Profile | Sí | - | - | - | - | - | Sí |
| `min_ec_size` | - | - | - | - | - | - | - | - | **Sí** |
| `sha1_in_certs` | - | **Sí** | - | - | - | - | - | - | - |
| `arbitrary_dh_groups` | Sí | Sí | - | - | - | - | - | - | - |
| `ssh_certs` | - | - | - | Sí | - | - | - | - | - |
| `etm` | - | - | - | Sí | Sí | - | - | - | - |
| `__ems` | Sí | Sí | - | - | - | - | - | - | - |
| `__openssl_block_sha1_signatures` | Sí | - | - | - | - | - | - | - | - |

Leyenda: **Sí** = totalmente implementado, **Parcial** = implementación indirecta o limitada, **No** = explícitamente no afecta, **-** = no aplicable.

**Nota:** Los parámetros con prefijo `__` son internos y no están documentados públicamente. Ver sección I.14 para detalles.

---

## I.26 Recomendaciones de Arquitectura

### Cuándo Usar Cada Enfoque

| Necesidad | Enfoque | Motivo |
|-------------|-----------|--------|
| Ajuste fino sobre política existente | Subpolítica `.pmod` sobre `DEFAULT` | Evoluciona con actualizaciones |
| Control total | Política `.pol` personalizada | Ninguna evolución automática — responsabilidad del admin |
| Override de una sola aplicación | `local.d/` o configuración explícita en la app | No afecta al resto del sistema |
| Compatibilidad temporal | `LEGACY` por tiempo limitado | Riesgo de seguridad — documentar y planificar salida |
| Conformidad regulatoria | `FIPS` + subpolítica si es necesario | Automatizado por `fips-mode-setup` |

### Flujo de Decisión para Política Personalizada

```
¿Necesito cambiar configuraciones criptográficas?
    │
    ├─ ¿Solo una aplicación específica?
    │   └─ Sí → Configurar directamente en la app O usar local.d/
    │
    ├─ ¿Quiero deshabilitar algo system-wide?
    │   └─ Sí → Crear .pmod con directivas '-'
    │           Aplicar con DEFAULT:MY-MODULE
    │
    ├─ ¿Quiero habilitar algo que DEFAULT bloquea?
    │   └─ Sí → Crear .pmod con directivas '+'
    │           Aplicar con DEFAULT:MY-MODULE
    │           ⚠️ Documentar por qué es necesario
    │
    ├─ ¿Quiero control absoluto de todo?
    │   └─ Sí → Crear .pol completa (copiar de DEFAULT.pol)
    │           ⚠️ Responsable del mantenimiento continuo
    │
    └─ ¿Ninguna de las anteriores?
        └─ Usar DEFAULT y no tocar nada
```

---

## I.27 Referencia de Archivos y Comandos

### Comandos Esenciales

```bash
# Ver política activa
update-crypto-policies --show

# Cambiar política
sudo update-crypto-policies --set <POLÍTICA>[:MÓDULO1][:MÓDULO2]

# Listar políticas base disponibles
ls /usr/share/crypto-policies/policies/*.pol

# Listar subpolíticas disponibles
ls /usr/share/crypto-policies/policies/modules/*.pmod

# Listar subpolíticas locales
ls /etc/crypto-policies/policies/modules/*.pmod 2>/dev/null

# Ver política efectiva (expandida)
cat /etc/crypto-policies/state/CURRENT.pol

# Ver back-end de una biblioteca específica
cat /etc/crypto-policies/back-ends/<backend>.config

# Verificar si cambió recientemente
stat /etc/crypto-policies/config
```

### Resumen de Directorios

| Directorio | Propósito | Quién Gestiona |
|-----------|-----------|---------------|
| `/usr/share/crypto-policies/policies/` | Políticas base del paquete RPM | Paquete `crypto-policies` |
| `/usr/share/crypto-policies/policies/modules/` | Subpolíticas del paquete RPM | Paquete `crypto-policies` |
| `/etc/crypto-policies/policies/` | Políticas personalizadas locales | Administrador |
| `/etc/crypto-policies/policies/modules/` | Subpolíticas personalizadas locales | Administrador |
| `/etc/crypto-policies/back-ends/` | Configs generadas para cada biblioteca | `update-crypto-policies` |
| `/etc/crypto-policies/local.d/` | Overrides extras por back-end | Administrador |
| `/etc/crypto-policies/state/` | Estado actual (enlace simbólico, política expandida) | `update-crypto-policies` |
| `/etc/crypto-policies/config` | Nombre textual de la política activa | `update-crypto-policies` |

---

## I.28 Fuentes y Referencias

### Documentación

- **Man page oficial:** `man 7 crypto-policies` — fuente primaria y canónica para todos los parámetros, ámbitos y comportamientos documentados en este apéndice.
- **Man page:** `man 8 update-crypto-policies` — uso del comando.
- **Documentación de políticas en disco:** `/usr/share/doc/crypto-policies/`
- **Red Hat Developer:** [Enhance security with system-wide crypto policies in RHEL 9](https://developers.redhat.com/articles/2024/10/09/enhance-security-system-wide-crypto-policies-rhel-9)
- **FOSDEM 2020:** [Custom crypto policies](https://archive.fosdem.org/2020/schedule/event/security_custom_crypto_policies/) — presentación del mantenedor original, Tomáš Mráz.
- **Red Hat Knowledge Base:** [Article 3642912](https://access.redhat.com/articles/3642912) — referencia para crypto-policies.
- **RFC 7457:** Summarizing Known Attacks on Transport Layer Security (TLS) — motivación para la obsolescencia de algoritmos.
- **RFC 7627:** Transport Layer Security (TLS) Session Hash and Extended Master Secret Extension.
- **RFC 9980:** Post-Quantum Public Key Algorithm Extension for the OpenPGP Standard (ML-DSA, SLH-DSA).

### Código Fuente (Repositorio Upstream)

- **Repositorio principal:** [gitlab.com/redhat-crypto/fedora-crypto-policies](https://gitlab.com/redhat-crypto/fedora-crypto-policies) (branch `master`)
- **Motor de parsing:** [`python/cryptopolicies/cryptopolicies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/cryptopolicies.py) — Clases `UnscopedCryptoPolicy`, `ScopedPolicy`, `ScopeSelector`, enum `Operation`, funciones `parse_line`, `parse_rhs`, `preprocess_text`.
- **Listas de algoritmos:** [`python/cryptopolicies/alg_lists.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/cryptopolicies/alg_lists.py) — `ALL_CIPHERS`, `ALL_MACS`, `ALL_HASHES`, `ALL_GROUPS`, `ALL_SIGN`, `ALL_KEY_EXCHANGES`, `ALL_PROTOCOLS`, `EXPERIMENTAL_GROUPS`, `EXPERIMENTAL_SIGN`.
- **Script principal:** [`python/update-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/update-crypto-policies.py) — Lógica de `--set`, `--show`, `--is-applied`, `--check`, FIPS auto-bind-mount, escritura atómica, symlinks.
- **Build de políticas:** [`python/build-crypto-policies.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/build-crypto-policies.py) — Genera todas las políticas para todos los back-ends (usado en el build del RPM).
- **Generador OpenSSL:** [`python/policygenerators/openssl.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssl.py) — `OpenSSLGenerator`, `OpenSSLFIPSGenerator`.
- **Generador GnuTLS:** [`python/policygenerators/gnutls.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/gnutls.py) — `GnuTLSGenerator` (modo allowlist).
- **Generador OpenSSH:** [`python/policygenerators/openssh.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/openssh.py) — `OpenSSHClientGenerator`, `OpenSSHServerGenerator`.
- **Clase base de los generadores:** [`python/policygenerators/configgenerator.py`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/python/policygenerators/configgenerator.py) — `ConfigGenerator`.
- **Políticas base:** [`policies/DEFAULT.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/DEFAULT.pol), [`policies/FUTURE.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FUTURE.pol), [`policies/LEGACY.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/LEGACY.pol), [`policies/FIPS.pol`](https://gitlab.com/redhat-crypto/fedora-crypto-policies/-/blob/master/policies/FIPS.pol).

### Licencia

El proyecto `fedora-crypto-policies` se distribuye bajo la licencia **LGPL-2.1-or-later**. Copyright © 2019 Red Hat, Inc. — Tomáš Mráz y colaboradores.

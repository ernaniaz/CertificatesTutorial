# Apéndice J: Guía Completa de Primitivas Criptográficas

> **Para quién es este apéndice:** Este apéndice es una referencia para quienes necesitan entender qué son y para qué sirven los algoritmos y mecanismos criptográficos mencionados a lo largo de este tutorial. El lenguaje es deliberadamente accesible — el objetivo es que un administrador de sistemas sin formación en criptografía pueda distinguir entre los diferentes tipos de recurso y tomar decisiones informadas.

---

## J.1 Cómo Leer Este Apéndice

La criptografía moderna se construye a partir de piezas menores llamadas **primitivas**. Cada primitiva resuelve un problema específico:

| Problema | Primitiva | Analogía del Mundo Físico |
|----------|-----------|---------------------------|
| "Nadie puede leer esto" | **Cifrado simétrico** | Caja fuerte con una llave única |
| "Nadie puede leer esto, pero no conozco al destinatario" | **Cifrado asimétrico** | Buzón: cualquiera deposita, solo el dueño abre |
| "Esto no ha sido alterado" | **Hash** | Huella digital de un documento |
| "Esto no ha sido alterado Y viene de quien dice" | **MAC** | Sello de seguridad con número de serie |
| "Garantizo que escribí esto" | **Firma digital** | Firma notarial con reconocimiento |
| "Acordemos un secreto sin que nadie escuche" | **Intercambio de clave** | Dos personas acuerdan un color mezclando pinturas en público |
| "Derivemos varios secretos de uno solo" | **KDF** | Máquina de hacer copias de llave a partir de una llave maestra |

Cada sección a continuación explica una categoría, lista los algoritmos más relevantes e indica su estado actual (seguro, legado, roto).

---

## J.2 Cifrados Simétricos — "La Misma Llave Cierra y Abre"

### El Concepto

Un cifrado simétrico usa **la misma clave** para cifrar y descifrar. Es el tipo más rápido de criptografía y protege la inmensa mayoría de los datos en tránsito (TLS, SSH, VPN) y en reposo (LUKS, BitLocker).

El desafío fundamental: ¿cómo entregar la clave al destinatario sin que un atacante la intercepte? Este problema se resuelve mediante el intercambio de clave (sección J.6).

### Cifrados de Bloque vs Cifrados de Flujo

Los cifrados simétricos se dividen en dos tipos:

- **Cifrado de bloque:** Procesa los datos en bloques de tamaño fijo (ej: 128 bits). Si el mensaje es mayor que un bloque, se necesita un **modo de operación** para encadenar los bloques. Ejemplos: AES, Camellia, 3DES.
- **Cifrado de flujo:** Genera un flujo continuo de bits pseudoaleatorios (keystream) que se combina con los datos mediante XOR, bit a bit. No necesita modo de operación. Ejemplos: ChaCha20, RC4.

### Algoritmos Simétricos

#### AES (Advanced Encryption Standard)

- **Qué es:** Estándar mundial de cifrado simétrico desde 2001, seleccionado por el NIST en competición pública. Nombre original: Rijndael.
- **Tamaños de clave:** 128, 192 o 256 bits.
- **Tamaño de bloque:** 128 bits.
- **Estado:** Seguro. Ningún ataque práctico conocido contra ninguna variante. AES-256 se considera resistente a computadores cuánticos (el ataque de Grover reduce la seguridad efectiva a ~128 bits, aún suficiente).
- **Dónde aparece:** Prácticamente en todas partes — TLS, SSH, VPN, cifrado de disco, Wi-Fi (WPA2/WPA3), mensajeros (Signal, WhatsApp).
- **Ventaja especial:** Los procesadores modernos (Intel, AMD, ARM) poseen instrucciones de hardware dedicadas (AES-NI) que hacen AES extremadamente rápido — órdenes de magnitud más rápido que la implementación en software.

#### ChaCha20

- **Qué es:** Cifrado de flujo creado por Daniel J. Bernstein en 2008. Variante mejorada de Salsa20.
- **Tamaño de clave:** 256 bits.
- **Estado:** Seguro. Adoptado por Google, Cloudflare y otros como alternativa a AES.
- **Dónde aparece:** TLS 1.3, SSH, WireGuard, protocolos de Google (QUIC).
- **Por qué existe si ya tenemos AES:** ChaCha20 es más rápido que AES en dispositivos **sin** aceleración de hardware (smartphones ARM antiguos, dispositivos IoT). En servidores con AES-NI, AES es más rápido.

#### Camellia

- **Qué es:** Cifrado de bloque desarrollado por Mitsubishi Electric y NTT (Japón) en 2000.
- **Tamaños de clave:** 128, 192, 256 bits.
- **Tamaño de bloque:** 128 bits.
- **Estado:** Seguro, pero poco utilizado fuera de Japón. Aprobado por NESSIE, CRYPTREC e ISO/IEC.
- **Dónde aparece:** Algunas implementaciones TLS, especialmente en entornos regulatorios japoneses.
- **En la práctica:** Raramente necesario. Las crypto-policies de RHEL incluyen Camellia en DEFAULT pero lo excluyen de TLS.

#### 3DES (Triple DES)

- **Qué es:** Aplicación triple del DES original (3 × DES con 2 o 3 claves diferentes).
- **Tamaño de clave efectivo:** 112 bits (con 3 claves) u 80 bits (con 2 claves).
- **Tamaño de bloque:** 64 bits.
- **Estado:** **Legado/Obsoleto.** El bloque de 64 bits lo hace vulnerable al ataque Sweet32 — después de ~32 GB de datos cifrados con la misma clave, patrones repetitivos filtran información. El NIST prohibió 3DES después de 2023.
- **Dónde aparece:** Sistemas legados, PKCS#12 antiguo, S/MIME antiguo, Active Directory muy antiguo.
- **Recomendación:** Migrar a AES lo antes posible. En las crypto-policies de RHEL, 3DES aparece solo en la política LEGACY.

#### DES (Data Encryption Standard)

- **Qué es:** Cifrado de bloque de 1977, primer estándar de cifrado del gobierno de EE.UU.
- **Tamaño de clave:** 56 bits.
- **Tamaño de bloque:** 64 bits.
- **Estado:** **Roto.** Una clave DES puede ser forzada en horas con hardware moderno. El proyecto DESCHALL rompió DES en 1997.
- **Dónde aparece:** No debería aparecer en ningún lugar. Eliminado de las bibliotecas criptográficas modernas.

#### RC4 (Rivest Cipher 4)

- **Qué es:** Cifrado de flujo creado por Ron Rivest en 1987. Simple y rápido.
- **Tamaño de clave:** Variable (40–256 bits).
- **Estado:** **Roto.** Múltiples sesgos estadísticos en el keystream permiten recuperar texto claro. Prohibido en TLS desde el RFC 7465 (2015).
- **Dónde aparece:** No debería. WEP (Wi-Fi antiguo) usaba RC4 y fue roto por su causa.

#### IDEA (International Data Encryption Algorithm)

- **Qué es:** Cifrado de bloque de 1991, usado en el PGP original.
- **Tamaño de clave:** 128 bits.
- **Tamaño de bloque:** 64 bits.
- **Estado:** Obsoleto. Patente expirada. Bloque de 64 bits es insuficiente.
- **Dónde aparece:** Solo en mensajes PGP muy antiguos.

#### SEED

- **Qué es:** Cifrado de bloque estándar surcoreano (1998).
- **Tamaño de clave:** 128 bits.
- **Tamaño de bloque:** 128 bits.
- **Estado:** Seguro pero sin adopción fuera de Corea del Sur. Irrelevante en la práctica.

#### Blowfish / Twofish

- **Qué son:** Cifrados de bloque creados por Bruce Schneier. Blowfish (1993, bloque de 64 bits) es el predecesor; Twofish (1998, bloque de 128 bits) fue finalista en la competición AES.
- **Estado:** Blowfish es legado (bloque de 64 bits). Twofish es seguro pero perdió la competición AES y tiene poca adopción.
- **Dónde aparece:** Blowfish sobrevive en `bcrypt` (hashing de contraseñas). Twofish aparece en algunas implementaciones de cifrado de disco.

### Modos de Operación — Cómo Encadenar Bloques

Un cifrado de bloque como AES procesa exactamente 128 bits cada vez. Para cifrar un mensaje mayor, se necesita un **modo de operación** que define cómo se encadenan los bloques. La elección del modo es tan importante como el cifrado.

#### ECB (Electronic Codebook)

- **Cómo funciona:** Cada bloque se cifra independientemente con la misma clave.
- **Estado:** **Inseguro.** Bloques idénticos de texto claro producen bloques idénticos de texto cifrado, revelando patrones. El famoso "pingüino ECB" demuestra esto visualmente.
- **Uso correcto:** Ninguno para datos generales. Solo para cifrar valores aleatorios de exactamente un bloque (ej: una clave).

#### CBC (Cipher Block Chaining)

- **Cómo funciona:** Cada bloque de texto claro se XORea con el bloque cifrado anterior antes de cifrarse. El primer bloque usa un Vector de Inicialización (IV) aleatorio.
- **Estado:** Seguro si se implementa correctamente, pero vulnerable a ataques de padding oracle (POODLE, Lucky13) cuando el padding no se verifica en tiempo constante.
- **Dónde aparece:** TLS 1.2 (en desuso), SSH (obsoleto en versiones recientes), PKCS#12, S/MIME.
- **En las crypto-policies:** DEFAULT deshabilita CBC en SSH (`cipher@SSH = -*-CBC`) por vulnerabilidad a plaintext recovery.

#### CTR (Counter)

- **Cómo funciona:** Transforma el cifrado de bloque en cifrado de flujo — cifra un contador incrementado en cada bloque y hace XOR con el texto claro.
- **Estado:** Seguro. Permite paralelismo y acceso aleatorio.
- **Dónde aparece:** SSH (AES-CTR es el modo predeterminado), Kerberos.
- **Precaución:** El contador (nonce + counter) nunca puede repetirse con la misma clave.

#### GCM (Galois/Counter Mode)

- **Cómo funciona:** Combina CTR (para confidencialidad) con multiplicación en campo de Galois (para integridad). Produce una etiqueta de autenticación junto con el texto cifrado.
- **Estado:** Seguro y eficiente. Es un modo **AEAD** (Authenticated Encryption with Associated Data) — ver sección J.5.
- **Dónde aparece:** TLS 1.2 y 1.3 (modo preferido), SSH, IPsec.
- **Ventaja:** Cifra y autentica en una sola operación. Acelerado por hardware (CLMUL/PCLMULQDQ).
- **En las crypto-policies:** AES-256-GCM es el primer cipher listado en todas las políticas.

#### CCM (Counter with CBC-MAC)

- **Cómo funciona:** Combina CTR (confidencialidad) con CBC-MAC (integridad). Modo AEAD.
- **Estado:** Seguro pero más lento que GCM (dos pasadas sobre los datos en vez de una).
- **Dónde aparece:** TLS 1.2/1.3, Wi-Fi (WPA2/CCMP), Bluetooth.

#### OCB (Offset Codebook Mode)

- **Cómo funciona:** Modo AEAD de pasada única — más rápido que GCM y CCM.
- **Estado:** Seguro. Estaba patentado hasta 2021, lo que impidió su adopción.
- **Dónde aparece:** OpenPGP (Sequoia), limitado en TLS por la patente histórica.

#### EAX

- **Cómo funciona:** Modo AEAD basado en CTR + OMAC. No patentado.
- **Estado:** Seguro. Similar a CCM pero más simple de implementar correctamente.
- **Dónde aparece:** OpenPGP (Sequoia).

#### CFB (Cipher Feedback)

- **Cómo funciona:** Similar a CBC pero opera como cifrado de flujo — permite procesar datos menores que un bloque.
- **Estado:** Seguro pero sin ventaja sobre CTR o GCM. No proporciona autenticación.
- **Dónde aparece:** OpenPGP (modo histórico obligatorio), GOST.

---

## J.3 Funciones de Hash — "La Huella Digital de los Datos"

### El Concepto

Una función de hash toma datos de cualquier tamaño y produce una salida de tamaño fijo (el **digest** o **resumen**). Las propiedades fundamentales:

1. **Determinista:** La misma entrada siempre produce la misma salida.
2. **Rápida:** Calcular el hash es computacionalmente barato.
3. **Irreversible (resistencia a preimagen):** Dado un hash, es computacionalmente inviable encontrar la entrada que lo produjo.
4. **Resistencia a colisión:** Es computacionalmente inviable encontrar dos entradas diferentes que produzcan el mismo hash.
5. **Efecto avalancha:** Un cambio mínimo en la entrada (un bit) altera drásticamente la salida.

**No confundir:** Los hashes **no cifran** — son operaciones de una sola vía. No existe "descifrar un hash". Si alguien dice "descifrar el MD5", está hablando de ataque de fuerza bruta o rainbow tables, no de reversión.

### Algoritmos de Hash

#### MD5 (Message Digest 5)

- **Creador:** Ron Rivest, 1991.
- **Tamaño de salida:** 128 bits (32 caracteres hexadecimales).
- **Estado:** **Roto para integridad criptográfica.** Las colisiones pueden generarse en segundos. En 2008, investigadores crearon un certificado CA falso usando una colisión MD5. El malware "Flame" explotaba colisiones MD5 en certificados de Microsoft.
- **Aún aceptable para:** Checksums de integridad no criptográfica (verificar si una descarga se corrompió, siempre que el atacante no controle la fuente). Nunca para firmas o autenticación.
- **En las crypto-policies:** Excluido de todas las políticas, incluyendo LEGACY.

#### SHA-1 (Secure Hash Algorithm 1)

- **Creador:** NSA, 1995.
- **Tamaño de salida:** 160 bits (40 caracteres hexadecimales).
- **Estado:** **Roto.** El proyecto SHAttered (Google, 2017) demostró una colisión práctica — dos PDFs diferentes con el mismo SHA-1. El coste era ~$110.000 en computación en la nube; hoy es menor. En 2020, se demostraron colisiones chosen-prefix por ~$45.000.
- **Aún aceptable para:** HMAC-SHA1 (donde la clave secreta impide ataques de colisión — ver sección J.4). Git usa SHA-1 pero está migrando a SHA-256.
- **En las crypto-policies:** DEFAULT permite SHA-1 solo en HMAC y DNSSec; FUTURE elimina SHA-1 completamente; LEGACY permite todo.

#### Familia SHA-2

Creada por la NSA, publicada entre 2001 y 2012. **Cuatro variantes** con seguridad proporcional al tamaño de la salida:

| Variante | Salida | Seguridad contra colisión | Notas |
|----------|--------|---------------------------|-------|
| **SHA-224** | 224 bits | 112 bits | Versión truncada de SHA-256. Raramente usada. |
| **SHA-256** | 256 bits | 128 bits | **El estándar actual.** Usado en TLS, certificados X.509, Bitcoin, firmas de software. |
| **SHA-384** | 384 bits | 192 bits | Versión truncada de SHA-512. Usado en TLS 1.3, certificados de alta seguridad. |
| **SHA-512** | 512 bits | 256 bits | Máxima seguridad. Más rápido que SHA-256 en procesadores de 64 bits. |

- **Estado:** Seguro. Ningún ataque práctico conocido contra ninguna variante.
- **Dónde aparece:** Certificados X.509 (la gran mayoría usa SHA-256), TLS, SSH, firmas de paquetes, blockchain, verificación de integridad de archivos.
- **En las crypto-policies:** SHA-256, SHA-384 y SHA-512 están habilitados en todas las políticas.

#### Familia SHA-3

Creada por Guido Bertoni, Joan Daemen, Michaël Peeters y Gilles Van Assche. Ganó la competición NIST en 2012. Nombre original: Keccak. Usa una construcción interna completamente diferente de SHA-2 (esponja en vez de Merkle-Damgård).

| Variante | Salida | Seguridad contra colisión |
|----------|--------|---------------------------|
| **SHA3-224** | 224 bits | 112 bits |
| **SHA3-256** | 256 bits | 128 bits |
| **SHA3-384** | 384 bits | 192 bits |
| **SHA3-512** | 512 bits | 256 bits |

- **Estado:** Seguro. Fundamentalmente diferente de SHA-2, sirviendo como "alternativa segura" en caso de que SHA-2 sea comprometido.
- **Por qué existen si SHA-2 es seguro:** Diversidad algorítmica. SHA-3 y SHA-2 usan construcciones matemáticas completamente diferentes. Si un ataque teórico compromete la familia SHA-2, SHA-3 probablemente no se vería afectado. Es la misma lógica de tener ChaCha20 como alternativa a AES.
- **En las crypto-policies:** Habilitados en DEFAULT, FUTURE y FIPS.

#### SHAKE-128 / SHAKE-256

- **Qué son:** Funciones de hash de salida **variable** (XOF — Extendable Output Function) basadas en la construcción Keccak/SHA-3. En vez de producir un digest de tamaño fijo, pueden producir salidas de cualquier tamaño.
- **Uso:** Derivación de clave, algoritmos postcuánticos (SLH-DSA usa SHAKE), protocolos que necesitan cantidades arbitrarias de material pseudoaleatorio.

#### BLAKE2 / BLAKE3

- **Qué son:** Funciones de hash alternativas de alto rendimiento. BLAKE2 (2012) es más rápido que MD5 manteniendo seguridad equivalente a SHA-3. BLAKE3 (2020) es aún más rápido y paralelizable.
- **Estado:** Seguros. Usados en WireGuard, Argon2, varios sistemas de archivos, pero no estandarizados por el NIST.
- **En las crypto-policies:** No soportados por las crypto-policies de RHEL (no se usan en TLS/SSH/IPsec).

#### RIPEMD-160

- **Qué es:** Función de hash europea (1996), salida de 160 bits.
- **Estado:** Seguro pero sin adopción significativa fuera de Bitcoin (usado en direcciones).
- **En las crypto-policies:** No soportado.

---

## J.4 MACs — "Sello de Autenticidad"

### El Concepto

Un MAC (Message Authentication Code) garantiza dos cosas simultáneamente:

1. **Integridad:** El mensaje no fue alterado en tránsito.
2. **Autenticidad:** El mensaje vino de alguien que posee la clave secreta.

La diferencia crucial respecto a un hash simple: el MAC usa una **clave secreta**. Sin la clave, no es posible generar ni verificar el MAC. Un hash simple (SHA-256) demuestra que los datos no fueron corrompidos, pero cualquier persona puede recalcularlo — no demuestra el origen.

### Algoritmos MAC

#### HMAC (Hash-based MAC)

- **Qué es:** Construcción genérica que transforma cualquier función de hash en un MAC. HMAC-SHA256 = HMAC usando SHA-256 internamente.
- **Cómo funciona:** `HMAC(clave, mensaje) = Hash((clave ⊕ opad) || Hash((clave ⊕ ipad) || mensaje))`. Dos rondas de hash con padding especial hacen que el resultado dependa de la clave de manera criptográficamente segura.
- **Estado:** Seguro. La seguridad depende del hash subyacente, pero incluso HMAC-SHA1 permanece seguro — los ataques de colisión contra SHA-1 **no** comprometen HMAC-SHA1, porque el atacante no controla la clave.
- **Variantes comunes:**
  - **HMAC-SHA2-256:** Estándar en TLS y SSH.
  - **HMAC-SHA2-384 / HMAC-SHA2-512:** Alta seguridad.
  - **HMAC-SHA1:** Legado pero seguro como MAC. DEFAULT de RHEL lo permite en TLS y SSH.
  - **HMAC-MD5:** Inseguro. Solo en LEGACY.
- **Dónde aparece:** TLS 1.2 (para ciphersuites no-AEAD), SSH, IPsec, APIs de autenticación (JWT, OAuth), verificación de integridad de paquetes.

#### CMAC (Cipher-based MAC)

- **Qué es:** MAC basado en cifrado de bloque (generalmente AES) en vez de hash.
- **Dónde aparece:** Wi-Fi (WPA2), Bluetooth, Kerberos.
- **Estado:** Seguro. Alternativa a HMAC cuando AES está disponible en hardware pero hash no.

#### Poly1305

- **Qué es:** MAC de alta velocidad creado por Daniel J. Bernstein. Usa aritmética modular en vez de hash o cifrado de bloque.
- **Estado:** Seguro. Diseñado para usarse **una vez por clave** — cada mensaje recibe una clave diferente (derivada de ChaCha20).
- **Dónde aparece:** Siempre combinado con ChaCha20 como ChaCha20-Poly1305 (modo AEAD). Nunca usado solo en protocolos modernos.

#### UMAC / UMAC-128

- **Qué es:** MAC basado en hashing universal, extremadamente rápido.
- **Dónde aparece:** SSH (específicamente `umac-64@openssh.com` y `umac-128-etm@openssh.com`).
- **Estado:** Seguro. El `umac-64` tiene etiqueta de 64 bits (adecuado solo para SSH donde el número de paquetes es limitado).

#### GMAC (Galois MAC)

- **Qué es:** La parte de autenticación del modo GCM, usada cuando no hay datos que cifrar (solo autenticar).
- **Dónde aparece:** Implícitamente en AES-GCM. También usado en MACsec (cifrado de capa 2 en redes Ethernet).

### Encrypt-then-MAC vs Encrypt-and-MAC vs MAC-then-Encrypt

Cuando un cifrado CBC (que no es AEAD) se usa con HMAC separado, el **orden** de las operaciones importa para la seguridad:

| Enfoque | Descripción | Seguridad |
|---------|-------------|-----------|
| **Encrypt-then-MAC (EtM)** | Cifrar, después calcular MAC del texto cifrado | **Seguro.** El MAC protege el texto cifrado — cualquier manipulación se detecta antes del descifrado. |
| **MAC-then-Encrypt (MtE)** | Calcular MAC del texto claro, después cifrar ambos | **Vulnerable.** TLS 1.2 con CBC usa este enfoque y es vulnerable a padding oracle (Lucky13, POODLE). |
| **Encrypt-and-MAC (E&M)** | Cifrar el texto claro y calcular MAC del texto claro por separado | **Vulnerable.** El MAC puede filtrar información sobre el texto claro. SSH usaba este enfoque. |

El parámetro `etm` de las crypto-policies de RHEL controla exactamente esto para SSH: `DISABLE_NON_ETM` fuerza Encrypt-then-MAC, `DISABLE_ETM` fuerza el modo antiguo (no recomendado).

---

## J.5 AEAD — "Cifrado y Autenticación Juntos"

### El Concepto

AEAD (Authenticated Encryption with Associated Data) combina **confidencialidad** e **integridad** en una sola operación atómica. En vez de usar un cifrado (AES-CBC) + un MAC (HMAC-SHA256) por separado — con todos los riesgos de combinarlos incorrectamente — un modo AEAD lo hace todo de una vez.

"Associated Data" son datos que necesitan ser **autenticados pero no cifrados** — por ejemplo, cabeceras de protocolo que necesitan ser legibles pero no pueden ser manipuladas.

**TLS 1.3 acepta SOLO ciphersuites AEAD.** Los modos no-AEAD (CBC + HMAC) fueron prohibidos.

### Algoritmos AEAD

| Algoritmo | Cifrado + Autenticación | Dónde Aparece | Notas |
|-----------|-------------------------|---------------|-------|
| **AES-256-GCM** | AES-256 (CTR) + GMAC | TLS, SSH, IPsec | Estándar dominante. Rápido con hardware AES-NI + CLMUL. |
| **AES-128-GCM** | AES-128 (CTR) + GMAC | TLS, SSH, IPsec | Seguro y más rápido que AES-256-GCM. |
| **ChaCha20-Poly1305** | ChaCha20 + Poly1305 | TLS, SSH, WireGuard | Alternativa sin dependencia de hardware AES. |
| **AES-256-CCM** | AES-256 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Más lento que GCM (dos pasadas). |
| **AES-128-CCM** | AES-128 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Ídem. |
| **AES-256-OCB** | AES-256 + Offset Codebook | OpenPGP | Pasada única (más rápido que GCM). |
| **AES-256-EAX** | AES-256 (CTR) + OMAC | OpenPGP | Sin patentes, simple de implementar. |

En la práctica, los tres AEADs dominantes son: **AES-GCM** (con hardware), **ChaCha20-Poly1305** (sin hardware) y **AES-CCM** (en protocolos que lo exigen).

---

## J.6 Criptografía Asimétrica — "Dos Claves: Una Pública, Una Privada"

### El Concepto

En la criptografía asimétrica (o de clave pública), cada participante posee un **par de claves**:

- **Clave pública:** Puede distribuirse libremente. Usada para cifrar datos destinados al propietario y para verificar firmas.
- **Clave privada:** Debe mantenerse en secreto absoluto. Usada para descifrar datos y para crear firmas.

La relación matemática entre las dos claves garantiza que los datos cifrados con la clave pública **solo pueden** ser descifrados por la clave privada correspondiente, y viceversa.

La criptografía asimétrica es **mucho más lenta** que la simétrica (cientos a miles de veces). Por eso, en la práctica, se usa solo para:
1. **Intercambiar claves simétricas** de sesión (TLS handshake).
2. **Firmar** datos (certificados, paquetes de software).
3. **Autenticar** identidades.

El cifrado masivo de datos siempre usa cifrados simétricos.

### Algoritmos Asimétricos

#### RSA (Rivest-Shamir-Adleman)

- **Qué es:** Primer sistema práctico de criptografía de clave pública (1977). Basado en la dificultad de factorizar el producto de dos números primos grandes.
- **Tamaños de clave comunes:** 2048, 3072, 4096 bits.
- **Uso:** Firma (certificados X.509, paquetes), intercambio de clave (TLS 1.2 — obsoleto), autenticación.
- **Estado:** Seguro con claves ≥ 2048 bits. Las claves de 1024 bits se consideran inseguras desde ~2010. Vulnerable a computadores cuánticos (algoritmo de Shor).
- **En las crypto-policies:** DEFAULT exige `min_rsa_size = 2048`, FUTURE exige 3072.

**RSA-PKCS#1 v1.5 vs RSA-PSS:**

| Esquema | Descripción | Estado |
|---------|-------------|--------|
| **RSA-PKCS#1 v1.5** | Esquema de padding original (1998). Determinístico para firmas. | Seguro para firmas, pero **inseguro para cifrado** (ataque Bleichenbacher). TLS lo mantiene por compatibilidad pero está siendo eliminado. |
| **RSA-PSS** | Probabilistic Signature Scheme (2003). El padding aleatorio hace cada firma diferente incluso para el mismo mensaje. | **Recomendado.** Prueba de seguridad formal. TLS 1.3 exige PSS para firmas RSA. |
| **RSA-OAEP** | Optimal Asymmetric Encryption Padding. Para cifrado (no firma). | Seguro. Sustituto de PKCS#1 v1.5 para cifrado. |

#### DSA (Digital Signature Algorithm)

- **Qué es:** Algoritmo de firma basado en el problema del logaritmo discreto. Estándar NIST (FIPS 186, 1994).
- **Tamaños de clave:** 1024, 2048, 3072 bits.
- **Estado:** **Obsoleto.** El NIST ya no recomienda DSA para nuevas implementaciones (FIPS 186-5, 2023). Vulnerable a computadores cuánticos.
- **En las crypto-policies:** DEFAULT no incluye DSA en `sign`. LEGACY incluye DSA-SHA1 y variantes.

#### Diffie-Hellman (DH)

- **Qué es:** Primer protocolo de intercambio de clave de clave pública (1976). Permite que dos partes acuerden un secreto compartido sobre un canal inseguro.
- **Cómo funciona (simplificado):** Alice y Bob eligen números grandes públicos (p, g). Cada uno genera un secreto privado, calcula un valor público derivado e intercambia. Ambos pueden entonces calcular el mismo secreto compartido, pero un observador no puede.
- **Variantes:**
  - **DH clásico (FFDHE):** Usa aritmética modular en campos finitos. Grupos estandarizados: FFDHE-2048, FFDHE-3072, FFDHE-4096, etc. (RFC 7919).
  - **ECDH (Elliptic Curve DH):** Usa curvas elípticas. Mucho más eficiente — una curva de 256 bits ofrece seguridad equivalente a DH de 3072 bits.
- **Estado:** Seguro con parámetros adecuados. DH con 1024 bits es vulnerable al ataque Logjam (2015). Vulnerable a computadores cuánticos.
- **En las crypto-policies:** DEFAULT exige `min_dh_size = 2048`. FUTURE exige 3072.

**DHE (Diffie-Hellman Ephemeral):** Versión en la que se generan claves DH nuevas para cada sesión, proporcionando **forward secrecy** — incluso si la clave privada a largo plazo del servidor se compromete en el futuro, las sesiones pasadas permanecen seguras.

#### ECDSA (Elliptic Curve Digital Signature Algorithm)

- **Qué es:** Versión de curva elíptica de DSA. Firmas más pequeñas y rápidas para el mismo nivel de seguridad.
- **Curvas comunes:** P-256 (NIST), P-384, P-521.
- **Estado:** Seguro. Estándar para certificados modernos (especialmente en móvil/IoT por el tamaño menor).
- **Precaución crítica:** ECDSA requiere un nonce aleatorio para cada firma. Si el generador de números aleatorios falla y el nonce se repite, la clave privada es **inmediatamente** recuperable. Esto ocurrió con la PlayStation 3 (2010) y carteras Bitcoin.
- **En las crypto-policies:** ECDSA-SHA2-256/384/512 están incluidos en todas las políticas.

#### EdDSA (Edwards-curve Digital Signature Algorithm)

- **Qué es:** Algoritmo de firma basado en curvas de Edwards torcidas. Creado por Daniel J. Bernstein y colaboradores.
- **Variantes:**
  - **Ed25519:** Usa Curve25519. Clave de 256 bits, ~128 bits de seguridad. Firmas de 512 bits.
  - **Ed448:** Usa curva Goldilocks. Clave de 448 bits, ~224 bits de seguridad. Firmas de 912 bits.
- **Estado:** Seguro. Diseñado para ser resistente a ataques de canal lateral y no depende de nonce aleatorio (usa hash determinístico).
- **Ventaja sobre ECDSA:** Determinístico — no depende de RNG para generar firmas, eliminando la clase de vulnerabilidades de nonce repetido.
- **Dónde aparece:** SSH (clave preferida), TLS 1.3, WireGuard, Signal.
- **En las crypto-policies:** Ed25519 y Ed448 están incluidos en DEFAULT, FUTURE y FIPS.

---

## J.7 Curvas Elípticas — "Más Seguridad con Menos Bits"

### El Concepto

La Criptografía de Curvas Elípticas (ECC) usa las propiedades matemáticas de curvas elípticas sobre campos finitos para crear sistemas criptográficos. La ventaja principal es la **eficiencia**: una clave ECC de 256 bits ofrece seguridad comparable a una clave RSA de 3072 bits.

| Seguridad (bits) | RSA/DH (bits) | ECC (bits) | Factor de reducción |
|-------------------|---------------|------------|---------------------|
| 80 | 1024 | 160 | 6,4× |
| 112 | 2048 | 224 | 9,1× |
| 128 | 3072 | 256 | 12× |
| 192 | 7680 | 384 | 20× |
| 256 | 15360 | 512 | 30× |

### Curvas Comunes

#### Curvas NIST (P-256, P-384, P-521)

- **Qué son:** Curvas estandarizadas por el NIST (FIPS 186-4). Usan la forma corta de Weierstrass.
- **P-256 (secp256r1):** 128 bits de seguridad. La curva más usada en certificados TLS.
- **P-384 (secp384r1):** 192 bits de seguridad. Usada por gobiernos y entornos de alta seguridad.
- **P-521 (secp521r1):** 256 bits de seguridad. Raramente necesaria.
- **Controversia:** Las semillas usadas para generar los parámetros de las curvas NIST nunca fueron completamente explicadas, generando desconfianza de que la NSA pudiera haber elegido parámetros con una puerta trasera. No se ha encontrado ninguna vulnerabilidad, pero la desconfianza motivó la creación de las curvas de Bernstein.

#### Curve25519 / X25519

- **Qué es:** Curva de Montgomery creada por Daniel J. Bernstein (2006). El nombre X25519 se refiere a la función de intercambio de clave; Curve25519 es la curva subyacente.
- **Seguridad:** ~128 bits.
- **Ventajas:** Diseñada para ser resistente a ataques de canal lateral, con implementación de tiempo constante. Parámetros completamente transparentes (el número primo es 2²⁵⁵ − 19, justificando el nombre).
- **Dónde aparece:** TLS 1.3 (grupo preferido), SSH, WireGuard, Signal, QUIC.
- **En las crypto-policies:** Presente en DEFAULT, FUTURE y FIPS (en los grupos).

#### Curve448 / X448

- **Qué es:** Curva "Goldilocks" creada por Mike Hamburg (2014). Versión de alta seguridad de X25519.
- **Seguridad:** ~224 bits.
- **Dónde aparece:** TLS 1.3, SSH.

#### Ed25519 / Ed448

- **Qué son:** Curvas de Edwards usadas para firmas (EdDSA). Ed25519 usa el isomorfismo de Curve25519. Ed448 usa Curve448.
- **Ver sección J.6** para detalles de uso en firmas.

#### Curvas Brainpool

- **Qué son:** Curvas alternativas generadas por el grupo de trabajo ECC Brainpool (consorcio europeo). Parámetros generados de forma verificable a partir de constantes de hash.
- **Variantes:** brainpoolP256r1, brainpoolP384r1, brainpoolP512r1.
- **Dónde aparece:** TLS (europeo), regulaciones BSI (Alemania).
- **En las crypto-policies:** Soportadas por el código fuente pero no incluidas en las políticas predeterminadas de RHEL.

---

## J.8 Intercambio de Clave — "Acordar un Secreto en Público"

### El Concepto

El problema fundamental de la criptografía simétrica es: ¿cómo Alice y Bob comparten la clave sin que un atacante la intercepte? El intercambio de clave resuelve esto permitiendo que dos partes acuerden un secreto compartido sobre un canal público.

### Métodos de Intercambio de Clave

#### ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)

- **Qué es:** Diffie-Hellman sobre curvas elípticas, con claves efímeras (nuevas en cada sesión).
- **Estado:** **Estándar actual.** Forward secrecy. Rápido. Claves pequeñas.
- **Dónde aparece:** TLS 1.2 y 1.3, SSH, IPsec.
- **En las crypto-policies:** Primero o segundo en la lista de `key_exchange` en todas las políticas.

#### DHE (Diffie-Hellman Ephemeral)

- **Qué es:** DH clásico con claves efímeras, usando grupos FFDHE estandarizados (RFC 7919).
- **Estado:** Seguro con grupos ≥ 2048 bits. Más lento que ECDHE.
- **Dónde aparece:** TLS 1.2, SSH, IPsec.
- **En las crypto-policies:** Presente en todas las políticas, con `min_dh_size` controlando el tamaño mínimo.

#### RSA Key Transport (Transporte de Clave RSA)

- **Qué es:** El cliente genera el secreto de sesión, lo cifra con la clave pública RSA del servidor y lo envía.
- **Estado:** **Obsoleto.** Sin forward secrecy — si la clave privada del servidor se compromete, todas las sesiones pasadas pueden ser descifradas. Eliminado de TLS 1.3.
- **En las crypto-policies:** DEFAULT mantiene `RSA` en `key_exchange` por compatibilidad; FUTURE lo elimina.

#### PSK (Pre-Shared Key)

- **Qué es:** Clave previamente compartida entre las partes (configurada manualmente o derivada de una sesión anterior).
- **Variantes:** PSK puro, DHE-PSK (con forward secrecy), ECDHE-PSK.
- **Dónde aparece:** IoT, TLS resumption, VPNs punto a punto.

#### KEM (Key Encapsulation Mechanism)

- **Qué es:** Mecanismo más reciente para intercambio de clave, donde una parte "encapsula" una clave en un ciphertext que solo el destinatario puede "desencapsular". Diferente de DH donde ambos contribuyen.
- **Dónde aparece:** Algoritmos postcuánticos (ML-KEM/Kyber). Ver sección J.10.

---

## J.9 Firmas Digitales — "Notaría Matemática"

### El Concepto

Una firma digital demuestra tres cosas:

1. **Autenticidad:** El mensaje vino del propietario de la clave privada.
2. **Integridad:** El mensaje no fue alterado después de la firma.
3. **No repudio:** El firmante no puede negar haber firmado (porque solo él posee la clave privada).

El proceso:
1. El firmante calcula el hash del mensaje.
2. El hash se "cifra" con la clave privada (en realidad, es una operación matemática específica de firma).
3. Cualquier persona con la clave pública puede verificar la firma.

### Esquemas de Firma en las Crypto-Policies

Las crypto-policies nombran las firmas como `ALGORITMO-HASH`. Ejemplos:

| Nombre en la Política | Significado |
|-----------------------|-------------|
| `RSA-SHA2-256` | Firma RSA (PKCS#1 v1.5) con hash SHA-256 |
| `RSA-PSS-SHA2-256` | Firma RSA-PSS con hash SHA-256 |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS con clave en formato RSAE (retrocompatible) |
| `ECDSA-SHA2-256` | Firma ECDSA con hash SHA-256 |
| `ECDSA-SHA2-384` | Firma ECDSA con hash SHA-384 |
| `EDDSA-ED25519` | Firma EdDSA usando curva Ed25519 (hash es intrínseco) |
| `EDDSA-ED448` | Firma EdDSA usando curva Ed448 |
| `DSA-SHA1` | Firma DSA con hash SHA-1 (legado) |
| `RSA-SHA1` | Firma RSA con hash SHA-1 (legado) |
| `ECDSA-SHA1` | Firma ECDSA con hash SHA-1 (legado) |

**Regla práctica:** Si el nombre contiene `SHA1`, la firma es legado y está siendo eliminada. Si contiene `PSS`, es la variante moderna de RSA. Si comienza con `EDDSA`, es la opción más moderna.

---

## J.10 Criptografía Postcuántica — "Preparándose Para el Futuro"

### El Problema

Computadores cuánticos suficientemente potentes podrán:

- **Romper RSA** usando el algoritmo de Shor (factorización).
- **Romper ECC/DH** usando el algoritmo de Shor (logaritmo discreto).
- **Debilitar hashes y cifrados simétricos** usando el algoritmo de Grover (búsqueda) — reduce la seguridad a la mitad (AES-256 cae a ~128 bits, aún seguro; AES-128 cae a ~64 bits, inseguro).

La amenaza "harvest now, decrypt later" (HNDL) ya es real: los adversarios pueden capturar tráfico cifrado hoy y almacenarlo para descifrarlo cuando los computadores cuánticos estén disponibles.

### Algoritmos Estandarizados por el NIST (2024)

#### ML-KEM (Module-Lattice-Based Key Encapsulation Mechanism)

- **Nombre anterior:** CRYSTALS-Kyber.
- **Tipo:** Intercambio de clave (KEM).
- **Problema matemático:** Learning With Errors en retículos (lattice).
- **Variantes:**
  - **ML-KEM-512:** ~128 bits de seguridad (NIST nivel 1).
  - **ML-KEM-768:** ~192 bits de seguridad (NIST nivel 3).
  - **ML-KEM-1024:** ~256 bits de seguridad (NIST nivel 5).
- **Uso en las crypto-policies:** En modo **híbrido** — combinado con algoritmo clásico para mantener seguridad incluso si el PQ es roto:
  - `MLKEM768-X25519` — ML-KEM-768 + X25519
  - `P256-MLKEM768` — ML-KEM-768 + NIST P-256
  - `P384-MLKEM1024` — ML-KEM-1024 + NIST P-384
- **Estado:** Presente en DEFAULT de RHEL como primer grupo en la lista (mayor prioridad).

#### ML-DSA (Module-Lattice-Based Digital Signature Algorithm)

- **Nombre anterior:** CRYSTALS-Dilithium.
- **Tipo:** Firma digital.
- **Problema matemático:** Learning With Errors en retículos.
- **Variantes:**
  - **ML-DSA-44 (MLDSA44):** NIST nivel 2. Presente en DEFAULT.
  - **ML-DSA-65 (MLDSA65):** NIST nivel 3. Presente en DEFAULT.
  - **ML-DSA-87 (MLDSA87):** NIST nivel 5. Presente en DEFAULT.
- **Tamaño de las firmas:** Significativamente mayores que ECDSA (~2,4 KB para ML-DSA-44 vs ~64 bytes para ECDSA-P256).

#### SLH-DSA (Stateless Hash-Based Digital Signature Algorithm)

- **Nombre anterior:** SPHINCS+.
- **Tipo:** Firma digital basada en hash (no en retículos).
- **Ventaja:** Seguridad basada únicamente en la seguridad de funciones de hash — comprendidas desde hace décadas. Es el "plan B" en caso de que los esquemas basados en retículos sean rotos.
- **Desventaja:** Firmas grandes (~7–49 KB) y lentas.
- **Variantes en las crypto-policies:** `SLHDSA-SHAKE-128S`, `SLHDSA-SHAKE-128F`, `SLHDSA-SHAKE-256S` — presentes en DEFAULT para Sequoia/RPM (OpenPGP).

### Otros Algoritmos PQ (Experimentales)

| Algoritmo | Tipo | Estado |
|-----------|------|--------|
| **FALCON** | Firma (NTRU lattice) | NIST ronda 4. Firmas más pequeñas que ML-DSA pero implementación compleja. |
| **NTRU Prime (SNTRUP761)** | KEM | Usado en SSH (`sntrup761x25519-sha512@openssh.com`). Alternativa a ML-KEM. |

### El Concepto de Enfoque Híbrido

La migración PQ se está realizando en modo **híbrido**: cada operación criptográfica combina un algoritmo clásico (ej: X25519) con un algoritmo PQ (ej: ML-KEM-768). Si el algoritmo PQ resulta inseguro, la seguridad clásica permanece. Si el computador cuántico llega, el PQ protege.

---

## J.11 Funciones de Derivación de Clave (KDF) — "Fabricar Claves a Partir de Secretos"

### El Concepto

Una KDF (Key Derivation Function) transforma un secreto de entrada (que puede ser débil, como una contraseña, o fuerte, como el resultado de un intercambio de clave) en una o más claves criptográficas adecuadas para su uso.

### KDFs Comunes

#### HKDF (HMAC-based Key Derivation Function)

- **Qué es:** KDF estandarizada (RFC 5869) basada en HMAC. Dos fases: Extract (comprime entropía) + Expand (genera material de clave).
- **Dónde aparece:** TLS 1.3 (derivación de todas las claves de sesión), Signal Protocol, WireGuard.
- **Estado:** Estándar para derivación de clave a partir de secretos de alta entropía.

#### PBKDF2 (Password-Based Key Derivation Function 2)

- **Qué es:** KDF diseñada para derivar claves a partir de **contraseñas** (secretos de baja entropía). Aplica HMAC repetidamente para hacer los ataques de fuerza bruta lentos.
- **Parámetro:** Número de iteraciones (recomendado ≥ 600.000 para SHA-256 en 2024).
- **Dónde aparece:** WPA2 (Wi-Fi), LUKS1 (cifrado de disco Linux), PKCS#12, almacenamiento de contraseñas.
- **Estado:** Seguro pero inferior a Argon2. Vulnerable a ataques con GPU/ASIC (la operación HMAC es eficiente en hardware paralelo).

#### bcrypt

- **Qué es:** Función de hashing de contraseñas basada en Blowfish (1999). Coste computacional ajustable.
- **Dónde aparece:** Almacenamiento de contraseñas en bases de datos, `/etc/shadow` en muchos sistemas.
- **Estado:** Seguro. Resistente a GPU por diseño (requiere acceso aleatorio a memoria).

#### scrypt

- **Qué es:** KDF que exige grandes cantidades de memoria además de CPU, haciendo que los ataques con hardware especializado sean más costosos.
- **Dónde aparece:** Algunas criptomonedas, LUKS2 (opcional).

#### Argon2

- **Qué es:** Ganador de la Password Hashing Competition (2015). Tres variantes: Argon2d (resistente a GPU), Argon2i (resistente a canal lateral), Argon2id (híbrido, recomendado).
- **Dónde aparece:** LUKS2 (predeterminado), almacenamiento moderno de contraseñas.
- **Estado:** **Recomendado para nuevas implementaciones.** Superior a PBKDF2, bcrypt y scrypt en todos los criterios.

---

## J.12 Protocolos de Transporte Seguro — "El Sobre Completo"

### El Concepto

Los protocolos de transporte seguro combinan todas las primitivas anteriores en un sistema completo de comunicación segura. Un protocolo TLS, por ejemplo, usa intercambio de clave (ECDHE) para establecer un secreto, KDF (HKDF) para derivar claves de sesión, cifrado AEAD (AES-GCM) para cifrar datos, firma digital (ECDSA) para autenticar el servidor, y hash (SHA-256) para integridad.

### TLS (Transport Layer Security)

| Versión | Estado | Notas |
|---------|--------|-------|
| **SSL 2.0** (1995) | **Eliminado** | Múltiples vulnerabilidades fatales. Eliminado de las bibliotecas. |
| **SSL 3.0** (1996) | **Eliminado** | Vulnerable a POODLE. Eliminado de las bibliotecas. |
| **TLS 1.0** (1999) | **Obsoleto** | Vulnerable a BEAST. Deshabilitado en DEFAULT. |
| **TLS 1.1** (2006) | **Obsoleto** | Sin vulnerabilidades específicas conocidas, pero sin ciphersuites AEAD. Deshabilitado en DEFAULT. |
| **TLS 1.2** (2008) | **Seguro** | Soporta AEAD (AES-GCM). Amplia compatibilidad. Requiere configuración cuidadosa. |
| **TLS 1.3** (2018) | **Recomendado** | Solo AEAD. Handshake más rápido (1-RTT). Forward secrecy obligatorio. Sin RSA key transport. |

**Ciphersuite TLS 1.3:** El nombre completo (ej: `TLS_AES_256_GCM_SHA384`) indica: protocolo (TLS), cifrado AEAD (AES-256-GCM), hash para HKDF (SHA-384). El intercambio de clave no forma parte del nombre porque siempre es ECDHE o DHE.

### DTLS (Datagram TLS)

- **Qué es:** TLS adaptado para UDP (transporte sin conexión). Necesario porque TLS asume TCP (entrega ordenada y confiable).
- **Versiones:** DTLS 1.0 (basado en TLS 1.1), DTLS 1.2 (basado en TLS 1.2).
- **Dónde aparece:** VoIP (SRTP), VPN (OpenConnect), IoT (CoAP).

### IKE (Internet Key Exchange)

| Versión | Estado | Notas |
|---------|--------|-------|
| **IKEv1** | **Obsoleto** | Complejo, múltiples modos de operación, vulnerabilidades. |
| **IKEv2** | **Recomendado** | Simplificado, más seguro, soporta MOBIKE (movilidad). |

IKE es el protocolo usado por IPsec (VPN) para negociar parámetros criptográficos y establecer Security Associations.

---

## J.13 Niveles de Seguridad — "Qué Significa 128 Bits de Seguridad"

### El Concepto

Cuando decimos que un sistema tiene **N bits de seguridad**, significa que el mejor ataque conocido requiere aproximadamente **2^N** operaciones. Como referencia:

| Bits | Operaciones | Viabilidad |
|------|-------------|------------|
| 64 | 2⁶⁴ ≈ 1,8 × 10¹⁹ | Rompible con hardware dedicado en meses |
| 80 | 2⁸⁰ ≈ 1,2 × 10²⁴ | Marginal — las agencias pueden tener capacidad |
| 112 | 2¹¹² ≈ 5,2 × 10³³ | Seguro para uso actual |
| 128 | 2¹²⁸ ≈ 3,4 × 10³⁸ | **Estándar mínimo recomendado.** Irrompible con tecnología clásica previsible |
| 192 | 2¹⁹² ≈ 6,3 × 10⁵⁷ | Margen de seguridad para décadas |
| 256 | 2²⁵⁶ ≈ 1,2 × 10⁷⁷ | Seguro incluso contra computadores cuánticos (para cifrados simétricos) |

### Equivalencia Entre Algoritmos

| Nivel de Seguridad | Cifrado Simétrico | Hash | RSA/DH | ECC | Política RHEL |
|--------------------|-------------------|------|--------|-----|---------------|
| 80 bits | 3DES | SHA-1 | 1024 | 160 | — |
| 112 bits | AES-128 | SHA-224 | 2048 | 224 | DEFAULT |
| 128 bits | AES-128 | SHA-256 | 3072 | 256 | FUTURE |
| 192 bits | AES-192 | SHA-384 | 7680 | 384 | — |
| 256 bits | AES-256 | SHA-512 | 15360 | 512 | — |

La política DEFAULT de RHEL apunta a 112 bits de seguridad. La política FUTURE apunta a 128 bits.

---

## J.14 Resumen Visual — Cuándo Usar Qué

```
┌─────────────────────────────────────────────────────────────────┐
│                    ELIGIENDO LA PRIMITIVA                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ¿Necesito CIFRAR datos en masa?                                 │
│  └─→ AES-256-GCM (con hardware) o ChaCha20-Poly1305 (sin)      │
│                                                                  │
│  ¿Necesito verificar INTEGRIDAD sin clave?                       │
│  └─→ SHA-256 (o SHA-512 en 64-bit)                              │
│                                                                  │
│  ¿Necesito verificar integridad CON autenticación?               │
│  └─→ HMAC-SHA256 (o usar AEAD que ya lo incluye)                │
│                                                                  │
│  ¿Necesito FIRMAR un documento/certificado?                      │
│  └─→ Ed25519 (preferido) o ECDSA-P256 o RSA-PSS-SHA256         │
│                                                                  │
│  ¿Necesito INTERCAMBIAR CLAVE con alguien?                       │
│  └─→ ECDHE con X25519 (o MLKEM768-X25519 para PQ)              │
│                                                                  │
│  ¿Necesito derivar clave de una CONTRASEÑA?                      │
│  └─→ Argon2id (preferido) o PBKDF2-SHA256                       │
│                                                                  │
│  ¿Necesito derivar claves de un SECRETO fuerte?                  │
│  └─→ HKDF-SHA256                                                 │
│                                                                  │
│  ¿Necesito resistencia a COMPUTADORES CUÁNTICOS?                 │
│  └─→ Enfoque híbrido: ML-KEM + ECDHE para intercambio de clave, │
│      ML-DSA para firmas, AES-256 para cifrado                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## J.15 Tabla de Referencia Rápida — Estado de Cada Algoritmo

### Cifrados Simétricos

| Algoritmo | ¿Seguro? | ¿En las Crypto-Policies? | Recomendación |
|-----------|----------|--------------------------|---------------|
| AES-256-GCM | Sí | Todas | Preferido |
| AES-128-GCM | Sí | DEFAULT, LEGACY, FIPS | Aceptable |
| ChaCha20-Poly1305 | Sí | DEFAULT, FUTURE, LEGACY | Alternativa a AES |
| AES-256-CBC | Sí (con EtM) | DEFAULT, LEGACY, FIPS (no en SSH/TLS) | Legado, preferir GCM |
| AES-128-CBC | Sí (con EtM) | DEFAULT, LEGACY, FIPS (no en SSH) | Legado, preferir GCM |
| Camellia-256-GCM | Sí | DEFAULT (no en TLS) | Raro |
| 3DES-CBC | Débil | Solo LEGACY | Migrar a AES |
| RC4 | Roto | Ninguna | Nunca usar |
| DES | Roto | Ninguna | Nunca usar |

### Hashes

| Algoritmo | ¿Seguro? | ¿En las Crypto-Policies? | Recomendación |
|-----------|----------|--------------------------|---------------|
| SHA-256 | Sí | Todas | Estándar |
| SHA-384 | Sí | Todas | Alta seguridad |
| SHA-512 | Sí | Todas | Máxima seguridad |
| SHA3-256 | Sí | Todas | Alternativa a SHA-256 |
| SHA-1 | Colisiones | LEGACY (general), DEFAULT (solo HMAC/DNSSec) | Solo HMAC |
| MD5 | Roto | Solo LEGACY (PKCS12/SMIME) | Nunca para seguridad |

### Firmas

| Algoritmo | ¿Seguro? | ¿En las Crypto-Policies? | Recomendación |
|-----------|----------|--------------------------|---------------|
| Ed25519 | Sí | DEFAULT, FUTURE, FIPS | Preferido (SSH) |
| ECDSA-SHA2-256 | Sí | Todas | Preferido (certificados) |
| RSA-PSS-SHA2-256 | Sí | Todas | Preferido (RSA) |
| RSA-SHA2-256 | Sí | Todas | Aceptable |
| ML-DSA-65 | Sí (PQ) | Todas | Futuro |
| RSA-SHA1 | Débil | LEGACY, DEFAULT (DNSSec) | Migrar |
| DSA-SHA1 | Débil | Solo LEGACY | Nunca |

### Intercambio de Clave

| Método | ¿Forward Secrecy? | ¿PQ-Seguro? | Recomendación |
|--------|:------------------:|:-----------:|---------------|
| ECDHE (X25519) | Sí | No | Estándar actual |
| MLKEM768-X25519 | Sí | Sí (híbrido) | Futuro |
| DHE (FFDHE-3072+) | Sí | No | Aceptable |
| RSA key transport | No | No | Obsoleto |

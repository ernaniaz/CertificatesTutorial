# Appendix J: Complete Guide to Cryptographic Primitives

> **Who this appendix is for:** This appendix is a reference for anyone who needs to understand what the cryptographic algorithms and mechanisms mentioned throughout this tutorial are and what they do. The language is deliberately accessible — the goal is that a system administrator without a cryptography background can distinguish between the different types of cryptographic resource and make informed choices.

---

## J.1 How to Read This Appendix

Modern cryptography is built from smaller pieces called **primitives**. Each primitive solves a specific problem:

| Problem | Primitive | Physical World Analogy |
|---------|-----------|------------------------|
| "No one can read this" | **Symmetric cipher** | Safe with a single key |
| "No one can read this, but I don't know the recipient" | **Asymmetric cipher** | Mailbox: anyone can deposit, only the owner opens |
| "This has not been tampered with" | **Hash** | Fingerprint of a document |
| "This has not been tampered with AND it came from who it claims" | **MAC** | Security seal with serial number |
| "I guarantee I wrote this" | **Digital signature** | Notarized signature with authentication |
| "Let's agree on a secret without anyone listening" | **Key exchange** | Two people agree on a color by mixing paints in public |
| "Let's derive multiple secrets from one" | **KDF** | Key-copying machine from a master key |

Each section below explains a category, lists the most relevant algorithms, and indicates their current status (secure, legacy, broken).

---

## J.2 Symmetric Ciphers — "The Same Key Locks and Unlocks"

### The Concept

A symmetric cipher uses **the same key** to encrypt and decrypt. It is the fastest type of cryptography and protects the vast majority of data in transit (TLS, SSH, VPN) and at rest (LUKS, BitLocker).

The fundamental challenge: how do you deliver the key to the recipient without an attacker intercepting it? This problem is solved by key exchange (section J.6).

### Block Ciphers vs Stream Ciphers

Symmetric ciphers are divided into two types:

- **Block cipher:** Processes data in fixed-size blocks (e.g., 128 bits). If the message is larger than one block, a **mode of operation** is needed to chain the blocks. Examples: AES, Camellia, 3DES.
- **Stream cipher:** Generates a continuous stream of pseudorandom bits (keystream) that is combined with the data via XOR, bit by bit. No mode of operation is needed. Examples: ChaCha20, RC4.

### Symmetric Algorithms

#### AES (Advanced Encryption Standard)

- **What it is:** The global standard for symmetric encryption since 2001, selected by NIST in a public competition. Original name: Rijndael.
- **Key sizes:** 128, 192, or 256 bits.
- **Block size:** 128 bits.
- **Status:** Secure. No practical attack known against any variant. AES-256 is considered resistant to quantum computers (Grover's attack reduces the effective security to ~128 bits, still sufficient).
- **Where it appears:** Practically everywhere — TLS, SSH, VPN, disk encryption, Wi-Fi (WPA2/WPA3), messengers (Signal, WhatsApp).
- **Special advantage:** Modern processors (Intel, AMD, ARM) have dedicated hardware instructions (AES-NI) that make AES extremely fast — orders of magnitude faster than software implementation.

#### ChaCha20

- **What it is:** Stream cipher created by Daniel J. Bernstein in 2008. Improved variant of Salsa20.
- **Key size:** 256 bits.
- **Status:** Secure. Adopted by Google, Cloudflare, and others as an alternative to AES.
- **Where it appears:** TLS 1.3, SSH, WireGuard, Google protocols (QUIC).
- **Why it exists when we already have AES:** ChaCha20 is faster than AES on devices **without** hardware acceleration (older ARM smartphones, IoT devices). On servers with AES-NI, AES is faster.

#### Camellia

- **What it is:** Block cipher developed by Mitsubishi Electric and NTT (Japan) in 2000.
- **Key sizes:** 128, 192, 256 bits.
- **Block size:** 128 bits.
- **Status:** Secure, but rarely used outside Japan. Approved by NESSIE, CRYPTREC, and ISO/IEC.
- **Where it appears:** Some TLS implementations, especially in Japanese regulatory environments.
- **In practice:** Rarely needed. RHEL crypto-policies include Camellia in DEFAULT but exclude it from TLS.

#### 3DES (Triple DES)

- **What it is:** Triple application of the original DES (3 × DES with 2 or 3 different keys).
- **Effective key size:** 112 bits (with 3 keys) or 80 bits (with 2 keys).
- **Block size:** 64 bits.
- **Status:** **Legacy/Deprecated.** The 64-bit block makes it vulnerable to the Sweet32 attack — after ~32 GB of data encrypted with the same key, repetitive patterns leak information. NIST prohibited 3DES after 2023.
- **Where it appears:** Legacy systems, old PKCS#12, old S/MIME, very old Active Directory.
- **Recommendation:** Migrate to AES as soon as possible. In RHEL crypto-policies, 3DES appears only in the LEGACY policy.

#### DES (Data Encryption Standard)

- **What it is:** Block cipher from 1977, the first encryption standard of the US government.
- **Key size:** 56 bits.
- **Block size:** 64 bits.
- **Status:** **Broken.** A DES key can be brute-forced in hours with modern hardware. The DESCHALL project broke DES in 1997.
- **Where it appears:** Should not appear anywhere. Removed from modern cryptographic libraries.

#### RC4 (Rivest Cipher 4)

- **What it is:** Stream cipher created by Ron Rivest in 1987. Simple and fast.
- **Key size:** Variable (40–256 bits).
- **Status:** **Broken.** Multiple statistical biases in the keystream allow plaintext recovery. Prohibited in TLS since RFC 7465 (2015).
- **Where it appears:** Should not. WEP (old Wi-Fi) used RC4 and was broken because of it.

#### IDEA (International Data Encryption Algorithm)

- **What it is:** Block cipher from 1991, used in the original PGP.
- **Key size:** 128 bits.
- **Block size:** 64 bits.
- **Status:** Obsolete. Patent expired. 64-bit block is insufficient.
- **Where it appears:** Only in very old PGP messages.

#### SEED

- **What it is:** South Korean standard block cipher (1998).
- **Key size:** 128 bits.
- **Block size:** 128 bits.
- **Status:** Secure but no adoption outside South Korea. Irrelevant in practice.

#### Blowfish / Twofish

- **What they are:** Block ciphers created by Bruce Schneier. Blowfish (1993, 64-bit block) is the predecessor; Twofish (1998, 128-bit block) was a finalist in the AES competition.
- **Status:** Blowfish is legacy (64-bit block). Twofish is secure but lost the AES competition and has little adoption.
- **Where it appears:** Blowfish survives in `bcrypt` (password hashing). Twofish appears in some disk encryption implementations.

### Modes of Operation — How to Chain Blocks

A block cipher like AES processes exactly 128 bits at a time. To encrypt a larger message, a **mode of operation** is needed that defines how blocks are chained. The choice of mode is as important as the cipher itself.

#### ECB (Electronic Codebook)

- **How it works:** Each block is encrypted independently with the same key.
- **Status:** **Insecure.** Identical plaintext blocks produce identical ciphertext blocks, revealing patterns. The famous "ECB penguin" demonstrates this visually.
- **Correct use:** None for general data. Only for encrypting random values of exactly one block (e.g., a key).

#### CBC (Cipher Block Chaining)

- **How it works:** Each plaintext block is XORed with the previous ciphertext block before being encrypted. The first block uses a random Initialization Vector (IV).
- **Status:** Secure if implemented correctly, but vulnerable to padding oracle attacks (POODLE, Lucky13) when padding is not verified in constant time.
- **Where it appears:** TLS 1.2 (deprecated), SSH (deprecated in recent versions), PKCS#12, S/MIME.
- **In crypto-policies:** DEFAULT disables CBC in SSH (`cipher@SSH = -*-CBC`) due to plaintext recovery vulnerability.

#### CTR (Counter)

- **How it works:** Transforms the block cipher into a stream cipher — encrypts a counter incremented for each block and XORs it with the plaintext.
- **Status:** Secure. Allows parallelism and random access.
- **Where it appears:** SSH (AES-CTR is the default mode), Kerberos.
- **Caution:** The counter (nonce + counter) must never repeat with the same key.

#### GCM (Galois/Counter Mode)

- **How it works:** Combines CTR (for confidentiality) with Galois field multiplication (for integrity). Produces an authentication tag along with the ciphertext.
- **Status:** Secure and efficient. It is an **AEAD** (Authenticated Encryption with Associated Data) mode — see section J.5.
- **Where it appears:** TLS 1.2 and 1.3 (preferred mode), SSH, IPsec.
- **Advantage:** Encrypts and authenticates in a single operation. Hardware-accelerated (CLMUL/PCLMULQDQ).
- **In crypto-policies:** AES-256-GCM is the first cipher listed in all policies.

#### CCM (Counter with CBC-MAC)

- **How it works:** Combines CTR (confidentiality) with CBC-MAC (integrity). AEAD mode.
- **Status:** Secure but slower than GCM (two passes over the data instead of one).
- **Where it appears:** TLS 1.2/1.3, Wi-Fi (WPA2/CCMP), Bluetooth.

#### OCB (Offset Codebook Mode)

- **How it works:** Single-pass AEAD mode — faster than GCM and CCM.
- **Status:** Secure. Was patented until 2021, which prevented its adoption.
- **Where it appears:** OpenPGP (Sequoia), limited in TLS due to the historical patent.

#### EAX

- **How it works:** AEAD mode based on CTR + OMAC. Not patented.
- **Status:** Secure. Similar to CCM but simpler to implement correctly.
- **Where it appears:** OpenPGP (Sequoia).

#### CFB (Cipher Feedback)

- **How it works:** Similar to CBC but operates as a stream cipher — allows processing data smaller than a block.
- **Status:** Secure but no advantage over CTR or GCM. Does not provide authentication.
- **Where it appears:** OpenPGP (mandatory historical mode), GOST.

---

## J.3 Hash Functions — "The Fingerprint of Data"

### The Concept

A hash function takes data of any size and produces a fixed-size output (the **digest**). The fundamental properties:

1. **Deterministic:** The same input always produces the same output.
2. **Fast:** Computing the hash is computationally cheap.
3. **Irreversible (preimage resistance):** Given a hash, it is computationally infeasible to find the input that produced it.
4. **Collision resistance:** It is computationally infeasible to find two different inputs that produce the same hash.
5. **Avalanche effect:** A minimal change in the input (one bit) drastically alters the output.

**Do not confuse:** Hashes **do not encrypt** — they are one-way operations. There is no such thing as "decrypting a hash." If someone says "decrypt the MD5," they are talking about a brute-force attack or rainbow tables, not reversal.

### Hash Algorithms

#### MD5 (Message Digest 5)

- **Creator:** Ron Rivest, 1991.
- **Output size:** 128 bits (32 hexadecimal characters).
- **Status:** **Broken for cryptographic integrity.** Collisions can be generated in seconds. In 2008, researchers created a fake CA certificate using an MD5 collision. The "Flame" malware exploited MD5 collisions in Microsoft certificates.
- **Still acceptable for:** Non-cryptographic integrity checksums (verifying if a download was corrupted, as long as the attacker does not control the source). Never for signatures or authentication.
- **In crypto-policies:** Excluded from all policies, including LEGACY.

#### SHA-1 (Secure Hash Algorithm 1)

- **Creator:** NSA, 1995.
- **Output size:** 160 bits (40 hexadecimal characters).
- **Status:** **Broken.** The SHAttered project (Google, 2017) demonstrated a practical collision — two different PDFs with the same SHA-1. The cost was ~$110,000 in cloud computing; today it is less. In 2020, chosen-prefix collisions were demonstrated for ~$45,000.
- **Still acceptable for:** HMAC-SHA1 (where the secret key prevents collision attacks — see section J.4). Git uses SHA-1 but is migrating to SHA-256.
- **In crypto-policies:** DEFAULT allows SHA-1 only in HMAC and DNSSec; FUTURE removes SHA-1 completely; LEGACY allows everything.

#### SHA-2 Family

Created by the NSA, published between 2001 and 2012. **Four variants** with security proportional to the output size:

| Variant | Output | Collision security | Notes |
|---------|--------|-------------------|-------|
| **SHA-224** | 224 bits | 112 bits | Truncated version of SHA-256. Rarely used. |
| **SHA-256** | 256 bits | 128 bits | **The current standard.** Used in TLS, X.509 certificates, Bitcoin, software signatures. |
| **SHA-384** | 384 bits | 192 bits | Truncated version of SHA-512. Used in TLS 1.3, high-security certificates. |
| **SHA-512** | 512 bits | 256 bits | Maximum security. Faster than SHA-256 on 64-bit processors. |

- **Status:** Secure. No practical attack known against any variant.
- **Where it appears:** X.509 certificates (the vast majority use SHA-256), TLS, SSH, package signatures, blockchain, file integrity verification.
- **In crypto-policies:** SHA-256, SHA-384, and SHA-512 are enabled in all policies.

#### SHA-3 Family

Created by Guido Bertoni, Joan Daemen, Michaël Peeters, and Gilles Van Assche. Won the NIST competition in 2012. Original name: Keccak. Uses a completely different internal construction from SHA-2 (sponge instead of Merkle-Damgård).

| Variant | Output | Collision security |
|---------|--------|--------------------|
| **SHA3-224** | 224 bits | 112 bits |
| **SHA3-256** | 256 bits | 128 bits |
| **SHA3-384** | 384 bits | 192 bits |
| **SHA3-512** | 512 bits | 256 bits |

- **Status:** Secure. Fundamentally different from SHA-2, serving as a "safe alternative" in case SHA-2 is compromised.
- **Why they exist when SHA-2 is secure:** Algorithmic diversity. SHA-3 and SHA-2 use completely different mathematical constructions. If a theoretical attack compromises the SHA-2 family, SHA-3 would likely not be affected. It is the same logic as having ChaCha20 as an alternative to AES.
- **In crypto-policies:** Enabled in DEFAULT, FUTURE, and FIPS.

#### SHAKE-128 / SHAKE-256

- **What they are:** **Variable-output** hash functions (XOF — Extendable Output Function) based on the Keccak/SHA-3 construction. Instead of producing a fixed-size digest, they can produce outputs of any length.
- **Use:** Key derivation, post-quantum algorithms (SLH-DSA uses SHAKE), protocols that need arbitrary amounts of pseudorandom material.

#### BLAKE2 / BLAKE3

- **What they are:** High-performance alternative hash functions. BLAKE2 (2012) is faster than MD5 while maintaining security equivalent to SHA-3. BLAKE3 (2020) is even faster and parallelizable.
- **Status:** Secure. Used in WireGuard, Argon2, various file systems, but not standardized by NIST.
- **In crypto-policies:** Not supported by RHEL crypto-policies (not used in TLS/SSH/IPsec).

#### RIPEMD-160

- **What it is:** European hash function (1996), 160-bit output.
- **Status:** Secure but no significant adoption outside Bitcoin (used in addresses).
- **In crypto-policies:** Not supported.

---

## J.4 MACs — "Seal of Authenticity"

### The Concept

A MAC (Message Authentication Code) guarantees two things simultaneously:

1. **Integrity:** The message was not altered in transit.
2. **Authenticity:** The message came from someone who possesses the secret key.

The crucial difference from a simple hash: the MAC uses a **secret key**. Without the key, it is impossible to generate or verify the MAC. A simple hash (SHA-256) proves that the data was not corrupted, but anyone can recalculate it — it does not prove the origin.

### MAC Algorithms

#### HMAC (Hash-based MAC)

- **What it is:** Generic construction that transforms any hash function into a MAC. HMAC-SHA256 = HMAC using SHA-256 internally.
- **How it works:** `HMAC(key, message) = Hash((key ⊕ opad) || Hash((key ⊕ ipad) || message))`. Two rounds of hashing with special padding make the result dependent on the key in a cryptographically secure manner.
- **Status:** Secure. Security depends on the underlying hash, but even HMAC-SHA1 remains secure — collision attacks against SHA-1 **do not** compromise HMAC-SHA1, because the attacker does not control the key.
- **Common variants:**
  - **HMAC-SHA2-256:** Standard in TLS and SSH.
  - **HMAC-SHA2-384 / HMAC-SHA2-512:** High security.
  - **HMAC-SHA1:** Legacy but secure as a MAC. RHEL DEFAULT allows it in TLS and SSH.
  - **HMAC-MD5:** Insecure. Only in LEGACY.
- **Where it appears:** TLS 1.2 (for non-AEAD ciphersuites), SSH, IPsec, authentication APIs (JWT, OAuth), package integrity verification.

#### CMAC (Cipher-based MAC)

- **What it is:** MAC based on a block cipher (usually AES) instead of a hash.
- **Where it appears:** Wi-Fi (WPA2), Bluetooth, Kerberos.
- **Status:** Secure. Alternative to HMAC when AES is available in hardware but hash is not.

#### Poly1305

- **What it is:** High-speed MAC created by Daniel J. Bernstein. Uses modular arithmetic instead of hash or block cipher.
- **Status:** Secure. Designed to be used **once per key** — each message receives a different key (derived from ChaCha20).
- **Where it appears:** Always combined with ChaCha20 as ChaCha20-Poly1305 (AEAD mode). Never used alone in modern protocols.

#### UMAC / UMAC-128

- **What it is:** MAC based on universal hashing, extremely fast.
- **Where it appears:** SSH (specifically `umac-64@openssh.com` and `umac-128-etm@openssh.com`).
- **Status:** Secure. `umac-64` has a 64-bit tag (adequate only for SSH where the number of packets is limited).

#### GMAC (Galois MAC)

- **What it is:** The authentication part of GCM mode, used when there is no data to encrypt (only authenticate).
- **Where it appears:** Implicitly in AES-GCM. Also used in MACsec (layer 2 encryption in Ethernet networks).

### Encrypt-then-MAC vs Encrypt-and-MAC vs MAC-then-Encrypt

When a CBC cipher (which is not AEAD) is used with a separate HMAC, the **order** of operations matters for security:

| Approach | Description | Security |
|----------|-------------|----------|
| **Encrypt-then-MAC (EtM)** | Encrypt, then compute MAC of the ciphertext | **Secure.** The MAC protects the ciphertext — any tampering is detected before decryption. |
| **MAC-then-Encrypt (MtE)** | Compute MAC of the plaintext, then encrypt both | **Vulnerable.** TLS 1.2 with CBC uses this approach and is vulnerable to padding oracle (Lucky13, POODLE). |
| **Encrypt-and-MAC (E&M)** | Encrypt the plaintext and compute MAC of the plaintext separately | **Vulnerable.** The MAC can leak information about the plaintext. SSH used this approach. |

The `etm` parameter in RHEL crypto-policies controls exactly this for SSH: `DISABLE_NON_ETM` forces Encrypt-then-MAC, `DISABLE_ETM` forces the old mode (not recommended).

---

## J.5 AEAD — "Encryption and Authentication Together"

### The Concept

AEAD (Authenticated Encryption with Associated Data) combines **confidentiality** and **integrity** in a single atomic operation. Instead of using a cipher (AES-CBC) + a MAC (HMAC-SHA256) separately — with all the risks of combining them incorrectly — an AEAD mode does everything at once.

"Associated Data" is data that needs to be **authenticated but not encrypted** — for example, protocol headers that need to be readable but cannot be tampered with.

**TLS 1.3 accepts ONLY AEAD ciphersuites.** Non-AEAD modes (CBC + HMAC) were banned.

### AEAD Algorithms

| Algorithm | Cipher + Authentication | Where It Appears | Notes |
|-----------|------------------------|-------------------|-------|
| **AES-256-GCM** | AES-256 (CTR) + GMAC | TLS, SSH, IPsec | Dominant standard. Fast with AES-NI + CLMUL hardware. |
| **AES-128-GCM** | AES-128 (CTR) + GMAC | TLS, SSH, IPsec | Secure and faster than AES-256-GCM. |
| **ChaCha20-Poly1305** | ChaCha20 + Poly1305 | TLS, SSH, WireGuard | Alternative without AES hardware dependency. |
| **AES-256-CCM** | AES-256 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Slower than GCM (two passes). |
| **AES-128-CCM** | AES-128 (CTR) + CBC-MAC | TLS, Wi-Fi, Bluetooth | Same. |
| **AES-256-OCB** | AES-256 + Offset Codebook | OpenPGP | Single pass (faster than GCM). |
| **AES-256-EAX** | AES-256 (CTR) + OMAC | OpenPGP | No patents, simple to implement. |

In practice, the three dominant AEADs are: **AES-GCM** (with hardware), **ChaCha20-Poly1305** (without hardware), and **AES-CCM** (in protocols that require it).

---

## J.6 Asymmetric Cryptography — "Two Keys: One Public, One Private"

### The Concept

In asymmetric cryptography (or public key cryptography), each participant possesses a **key pair**:

- **Public key:** Can be freely distributed. Used to encrypt data intended for the owner and to verify signatures.
- **Private key:** Must be kept in absolute secrecy. Used to decrypt data and to create signatures.

The mathematical relationship between the two keys ensures that data encrypted with the public key **can only** be decrypted by the corresponding private key, and vice versa.

Asymmetric cryptography is **much slower** than symmetric (hundreds to thousands of times). Therefore, in practice, it is used only to:
1. **Exchange symmetric session keys** (TLS handshake).
2. **Sign** data (certificates, software packages).
3. **Authenticate** identities.

Bulk data encryption always uses symmetric ciphers.

### Asymmetric Algorithms

#### RSA (Rivest-Shamir-Adleman)

- **What it is:** First practical public key encryption system (1977). Based on the difficulty of factoring the product of two large prime numbers.
- **Common key sizes:** 2048, 3072, 4096 bits.
- **Use:** Signing (X.509 certificates, packages), key exchange (TLS 1.2 — deprecated), authentication.
- **Status:** Secure with keys ≥ 2048 bits. 1024-bit keys have been considered insecure since ~2010. Vulnerable to quantum computers (Shor's algorithm).
- **In crypto-policies:** DEFAULT requires `min_rsa_size = 2048`, FUTURE requires 3072.

**RSA-PKCS#1 v1.5 vs RSA-PSS:**

| Scheme | Description | Status |
|--------|-------------|--------|
| **RSA-PKCS#1 v1.5** | Original padding scheme (1998). Deterministic for signatures. | Secure for signatures, but **insecure for encryption** (Bleichenbacher attack). TLS keeps it for compatibility but is phasing it out. |
| **RSA-PSS** | Probabilistic Signature Scheme (2003). Random padding makes each signature different even for the same message. | **Recommended.** Formal security proof. TLS 1.3 requires PSS for RSA signatures. |
| **RSA-OAEP** | Optimal Asymmetric Encryption Padding. For encryption (not signing). | Secure. Replacement for PKCS#1 v1.5 for encryption. |

#### DSA (Digital Signature Algorithm)

- **What it is:** Signature algorithm based on the discrete logarithm problem. NIST standard (FIPS 186, 1994).
- **Key sizes:** 1024, 2048, 3072 bits.
- **Status:** **Deprecated.** NIST no longer recommends DSA for new implementations (FIPS 186-5, 2023). Vulnerable to quantum computers.
- **In crypto-policies:** DEFAULT does not include DSA in `sign`. LEGACY includes DSA-SHA1 and variants.

#### Diffie-Hellman (DH)

- **What it is:** First public key key exchange protocol (1976). Allows two parties to agree on a shared secret over an insecure channel.
- **How it works (simplified):** Alice and Bob choose large public numbers (p, g). Each generates a private secret, computes a derived public value, and exchanges it. Both can then compute the same shared secret, but an observer cannot.
- **Variants:**
  - **Classic DH (FFDHE):** Uses modular arithmetic in finite fields. Standardized groups: FFDHE-2048, FFDHE-3072, FFDHE-4096, etc. (RFC 7919).
  - **ECDH (Elliptic Curve DH):** Uses elliptic curves. Much more efficient — a 256-bit curve offers security equivalent to 3072-bit DH.
- **Status:** Secure with adequate parameters. DH with 1024 bits is vulnerable to the Logjam attack (2015). Vulnerable to quantum computers.
- **In crypto-policies:** DEFAULT requires `min_dh_size = 2048`. FUTURE requires 3072.

**DHE (Diffie-Hellman Ephemeral):** Version where new DH keys are generated for each session, providing **forward secrecy** — even if the server's long-term private key is compromised in the future, past sessions remain secure.

#### ECDSA (Elliptic Curve Digital Signature Algorithm)

- **What it is:** Elliptic curve version of DSA. Smaller and faster signatures for the same security level.
- **Common curves:** P-256 (NIST), P-384, P-521.
- **Status:** Secure. Standard for modern certificates (especially in mobile/IoT due to smaller size).
- **Critical caution:** ECDSA requires a random nonce for each signature. If the random number generator fails and the nonce repeats, the private key is **immediately** recoverable. This happened with the PlayStation 3 (2010) and Bitcoin wallets.
- **In crypto-policies:** ECDSA-SHA2-256/384/512 are included in all policies.

#### EdDSA (Edwards-curve Digital Signature Algorithm)

- **What it is:** Signature algorithm based on twisted Edwards curves. Created by Daniel J. Bernstein and collaborators.
- **Variants:**
  - **Ed25519:** Uses Curve25519. 256-bit key, ~128 bits of security. 512-bit signatures.
  - **Ed448:** Uses Goldilocks curve. 448-bit key, ~224 bits of security. 912-bit signatures.
- **Status:** Secure. Designed to be resistant to side-channel attacks and does not depend on a random nonce (uses deterministic hash).
- **Advantage over ECDSA:** Deterministic — does not depend on RNG to generate signatures, eliminating the class of repeated nonce vulnerabilities.
- **Where it appears:** SSH (preferred key), TLS 1.3, WireGuard, Signal.
- **In crypto-policies:** Ed25519 and Ed448 are included in DEFAULT, FUTURE, and FIPS.

---

## J.7 Elliptic Curves — "More Security with Fewer Bits"

### The Concept

Elliptic Curve Cryptography (ECC) uses the mathematical properties of elliptic curves over finite fields to create cryptographic systems. The main advantage is **efficiency**: a 256-bit ECC key offers security comparable to a 3072-bit RSA key.

| Security (bits) | RSA/DH (bits) | ECC (bits) | Reduction factor |
|-----------------|---------------|------------|------------------|
| 80 | 1024 | 160 | 6.4× |
| 112 | 2048 | 224 | 9.1× |
| 128 | 3072 | 256 | 12× |
| 192 | 7680 | 384 | 20× |
| 256 | 15360 | 512 | 30× |

### Common Curves

#### NIST Curves (P-256, P-384, P-521)

- **What they are:** Curves standardized by NIST (FIPS 186-4). Use the short Weierstrass form.
- **P-256 (secp256r1):** 128 bits of security. The most widely used curve in TLS certificates.
- **P-384 (secp384r1):** 192 bits of security. Used by governments and high-security environments.
- **P-521 (secp521r1):** 256 bits of security. Rarely needed.
- **Controversy:** The seeds used to generate the NIST curve parameters were never fully explained, generating distrust that the NSA may have chosen parameters with a backdoor. No vulnerability has been found, but the distrust motivated the creation of the Bernstein curves.

#### Curve25519 / X25519

- **What it is:** Montgomery curve created by Daniel J. Bernstein (2006). The name X25519 refers to the key exchange function; Curve25519 is the underlying curve.
- **Security:** ~128 bits.
- **Advantages:** Designed to be resistant to side-channel attacks, with constant-time implementation. Completely transparent parameters (the prime number is 2²⁵⁵ − 19, justifying the name).
- **Where it appears:** TLS 1.3 (preferred group), SSH, WireGuard, Signal, QUIC.
- **In crypto-policies:** Present in DEFAULT, FUTURE, and FIPS (in groups).

#### Curve448 / X448

- **What it is:** "Goldilocks" curve created by Mike Hamburg (2014). High-security version of X25519.
- **Security:** ~224 bits.
- **Where it appears:** TLS 1.3, SSH.

#### Ed25519 / Ed448

- **What they are:** Edwards curves used for signatures (EdDSA). Ed25519 uses the isomorphism of Curve25519. Ed448 uses Curve448.
- **See section J.6** for details on signature usage.

#### Brainpool Curves

- **What they are:** Alternative curves generated by the ECC Brainpool working group (European consortium). Parameters generated in a verifiable manner from hash constants.
- **Variants:** brainpoolP256r1, brainpoolP384r1, brainpoolP512r1.
- **Where it appears:** TLS (European), BSI regulations (Germany).
- **In crypto-policies:** Supported by the source code but not included in RHEL default policies.

---

## J.8 Key Exchange — "Agreeing on a Secret in Public"

### The Concept

The fundamental problem of symmetric cryptography is: how do Alice and Bob share the key without an attacker intercepting it? Key exchange solves this by allowing two parties to agree on a shared secret over a public channel.

### Key Exchange Methods

#### ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)

- **What it is:** Diffie-Hellman over elliptic curves, with ephemeral keys (new for each session).
- **Status:** **Current standard.** Forward secrecy. Fast. Small keys.
- **Where it appears:** TLS 1.2 and 1.3, SSH, IPsec.
- **In crypto-policies:** First or second in the `key_exchange` list in all policies.

#### DHE (Diffie-Hellman Ephemeral)

- **What it is:** Classic DH with ephemeral keys, using standardized FFDHE groups (RFC 7919).
- **Status:** Secure with groups ≥ 2048 bits. Slower than ECDHE.
- **Where it appears:** TLS 1.2, SSH, IPsec.
- **In crypto-policies:** Present in all policies, with `min_dh_size` controlling the minimum size.

#### RSA Key Transport

- **What it is:** The client generates the session secret, encrypts it with the server's RSA public key, and sends it.
- **Status:** **Deprecated.** No forward secrecy — if the server's private key is compromised, all past sessions can be decrypted. Removed from TLS 1.3.
- **In crypto-policies:** DEFAULT keeps `RSA` in `key_exchange` for compatibility; FUTURE removes it.

#### PSK (Pre-Shared Key)

- **What it is:** Key previously shared between the parties (configured manually or derived from a previous session).
- **Variants:** Pure PSK, DHE-PSK (with forward secrecy), ECDHE-PSK.
- **Where it appears:** IoT, TLS resumption, point-to-point VPNs.

#### KEM (Key Encapsulation Mechanism)

- **What it is:** A more recent mechanism for key exchange, where one party "encapsulates" a key in a ciphertext that only the recipient can "decapsulate." Different from DH where both parties contribute.
- **Where it appears:** Post-quantum algorithms (ML-KEM/Kyber). See section J.10.

---

## J.9 Digital Signatures — "Mathematical Notary"

### The Concept

A digital signature proves three things:

1. **Authenticity:** The message came from the owner of the private key.
2. **Integrity:** The message was not altered after signing.
3. **Non-repudiation:** The signer cannot deny having signed (because only they possess the private key).

The process:
1. The signer computes the hash of the message.
2. The hash is "encrypted" with the private key (in reality, it is a specific mathematical signing operation).
3. Anyone with the public key can verify the signature.

### Signature Schemes in Crypto-Policies

Crypto-policies name signatures as `ALGORITHM-HASH`. Examples:

| Name in Policy | Meaning |
|----------------|---------|
| `RSA-SHA2-256` | RSA signature (PKCS#1 v1.5) with SHA-256 hash |
| `RSA-PSS-SHA2-256` | RSA-PSS signature with SHA-256 hash |
| `RSA-PSS-RSAE-SHA2-256` | RSA-PSS with key in RSAE format (backward compatible) |
| `ECDSA-SHA2-256` | ECDSA signature with SHA-256 hash |
| `ECDSA-SHA2-384` | ECDSA signature with SHA-384 hash |
| `EDDSA-ED25519` | EdDSA signature using Ed25519 curve (hash is intrinsic) |
| `EDDSA-ED448` | EdDSA signature using Ed448 curve |
| `DSA-SHA1` | DSA signature with SHA-1 hash (legacy) |
| `RSA-SHA1` | RSA signature with SHA-1 hash (legacy) |
| `ECDSA-SHA1` | ECDSA signature with SHA-1 hash (legacy) |

**Practical rule:** If the name contains `SHA1`, the signature is legacy and is being phased out. If it contains `PSS`, it is the modern RSA variant. If it starts with `EDDSA`, it is the most modern option.

---

## J.10 Post-Quantum Cryptography — "Preparing for the Future"

### The Problem

Sufficiently powerful quantum computers will be able to:

- **Break RSA** using Shor's algorithm (factoring).
- **Break ECC/DH** using Shor's algorithm (discrete logarithm).
- **Weaken hashes and symmetric ciphers** using Grover's algorithm (search) — reduces security by half (AES-256 falls to ~128 bits, still secure; AES-128 falls to ~64 bits, insecure).

The "harvest now, decrypt later" (HNDL) threat is already real: adversaries can capture encrypted traffic today and store it for decryption when quantum computers become available.

### Algorithms Standardized by NIST (2024)

#### ML-KEM (Module-Lattice-Based Key Encapsulation Mechanism)

- **Previous name:** CRYSTALS-Kyber.
- **Type:** Key exchange (KEM).
- **Mathematical problem:** Learning With Errors on lattices.
- **Variants:**
  - **ML-KEM-512:** ~128 bits of security (NIST level 1).
  - **ML-KEM-768:** ~192 bits of security (NIST level 3).
  - **ML-KEM-1024:** ~256 bits of security (NIST level 5).
- **Use in crypto-policies:** In **hybrid** mode — combined with a classical algorithm to maintain security even if PQ is broken:
  - `MLKEM768-X25519` — ML-KEM-768 + X25519
  - `P256-MLKEM768` — ML-KEM-768 + NIST P-256
  - `P384-MLKEM1024` — ML-KEM-1024 + NIST P-384
- **Status:** Present in RHEL DEFAULT as the first group in the list (highest priority).

#### ML-DSA (Module-Lattice-Based Digital Signature Algorithm)

- **Previous name:** CRYSTALS-Dilithium.
- **Type:** Digital signature.
- **Mathematical problem:** Learning With Errors on lattices.
- **Variants:**
  - **ML-DSA-44 (MLDSA44):** NIST level 2. Present in DEFAULT.
  - **ML-DSA-65 (MLDSA65):** NIST level 3. Present in DEFAULT.
  - **ML-DSA-87 (MLDSA87):** NIST level 5. Present in DEFAULT.
- **Signature size:** Significantly larger than ECDSA (~2.4 KB for ML-DSA-44 vs ~64 bytes for ECDSA-P256).

#### SLH-DSA (Stateless Hash-Based Digital Signature Algorithm)

- **Previous name:** SPHINCS+.
- **Type:** Hash-based digital signature (not lattice-based).
- **Advantage:** Security based solely on the security of hash functions — understood for decades. It is the "plan B" in case lattice-based schemes are broken.
- **Disadvantage:** Large (~7–49 KB) and slow signatures.
- **Variants in crypto-policies:** `SLHDSA-SHAKE-128S`, `SLHDSA-SHAKE-128F`, `SLHDSA-SHAKE-256S` — present in DEFAULT for Sequoia/RPM (OpenPGP).

### Other PQ Algorithms (Experimental)

| Algorithm | Type | Status |
|-----------|------|--------|
| **FALCON** | Signature (NTRU lattice) | NIST round 4. Smaller signatures than ML-DSA but complex implementation. |
| **NTRU Prime (SNTRUP761)** | KEM | Used in SSH (`sntrup761x25519-sha512@openssh.com`). Alternative to ML-KEM. |

### The Hybrid Approach Concept

PQ migration is being done in **hybrid** mode: each cryptographic operation combines a classical algorithm (e.g., X25519) with a PQ algorithm (e.g., ML-KEM-768). If the PQ algorithm turns out to be insecure, classical security remains. If quantum computers arrive, PQ provides protection.

---

## J.11 Key Derivation Functions (KDF) — "Manufacturing Keys from Secrets"

### The Concept

A KDF (Key Derivation Function) transforms an input secret (which can be weak, like a password, or strong, like the result of a key exchange) into one or more cryptographic keys suitable for use.

### Common KDFs

#### HKDF (HMAC-based Key Derivation Function)

- **What it is:** Standardized KDF (RFC 5869) based on HMAC. Two phases: Extract (compresses entropy) + Expand (generates key material).
- **Where it appears:** TLS 1.3 (derivation of all session keys), Signal Protocol, WireGuard.
- **Status:** Standard for key derivation from high-entropy secrets.

#### PBKDF2 (Password-Based Key Derivation Function 2)

- **What it is:** KDF designed to derive keys from **passwords** (low-entropy secrets). Applies HMAC repeatedly to make brute-force attacks slow.
- **Parameter:** Number of iterations (recommended ≥ 600,000 for SHA-256 as of 2024).
- **Where it appears:** WPA2 (Wi-Fi), LUKS1 (Linux disk encryption), PKCS#12, password storage.
- **Status:** Secure but inferior to Argon2. Vulnerable to GPU/ASIC attacks (the HMAC operation is efficient on parallel hardware).

#### bcrypt

- **What it is:** Password hashing function based on Blowfish (1999). Adjustable computational cost.
- **Where it appears:** Password storage in databases, `/etc/shadow` on many systems.
- **Status:** Secure. Resistant to GPU by design (requires random memory access).

#### scrypt

- **What it is:** KDF that requires large amounts of memory in addition to CPU, making attacks with specialized hardware more expensive.
- **Where it appears:** Some cryptocurrencies, LUKS2 (optional).

#### Argon2

- **What it is:** Winner of the Password Hashing Competition (2015). Three variants: Argon2d (GPU-resistant), Argon2i (side-channel resistant), Argon2id (hybrid, recommended).
- **Where it appears:** LUKS2 (default), modern password storage.
- **Status:** **Recommended for new implementations.** Superior to PBKDF2, bcrypt, and scrypt on all criteria.

---

## J.12 Secure Transport Protocols — "The Complete Envelope"

### The Concept

Secure transport protocols combine all the previous primitives into a complete secure communication system. A TLS protocol, for example, uses key exchange (ECDHE) to establish a secret, KDF (HKDF) to derive session keys, AEAD cipher (AES-GCM) to encrypt data, digital signature (ECDSA) to authenticate the server, and hash (SHA-256) for integrity.

### TLS (Transport Layer Security)

| Version | Status | Notes |
|---------|--------|-------|
| **SSL 2.0** (1995) | **Removed** | Multiple fatal vulnerabilities. Removed from libraries. |
| **SSL 3.0** (1996) | **Removed** | Vulnerable to POODLE. Removed from libraries. |
| **TLS 1.0** (1999) | **Deprecated** | Vulnerable to BEAST. Disabled in DEFAULT. |
| **TLS 1.1** (2006) | **Deprecated** | No specific known vulnerabilities, but no AEAD ciphersuites. Disabled in DEFAULT. |
| **TLS 1.2** (2008) | **Secure** | Supports AEAD (AES-GCM). Wide compatibility. Requires careful configuration. |
| **TLS 1.3** (2018) | **Recommended** | AEAD only. Faster handshake (1-RTT). Mandatory forward secrecy. No RSA key transport. |

**TLS 1.3 Ciphersuite:** The full name (e.g., `TLS_AES_256_GCM_SHA384`) indicates: protocol (TLS), AEAD cipher (AES-256-GCM), hash for HKDF (SHA-384). Key exchange is not part of the name because it is always ECDHE or DHE.

### DTLS (Datagram TLS)

- **What it is:** TLS adapted for UDP (connectionless transport). Necessary because TLS assumes TCP (ordered and reliable delivery).
- **Versions:** DTLS 1.0 (based on TLS 1.1), DTLS 1.2 (based on TLS 1.2).
- **Where it appears:** VoIP (SRTP), VPN (OpenConnect), IoT (CoAP).

### IKE (Internet Key Exchange)

| Version | Status | Notes |
|---------|--------|-------|
| **IKEv1** | **Deprecated** | Complex, multiple modes of operation, vulnerabilities. |
| **IKEv2** | **Recommended** | Simplified, more secure, supports MOBIKE (mobility). |

IKE is the protocol used by IPsec (VPN) to negotiate cryptographic parameters and establish Security Associations.

---

## J.13 Security Levels — "What 128 Bits of Security Means"

### The Concept

When we say a system has **N bits of security**, it means the best known attack requires approximately **2^N** operations. For reference:

| Bits | Operations | Feasibility |
|------|-----------|-------------|
| 64 | 2⁶⁴ ≈ 1.8 × 10¹⁹ | Breakable with dedicated hardware in months |
| 80 | 2⁸⁰ ≈ 1.2 × 10²⁴ | Marginal — agencies may have capability |
| 112 | 2¹¹² ≈ 5.2 × 10³³ | Secure for current use |
| 128 | 2¹²⁸ ≈ 3.4 × 10³⁸ | **Minimum recommended standard.** Unbreakable with foreseeable classical technology |
| 192 | 2¹⁹² ≈ 6.3 × 10⁵⁷ | Safety margin for decades |
| 256 | 2²⁵⁶ ≈ 1.2 × 10⁷⁷ | Secure even against quantum computers (for symmetric ciphers) |

### Equivalence Between Algorithms

| Security Level | Symmetric Cipher | Hash | RSA/DH | ECC | RHEL Policy |
|----------------|-----------------|------|--------|-----|-------------|
| 80 bits | 3DES | SHA-1 | 1024 | 160 | — |
| 112 bits | AES-128 | SHA-224 | 2048 | 224 | DEFAULT |
| 128 bits | AES-128 | SHA-256 | 3072 | 256 | FUTURE |
| 192 bits | AES-192 | SHA-384 | 7680 | 384 | — |
| 256 bits | AES-256 | SHA-512 | 15360 | 512 | — |

RHEL's DEFAULT policy targets 112 bits of security. The FUTURE policy targets 128 bits.

---

## J.14 Visual Summary — When to Use What

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHOOSING THE PRIMITIVE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Need to ENCRYPT data in bulk?                                   │
│  └─→ AES-256-GCM (with hardware) or ChaCha20-Poly1305 (without)│
│                                                                  │
│  Need to verify INTEGRITY without a key?                         │
│  └─→ SHA-256 (or SHA-512 on 64-bit)                             │
│                                                                  │
│  Need to verify integrity WITH authentication?                   │
│  └─→ HMAC-SHA256 (or use AEAD which already includes it)        │
│                                                                  │
│  Need to SIGN a document/certificate?                            │
│  └─→ Ed25519 (preferred) or ECDSA-P256 or RSA-PSS-SHA256       │
│                                                                  │
│  Need to EXCHANGE KEYS with someone?                             │
│  └─→ ECDHE with X25519 (or MLKEM768-X25519 for PQ)             │
│                                                                  │
│  Need to derive a key from a PASSWORD?                           │
│  └─→ Argon2id (preferred) or PBKDF2-SHA256                      │
│                                                                  │
│  Need to derive keys from a strong SECRET?                       │
│  └─→ HKDF-SHA256                                                 │
│                                                                  │
│  Need resistance to QUANTUM COMPUTERS?                           │
│  └─→ Hybrid approach: ML-KEM + ECDHE for key exchange,          │
│      ML-DSA for signatures, AES-256 for encryption               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## J.15 Quick Reference Table — Status of Each Algorithm

### Symmetric Ciphers

| Algorithm | Secure? | In Crypto-Policies? | Recommendation |
|-----------|---------|---------------------|----------------|
| AES-256-GCM | Yes | All | Preferred |
| AES-128-GCM | Yes | DEFAULT, LEGACY, FIPS | Acceptable |
| ChaCha20-Poly1305 | Yes | DEFAULT, FUTURE, LEGACY | Alternative to AES |
| AES-256-CBC | Yes (with EtM) | DEFAULT, LEGACY, FIPS (not in SSH/TLS) | Legacy, prefer GCM |
| AES-128-CBC | Yes (with EtM) | DEFAULT, LEGACY, FIPS (not in SSH) | Legacy, prefer GCM |
| Camellia-256-GCM | Yes | DEFAULT (not in TLS) | Rare |
| 3DES-CBC | Weak | LEGACY only | Migrate to AES |
| RC4 | Broken | None | Never use |
| DES | Broken | None | Never use |

### Hashes

| Algorithm | Secure? | In Crypto-Policies? | Recommendation |
|-----------|---------|---------------------|----------------|
| SHA-256 | Yes | All | Standard |
| SHA-384 | Yes | All | High security |
| SHA-512 | Yes | All | Maximum security |
| SHA3-256 | Yes | All | Alternative to SHA-256 |
| SHA-1 | Collisions | LEGACY (general), DEFAULT (HMAC/DNSSec only) | HMAC only |
| MD5 | Broken | LEGACY only (PKCS12/SMIME) | Never for security |

### Signatures

| Algorithm | Secure? | In Crypto-Policies? | Recommendation |
|-----------|---------|---------------------|----------------|
| Ed25519 | Yes | DEFAULT, FUTURE, FIPS | Preferred (SSH) |
| ECDSA-SHA2-256 | Yes | All | Preferred (certificates) |
| RSA-PSS-SHA2-256 | Yes | All | Preferred (RSA) |
| RSA-SHA2-256 | Yes | All | Acceptable |
| ML-DSA-65 | Yes (PQ) | All | Future |
| RSA-SHA1 | Weak | LEGACY, DEFAULT (DNSSec) | Migrate |
| DSA-SHA1 | Weak | LEGACY only | Never |

### Key Exchange

| Method | Forward Secrecy? | PQ-Secure? | Recommendation |
|--------|:----------------:|:----------:|----------------|
| ECDHE (X25519) | Yes | No | Current standard |
| MLKEM768-X25519 | Yes | Yes (hybrid) | Future |
| DHE (FFDHE-3072+) | Yes | No | Acceptable |
| RSA key transport | No | No | Deprecated |

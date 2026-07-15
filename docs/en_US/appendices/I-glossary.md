# Appendix I: Glossary

## Glossary of PKI & Certificate Terms

## A

**ACME (Automated Certificate Management Environment)**
Protocol (RFC 8555) for automated certificate issuance and renewal, popularised by Let's Encrypt.

**ASN.1 (Abstract Syntax Notation One)**
Data serialisation format used to encode X.509 certificates.

**Asymmetric Cryptography**
Public-key system where encryption/decryption use complementary key pairs (public and private).

## B

**Baseline Requirements**
CAB Forum rules that publicly-trusted CAs must follow (e.g., 398-day maximum validity).

## C

**CA (Certificate Authority)**
Entity that issues and signs digital certificates.

**CAB Forum (CA/Browser Forum)**
Industry consortium defining standards for publicly-trusted TLS certificates.

**Certificate Chain**
Sequence of certificates from end-entity -> intermediate(s) -> root CA.

**Certificate Policy (CP)**
High-level document describing what assurances a PKI provides.

**Certificate Revocation List (CRL)**
Signed list of revoked certificate serial numbers.

**Certificate Signing Request (CSR)**
Message requesting a CA to sign a public key, includes subject DN and extensions.

**Certificate Transparency (CT)**
Public log system (RFC 6962) that records all issued certificates for auditability.

**Certification Practice Statement (CPS)**
Detailed operational procedures of how a CA implements its CP.

**Cipher Suite**
Set of cryptographic algorithms used in TLS (e.g., key exchange, encryption, MAC).

**CN (Common Name)**
Field in certificate subject; historically held domain name, now superseded by SAN.

**Code Signing Certificate**
Certificate with `extKeyUsage: codeSigning` for authenticating software publishers.

## D

**DER (Distinguished Encoding Rules)**
Binary encoding of ASN.1, used for certificates in Java keystores and embedded systems.

**DH (Diffie-Hellman)**
Key-exchange algorithm allowing two parties to agree on a shared secret over insecure channel.

**DN (Distinguished Name)**
Hierarchical identifier in X.500 format (e.g., `/C=US/O=Example/CN=server.example.com`).

## E

**ECC (Elliptic Curve Cryptography)**
Public-key crypto using elliptic curves; offers smaller keys than RSA for equivalent security.

**ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)**
Key-exchange providing forward secrecy in TLS.

**ECDSA (Elliptic Curve Digital Signature Algorithm)**
Signature scheme based on elliptic curves.

**EKU (Extended Key Usage)**
X.509 extension specifying allowed certificate purposes (`serverAuth`, `clientAuth`, `codeSigning`, etc.).

**End-Entity Certificate**
Leaf certificate issued to servers, devices, or users (not a CA).

**EST (Enrollment over Secure Transport)**
RFC 7030 protocol for certificate enrollment, simpler than full SCEP.

## F

**FIPS 140-2**
U.S. government standard for cryptographic module security (Levels 1-5).

**Forward Secrecy**
Property ensuring past session keys remain secure even if long-term private key is compromised (achieved via ephemeral DH/ECDHE).

## H

**HSM (Hardware Security Module)**
Tamper-resistant device storing cryptographic keys and performing operations in hardware.

**HSTS (HTTP Strict Transport Security)**
Header forcing browsers to use HTTPS for a domain.

## I

**Intermediate CA**
CA certificate signed by root CA, used to issue end-entity certificates.

**Issuer**
DN of the CA that signed a certificate.

## J

**JWKS (JSON Web Key Set)**
Set of public keys in JSON format, often used with OAuth/OpenID Connect.

**JWT (JSON Web Token)**
Compact token format for transmitting claims; can be signed with RSA/ECDSA.

## K

**Key Escrow**
Practice of storing private keys with a third party; controversial for user privacy.

**Key Usage**
X.509 extension defining permitted cryptographic operations (`digitalSignature`, `keyEncipherment`, etc.).

**Keystore**
File storing private keys and certificates (e.g., Java JKS, PKCS#12).

## L

**LDAP (Lightweight Directory Access Protocol)**
Protocol for accessing directory services; often used to publish certificates and CRLs.

## M

**mTLS (Mutual TLS)**
TLS where both client and server present certificates for bidirectional authentication.

## N

**NSS (Network Security Services)**
Mozilla's crypto library used by Firefox; maintains its own trust store.

## O

**OCSP (Online Certificate Status Protocol)**
Real-time protocol (RFC 6960) for checking certificate revocation status.

**OCSP Stapling**
Server includes fresh OCSP response in TLS handshake, improving privacy and performance.

**OID (Object Identifier)**
Unique numeric identifier in ASN.1 (e.g., `2.5.29.17` for SAN extension).

## P

**PEM (Privacy Enhanced Mail)**
Base64-encoded DER with `-----BEGIN CERTIFICATE-----` headers.

**PFX**
See PKCS#12.

**PIN (Public Key Pinning)**
Mechanism to associate domain with specific public key(s); deprecated in browsers due to operational risks.

**PKI (Public Key Infrastructure)**
System of hardware, software, policies, and procedures for managing digital certificates.

**PKCS (Public-Key Cryptography Standards)**
Family of standards by RSA Labs (PKCS#1-15).

**PKCS#7**
Container format for certificates and CRLs (no private key).

**PKCS#12**
Archive format bundling certificate + private key + chain, password-protected (`.p12`, `.pfx`).

## R

**RA (Registration Authority)**
Entity validating identity before forwarding CSR to CA.

**Root CA**
Self-signed CA at top of hierarchy; embedded in OS/browser trust stores.

**RSA (Rivest-Shamir-Adleman)**
Widely-used public-key algorithm based on integer factorisation.

## S

**SAN (Subject Alternative Name)**
X.509 extension listing additional identities (DNS names, IPs, URIs).

**SCT (Signed Certificate Timestamp)**
Proof from CT log that certificate has been logged.

**Self-Signed Certificate**
Certificate where issuer == subject; not trusted by default.

**Serial Number**
Unique identifier assigned by CA to each certificate.

**SHA-256 / SHA-384**
Cryptographic hash functions (part of SHA-2 family).

**SPIFFE (Secure Production Identity Framework For Everyone)**
Standard for workload identity in dynamic environments; uses URI SANs (`spiffe://trust-domain/workload`).

**SSL (Secure Sockets Layer)**
Deprecated predecessor to TLS.

## T

**TLS (Transport Layer Security)**
Cryptographic protocol for secure network communication (current versions: 1.2, 1.3).

**TPM (Trusted Platform Module)**
Hardware chip for secure key storage on devices.

**Trust Anchor**
Root certificate implicitly trusted by a system.

**Trust Store**
Collection of trusted root CA certificates (e.g., `/etc/pki/ca-trust`, Windows Certificate Store).

## V

**VA (Validation Authority)**
Component handling OCSP/CRL queries.

## W

**Wildcard Certificate**
Certificate covering `*.example.com` (matches `app.example.com`, not `sub.app.example.com`).

## X

**X.509**
ITU-T standard defining certificate format (RFC 5280 is IETF version).

## Z

**Zero Trust**
Security model assuming no implicit trust; every request authenticated and authorised.

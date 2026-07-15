# Apéndice I: Glosario

## Glosario de Términos PKI y Certificados

## A

**ACME (Automated Certificate Management Environment)**
Protocolo (RFC 8555) para emisión y renovación automatizada de certificados, popularizado por Let's Encrypt.

**ASN.1 (Abstract Syntax Notation One)**
Formato de serialización de datos usado para codificar certificados X.509.

**Asymmetric Cryptography (Criptografía Asimétrica)**
Sistema de clave pública donde cifrado/descifrado usan pares de claves complementarias (pública y privada).

## B

**Baseline Requirements (Requisitos de Línea Base)**
Reglas CAB Forum que las CAs públicamente confiables deben seguir (ej., validez máxima 398 días).

## C

**CA (Certificate Authority / Autoridad Certificadora)**
Entidad que emite y firma certificados digitales.

**CAB Forum (CA/Browser Forum)**
Consorcio industrial que define estándares para certificados TLS públicamente confiables.

**Certificate Chain (Cadena de Certificado)**
Secuencia de certificados desde entidad final → intermedio(s) → CA raíz.

**Certificate Policy (CP / Política de Certificado)**
Documento de alto nivel describiendo qué aseguramientos proporciona una PKI.

**Certificate Revocation List (CRL / Lista de Revocación de Certificados)**
Lista firmada de números seriales de certificados revocados.

**Certificate Signing Request (CSR / Solicitud de Firma de Certificado)**
Mensaje solicitando a una CA firmar una clave pública, incluye DN del sujeto y extensiones.

**Certificate Transparency (CT / Transparencia de Certificado)**
Sistema de log público (RFC 6962) que registra todos los certificados emitidos para auditabilidad.

**Certification Practice Statement (CPS / Declaración de Prácticas de Certificación)**
Procedimientos operacionales detallados de cómo una CA implementa su CP.

**Cipher Suite (Suite de Cifrado)**
Conjunto de algoritmos criptográficos usados en TLS (ej., intercambio de clave, cifrado, MAC).

**CN (Common Name / Nombre Común)**
Campo en sujeto del certificado; históricamente contenía nombre de dominio, ahora reemplazado por SAN.

**Code Signing Certificate (Certificado de Firma de Código)**
Certificado con `extKeyUsage: codeSigning` para autenticar publicadores de software.

## D

**DER (Distinguished Encoding Rules)**
Codificación binaria de ASN.1, usado para certificados en keystores Java y sistemas embebidos.

**DH (Diffie-Hellman)**
Algoritmo de intercambio de clave permitiendo a dos partes acordar un secreto compartido sobre canal inseguro.

**DN (Distinguished Name / Nombre Distinguido)**
Identificador jerárquico en formato X.500 (ej., `/C=US/O=Example/CN=server.example.com`).

## E

**ECC (Elliptic Curve Cryptography / Criptografía de Curva Elíptica)**
Criptografía de clave pública usando curvas elípticas; ofrece claves más pequeñas que RSA para seguridad equivalente.

**ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)**
Intercambio de clave proporcionando forward secrecy en TLS.

**ECDSA (Elliptic Curve Digital Signature Algorithm)**
Esquema de firma basado en curvas elípticas.

**EKU (Extended Key Usage / Uso Extendido de Clave)**
Extensión X.509 especificando propósitos permitidos del certificado (`serverAuth`, `clientAuth`, `codeSigning`, etc.).

**End-Entity Certificate (Certificado de Entidad Final)**
Certificado hoja emitido a servidores, dispositivos o usuarios (no una CA).

**EST (Enrollment over Secure Transport)**
Protocolo RFC 7030 para inscripción de certificado, más simple que SCEP completo.

## F

**FIPS 140-2**
Estándar del gobierno de EE.UU. para seguridad de módulo criptográfico (Niveles 1-5).

**Forward Secrecy (Secreto Hacia Adelante)**
Propiedad asegurando que claves de sesión pasadas permanezcan seguras incluso si clave privada de largo plazo es comprometida (logrado vía DH/ECDHE efímero).

## H

**HSM (Hardware Security Module / Módulo de Seguridad de Hardware)**
Dispositivo resistente a manipulación almacenando claves criptográficas y realizando operaciones en hardware.

**HSTS (HTTP Strict Transport Security)**
Encabezado forzando navegadores a usar HTTPS para un dominio.

## I

**Intermediate CA (CA Intermedia)**
Certificado CA firmado por CA raíz, usado para emitir certificados de entidad final.

**Issuer (Emisor)**
DN de la CA que firmó un certificado.

## J

**JWKS (JSON Web Key Set)**
Conjunto de claves públicas en formato JSON, a menudo usado con OAuth/OpenID Connect.

**JWT (JSON Web Token)**
Formato de token compacto para transmitir claims; puede firmarse con RSA/ECDSA.

## K

**Key Escrow (Custodia de Clave)**
Práctica de almacenar claves privadas con tercero; controversial para privacidad de usuario.

**Key Usage (Uso de Clave)**
Extensión X.509 definiendo operaciones criptográficas permitidas (`digitalSignature`, `keyEncipherment`, etc.).

**Keystore**
Archivo almacenando claves privadas y certificados (ej., Java JKS, PKCS#12).

## L

**LDAP (Lightweight Directory Access Protocol)**
Protocolo para acceder servicios de directorio; a menudo usado para publicar certificados y CRLs.

## M

**mTLS (Mutual TLS / TLS Mutuo)**
TLS donde tanto cliente como servidor presentan certificados para autenticación bidireccional.

## N

**NSS (Network Security Services)**
Biblioteca crypto de Mozilla usada por Firefox; mantiene su propio almacén de confianza.

## O

**OCSP (Online Certificate Status Protocol)**
Protocolo en tiempo real (RFC 6960) para verificar estado de revocación de certificado.

**OCSP Stapling**
El servidor incluye respuesta OCSP fresca en handshake TLS, mejorando privacidad y rendimiento.

**OID (Object Identifier / Identificador de Objeto)**
Identificador numérico único en ASN.1 (ej., `2.5.29.17` para extensión SAN).

## P

**PEM (Privacy Enhanced Mail)**
DER codificado en Base64 con encabezados `-----BEGIN CERTIFICATE-----`.

**PFX**
Ver PKCS#12.

**PIN (Public Key Pinning / Anclaje de Clave Pública)**
Mecanismo para asociar dominio con clave(s) pública(s) específica(s); obsoleto en navegadores debido a riesgos operacionales.

**PKI (Public Key Infrastructure / Infraestructura de Clave Pública)**
Sistema de hardware, software, políticas y procedimientos para gestionar certificados digitales.

**PKCS (Public-Key Cryptography Standards)**
Familia de estándares por RSA Labs (PKCS#1–15).

**PKCS#7**
Formato contenedor para certificados y CRLs (sin clave privada).

**PKCS#12**
Formato archivo empaquetando certificado + clave privada + cadena, protegido por contraseña (`.p12`, `.pfx`).

## R

**RA (Registration Authority / Autoridad de Registro)**
Entidad validando identidad antes de reenviar CSR a CA.

**Root CA (CA Raíz)**
CA autofirmada en cima de jerarquía; embebida en almacenes de confianza OS/navegador.

**RSA (Rivest–Shamir–Adleman)**
Algoritmo de clave pública ampliamente usado basado en factorización de enteros.

## S

**SAN (Subject Alternative Name / Nombre Alternativo del Sujeto)**
Extensión X.509 listando identidades adicionales (nombres DNS, IPs, URIs).

**SCT (Signed Certificate Timestamp)**
Prueba de log CT de que certificado ha sido registrado.

**Self-Signed Certificate (Certificado Autofirmado)**
Certificado donde emisor == sujeto; no confiable por defecto.

**Serial Number (Número Serial)**
Identificador único asignado por CA a cada certificado.

**SHA-256 / SHA-384**
Funciones hash criptográficas (parte de familia SHA-3).

**SPIFFE (Secure Production Identity Framework For Everyone)**
Estándar para identidad de carga de trabajo en entornos dinámicos; usa SANs URI (`spiffe://trust-domain/workload`).

**SSL (Secure Sockets Layer)**
Predecesor obsoleto de TLS.

## T

**TLS (Transport Layer Security)**
Protocolo criptográfico para comunicación de red segura (versiones actuales: 1.2, 1.3).

**TPM (Trusted Platform Module / Módulo de Plataforma Confiable)**
Chip de hardware para almacenamiento seguro de clave en dispositivos.

**Trust Anchor (Ancla de Confianza)**
Certificado raíz implícitamente confiable por un sistema.

**Almacén de Confianza (Trust Store)**
Colección de certificados CA raíz confiables (ej., `/etc/pki/ca-trust`, Windows Certificate Store).

## V

**VA (Validation Authority / Autoridad de Validación)**
Componente manejando consultas OCSP/CRL.

## W

**Wildcard Certificate (Certificado Comodín)**
Certificado cubriendo `*.example.com` (coincide `app.example.com`, no `sub.app.example.com`).

## X

**X.509**
Estándar ITU-T definiendo formato de certificado (RFC 5280 es versión IETF).

## Z

**Zero Trust (Confianza Cero)**
Modelo de seguridad asumiendo ninguna confianza implícita; cada solicitud autenticada y autorizada.

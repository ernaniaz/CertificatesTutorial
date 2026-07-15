# Apéndice J: Referencias

## Referencias y Lectura Adicional

Lista curada de recursos autoritativos para profundizar tu conocimiento de PKI y certificados.

## Estándares y RFCs

### Estándares PKI Core
- **RFC 5280** — Internet X.509 Public Key Infrastructure Certificate and CRL Profile
  [https://datatracker.ietf.org/doc/html/rfc5280](https://datatracker.ietf.org/doc/html/rfc5280)

- **RFC 6960** — Online Certificate Status Protocol (OCSP)
  [https://datatracker.ietf.org/doc/html/rfc6960](https://datatracker.ietf.org/doc/html/rfc6960)

- **RFC 6962** — Certificate Transparency
  [https://datatracker.ietf.org/doc/html/rfc6962](https://datatracker.ietf.org/doc/html/rfc6962)

- **RFC 8555** — Automatic Certificate Management Environment (ACME)
  [https://datatracker.ietf.org/doc/html/rfc8555](https://datatracker.ietf.org/doc/html/rfc8555)

- **RFC 7030** — Enrollment over Secure Transport (EST)
  [https://datatracker.ietf.org/doc/html/rfc7030](https://datatracker.ietf.org/doc/html/rfc7030)

### TLS/SSL
- **RFC 8446** — The Transport Layer Security (TLS) Protocol Version 1.3
  [https://datatracker.ietf.org/doc/html/rfc8446](https://datatracker.ietf.org/doc/html/rfc8446)

- **RFC 6125** — Representation and Verification of Domain-Based Application Service Identity
  [https://datatracker.ietf.org/doc/html/rfc6125](https://datatracker.ietf.org/doc/html/rfc6125)

### Algoritmos Criptográficos
- **RFC 3447** — RSA Cryptography Specifications (PKCS #1 v2.1)
  [https://datatracker.ietf.org/doc/html/rfc3447](https://datatracker.ietf.org/doc/html/rfc3447)

- **RFC 6090** — Fundamental Elliptic Curve Cryptography Algorithms
  [https://datatracker.ietf.org/doc/html/rfc6090](https://datatracker.ietf.org/doc/html/rfc6090)

- **FIPS 186-5** — Digital Signature Standard (DSS)
  [https://csrc.nist.gov/publications/detail/fips/186/5/final](https://csrc.nist.gov/publications/detail/fips/186/5/final)

## Guías de Industria

### CA/Browser Forum
- **Baseline Requirements for TLS Certificates**
  [https://cabforum.org/baseline-requirements-documents/](https://cabforum.org/baseline-requirements-documents/)

- **EV SSL Certificate Guidelines**
  [https://cabforum.org/extended-validation/](https://cabforum.org/extended-validation/)

### Publicaciones NIST
- **SP 800-57** — Recommendation for Key Management
  [https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)

- **SP 800-207** — Zero Trust Architecture
  [https://csrc.nist.gov/publications/detail/sp/800-207/final](https://csrc.nist.gov/publications/detail/sp/800-207/final)

- **SP 800-52 Rev. 2** — Guidelines for TLS Implementations
  [https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final](https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final)

### Estándares ETSI
- **ETSI EN 319 411-1** — Policy and security requirements for Trust Service Providers issuing certificates
  [https://www.etsi.org/standards](https://www.etsi.org/standards)

## Libros

### Fundamentales
- **"Network Security with OpenSSL"** por Pravir Chandra, Matt Messier, John Viega
  O'Reilly, 2002 — Guía integral de OpenSSL

- **"PKI Uncovered"** por Andre Karamanian, Siva Sathianathan
  Cisco Press, 2011 — Patrones de diseño PKI empresarial

- **"Bulletproof SSL and TLS"** por Ivan Ristić
  Feisty Duck, 2022 — Guía autoritativa para desplegar TLS correctamente

### Avanzados
- **"Serious Cryptography"** por Jean-Philippe Aumasson
  No Starch Press, 2017 — Algoritmos y protocolos criptográficos modernos

- **"Applied Cryptography"** por Bruce Schneier
  Wiley, 1996 — Texto clásico sobre protocolos criptográficos

## Recursos en Línea

### Documentación
- **OpenSSL Documentation**
  [https://www.openssl.org/docs/](https://www.openssl.org/docs/)

- **Let's Encrypt Documentation**
  [https://letsencrypt.org/docs/](https://letsencrypt.org/docs/)

- **cert-manager Documentation**
  [https://cert-manager.io/docs/](https://cert-manager.io/docs/)

- **HashiCorp Vault PKI Secrets Engine**
  [https://www.vaultproject.io/docs/secrets/pki](https://www.vaultproject.io/docs/secrets/pki)

- **FreeIPA Documentation**
  [https://www.freeipa.org/page/Documentation](https://www.freeipa.org/page/Documentation)

### Herramientas de Prueba
- **SSL Labs Server Test**
  [https://www.ssllabs.com/ssltest/](https://www.ssllabs.com/ssltest/)
  Probar configuración de servidor HTTPS y cadena de certificado

- **testssl.sh**
  [https://testssl.sh/](https://testssl.sh/)
  Herramienta de prueba TLS/SSL de línea de comandos

- **crt.sh — Certificate Search**
  [https://crt.sh/](https://crt.sh/)
  Consultar logs de Certificate Transparency

- **Hardenize**
  [https://www.hardenize.com/](https://www.hardenize.com/)
  Escáner comprehensivo TLS/PKI

### Tutoriales y Blogs
- **Cloudflare Learning Center — SSL/TLS**
  [https://www.cloudflare.com/learning/ssl/](https://www.cloudflare.com/learning/ssl/)

- **Mozilla SSL Configuration Generator**
  [https://ssl-config.mozilla.org/](https://ssl-config.mozilla.org/)
  Generar configuraciones TLS seguras para servidores comunes

- **PKI Solutions Blog**
  [https://pkisolutions.com/blog/](https://pkisolutions.com/blog/)
  Perspectivas PKI empresarial

## Videos y Cursos

- **"Public Key Cryptography" (Khan Academy)**
  Introducción a RSA e intercambio de clave

- **"How HTTPS Works" (Cloudflare YouTube)**
  Explicación animada de handshake TLS

- **Pluralsight — "PKI Architecture and Implementation"**
  Curso de video comprehensivo sobre PKI empresarial

## Software y Herramientas

### Software CA
- **OpenSSL** — [https://www.openssl.org/](https://www.openssl.org/)
- **FreeIPA** — [https://www.freeipa.org/](https://www.freeipa.org/)
- **EJBCA** — [https://www.ejbca.org/](https://www.ejbca.org/)
- **step-ca** — [https://smallstep.com/docs/step-ca](https://smallstep.com/docs/step-ca)
- **HashiCorp Vault** — [https://www.vaultproject.io/](https://www.vaultproject.io/)

### Gestión de Certificados
- **cert-manager** (Kubernetes) — [https://cert-manager.io/](https://cert-manager.io/)
- **Certbot** (cliente ACME) — [https://certbot.eff.org/](https://certbot.eff.org/)
- **certmonger** (RHEL) — [https://pagure.io/certmonger](https://pagure.io/certmonger)
- **Venafi** (Empresarial) — [https://www.venafi.com/](https://www.venafi.com/)

### Bibliotecas
- **BouncyCastle** (Java/C#) — [https://www.bouncycastle.org/](https://www.bouncycastle.org/)
- **cryptography** (Python) — [https://cryptography.io/](https://cryptography.io/)
- **Go crypto/x509** — [https://pkg.go.dev/crypto/x509](https://pkg.go.dev/crypto/x509)

## Comunidades y Foros

- **Let's Encrypt Community Forum**
  [https://community.letsencrypt.org/](https://community.letsencrypt.org/)

- **r/crypto (Reddit)**
  [https://www.reddit.com/r/crypto/](https://www.reddit.com/r/crypto/)

- **r/netsec (Reddit)**
  [https://www.reddit.com/r/netsec/](https://www.reddit.com/r/netsec/)

- **IETF TLS Working Group**
  [https://datatracker.ietf.org/wg/tls/about/](https://datatracker.ietf.org/wg/tls/about/)

## Artículos de Investigación

- **"The Most Dangerous Code in the World"** (Martin et al., 2012)
  Análisis de vulnerabilidades de validación de certificado SSL

- **"Analysis of the HTTPS Certificate Ecosystem"** (Durumeric et al., IMC 2013)
  Estudio a gran escala de despliegue TLS

- **"SoK: SSL and HTTPS Revisiting past challenges and evaluating certificate trust model enhancements"** (Clark & van Oorschot, S&P 2013)

## Marcos de Cumplimiento

- **PCI DSS** — Payment Card Industry Data Security Standard
  [https://www.pcisecuritystandards.org/](https://www.pcisecuritystandards.org/)

- **HIPAA** — Health Insurance Portability and Accountability Act
  [https://www.hhs.gov/hipaa/](https://www.hhs.gov/hipaa/)

- **SOC 2** — Service Organization Control 2
  [https://www.aicpa.org/](https://www.aicpa.org/)

- **eIDAS** — EU electronic identification and trust services
  [https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation)

---

> **Mantenerse Actualizado:** Los estándares PKI y TLS evolucionan continuamente. Suscríbete a la lista de correo del grupo de trabajo TLS de IETF y sigue avisos de seguridad de tu CA y proveedores de software.

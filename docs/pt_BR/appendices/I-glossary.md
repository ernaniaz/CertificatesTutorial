# Apêndice I: Glossário

## Glossário de Termos PKI e Certificados

## A

**ACME (Automated Certificate Management Environment)**
Protocolo (RFC 8555) para emissão e renovação certificado automatizadas, popularizado pelo Let's Encrypt.

**ASN.1 (Abstract Syntax Notation One)**
Formato de serialização de dados usado para codificar certificados X.509.

**Criptografia Assimétrica**
Sistema de chave pública onde criptografia/descriptografia usam pares de chave complementares (pública e privada).

## B

**Baseline Requirements**
Regras CA/B Forum que CAs publicamente confiáveis devem seguir (ex: validade máxima 398 dias).

## C

**Autoridade certificadora (CA)**
Entidade que emite e assina certificados digitais.

**CAB Forum (CA/Browser Forum)**
Consórcio de indústria definindo padrões para certificados TLS publicamente confiáveis.

**Cadeia Certificados**
Sequência de certificados de entidade-final → intermediário(s) → CA raiz.

**Certificate Policy (CP)**
Documento de alto nível descrevendo quais garantias uma PKI fornece.

**Certificate Revocation List (CRL)**
Lista assinada de números seriais de certificados revogados.

**Certificate Signing Request (CSR)**
Mensagem solicitando que CA assine chave pública, inclui DN subject e extensões.

**Certificate Transparency (CT)**
Sistema de log público (RFC 6962) que registra todos certificados emitidos para auditabilidade.

**Certification Practice Statement (CPS)**
Procedimentos operacionais detalhados de como CA implementa seu CP.

**Cipher Suite**
Conjunto de algoritmos criptográficos usados em TLS (ex: troca de chave, criptografia, MAC).

**CN (Common Name)**
Campo subject do certificado; historicamente continha nome do domínio, agora superado por SAN.

**Certificado Code Signing**
Certificado com `extKeyUsage: codeSigning` para autenticar publicadores de software.

## D

**DER (Distinguished Encoding Rules)**
Codificação binária de ASN.1, usado para certificados em keystores Java e sistemas embarcados.

**DH (Diffie-Hellman)**
Algoritmo de troca de chave permitindo duas partes concordarem em segredo compartilhado sobre canal inseguro.

**DN (Distinguished Name)**
Identificador hierárquico em formato X.500 (ex: `/C=US/O=Example/CN=server.example.com`).

## E

**ECC (Elliptic Curve Cryptography)**
Crypto de chave pública usando curvas elípticas; oferece chaves menores que RSA para segurança equivalente.

**ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)**
Troca de chave fornecendo forward secrecy em TLS.

**ECDSA (Elliptic Curve Digital Signature Algorithm)**
Esquema de assinatura baseado em curvas elípticas.

**EKU (Extended Key Usage)**
Extensão X.509 especificando propósitos permitidos do certificado (`serverAuth`, `clientAuth`, `codeSigning`, etc.).

**Certificado End-Entity**
Certificado folha emitido para servidores, dispositivos ou usuários (não CA).

**EST (Enrollment over Secure Transport)**
Protocolo RFC 7030 para enrollment de certificado, mais simples que SCEP completo.

## F

**FIPS 140-2**
Padrão do governo Norte Americano para segurança de módulo criptográfico (Níveis 1-5).

**Forward Secrecy**
Propriedade garantindo que chaves de sessão passadas permanecem seguras mesmo se chave privada de longo prazo for comprometida (alcançado via DH/ECDHE ephemeral).

## H

**HSM (Hardware Security Module)**
Dispositivo resistente à adulteração armazenando chaves criptográficas e executando operações em hardware.

**HSTS (HTTP Strict Transport Security)**
Cabeçalho forçando navegadores a usar HTTPS para domínio.

## I

**CA Intermediária**
Certificado CA assinado por CA raiz, usado para emitir certificados entidade-final.

**Emissor**
DN da CA que assinou o certificado.

## J

**JWKS (JSON Web Key Set)**
Conjunto de chaves públicas em formato JSON, frequentemente usado com OAuth/OpenID Connect.

**JWT (JSON Web Token)**
Formato de token compacto para transmitir claims; pode ser assinado com RSA/ECDSA.

## K

**Key Escrow**
Prática de armazenar chaves privadas com terceiro; controverso para privacidade do usuário.

**Key Usage**
Extensão X.509 definindo operações criptográficas permitidas (`digitalSignature`, `keyEncipherment`, etc.).

**Keystore**
Arquivo armazenando chaves privadas e certificados (ex: Java JKS, PKCS#12).

## L

**LDAP (Lightweight Directory Access Protocol)**
Protocolo para acessar serviços de diretório; frequentemente usado para publicar certificados e CRLs.

## M

**mTLS (Mutual TLS)**
TLS onde ambos cliente e servidor apresentam certificados para autenticação bidirecional.

## N

**NSS (Network Security Services)**
Biblioteca de crypto Mozilla usada pelo Firefox; mantém seu próprio repositório de confiança.

## O

**OCSP (Online Certificate Status Protocol)**
Protocolo de tempo real (RFC 6960) para verificar status de revogação de certificado.

**OCSP Stapling**
Servidor inclui resposta OCSP fresca em handshake TLS, melhorando privacidade e desempenho.

**OID (Object Identifier)**
Identificador numérico único em ASN.1 (ex: `2.5.29.17` para extensão SAN).

## P

**PEM (Privacy Enhanced Mail)**
DER codificado em base64 com headers `-----BEGIN CERTIFICATE-----`.

**PFX**
Ver PKCS#12.

**PIN (Public Key Pinning)**
Mecanismo para associar domínio com chave(s) pública(s) específica(s); depreciado em navegadores devido à riscos operacionais.

**PKI (Public Key Infrastructure)**
Sistema de hardware, software, políticas e procedimentos para gerenciar certificados digitais.

**PKCS (Public-Key Cryptography Standards)**
Família de padrões da RSA Labs (PKCS#1–15).

**PKCS#7**
Formato de container para certificados e CRLs (sem chave privada).

**PKCS#12**
Formato de arquivo empacotando certificado + chave privada + cadeia, protegido por senha (`.p12`, `.pfx`).

## R

**RA (Registration Authority)**
Entidade validando identidade antes de encaminhar CSR para CA.

**CA Raiz**
CA auto-assinada no topo da hierarquia; embutida em repositórios de confiança do SO/navegador.

**RSA (Rivest–Shamir–Adleman)**
Algoritmo de chave pública amplamente usado baseado em fatoração de inteiros.

## S

**SAN (Subject Alternative Name)**
Extensão X.509 listando identidades adicionais (nomes DNS, IPs, URIs).

**SCT (Signed Certificate Timestamp)**
Prova de log CT que certificado foi logado.

**Certificado Autoassinado**
Certificado onde emissor == subject; não confiável por padrão.

**Número Serial**
Identificador único atribuído por CA a cada certificado.

**SHA-256 / SHA-384**
Funções hash criptográficas (parte da família SHA-3).

**SPIFFE (Secure Production Identity Framework For Everyone)**
Padrão para identidade de carga de trabalho em ambientes dinâmicos; usa SANs URI (`spiffe://trust-domain/workload`).

**SSL (Secure Sockets Layer)**
Predecessor depreciado do TLS.

## T

**TLS (Transport Layer Security)**
Protocolo criptográfico para comunicação de rede segura (versões atuais: 1.2, 1.3).

**TPM (Trusted Platform Module)**
Hardware para armazenamento de chave segura em dispositivos.

**Trust Anchor**
Certificado raiz implicitamente confiável pelo sistema.

**Repositório de Confiança**
Coleção de certificados CA raiz confiáveis (ex: `/etc/pki/ca-trust`, Windows Certificate Store).

## V

**VA (Validation Authority)**
Componente que lida com consultas OCSP/CRL.

## W

**Certificado Wildcard**
Certificado cobrindo `*.example.com` (coincide `app.example.com`, não `sub.app.example.com`).

## X

**X.509**
Padrão ITU-T definindo formato de certificado (RFC 5280 é versão IETF).

## Z

**Zero Trust**
Modelo de segurança sem assumir confiança implícita; cada requisição é autenticada e autorizada.

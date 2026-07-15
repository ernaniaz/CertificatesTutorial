# Lab 20: Endurecimento de Segurança para Certificados

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Endurecer configurações SSL/TLS do Apache e NGINX
- Desabilitar protocolos e cifras fracos
- Implementar cabeçalhos de segurança
- Aplicar TLS 1.3
- Configurar HSTS
- Aplicar boas práticas de segurança

## Pré-requisitos

- **Labs 01-10** concluídos
- **RHEL 8 ou 9** recomendado
- **Acesso ao sistema:** Root/sudo necessário
- **Apache ou NGINX** instalado

## Tempo estimado

**30-40 minutos**

## Visão geral

Aprenda a aplicar boas práticas de endurecimento de segurança em configurações de certificados, garantindo máxima proteção contra ataques e vulnerabilidades conhecidos.

---

## Instruções

### Passo 1: Endurecer Apache

```bash
sudo ./harden-apache.sh
```

### Passo 2: Endurecer NGINX

```bash
sudo ./harden-nginx.sh
```

### Passo 3: Desabilitar protocolos fracos

```bash
sudo ./disable-weak-protocols.sh
```

### Passo 4: Aplicar TLS 1.3

```bash
sudo ./enforce-tls13.sh
```

### Passo 5: Configurar HSTS

```bash
sudo ./enable-hsts.sh
```

### Passo 6: Auditar configuração

```bash
./audit-security.sh
```

---

## Boas práticas de segurança

### Versões de protocolo TLS
- ✅ TLS 1.3 (melhor)
- ✅ TLS 1.2 (aceitável)
- ❌ TLS 1.1 (obsoleto)
- ❌ TLS 1.0 (inseguro)
- ❌ SSLv3 (vulnerável)

### Conjuntos de cifras
Use cifras com forward secrecy:
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-RSA-CHACHA20-POLY1305

### Cabeçalhos de segurança
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
```

---

## Validação

Verifique endurecimento de segurança:

```bash
./audit-security.sh
```

**Resultados esperados:**
- ✓ Se `/etc/httpd/conf.d/ssl-hardening.conf` existir, `./audit-security.sh` reporta a configuração de endurecimento do Apache
- ✓ Se `/etc/nginx/conf.d/ssl-hardening.conf` existir, `./audit-security.sh` reporta a configuração de endurecimento do NGINX
- ✓ O script mostra um resumo pass/fail para os arquivos drop-in de endurecimento presentes no sistema

**Testes manuais adicionais:**
```bash
# Testar versão TLS
openssl s_client -connect localhost:443 -tls1
# Deve falhar

# Testar TLS 1.2
openssl s_client -connect localhost:443 -tls1_2
# Deve ter sucesso

# Verificar cabeçalhos
curl -I https://localhost
# Deve incluir HSTS e cabeçalhos de segurança

# Verificar força das cifras
nmap --script ssl-enum-ciphers -p 443 localhost
```

---

## Limpeza

```bash
sudo ./cleanup.sh
```

---

**Nível de dificuldade:** Avançado

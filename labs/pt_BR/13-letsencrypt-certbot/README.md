# Lab 13: Let's Encrypt com Certbot

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar Certbot para protocolo ACME
- Obter certificados do Let's Encrypt
- Configurar renovação automática
- Integrar com Apache e NGINX
- Testar processo de renovação
- Configurar timers systemd para automação
- Entender tipos de desafio ACME

## Pré-requisitos

- **Labs 01-06** concluídos (conhecimento de Apache ou NGINX)
- **Versão do RHEL:** 8, 9 ou 10 (RHEL 7 não é suportado)
- **Acesso ao sistema:** Root/sudo necessário
- **Conexão com internet** necessária
- **Domínio público** (ou use staging para testes)

## Tempo estimado

**40-50 minutos**

## Visão geral

Let's Encrypt é uma Certificate Authority gratuita e automatizada. Aprenda a usar Certbot para obter e renovar automaticamente certificados confiáveis usando o protocolo ACME, eliminando o gerenciamento manual de certificados.

---

## Instruções

### Passo 1: Instale o Certbot

Instale o Certbot:

```bash
sudo ./install-certbot.sh
```

Isso instala:
- Ferramenta de linha de comando `certbot`
- Plugins de servidor web (se disponíveis)
- Dependências

---

### Passo 2: Obtenha certificado (Standalone)

Obtenha certificado usando modo standalone:

```bash
sudo ./obtain-standalone.sh
```

Isso:
- Para servidores web temporariamente
- Executa servidor web integrado
- Completa desafio HTTP-01
- Obtém certificado

---

### Passo 3: Obtenha certificado (Apache/NGINX)

Obtenha certificado com integração ao servidor web:

```bash
sudo ./obtain-webserver.sh
```

Isso:
- Integra com servidor web em execução
- Configura HTTPS automaticamente
- Sem tempo de inatividade
- Testa configuração

---

### Passo 4: Teste renovação

Teste processo de renovação de certificado:

```bash
sudo ./test-renewal.sh
```

Isso testa:
- Renovação em dry-run
- Hooks de renovação
- Validação de configuração
- Tratamento de erros

---

### Passo 5: Configure renovação automática

Configure renovação automática:

```bash
sudo ./setup-autorenewal.sh
```

Isso configura:
- Timer systemd
- Hooks de renovação
- Notificações por e-mail

---

### Passo 6: Verifique a configuração

Execute a validação abrangente:

```bash
sudo ./verify.sh
```

---

## Validação

```bash
sudo ./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ Certbot instalado
- ✅ Certificado Let's Encrypt obtido
- ✅ Renovação automática configurada
- ✅ Servidor web configurado
- ✅ Compreensão do protocolo ACME

---

## Conceitos-chave

### Visão geral do Let's Encrypt

**O que é:**
- Certificate Authority gratuita e automatizada
- Usa protocolo ACME
- Confiável por todos os principais navegadores
- Validade de certificado de 90 dias
- Renovação automática recomendada

**Limites de taxa:**
- 50 certificados por domínio por semana
- 5 certificados duplicados por semana
- Use ambiente staging para testes

### Tipos de desafio ACME

**Desafio HTTP-01:**
- Coloca arquivo em `.well-known/acme-challenge/`
- Exige porta 80 acessível
- Não funciona com certificados wildcard
- Método mais comum

**Desafio DNS-01:**
- Cria registro DNS TXT
- Funciona com wildcards
- Não precisa da porta 80
- Exige acesso à API DNS

**Desafio TLS-ALPN-01:**
- Usa porta 443
- Menos comum
- Casos de uso específicos

### Comandos Certbot

**Obter certificado:**
```bash
# Standalone (para servidor web)
certbot certonly --standalone -d example.com

# Webroot (sem downtime)
certbot certonly --webroot -w /var/www/html -d example.com

# Plugin Apache
certbot --apache -d example.com

# Plugin NGINX
certbot --nginx -d example.com

# DNS manual
certbot certonly --manual --preferred-challenges dns -d example.com
```

**Gerenciar certificados:**
```bash
# Listar certificados
certbot certificates

# Renovar todos
certbot renew

# Renovar específico
certbot renew --cert-name example.com

# Testar renovação (dry-run)
certbot renew --dry-run

# Revogar certificado
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem
```

**Excluir certificado:**
```bash
certbot delete --cert-name example.com
```

### Localização dos certificados

```
/etc/letsencrypt/
├── live/
│   └── example.com/
│       ├── cert.pem         # Certificado
│       ├── chain.pem        # Cadeia intermediária
│       ├── fullchain.pem    # cert.pem + chain.pem
│       └── privkey.pem      # Chave privada
├── archive/                 # Todas as versões
├── renewal/                 # Configs de renovação
└── accounts/                # Info da conta ACME
```

### Automação de renovação

**Timer systemd (RHEL 8+):**
```bash
systemctl list-timers certbot
systemctl status certbot-renew.timer
```

### Hooks de renovação

```bash
# Pre-hook (antes da renovação)
certbot renew --pre-hook "systemctl stop nginx"

# Post-hook (após renovação)
certbot renew --post-hook "systemctl reload nginx"

# deploy-hook (somente se renovado)
certbot renew --deploy-hook "systemctl reload httpd"
```

---

## Resolução de problemas

### Problema: Desafio HTTP falha

**Sintoma:**
```
Failed authorization procedure
Connection refused
```

**Solução:**
```bash
# Certifique-se de que a porta 80 está acessível
sudo firewall-cmd --add-service=http
sudo firewall-cmd --reload

# Verifique servidor web
sudo systemctl status httpd
```

---

### Problema: Limite de taxa excedido

**Sintoma:**
```
too many certificates already issued
```

**Solução:**
Use ambiente staging para testes:
```bash
certbot --staging -d example.com
```

---

### Problema: Validação de domínio falha

**Sintoma:**
```
DNS problem: NXDOMAIN
```

**Solução:**
Verifique DNS:
```bash
dig example.com
nslookup example.com
# Certifique-se de que o domínio aponta para seu servidor
```

---

### Problema: Renovação falha

**Sintoma:**
Certificado não renovado automaticamente

**Solução:**
```bash
# Teste renovação
certbot renew --dry-run

# Verifique logs
journalctl -u certbot-renew

# Renovação manual
certbot renew --force-renewal
```

---

## Notas específicas por versão

### RHEL 8
- Disponível no AppStream
- Usa timers systemd
- Melhor integração de plugins

### RHEL 9
- certbot 1.x ou 2.x
- Segurança aprimorada
- Automação aprimorada

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove Certbot e certificados.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 24: Let's Encrypt com Certbot

**Documentação:**
- `man certbot`
- https://letsencrypt.org/docs/
- https://certbot.eff.org/
- https://community.letsencrypt.org/

**Limites de taxa:**
- https://letsencrypt.org/docs/rate-limits/

**Ambiente staging:**
```bash
certbot --staging ...
# Staging URL: https://acme-staging-v02.api.letsencrypt.org/directory
```

---

## Próximos passos

Prossiga para o **Lab 14: Automação com Ansible** para aprender implantação de certificados em escala.

---

**Nível de dificuldade**: Intermediário  
**Nota**: Requer conexão com internet e, idealmente, um domínio real para certificados de produção

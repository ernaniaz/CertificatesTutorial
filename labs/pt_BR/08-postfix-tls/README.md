# Lab 08: Configuração TLS no Postfix

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar e configurar o servidor de e-mail Postfix
- Configurar SMTP com criptografia STARTTLS
- Habilitar TLS na porta de submissão (587)
- Testar conexões SMTP TLS
- Entender requisitos de certificados para servidores de e-mail
- Configurar registro de logs TLS no Postfix

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Portas:** 25 (SMTP), 587 (submissão)

## Tempo estimado

**30-40 minutos**

## Visão geral

Postfix é o agente de transferência de e-mail (MTA) padrão no RHEL. Aprenda a configurá-lo com TLS para transmissão segura de e-mail usando STARTTLS na porta 25 e TLS obrigatório na porta de submissão (587).

---

## Instruções

### Passo 1: Instale o Postfix

Instale o servidor de e-mail Postfix:

```bash
sudo ./install-postfix.sh
```

Isso instala:
- Servidor de e-mail `postfix`
- Dependências necessárias
- Configurações básicas

---

### Passo 2: Configure TLS

Configure o Postfix com certificados TLS:

```bash
sudo ./configure-tls.sh
```

Isso:
- Copia certificados do Lab 04
- Configura parâmetros TLS em main.cf
- Habilita STARTTLS na porta 25
- Configura TLS obrigatório na porta 587
- Reinicia o Postfix

---

### Passo 3: Teste STARTTLS

Teste STARTTLS na porta 25:

```bash
./test-starttls.sh
```

Isso testa:
- Conexão SMTP básica
- Capacidade STARTTLS
- Handshake TLS
- Apresentação do certificado

---

### Passo 4: Teste a porta de submissão

Teste submissão segura na porta 587:

```bash
./test-submission.sh
```

Isso testa:
- Conectividade na porta de submissão
- Aplicação obrigatória de TLS
- Requisitos de autenticação
- Criptografia TLS

---

### Passo 5: Verifique a configuração

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
- ✅ Postfix instalado e em execução
- ✅ STARTTLS disponível na porta 25
- ✅ TLS obrigatório na porta 587
- ✅ Certificados configurados corretamente
- ✅ Compreensão de TLS em servidores de e-mail

---

## Conceitos-chave

### Arquivos de configuração do Postfix

```
/etc/postfix/
├── main.cf              # Configuração principal
├── master.cf            # Definições de serviços
├── transport            # Mapas de transporte
└── virtual              # Aliases virtuais
```

### Diretivas TLS em main.cf

```conf
# TLS para conexões de entrada (modo servidor)
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.crt
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1

# TLS para conexões de saída (modo cliente)
smtp_tls_security_level = may
smtp_tls_loglevel = 1

# Protocolos TLS e cifras
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, MD5
```

### Porta 25 vs porta 587

**Porta 25 (SMTP):**
- Porta tradicional de transferência de e-mail
- Comunicação servidor a servidor
- TLS opcional (STARTTLS)
- Autenticação normalmente não exigida

**Porta 587 (Submissão):**
- Submissão de e-mail por clientes
- Exige autenticação
- TLS deve ser obrigatório
- Boa prática moderna para submissão de e-mail por clientes

### Processo STARTTLS

1. Cliente conecta na porta em texto plano
2. Servidor anuncia capacidade STARTTLS
3. Cliente emite comando STARTTLS
4. Negociação faz upgrade para TLS
5. Comunicação criptografada continua

---

## Resolução de problemas

### Problema: Postfix não inicia

**Sintoma:**
```
Job for postfix.service failed
```

**Solução:**
Verifique configuração e logs:
```bash
sudo postfix check
sudo journalctl -xeu postfix
sudo tail -f /var/log/maillog
```

---

### Problema: STARTTLS não anunciado

**Sintoma:**
EHLO não mostra capacidade STARTTLS

**Solução:**
Verifique a configuração TLS:
```bash
postconf -n | grep tls
# Certifique-se de que smtpd_tls_cert_file e smtpd_tls_key_file estão definidos
# Reinicie postfix: systemctl restart postfix
```

---

### Problema: Erros de certificado

**Sintoma:**
```
warning: cannot get RSA private key
```

**Solução:**
Verifique permissões do certificado:
```bash
ls -l /etc/pki/tls/certs/postfix.crt
ls -l /etc/pki/tls/private/postfix.key
# A chave privada deve ser legível pelo postfix
chmod 600 /etc/pki/tls/private/postfix.key
chown root:root /etc/pki/tls/private/postfix.key
```

---

### Problema: Porta 25 bloqueada

**Sintoma:**
Não é possível conectar na porta 25

**Solução:**
Muitos ISPs bloqueiam a porta 25 de saída. Isso é normal. Use a porta 587 para conexões de clientes:
```bash
# Teste localmente
telnet localhost 25
# Se funcionar localmente, é bloqueio de rede/firewall no acesso externo
```

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- Logs em `/var/log/maillog`
- Postfix 2.10.x normalmente

### RHEL 8
- Usa `dnf` para instalação
- Postfix 3.3.x ou 3.5.x
- Crypto-policies afetam TLS
- Pode referenciar `/etc/crypto-policies/back-ends/postfix.config`

### RHEL 9
- Postfix 3.5.x
- Padrões TLS mais rigorosos
- SHA-1 bloqueado
- Exige cifras fortes

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o Postfix e restaura o estado do sistema.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 16: TLS no servidor de e-mail Postfix

**Documentação:**
- `man 5 postconf`
- `man postfix`
- `/usr/share/doc/postfix/`
- http://www.postfix.org/TLS_README.html

**Ferramentas de teste:**
- `openssl s_client -starttls smtp`
- `swaks` (canivete suíço para SMTP)

---

## Próximos passos

Prossiga para o **Lab 09: OpenLDAP LDAPS** para aprender LDAP sobre TLS.

---

**Nível de dificuldade:** Intermediário

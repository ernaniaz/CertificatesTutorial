# Lab 09: Configuração OpenLDAP LDAPS

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar e configurar o servidor OpenLDAP
- Configurar LDAP sobre TLS (LDAPS) na porta 636
- Configurar STARTTLS na porta 389
- Configurar TLS no cliente LDAP
- Testar conexões LDAP seguras
- Entender cn=config vs slapd.conf

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Portas:** 389 (LDAP), 636 (LDAPS)

## Tempo estimado

**40-50 minutos**

## Visão geral

OpenLDAP é uma implementação de serviço de diretório. Aprenda a configurá-lo com TLS para autenticação segura e consultas de diretório usando LDAPS (porta TLS dedicada) e STARTTLS (upgrade de conexão em texto plano).

---

## Instruções

### Passo 1: Instale o OpenLDAP

Instale o servidor OpenLDAP:

```bash
sudo ./install-openldap.sh
```

Isso instala:
- `openldap-servers` (servidor LDAP)
- `openldap-clients` (ferramentas de cliente)
- Estrutura básica de diretório

> **Nota:** No RHEL 9+, `openldap-servers` foi removido dos repositórios base. O script habilita automaticamente o EPEL para instalá-lo.

---

### Passo 2: Configure LDAPS

Configure LDAP com certificados TLS:

```bash
sudo ./configure-ldaps.sh
```

Isso:
- Copia certificados do Lab 04
- Configura TLS em cn=config
- Habilita LDAPS na porta 636
- Define caminhos dos certificados
- Reinicia slapd

---

### Passo 3: Configure o cliente LDAP

Configure o cliente LDAP para TLS:

```bash
sudo ./configure-client.sh
```

Isso:
- Configura `/etc/openldap/ldap.conf`
- Define caminho do certificado TLS
- Configura opções TLS
- Habilita validação de certificados

---

### Passo 4: Teste conexões

Teste conexões LDAP e LDAPS:

```bash
./test-connection.sh
```

Isso testa:
- LDAP em texto plano (porta 389)
- STARTTLS na porta 389
- LDAPS na porta 636
- Validação de certificados

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
- ✅ OpenLDAP instalado e em execução
- ✅ LDAPS funcionando na porta 636
- ✅ STARTTLS funcionando na porta 389
- ✅ Cliente configurado para TLS
- ✅ Compreensão da configuração TLS no LDAP

---

## Conceitos-chave

### Configuração do OpenLDAP

**RHEL 7:**
- Usa `/etc/openldap/slapd.conf` (tradicional)
- Configuração baseada em texto
- Exige reinício para aplicar alterações

**RHEL 8+:**
- Usa cn=config (configuração dinâmica)
- Baseado em LDIF em `/etc/openldap/slapd.d/`
- Alterações aplicadas sem reinício

### Portas LDAP

**Porta 389 (LDAP):**
- LDAP em texto plano
- Suporta upgrade STARTTLS
- Porta LDAP padrão

**Porta 636 (LDAPS):**
- LDAP sobre TLS desde o início
- Como HTTPS vs HTTP
- Porta segura dedicada

### Diretivas de configuração TLS

**Servidor (cn=config):**
```ldif
olcTLSCertificateFile: /etc/pki/tls/certs/ldap.crt
olcTLSCertificateKeyFile: /etc/pki/tls/private/ldap.key
olcTLSCACertificateFile: /etc/pki/tls/certs/ca-bundle.crt
olcTLSProtocolMin: 3.3
olcTLSCipherSuite: HIGH:!aNULL:!MD5
```

**Cliente (/etc/openldap/ldap.conf):**
```conf
TLS_CACERTDIR /etc/openldap/certs
TLS_REQCERT allow
URI ldaps://localhost
```

### Comandos ldapsearch

```bash
# LDAP em texto plano
ldapsearch -x -H ldap://localhost -b "" -s base

# LDAP com STARTTLS
ldapsearch -x -H ldap://localhost -b "" -s base -ZZ

# LDAPS
ldapsearch -x -H ldaps://localhost -b "" -s base
```

---

## Resolução de problemas

### Problema: slapd não inicia

**Sintoma:**
```
Job for slapd.service failed
```

**Solução:**
Verifique logs e configuração:
```bash
journalctl -xeu slapd
slapd -d 1  # Modo debug
# Verifique permissões dos arquivos de certificado
```

---

### Problema: Falha no handshake TLS

**Sintoma:**
```
ldap_start_tls: Connect error (-11)
TLS: can't connect: TLS error
```

**Solução:**
Verifique a configuração de certificados:
```bash
# Verifique se os certificados são legíveis pelo usuário ldap
ls -l /etc/openldap/certs/
# Verifique contextos SELinux
ls -Z /etc/openldap/certs/
# Restaure contextos se necessário
restorecon -Rv /etc/openldap/certs/
```

---

### Problema: Falha na verificação do certificado

**Sintoma:**
```
TLS certificate verification: Error, self signed certificate
```

**Solução:**
Configure o cliente para confiar no certificado:
```bash
# Opção 1: Use TLS_REQCERT allow (para laboratório/teste)
echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf

# Opção 2: Adicione certificado CA (produção)
cp /path/to/ca.crt /etc/openldap/certs/
echo "TLS_CACERT /etc/openldap/certs/ca.crt" >> /etc/openldap/ldap.conf
```

---

### Problema: Porta 636 não escutando

**Sintoma:**
Não é possível conectar a ldaps://localhost:636

**Solução:**
Habilite LDAPS na configuração do slapd:
```bash
# Verifique argumentos do slapd
systemctl cat slapd | grep ExecStart

# RHEL 8+: Edite /etc/sysconfig/slapd
# Adicione: SLAPD_URLS="ldap:/// ldaps:/// ldapi:///"

systemctl restart slapd
ss -tlnp | grep 636
```

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- Pode usar slapd.conf (config tradicional)
- Configuração manual de protocolos TLS
- Suporte TLS via OpenSSL

### RHEL 8
- Usa `dnf` para instalação
- Apenas cn=config (sem slapd.conf)
- Crypto-policies afetam TLS
- OpenLDAP 2.4.x

### RHEL 9
- **`openldap-servers` removido dos repos base** — instalado via EPEL
- OpenLDAP 2.4.x ou 2.5.x
- Padrões TLS mais rigorosos
- SHA-1 bloqueado por padrão
- Políticas de segurança aprimoradas
- Melhor integração com SELinux

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o OpenLDAP e restaura o estado do sistema.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 17: OpenLDAP LDAPS

**Documentação:**
- `man slapd`
- `man slapd.conf` (RHEL 7)
- `man slapd-config` (cn=config)
- `man ldap.conf`
- https://www.openldap.org/doc/admin24/tls.html

**Ferramentas de cliente:**
- `ldapsearch` - pesquisar diretório
- `ldapadd` - adicionar entradas
- `ldapmodify` - modificar entradas

---

## Próximos passos

Prossiga para o **Lab 10: TLS no PostgreSQL** para aprender configuração TLS de banco de dados.

---

**Nível de dificuldade**: Intermediário a avançado

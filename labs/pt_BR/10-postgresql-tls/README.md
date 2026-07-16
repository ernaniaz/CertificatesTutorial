# Lab 10: Configuração TLS no PostgreSQL

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar e configurar o banco de dados PostgreSQL
- Habilitar SSL/TLS no PostgreSQL
- Entender onde a autenticação com certificado de cliente teria de ser adicionada manualmente
- Testar conexões seguras de banco de dados
- Entender a configuração SSL em pg_hba.conf
- Consultar status de conexões SSL

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Porta:** 5432 (PostgreSQL)

## Tempo estimado

**30-40 minutos**

## Visão geral

PostgreSQL é um banco de dados relacional open-source poderoso. Este laboratório configura TLS do lado do servidor para criptografar a comunicação cliente-servidor. A autenticação com certificados de cliente fica como material opcional posterior e não é configurada pelo `configure-tls.sh` incluído.

---

## Instruções

### Passo 1: Instale o PostgreSQL

Instale o servidor de banco de dados PostgreSQL:

```bash
sudo ./install-postgresql.sh
```

Isso instala:
- `postgresql-server` (servidor de banco de dados)
- `postgresql` (ferramentas de cliente)
- Inicializa o cluster de banco de dados

---

### Passo 2: Configure TLS

Configure o PostgreSQL com certificados TLS:

```bash
sudo ./configure-tls.sh
```

Isso:
- Copia certificados do Lab 04
- Habilita SSL em postgresql.conf
- Configura regras `hostssl` para conexões TLS locais
- Define permissões dos certificados
- Reinicia o PostgreSQL

---

### Passo 3: Teste a conexão

Teste conexões seguras de banco de dados:

```bash
./test-connection.sh
```

Isso testa:
- Conexão básica de banco de dados
- Conexão com SSL/TLS habilitado
- Verificação de conexão SSL
- Status da conexão SSL e detalhes da cifra

---

### Passo 4: Verifique o status SSL

Verifique a configuração SSL:

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
- ✅ PostgreSQL instalado e em execução
- ✅ SSL/TLS habilitado
- ✅ Conexões seguras funcionando
- ✅ Status SSL consultável
- ✅ Compreensão de TLS no PostgreSQL

---

## Conceitos-chave

### Arquivos de configuração do PostgreSQL

```
/var/lib/pgsql/data/
├── postgresql.conf       # Configuração principal
├── pg_hba.conf          # Autenticação de clientes
├── server.crt           # Certificado de servidor
├── server.key           # Chave privada de servidor
└── root.crt             # Arquivo de CA opcional para configuração manual
```

### Configuração SSL em postgresql.conf

```conf
# Habilitar SSL
ssl = on

# Arquivos de certificado (relativos ao diretório de dados)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'

# Cifras SSL
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on

# Versão mínima TLS (somente PostgreSQL 12+)
ssl_min_protocol_version = 'TLSv1.2'
```

### Regras SSL em pg_hba.conf

```conf
# TYPE  DATABASE  USER  ADDRESS      METHOD

# Adicionado por configure-tls.sh
hostssl    all    all    127.0.0.1/32    md5
hostssl    all    all    ::1/128         md5
```

O laboratório incluído não adiciona `ssl_ca_file` nem regras de autenticação de cliente baseadas em `cert`. Se quiser explorar certificados de cliente, adicione manualmente o material de CA e regras `pg_hba.conf` mais restritivas depois de concluir o lab.

### String de conexão com SSL

```bash
# Conexão SSL básica usada neste lab
psql "host=localhost sslmode=require user=postgres"

# Consultar detalhes SSL da sessão atual
sudo -u postgres psql -c "SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

### Modos SSL

| Modo | Criptografia | Validação de certificado |
|------|--------------|--------------------------|
| disable | Não | Não |
| allow | Talvez | Não |
| prefer | Talvez | Não |
| require | Sim | Não |
| verify-ca | Sim | Apenas CA |
| verify-full | Sim | CA + hostname |

---

## Resolução de problemas

### Problema: PostgreSQL não inicia

**Sintoma:**
```
Job for postgresql.service failed
```

**Solução:**
Verifique logs e configuração:
```bash
journalctl -xeu postgresql
# Verifique permissões do diretório de dados
ls -la /var/lib/pgsql/data/
# Verifique permissões de server.key (deve ser 600)
```

---

### Problema: SSL não habilitado

**Sintoma:**
```
SSL connection (protocol: unknown, cipher: unknown, bits: unknown)
```

**Solução:**
Verifique se SSL está habilitado:
```bash
sudo -u postgres psql -c "SHOW ssl;"
# Deve retornar 'on'

# Verifique postgresql.conf
grep "^ssl" /var/lib/pgsql/data/postgresql.conf
```

---

### Problema: Erros de permissão de certificado

**Sintoma:**
```
FATAL: could not load server certificate file
```

**Solução:**
Corrija permissões dos certificados:
```bash
cd /var/lib/pgsql/data/
chmod 600 server.key
chmod 644 server.crt
chown postgres:postgres server.key server.crt
```

---

### Problema: Conexão recusada

**Sintoma:**
```
psql: could not connect to server
```

**Solução:**
Verifique se o PostgreSQL está escutando:
```bash
ss -tlnp | grep 5432
# Edite postgresql.conf
listen_addresses = 'localhost'  # ou '*' para todas as interfaces
# Reinicie: systemctl restart postgresql
```

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- PostgreSQL 9.2.x normalmente — `ssl_min_protocol_version` não disponível (requer PG 12+)
- Diretório de dados: `/var/lib/pgsql/data/`
- Serviço: `postgresql.service`

### RHEL 8
- Usa `dnf` para instalação
- PostgreSQL 10.x ou 12.x (módulos AppStream)
- `ssl_min_protocol_version` só disponível se o módulo PG 12+ estiver habilitado
- Diretório de dados: `/var/lib/pgsql/data/`

### RHEL 9
- PostgreSQL 13.x normalmente
- Padrões de segurança aprimorados
- Melhor suporte a protocolos TLS
- SHA-1 bloqueado por padrão

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o PostgreSQL e restaura o estado do sistema.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 18: Configuração TLS de banco de dados

**Documentação:**
- `man postgres`
- `man psql`
- `man pg_hba.conf`
- https://www.postgresql.org/docs/current/ssl-tcp.html

**Consultas úteis:**
```sql
-- Verificar status SSL
SHOW ssl;

-- Visualizar conexões atuais com informações SSL
SELECT datname, usename, ssl, client_addr, backend_type
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);

-- Obter informações de cifra SSL
SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();
```

---

## Próximos passos

Prossiga para o **Lab 11: Noções Básicas do certmonger** para aprender gerenciamento automático de certificados.

---

**Nível de dificuldade**: Intermediário

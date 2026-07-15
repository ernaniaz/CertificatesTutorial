# Capítulo 18: TLS em Bancos de Dados (PostgreSQL, MySQL)

> **Dados em Trânsito:** Proteja conexões banco dados com criptografia TLS. Aprenda como configurar PostgreSQL e MySQL/MariaDB com certificados no RHEL.

---

## 18.1 Por Que TLS de Banco de Dados?

**Proteger Dados Sensíveis:**
- ✅ Criptografar consultas e resultados banco dados
- ✅ Prevenir escuta clandestina em credenciais
- ✅ Autenticar servidores banco dados
- ✅ Habilitar autenticação certificado cliente
- ✅ Cumprir requisitos conformidade (PCI-DSS, HIPAA)

**Modelo Ameaça:**
- Sem TLS: Senhas e dados viajam em cleartext
- Com TLS: Toda comunicação criptografada

---

## 18.2 PostgreSQL com SSL/TLS

### Instalação

```bash
#============================================#
# INSTALAR POSTGRESQL
#============================================#

# RHEL 7/8/9/10
sudo dnf install postgresql-server -y

# Inicializar banco dados
sudo postgresql-setup --initdb

# Habilitar e iniciar
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Verificar
systemctl status postgresql
ss -tlnp | grep 5432
```

### Gerar Certificados PostgreSQL

```bash
#============================================#
# GERAR CERTIFICADOS POSTGRESQL
#============================================#

# Passo 1: Gerar chave servidor
sudo -u postgres openssl genpkey -algorithm RSA \
  -out /var/lib/pgsql/data/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Passo 2: Definir permissões (crítico!)
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Passo 3: Gerar CSR
sudo -u postgres openssl req -new \
  -key /var/lib/pgsql/data/server.key \
  -out /tmp/postgres.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:postgres.example.com"

# Passo 4: Obter certificado da CA

# Passo 5: Instalar certificado
sudo cp postgres.crt /var/lib/pgsql/data/server.crt
sudo chmod 600 /var/lib/pgsql/data/server.crt
sudo chown postgres:postgres /var/lib/pgsql/data/server.crt

# Passo 6: Instalar certificado CA
sudo cp ca.crt /var/lib/pgsql/data/root.crt
sudo chmod 644 /var/lib/pgsql/data/root.crt
```

### Configurar PostgreSQL para SSL

```bash
#============================================#
# CONFIGURAR POSTGRESQL SSL
#============================================#

# Editar /var/lib/pgsql/data/postgresql.conf
sudo -u postgres vi /var/lib/pgsql/data/postgresql.conf

# Habilitar SSL
ssl = on

# Arquivos certificado (relativos ao diretório data)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'

# RHEL 7: Especificar versão TLS mínima
# ssl_min_protocol_version = 'TLSv1.2'

# RHEL 8/9/10: Usa crypto-policy sistema
# (sem necessidade especificar ssl_min_protocol_version)

# Opcional: Preferir cifras servidor
ssl_prefer_server_ciphers = on

# Reiniciar PostgreSQL
sudo systemctl restart postgresql
```

### Configurar Autenticação Cliente

```bash
#============================================#
# /var/lib/pgsql/data/pg_hba.conf
#============================================#

# Requerer SSL para todas conexões
hostssl all all 0.0.0.0/0 md5

# Requerer certificado cliente
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Recarregar configuração
sudo systemctl reload postgresql
```

**Tipos HBA:**
- `host`: Permitir não-SSL
- `hostssl`: Requerer SSL
- `hostnossl`: Explicitamente proibir SSL

**Opções Cert Cliente:**
- `md5`: SSL requerido, auth senha
- `cert`: SSL + certificado cliente requerido
- `clientcert=verify-full`: Verificar cert cliente contra CA

### Testar PostgreSQL SSL

```bash
#============================================#
# TESTAR POSTGRESQL SSL
#============================================#

# Teste 1: Conectar com SSL requerido
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=require"

# Teste 2: Conectar com verificação completa
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=verify-full sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Teste 3: Com certificado cliente
psql "host=db.example.com port=5432 user=alice dbname=mydb sslmode=verify-full sslcert=/home/alice/.postgresql/client.crt sslkey=/home/alice/.postgresql/client.key sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Teste 4: Verificar SSL de dentro PostgreSQL
psql -h db.example.com -U testuser -d testdb -c "SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

# Teste 5: Teste OpenSSL
openssl s_client -connect db.example.com:5432 -starttls postgres
```

**Modos SSL:**
- `disable`: Sem SSL
- `allow`: Tentar SSL, fallback para não-SSL
- `prefer`: Preferir SSL, fallback permitido
- `require`: Requerer SSL (não verificar cert)
- `verify-ca`: Requerer SSL, verificar CA
- `verify-full`: Requerer SSL, verificar hostname + CA

---

## 18.3 MySQL/MariaDB com SSL/TLS

### Instalação

```bash
#============================================#
# INSTALAR MARIADB (SUBSTITUIÇÃO MYSQL NO RHEL 8+)
#============================================#

# RHEL 8/9/10
sudo dnf install mariadb-server -y

# Iniciar e habilitar
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Instalação segura
sudo mysql_secure_installation

# Verificar
systemctl status mariadb
ss -tlnp | grep 3306
```

### Gerar Certificados MySQL/MariaDB

```bash
#============================================#
# GERAR CERTIFICADOS MYSQL/MARIADB
#============================================#

# Criar diretório certificado
sudo mkdir -p /etc/mysql/certs
sudo chmod 755 /etc/mysql/certs

# Passo 1: Gerar chave servidor
sudo openssl genpkey -algorithm RSA \
  -out /etc/mysql/certs/server.key \
  -pkeyopt rsa_keygen_bits:2048

sudo chmod 600 /etc/mysql/certs/server.key
sudo chown mysql:mysql /etc/mysql/certs/server.key

# Passo 2: Gerar CSR
sudo openssl req -new \
  -key /etc/mysql/certs/server.key \
  -out /tmp/mysql.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:mysql.example.com"

# Passo 3: Obter certificado da CA

# Passo 4: Instalar certificado e CA
sudo cp mysql.crt /etc/mysql/certs/server.crt
sudo cp ca.crt /etc/mysql/certs/ca.crt
sudo chmod 644 /etc/mysql/certs/{server.crt,ca.crt}
sudo chown mysql:mysql /etc/mysql/certs/{server.crt,ca.crt}
```

### Configurar MySQL/MariaDB para SSL

```bash
#============================================#
# CONFIGURAR MYSQL/MARIADB SSL
#============================================#

# Editar /etc/my.cnf.d/server.cnf (ou /etc/my.cnf)
sudo vi /etc/my.cnf.d/server.cnf

[mysqld]
# Configuração SSL/TLS
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Requerer transporte seguro (opcional, força TLS para todos)
require_secure_transport=ON

# RHEL 7: Especificar versão TLS
# tls_version=TLSv1.2,TLSv1.3

# Reiniciar MySQL/MariaDB
sudo systemctl restart mariadb
```

### Verificar SSL Está Habilitado

```bash
#============================================#
# VERIFICAR MYSQL SSL
#============================================#

# Conectar e verificar status SSL
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Deveria mostrar:
# have_ssl           | YES
# ssl_ca             | /etc/mysql/certs/ca.crt
# ssl_cert           | /etc/mysql/certs/server.crt
# ssl_key            | /etc/mysql/certs/server.key

# Verificar conexões ativas
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_cipher';"
```

### Testar Conexão MySQL SSL

```bash
#============================================#
# TESTAR CONEXÃO MYSQL SSL
#============================================#

# Conectar com SSL
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h db.example.com \
  -u testuser \
  -p

# Verificar SSL em uso
mysql> \s
# Procurar por: "SSL: Cipher in use is ..."

# Ou verificar de linha comando
mysql -h db.example.com -u testuser -p -e "STATUS" | grep SSL
```

---

## 18.4 Autenticação Certificado Cliente

### PostgreSQL com Certificados Cliente

```bash
#============================================#
# AUTH CERT CLIENTE POSTGRESQL
#============================================#

# Lado servidor: pg_hba.conf
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Gerar certificado cliente
openssl genpkey -algorithm RSA -out alice.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice"
# Obter assinado por CA

# Conexão cliente
psql "host=db.example.com user=alice dbname=mydb sslmode=verify-full sslcert=alice.crt sslkey=alice.key sslrootcert=ca.crt"
```

### MySQL/MariaDB com Certificados Cliente

```bash
#============================================#
# AUTH CERT CLIENTE MYSQL/MARIADB
#============================================#

# Criar usuário requerendo X.509
mysql -u root -p << EOF
CREATE USER 'alice'@'%' REQUIRE X509;
GRANT ALL ON mydb.* TO 'alice'@'%';
FLUSH PRIVILEGES;
EOF

# Conexão cliente
mysql --ssl-ca=ca.crt \
  --ssl-cert=alice.crt \
  --ssl-key=alice.key \
  -h db.example.com \
  -u alice \
  -p mydb
```

---

## 18.5 Solução de Problemas TLS Banco Dados

### Solução de Problemas PostgreSQL

```bash
#============================================#
# SOLUÇÃO DE PROBLEMAS SSL POSTGRESQL
#============================================#

# Verificar SSL está habilitado
sudo -u postgres psql -c "SHOW ssl;"
# Deveria mostrar: on

# Ver configurações SSL
sudo -u postgres psql -c "SHOW ssl_cert_file; SHOW ssl_key_file; SHOW ssl_ca_file;"

# Verificar arquivos certificado
ls -l /var/lib/pgsql/data/server.{crt,key}

# Verificar propriedade
# Deveria ser: postgres:postgres

# Verificar permissões
# server.key deveria ser 600

# Testar conexão com debugging SSL
psql "host=db.example.com sslmode=require" -d postgres -U testuser --set=sslcompression=on

# Verificar logs PostgreSQL
sudo tail -f /var/lib/pgsql/data/log/postgresql-*.log | grep -i ssl
```

### Solução de Problemas MySQL/MariaDB

```bash
#============================================#
# SOLUÇÃO DE PROBLEMAS SSL MYSQL/MARIADB
#============================================#

# Verificar variáveis SSL
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Se have_ssl = NO, verificar:
# 1. Arquivos certificado existem
ls -l /etc/mysql/certs/

# 2. Permissões
# Deveriam ser legíveis por usuário mysql

# 3. Reiniciar banco dados
sudo systemctl restart mariadb

# Verificar log erro
sudo tail -f /var/log/mariadb/mariadb.log | grep -i ssl

# Testar conexão
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h localhost \
  -u root \
  -p \
  -e "STATUS" | grep SSL
```

---

## 18.6 Problemas e Soluções Comuns

### Problema 1: PostgreSQL "Permission denied" em server.key

**Sintoma:** PostgreSQL não inicia, logs mostram erro permissão

**Correção:**
```bash
# Definir permissões corretas
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Corrigir contexto SELinux
sudo restorecon -Rv /var/lib/pgsql/data/

# Reiniciar
sudo systemctl restart postgresql
```

### Problema 2: MySQL "SSL connection error"

**Diagnóstico:**
```bash
# Verificar se SSL está disponível
mysql -u root -p -e "SHOW VARIABLES LIKE 'have_ssl';"
# Deveria mostrar: YES

# Se mostra: DISABLED
# Verificar caminhos certificado em my.cnf
```

**Correção:**
```bash
# Verificar caminhos em /etc/my.cnf.d/server.cnf
[mysqld]
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Reiniciar
sudo systemctl restart mariadb
```

### Problema 3: Certificado Cliente Rejeitado

**Sintoma:** Conexão falha com cert cliente

**Correção PostgreSQL:**
```bash
# Verificar pg_hba.conf
cat /var/lib/pgsql/data/pg_hba.conf | grep hostssl

# Garantir que CA cliente está instalada
sudo cp client-ca.crt /var/lib/pgsql/data/root.crt

# Recarregar
sudo systemctl reload postgresql
```

**Correção MySQL:**
```bash
# Verificar usuário requer X.509
mysql -u root -p -e "SELECT user, host, ssl_type FROM mysql.user WHERE user='alice';"
# Deveria mostrar: X509

# Verificar arquivo CA configurado
mysql -u root -p -e "SHOW VARIABLES LIKE 'ssl_ca';"
```

---

## 18.7 Considerações Específicas por Versão

### Versões PostgreSQL no RHEL

| Versão RHEL | PostgreSQL | Suporte SSL | Notas |
|-------------|------------|-------------|-------|
| RHEL 7 | 9.2 | ✅ Sim | Config versão TLS manual |
| RHEL 8 | 10.x+ | ✅ Sim | Crypto-policy sistema |
| RHEL 9 | 13.x+ | ✅ Sim | Aprimorado, crypto-policy |
| RHEL 10 | 15.x+ | ✅ Sim | Último, crypto-policy |

### Versões MySQL/MariaDB no RHEL

| Versão RHEL | Banco Dados | Suporte SSL | Notas |
|-------------|-------------|-------------|-------|
| RHEL 7 | MariaDB 5.5 | ✅ Sim | Config manual |
| RHEL 8 | MariaDB 10.3+ | ✅ Sim | Consciente crypto-policy |
| RHEL 9 | MariaDB 10.5+ | ✅ Sim | TLS moderno |
| RHEL 10 | MariaDB 10.11+ | ✅ Sim | Recursos últimos |

---

## 18.8 Considerações Desempenho

### Desempenho SSL PostgreSQL

```ini
#============================================#
# AJUSTE DESEMPENHO SSL POSTGRESQL
#============================================#

# /var/lib/pgsql/data/postgresql.conf

# SSL habilitado
ssl = on

# Compressão SSL (desabilitada para segurança, ataque CRIME)
ssl_compression = off

# Cifras SSL (RHEL 7 - manual)
# ssl_ciphers = 'HIGH:!aNULL:!MD5'

# RHEL 8/9/10: crypto-policy lida com cifras

# Connection pooling ajuda (usar pgBouncer)
# Terminação SSL em proxy pode melhorar desempenho
```

### Desempenho SSL MySQL

```ini
#============================================#
# DESEMPENHO SSL MYSQL
#============================================#

# [mysqld] em /etc/my.cnf.d/server.cnf

# SSL habilitado
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Desabilitar cifras fracas (RHEL 7)
# tls_version=TLSv1.2,TLSv1.3
# ssl_cipher='ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'

# RHEL 8/9/10: crypto-policy lida com isso

# Connection pooling (usar ProxySQL ou similar)
```

---

## 18.9 Monitorando TLS Banco Dados

### Monitoramento PostgreSQL

```bash
#============================================#
# MONITORAR SSL POSTGRESQL
#============================================#

# Verificar conexões SSL
sudo -u postgres psql -c "SELECT datname, usename, ssl, version FROM pg_stat_ssl JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid;"

# Contar SSL vs não-SSL
sudo -u postgres psql -c "SELECT ssl, COUNT(*) FROM pg_stat_ssl GROUP BY ssl;"

# Verificar expiração certificado
openssl x509 -in /var/lib/pgsql/data/server.crt -noout -checkend $((86400*30))

# Monitorar conexões
sudo -u postgres psql -c "SELECT COUNT(*) FROM pg_stat_activity WHERE ssl = true;"
```

### Monitoramento MySQL

```bash
#============================================#
# MONITORAR SSL MYSQL
#============================================#

# Verificar status SSL
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl%';"

# Contar conexões SSL
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_accepts';"

# Conexões SSL atuais
mysql -u root -p -e "SELECT user, host, connection_type FROM information_schema.processlist WHERE connection_type = 'SSL/TLS';"

# Expiração certificado
openssl x509 -in /etc/mysql/certs/server.crt -noout -checkend $((86400*30))
```

---

## 18.10 Scripts Configuração Completo

### Script Configuração SSL PostgreSQL

```bash
#!/bin/bash
# setup-postgresql-ssl.sh

echo "=== Setup SSL PostgreSQL ==="

# Gerar cert autoassinado (substituir com cert CA apropriado!)
sudo -u postgres openssl req -new -x509 -days 365 -nodes \
  -out /var/lib/pgsql/data/server.crt \
  -keyout /var/lib/pgsql/data/server.key \
  -subj "/CN=$(hostname -f)"

# Definir permissões
sudo chmod 600 /var/lib/pgsql/data/server.{crt,key}
sudo chown postgres:postgres /var/lib/pgsql/data/server.{crt,key}

# Habilitar SSL em postgresql.conf
sudo -u postgres psql -c "ALTER SYSTEM SET ssl = on;"

# Reiniciar
sudo systemctl restart postgresql

# Testar
sudo -u postgres psql -c "SHOW ssl;"

echo "✅ PostgreSQL SSL habilitado"
echo "⚠️ Substituir cert autoassinado com certificado apropriado da CA"
```

---

## 18.11 Conclusões Chave

1. **Ambos PostgreSQL e MySQL suportam SSL/TLS**
2. **Propriedade arquivo crítica** - postgres:postgres ou mysql:mysql
3. **Permissões:** 600 para chaves, 644 para certs
4. **pg_hba.conf controla** acesso PostgreSQL (hostssl)
5. **sslmode importante** para clientes PostgreSQL
6. **Certificados cliente habilitam** autenticação forte
7. **Testar completamente** antes forçar TLS
8. **Monitorar uso SSL** - Garantir clientes realmente usam

---

## Cartão de Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA TLS BANCO DADOS                            │
├──────────────────────────────────────────────────────────────┤
│ === POSTGRESQL ===                                           │
│ Config:        /var/lib/pgsql/data/postgresql.conf           │
│ Acesso:        /var/lib/pgsql/data/pg_hba.conf               │
│ Certs:         /var/lib/pgsql/data/server.{crt,key}          │
│ Proprietário:  postgres:postgres                             │
│ Habilitar:     ssl = on                                      │
│ Testar:        psql "sslmode=require"                        │
│                                                              │
│ === MYSQL/MARIADB ===                                        │
│ Config:        /etc/my.cnf.d/server.cnf                      │
│ Certs:         /etc/mysql/certs/server.{crt,key}             │
│ Proprietário:  mysql:mysql                                   │
│ Habilitar:     ssl-ca, ssl-cert, ssl-key em [mysqld]         │
│ Testar:        mysql --ssl-mode=REQUIRED                     │
│                                                              │
│ Permissões:    chmod 600 *.key                               │
│                chmod 644 *.crt                               │
└──────────────────────────────────────────────────────────────┘

⚠️ Propriedade e permissões arquivo são críticas!
✅ Usar hostssl em pg_hba.conf para requerer SSL
```

---

## 🧪 Laboratório Prático

**Lab 10: TLS do PostgreSQL**

Configure TLS para conexões de banco de dados PostgreSQL

- 📁 **Localização:** `labs/pt_BR/10-postgresql-tls/`
- ⏱️ **Tempo:** 25-30 minutos
- 🎯 **Nível:** Intermediário

---

**Navegação do Capítulo**

| [← Anterior: Capítulo 17 - OpenLDAP e Serviços de Diretório](17-openldap-ldaps.md) | [Próximo: Capítulo 19 - Serviços de Certificados do FreeIPA →](19-freeipa-services.md) |
|:---|---:|

# 🧪 Exercícios de Laboratório

Laboratórios práticos completos para praticar o que você aprendeu. Cada laboratório inclui scripts funcionais, instruções passo a passo e procedimentos de validação.

---

## Laboratórios por Categoria

### 📚 Laboratórios Fundamentais (1-5)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [01](01-environment-setup/) | Configuração do Ambiente | 15-20 min | Iniciante | Cap. 1-3 |
| [02](02-key-generation/) | Geração de Chaves | 20-25 min | Iniciante | Cap. 4 |
| [03](03-digital-signatures/) | Assinaturas Digitais | 20 min | Iniciante | Cap. 7 |
| [04](04-x509-certificates/) | Certificados X.509 | 25-30 min | Iniciante | Cap. 5 |
| [05](05-trust-store/) | Gerenciamento do Repositório de Confiança | 25 min | Iniciante | Cap. 6 |

### 🌐 Laboratórios de Configuração de Serviços (6-10)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [06](06-apache-https/) | Configuração HTTPS no Apache | 30-40 min | Intermediário | Cap. 14 |
| [07](07-nginx-https/) | Configuração HTTPS no NGINX | 30-35 min | Intermediário | Cap. 15 |
| [08](08-postfix-tls/) | TLS no Postfix | 30-40 min | Intermediário | Cap. 16 |
| [09](09-openldap-ldaps/) | OpenLDAP LDAPS | 40-50 min | Intermediário | Cap. 17 |
| [10](10-postgresql-tls/) | TLS no PostgreSQL | 30-40 min | Intermediário | Cap. 18 |

### ⚙️ Laboratórios de Automação (11-14)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [11](11-certmonger-basics/) | Noções Básicas do certmonger | 40-50 min | Intermediário | Cap. 22 |
| [12](12-crypto-policies/) | Crypto-Policies | 30-40 min | Intermediário | Cap. 23 |
| [13](13-letsencrypt-certbot/) | Let's Encrypt e Certbot | 40-50 min | Intermediário | Cap. 24 |
| [14](14-ansible-automation/) | Automação com Ansible | 50-60 min | Avançado | Cap. 25 |

### 🔧 Laboratórios de Resolução de Problemas (15-16) - CRÍTICO

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [15](15-troubleshooting-scenarios/) | Cenários de Resolução de Problemas (certificado expirado) | 15-20 min | Avançado | Cap. 27-29 |
| [16](16-emergency-procedures/) | Procedimentos de Emergência | 30-40 min | Avançado | Cap. 33 |

### 🔄 Laboratórios de Migração (17-18)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [17](17-rhel7to8-migration/) | Migração RHEL 7→8 | 40-50 min | Avançado | Cap. 35 |
| [18](18-rhel8to9-migration/) | Migração RHEL 8→9 | 40-50 min | Avançado | Cap. 36 |

### 🔒 Laboratórios de Segurança (19-20)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [19](19-fips-mode/) | Configuração do Modo FIPS | 40-50 min | Avançado | Cap. 38-39 |
| [20](20-security-hardening/) | Endurecimento de Segurança | 30-40 min | Avançado | Cap. 40 |

### 🚀 Laboratórios Avançados/Apêndice (21-22)

| Lab | Título | Tempo | Nível | Capítulo |
|-----|--------|-------|-------|----------|
| [21](21-kubernetes-cert-manager/) | Kubernetes cert-manager | 40-50 min | Avançado | Apêndice A |
| [22](22-vault-pki/) | HashiCorp Vault PKI | 35-45 min | Avançado | Apêndice B |

---

## Recursos dos Laboratórios

Os laboratórios geralmente incluem:
- ✅ **README.md** - Instruções completas e objetivos de aprendizagem
- ✅ **Scripts shell** - Scripts de automação funcionais e testados
- ✅ **Validação** - Um comando ou procedimento de validação documentado
- ✅ **Limpeza** - Procedimentos de limpeza quando o laboratório os fornece
- ✅ **Tratamento de erros** - Saída colorida e mensagens de erro úteis
- ✅ **Notas de versão do RHEL** - Consulte o README de cada laboratório para ver as versões compatíveis

---

## Trilhas de Aprendizagem

### Trilha para Iniciantes (Comece Aqui!)
1. Lab 01: Configuração do Ambiente
2. Lab 02: Geração de Chaves
3. Lab 03: Assinaturas Digitais
4. Lab 04: Certificados X.509
5. Lab 05: Repositório de Confiança

### Trilha para Administradores de Serviços
1. Conclua os Laboratórios Fundamentais (1-5)
2. Lab 06: HTTPS no Apache
3. Lab 07: HTTPS no NGINX
4. Lab 08-10: Serviços Adicionais

### Trilha para Engenheiros de Automação
1. Conclua os Laboratórios Fundamentais (1-5)
2. Lab 11: Noções Básicas do certmonger
3. Lab 12: Crypto-Policies
4. Lab 13: Let's Encrypt
5. Lab 14: Automação com Ansible

### Trilha para Suporte em Produção (Mais Importante!)
1. Conclua os Laboratórios Fundamentais (1-5)
2. Lab 15: Cenários de Resolução de Problemas ⭐
3. Lab 16: Procedimentos de Emergência ⭐
4. Labs 17-18: Laboratórios de Migração
5. Labs 19-20: Laboratórios de Segurança

---

## Início Rápido

```bash
# Navegue até o diretório dos laboratórios
cd labs/pt_BR

# Comece pelo Lab 01
cd 01-environment-setup
./setup.sh
./verify-environment.sh

# Cada laboratório segue o fluxo de validação documentado em seu README:
cd ../XX-lab-name/
./script-name.sh
./verify*.sh ou ./test*.sh
./cleanup*.sh
```

---

## Pré-requisitos

- **Sistema RHEL:** Versão 7, 8, 9 ou 10
- **Acesso:** Privilégios de root ou sudo
- **Conhecimentos:** Noções básicas de linha de comando Linux
- **Tempo:** Reserve de 15 a 90 minutos por laboratório

---

## Suporte

- **Problemas?** Consulte a seção Resolução de Problemas de cada laboratório no README.md
- **Dúvidas?** Consulte os capítulos relevantes do tutorial
- **Erros?** Os laboratórios incluem mensagens de erro detalhadas e dicas

---

**Tempo Total dos Laboratórios:** ~15-20 horas para todos os 22 laboratórios
**Dificuldade:** Progressão de Iniciante → Avançado

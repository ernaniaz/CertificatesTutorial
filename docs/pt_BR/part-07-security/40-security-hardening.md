# Capítulo 40: Fortalecimento de Segurança de Certificados no RHEL

> **Defesa em Profundidade:** Além de FIPS, aprenda como fortalecer segurança certificado no RHEL usando SELinux, TPM, smart cards e ferramentas scan segurança.

---

## 40.1 Visão geral do fortalecimento de segurança

**Camadas de Segurança Certificado:**

1. **Permissões Arquivo** - Proteger chaves privadas
2. **SELinux** - Controle acesso obrigatório
3. **Firewall** - Limitar exposição
4. **Auditoria** - Rastrear acesso
5. **TPM** - Proteção chave hardware
6. **Smart Cards** - Tokens físicos
7. **Monitoramento** - Detectar problemas
8. **Scanning Conformidade** - Verificar configuração

---

## 40.2 SELinux para Certificados

### Contextos SELinux Apropriados

```bash
#============================================#
# CONTEXTOS CERTIFICADO SELINUX
#============================================#

# Verificar contextos atuais
ls -Z /etc/pki/tls/certs/*.crt
ls -Z /etc/pki/tls/private/*.key

# Contextos corretos:
# Certificados: system_u:object_r:cert_t:s0
# Chaves privadas: system_u:object_r:cert_t:s0

# Corrigir contextos se errados
sudo restorecon -Rv /etc/pki/tls/

# Verificar
ls -Z /etc/pki/tls/certs/server.crt
# system_u:object_r:cert_t:s0  ← Correto
```

### Política Certificado SELinux

```bash
#============================================#
# FORTALECIMENTO CERTIFICADO SELINUX
#============================================#

# Garantir SELinux enforcing
getenforce
# Enforcing  ← Bom

# Se permissive, habilitar enforcing
sudo setenforce 1

# Tornar permanente
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Verificar por negações relacionadas certificado
sudo ausearch -m avc -ts recent | grep cert

# Se negações encontradas, gerar política
sudo ausearch -m avc -ts recent | audit2allow -M mycert-policy
sudo semodule -i mycert-policy.pp
```

---

## 40.3 Fortalecimento de permissões de arquivos

### Modelo Permissão Rigoroso

```bash
#============================================#
# PERMISSÕES ARQUIVO FORTALECIDAS
#============================================#

# Certificados (públicos) - acesso mínimo
sudo chmod 444 /etc/pki/tls/certs/*.crt
sudo chown root:root /etc/pki/tls/certs/*.crt

# Chaves privadas (secretas!) - apenas proprietário
sudo chmod 400 /etc/pki/tls/private/*.key
sudo chown root:root /etc/pki/tls/private/*.key

# Ainda mais rigoroso: Imutável (não pode ser modificado mesmo por root sem remover flag)
sudo chattr +i /etc/pki/tls/certs/critical.crt
sudo chattr +i /etc/pki/tls/private/critical.key

# Remover imutável quando necessitar atualizar
# sudo chattr -i /etc/pki/tls/private/critical.key

# Verificar
ls -l /etc/pki/tls/private/
# -r--------. 1 root root  ← 400, muito restritivo
```

---

## 40.4 TPM (Trusted Platform Module)

### Usando TPM para Armazenamento Chave

**Benefícios TPM:**
- ✅ Chaves protegidas hardware
- ✅ Chaves nunca saem TPM
- ✅ Resistente adulteração
- ✅ Atestação plataforma

```bash
#============================================#
# TPM PARA CHAVES CERTIFICADO (AVANÇADO)
#============================================#

# Verificar se TPM disponível
ls /dev/tpm*

# Instalar ferramentas TPM
sudo dnf install tpm2-tools -y

# Gerar chave em TPM
tpm2_createprimary -C o -g sha256 -G rsa -c primary.ctx
tpm2_create -G rsa -u rsa.pub -r rsa.priv -C primary.ctx

# Usar chave TPM com OpenSSL requer setup adicional
# (Complexo, caso uso empresarial)

# Para certmonger com TPM:
# Experimental/avançado - verificar docs Red Hat
```

---

## 40.5 Smart Cards e PIV

### Usando Smart Cards para Autenticação

```bash
#============================================#
# SETUP SMART CARD (PIV/CAC)
#============================================#

# Instalar suporte smart card
sudo dnf install opensc pcsc-lite -y

# Iniciar daemon PC/SC
sudo systemctl enable --now pcscd

# Verificar se cartão legível
pkcs11-tool --list-slots

# Listar certificados no cartão
pkcs11-tool --list-objects

# Usar smart card com SSH
# /etc/ssh/sshd_config:
# PubkeyAuthentication yes

# Extrair chave pública do cartão
ssh-keygen -D /usr/lib64/opensc-pkcs11.so > ~/.ssh/authorized_keys
```

---

## 40.6 Auditoria e Monitoramento

### auditd para Acesso Certificado

```bash
#============================================#
# AUDITAR ACESSO CERTIFICADO
#============================================#

# Adicionar regras audit para acesso chave privada
sudo auditctl -w /etc/pki/tls/private/ -p war -k certificate-access

# Tornar permanente
echo "-w /etc/pki/tls/private/ -p war -k certificate-access" | \
  sudo tee -a /etc/audit/rules.d/certificate.rules

# Recarregar regras
sudo augenrules --load

# Monitorar acesso
sudo ausearch -k certificate-access

# Monitoramento tempo real
sudo ausearch -k certificate-access -ts recent -i
```

---

## 40.7 Scanning OpenSCAP

### Scanning Conformidade Segurança

```bash
#============================================#
# SCANNING CERTIFICADO OPENSCAP
#============================================#

# Instalar OpenSCAP
sudo dnf install openscap-scanner scap-security-guide -y

# Scan por problemas certificado
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_pci-dss \
  --results scan-results.xml \
  --report scan-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Ver relatório
firefox scan-report.html

# Verificações relacionadas certificado:
# - Permissões arquivo
# - Contextos SELinux
# - Algoritmos fracos
# - Expiração
```

---

## 40.8 Lista de verificação de fortalecimento de segurança

```markdown
## Lista de verificação de fortalecimento de segurança de certificados

### Segurança Arquivo
- [ ] Chaves privadas modo 400 ou 600 (nunca 644!)
- [ ] Certificados modo 444 ou 644
- [ ] Propriedade: root:root ou usuário serviço
- [ ] Contextos SELinux: cert_t
- [ ] Considerar flag imutável (+i) para certs críticos

### Controle Acesso
- [ ] SELinux enforcing
- [ ] Regras audit para acesso chave privada
- [ ] Firewall limitando portas TLS
- [ ] Princípio menor privilégio aplicado

### Segurança Algoritmo
- [ ] Apenas assinaturas SHA-256+
- [ ] Chaves RSA 2048+ ou ECC P-256+
- [ ] Apenas TLS 1.2+ (sem 1.0/1.1)
- [ ] Cifras fortes (via crypto-policy)
- [ ] Modo FIPS se requerido

### Segurança Operacional
- [ ] Certificados monitorados para expiração
- [ ] Renovação automática habilitada (certmonger)
- [ ] Backups criptografados
- [ ] Chaves nunca emailadas ou em tickets
- [ ] Acesso logado e revisado
- [ ] Scans segurança regulares

### Segurança Rede
- [ ] Regras firewall restritivas
- [ ] Apenas portas necessárias abertas
- [ ] Certificate pinning (onde aplicável)
- [ ] HSTS habilitado para servidores web
- [ ] OCSP stapling habilitado

### Conformidade
- [ ] Scans OpenSCAP passando
- [ ] Conformidade STIG verificada
- [ ] Benchmarks CIS cumpridos
- [ ] Documentação atual
- [ ] Trilha auditoria mantida
```

---

## 40.9 Conclusões Chave

1. **Defesa em profundidade** - Múltiplas camadas segurança
2. **SELinux enforcing** - Obrigatório para produção
3. **Permissões arquivo críticas** - 400/600 para chaves
4. **Auditar tudo** - Rastrear acesso chave
5. **TPM para alta segurança** - Proteção hardware
6. **OpenSCAP para conformidade** - Scanning automatizado
7. **Monitorar continuamente** - Segurança é contínua

---

## Cartão de Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ FORTALECIMENTO DE SEGURANÇA DE CERTIFICADOS                  │
├──────────────────────────────────────────────────────────────┤
│ Permissões:   chmod 400 /etc/pki/tls/private/*.key           │
│               chmod 444 /etc/pki/tls/certs/*.crt             │
│                                                              │
│ SELinux:      getenforce (deve ser Enforcing)                │
│               restorecon -Rv /etc/pki/tls/                   │
│               ls -Z (verificar contextos)                    │
│                                                              │
│ Auditoria:    auditctl -w /etc/pki/tls/private/ -p war       │
│               ausearch -k certificate-access                 │
│                                                              │
│ Scan:         oscap xccdf eval --profile pci-dss ...         │
│                                                              │
│ Imutável:     chattr +i /etc/pki/tls/private/key.key         │
│               chattr -i (para modificar)                     │
└──────────────────────────────────────────────────────────────┘

✅ SELinux enforcing é obrigatório
✅ Auditar acesso chave privada
✅ Usar 400 (não 600) para segurança máxima
```

---

## 🧪 Laboratório Prático

**Lab 20: Fortalecimento de Segurança**

Aplique melhores práticas de segurança às configurações de certificados

- 📁 **Localização:** `labs/pt_BR/20-security-hardening/`
- ⏱️ **Tempo:** 30-40 minutos
- 🎯 **Nível:** Avançado

---

**Navegação do Capítulo**

| [← Anterior: Capítulo 39 - Certificados Conformes FIPS](39-fips-certificates.md) | [Próximo: Capítulo 41 - Conformidade e Auditoria →](41-compliance-auditing.md) |
|:---|---:|

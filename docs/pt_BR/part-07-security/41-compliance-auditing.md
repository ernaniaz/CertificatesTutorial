# Capítulo 41: Conformidade e Auditoria

> **Cumprir Requisitos:** Aprenda como cumprir requisitos conformidade segurança (STIG, CIS, PCI-DSS) e auditar configurações certificado no RHEL.

---

## 41.1 Frameworks Conformidade

### Requisitos Comuns Relacionados Certificado

| Framework | Foco | Requisitos Certificado |
|-----------|------|------------------------|
| **STIG** | Segurança DoD | FIPS, algoritmos fortes, auditoria |
| **CIS Benchmark** | Melhores práticas indústria | TLS 1.2+, cifras fortes, permissões |
| **PCI-DSS** | Indústria cartão pagamento | Crypto forte, sem TLS/cifras fracas |
| **HIPAA** | Healthcare | Criptografia, controle acesso, auditoria |
| **NIST 800-53** | Sistemas federais | FIPS, algoritmos aprovados, monitoramento |

---

## 41.2 Conformidade STIG

### Requisitos DISA STIG para Certificados

**Requisitos STIG Chave:**

```markdown
## Controles STIG Certificado

### V-238200: SSH deve usar cifras fortes
- Requisito: Apenas algoritmos aprovados FIPS
- Verificar: /etc/ssh/sshd_config
- Corrigir: Usar crypto-policies (RHEL 8+)

### V-238201: Servidor web deve usar TLS forte
- Requisito: Apenas TLS 1.2+
- Verificar: Configuração Apache/NGINX
- Corrigir: Desabilitar TLS 1.0/1.1

### V-238202: Certificados devem ser de CA aprovada DoD
- Requisito: Usar CA aprovada
- Verificar: Emissor certificado
- Corrigir: Obter de fonte aprovada

### V-238203: Chaves privadas devem ser protegidas
- Requisito: Modo 600 ou mais rigoroso
- Verificar: ls -l /etc/pki/tls/private/
- Corrigir: chmod 600

### V-238204: Expiração certificado deve ser monitorada
- Requisito: Monitoramento automatizado
- Verificar: Sistema monitoramento em vigor
- Corrigir: Implementar (ver Capítulo 26)
```

### Scanning Conformidade STIG

```bash
#============================================#
# SCAN CONFORMIDADE STIG PARA CERTIFICADOS
#============================================#

# Instalar SCAP Security Guide
sudo dnf install scap-security-guide openscap-scanner -y

# Executar scan STIG
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_stig \
  --results stig-results.xml \
  --report stig-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Ver relatório
firefox stig-report.html

# Verificar descobertas específicas certificado
grep -i "cert\|tls\|ssl" stig-report.html
```

---

## 41.3 Conformidade CIS Benchmark

### Controles CIS para Certificados

**Recomendações CIS RHEL Benchmark:**

```markdown
## Controles Certificado CIS

### 5.2.14: Garantir apenas cifras fortes usadas
- Verificar: Crypto-policy DEFAULT ou FUTURE
- Comando: `update-crypto-policies --show`

### 5.2.15: Garantir apenas algoritmos fortes usados
- Verificar: Sem MD5, SHA-1, chaves fracas
- Scan: Verificar todos certificados

### 5.2.16: Garantir TLS 1.2 mínimo
- Verificar: Crypto-policy ou config serviço
- Testar: `openssl s_client -tls1_2`

### 5.3.1: Garantir permissões em chaves privadas
- Requisito: 600 ou mais rigoroso
- Verificar: `ls -l /etc/pki/tls/private/`

### 5.3.2: Garantir monitoramento expiração certificado
- Requisito: Verificações automatizadas
- Implementação: certmonger ou script monitoramento
```

### Scan Conformidade CIS

```bash
#============================================#
# SCAN CIS BENCHMARK
#============================================#

# Executar scan CIS
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results cis-results.xml \
  --report cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Gerar script remediação
sudo oscap xccdf generate fix \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --fix-type bash \
  cis-results.xml > remediation.sh

# Revisar e executar remediação
chmod +x remediation.sh
sudo ./remediation.sh
```

---

## 41.4 Conformidade PCI-DSS

### Requisitos Certificado PCI-DSS

**Requisitos PCI-DSS v4.0:**

```markdown
## Controles Certificado PCI-DSS

### Requisito 4.2.1: Criptografia forte
- TLS 1.2 mínimo (1.3 recomendado)
- Apenas suites cipher fortes
- Verificar: crypto-policy DEFAULT ou FUTURE

### Requisito 4.2.1.1: Protocolos inseguros desabilitados
- SEM SSL, TLS 1.0, TLS 1.1
- Verificar: `openssl s_client -tls1`
- Deveria falhar em sistema conforme

### Requisito 4.2.1.2: Algoritmos criptografia fortes
- AES-128 mínimo
- SEM 3DES, DES, RC4
- Verificar: `openssl ciphers -v`

### Requisito 8.3.2: Autenticação baseada certificado
- Para acesso administrativo
- Implementação: Certificados cliente, smart cards

### Requisito 10: Auditar acesso certificado
- Logar todo acesso chave privada
- Implementação: Regras auditd
```

### Script Validação PCI-DSS

```bash
#!/bin/bash
# pci-dss-cert-check.sh

echo "=== Verificação Conformidade Certificado PCI-DSS ==="

# Verificação 1: Apenas TLS 1.2+
echo "1. Verificação Versão TLS:"
if openssl s_client -connect localhost:443 -tls1 &>/dev/null; then
  echo "  ❌ FALHA: TLS 1.0 está habilitado"
else
  echo "  ✅ PASSOU: TLS 1.0 desabilitado"
fi

# Verificação 2: Cifras fortes
echo ""
echo "2. Força Cipher:"
WEAK=$(openssl ciphers -v | grep -Ei "3des|rc4|des-cbc" | wc -l)
if [ $WEAK -gt 0 ]; then
  echo "  ❌ FALHA: Cifras fracas disponíveis"
else
  echo "  ✅ PASSOU: Sem cifras fracas"
fi

# Verificação 3: Monitoramento expiração certificado
echo ""
echo "3. Monitoramento Expiração:"
if systemctl is-active --quiet certmonger || \
   systemctl list-timers | grep -q cert-monitor; then
  echo "  ✅ PASSOU: Monitoramento habilitado"
else
  echo "  ⚠️ AVISO: Nenhum monitoramento automatizado detectado"
fi

# Verificação 4: Permissões chave privada
echo ""
echo "4. Permissões Chave Privada:"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
if [ $BAD_PERMS -gt 0 ]; then
  echo "  ❌ FALHA: $BAD_PERMS chaves com permissões erradas"
else
  echo "  ✅ PASSOU: Todas chaves apropriadamente protegidas"
fi

echo ""
echo "=== Verificação Completa ==="
```

---

## 41.5 Procedimentos Auditoria

### Lista de verificação de auditoria de certificados

```markdown
## Lista de verificação trimestral de auditoria de certificados

### Revisão Inventário
- [ ] Todos certificados documentados
- [ ] Inventário certificados atual
- [ ] Propriedade documentada
- [ ] Propósito documentado

### Revisão Expiração
- [ ] Sem certificados expirados
- [ ] Sem certificados expirando < 30 dias
- [ ] Processo renovação documentado
- [ ] Alertas monitoramento funcionando

### Revisão Segurança
- [ ] Apenas assinaturas SHA-256+ (sem SHA-1 e MD5)
- [ ] Chaves RSA 2048+ ou ECC P-256+
- [ ] Apenas TLS 1.2+ (sem 1.0/1.1)
- [ ] Permissões chave privada corretas (600)
- [ ] Contextos SELinux corretos
- [ ] Sem certificados desnecessários

### Revisão Configuração
- [ ] Configurações serviço revisadas
- [ ] Crypto-policy apropriada
- [ ] Sem overrides cipher fracos
- [ ] HSTS habilitado (servidores web)
- [ ] Certificate pinning documentado

### Revisão Acesso
- [ ] Logs audit revisados
- [ ] Acesso não autorizado investigado
- [ ] Acesso chave limitado a pessoal autorizado
- [ ] Acesso backup controlado

### Revisão Conformidade
- [ ] Conformidade STIG/CIS/PCI verificada
- [ ] Scans segurança passando
- [ ] Remediação completa
- [ ] Documentação atualizada
```

---

## 41.6 Relatório Conformidade Automatizado

### Gerar Relatório Conformidade

```bash
#!/bin/bash
# generate-compliance-report.sh

REPORT_FILE="compliance-report-$(date +%Y%m%d).txt"

cat > "$REPORT_FILE" << EOF
=== Relatório Conformidade Certificado ===
Gerado: $(date)
Sistema: $(hostname)
Versão RHEL: $(cat /etc/redhat-release)

=== Configuração ===
Versão OpenSSL: $(openssl version)
Crypto-Policy: $(update-crypto-policies --show 2>/dev/null || echo "N/A (RHEL 7)")
Modo FIPS: $(fips-mode-setup --check 2>/dev/null || echo "N/A")
SELinux: $(getenforce)

=== Inventário Certificados ===
EOF

# Contar certificados
TOTAL=$(find /etc/pki/tls/certs/ -name "*.crt" -type f 2>/dev/null | wc -l)
echo "Total Certificados: $TOTAL" >> "$REPORT_FILE"

# Verificar expirações
echo "" >> "$REPORT_FILE"
echo "Status Expiração:" >> "$REPORT_FILE"
EXPIRING=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*30)) 2>/dev/null; then
    echo "  ⚠️ Expira dentro 30 dias: $cert" >> "$REPORT_FILE"
    ((EXPIRING++))
  fi
done
echo "Certificados expirando < 30 dias: $EXPIRING" >> "$REPORT_FILE"

# Verificar algoritmos
echo "" >> "$REPORT_FILE"
echo "Conformidade Algoritmo:" >> "$REPORT_FILE"
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -qi "sha1.*signature"; then
    echo "  ❌ Assinatura SHA-1: $cert" >> "$REPORT_FILE"
    ((SHA1_COUNT++))
  fi
done
echo "Certificados SHA-1: $SHA1_COUNT (deveria ser 0)" >> "$REPORT_FILE"

# Verificar permissões
echo "" >> "$REPORT_FILE"
echo "Conformidade Permissão:" >> "$REPORT_FILE"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
echo "Chaves com permissões incorretas: $BAD_PERMS (deveria ser 0)" >> "$REPORT_FILE"

# Status certmonger
if command -v getcert &>/dev/null; then
  echo "" >> "$REPORT_FILE"
  echo "Status certmonger:" >> "$REPORT_FILE"
  sudo getcert list | grep "status:" | sort | uniq -c >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "=== Relatório Completo ===" >> "$REPORT_FILE"

cat "$REPORT_FILE"
echo ""
echo "Relatório salvo em: $REPORT_FILE"
```

---

## 41.7 Conclusões Chave

1. **Conformidade é contínua** - Não única vez
2. **Múltiplos frameworks existem** - STIG, CIS, PCI, HIPAA
3. **OpenSCAP automatiza scanning** no RHEL
4. **Documentar tudo** - Requerido para auditorias
5. **Auditorias regulares essenciais** - Trimestral mínimo
6. **Remediação deve ser rastreada** - Corrigir e verificar
7. **Monitoramento é conformidade** - Validação contínua

---

## Cartão de Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CONFORMIDADE E AUDITORIA                   │
├──────────────────────────────────────────────────────────────┤
│ STIG:         oscap ... --profile stig                       │
│ CIS:          oscap ... --profile cis                        │
│ PCI-DSS:      oscap ... --profile pci-dss                    │
│                                                              │
│ Requisitos Comuns:                                           │
│   - Apenas TLS 1.2+                                          │
│   - Algoritmos fortes (SHA-256+, RSA 2048+)                  │
│   - Sem cifras fracas (3DES, RC4)                            │
│   - Chaves privadas protegidas (modo 600)                    │
│   - Monitoramento expiração                                  │
│   - Logging auditoria habilitado                             │
│   - Modo FIPS (para federal)                                 │
│                                                              │
│ Ferramentas:  OpenSCAP, aide, auditd                         │
│ Scan:         oscap xccdf eval --profile <profile> ...       │
│ Remediar:     oscap xccdf generate fix ...                   │
└──────────────────────────────────────────────────────────────┘

✅ Conformidade é contínua, não única vez
✅ Automatizar scanning com OpenSCAP
✅ Documentar todas configurações e exceções
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 40 - Fortalecimento de Segurança de Certificados no RHEL](40-security-hardening.md) | |
|:---|---:|

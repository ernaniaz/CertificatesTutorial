# Início Rápido de Solução de Problemas

**Quando você tiver um problema de certificado, comece aqui!**

---

## 🚨 Emergência? Pule para o Capítulo 33!

Se a produção estiver fora do ar, vá imediatamente para [Capítulo 33: Procedimentos de Emergência](part-05-troubleshooting/33-emergency-procedures.md)

---

## 📋 O Método de 7 Passos (Capítulo 27)

```
1. Identificar: versão do RHEL, OpenSSL e crypto-policy
2. Verificar: expiração, hostname, correspondência chave-certificado e algoritmo
3. Confiança: validação da CA, cadeia e intermediários
4. Configuração: arquivos do serviço, caminhos e permissões
5. Sistema: crypto-policy, FIPS, SELinux e firewall
6. Testar: conexões ao vivo, curl e openssl s_client
7. Logs: logs do serviço, journal e auditoria SELinux
```

**Metodologia completa:** [Capítulo 27](part-05-troubleshooting/27-troubleshooting-methodology.md)

---

## ⚡ Diagnóstico Rápido

### Primeiros 60 Segundos

```bash
# Qual versão do RHEL?
cat /etc/redhat-release

# Certificado expirado?
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -checkend 0

# Serviço em execução?
systemctl status httpd

# Erros recentes?
journalctl -xe | grep -i cert | tail -20

# Crypto-policy? (RHEL 8+)
update-crypto-policies --show
```

---

## 🔍 Problemas Comuns

### Certificado Expirado
```bash
# Verificar
openssl x509 -in cert.crt -noout -dates

# Corrigir
sudo getcert resubmit -f cert.crt  # Se estiver usando certmonger
# Ou renovar manualmente, ou usar os procedimentos de emergência do Capítulo 33
```

### Cadeia de Confiança Quebrada
```bash
# Verificar
openssl verify cert.crt

# Corrigir
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### Permissão Negada
```bash
# Verificar
ls -l /etc/pki/tls/private/server.key

# Corrigir
sudo chmod 600 /etc/pki/tls/private/server.key
sudo chown root:root /etc/pki/tls/private/server.key
```

### Desajuste de Hostname
```bash
# Verificar
openssl x509 -in cert.crt -noout -ext subjectAltName

# Corrigir
# Reemitir certificado com SANs corretos
```

### Nenhuma Cifra em Comum (RHEL 8+)
```bash
# Verificar
update-crypto-policies --show

# Correção temporária
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd

# Correção apropriada: atualizar o cliente para suportar TLS 1.2+
```

### SHA-1 Rejeitado (RHEL 9+)
```bash
# Verificar
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"

# Corrigir
# Deve reemitir com SHA-256+ (sem contorno alternativo)
```

---

## 📖 Onde Procurar

| Tipo de Problema | Ir para o Capítulo |
|------------------|--------------------|
| **Solução de problemas geral** | Capítulo 27 |
| **Erros comuns** | Capítulo 28 |
| **Problemas Apache/NGINX/Postfix** | Capítulo 29 |
| **Problemas do certmonger** | Capítulo 30 |
| **Problemas de crypto-policy** | Capítulo 31 |
| **Análise de relatórios SOS** | Capítulo 32 |
| **Emergência em produção** | Capítulo 33 |
| **Específico para RHEL 7** | Capítulo 9 |
| **Específico para RHEL 8** | Capítulo 10 |
| **Específico para RHEL 9** | Capítulo 11 |
| **Específico para RHEL 10** | Capítulo 12 |
| **Após migração** | Capítulos 35-36 |

---

## ⚙️ Comandos Específicos por Serviço

```bash
# Apache
apachectl configtest
tail -f /var/log/httpd/ssl_error_log

# NGINX
nginx -t
tail -f /var/log/nginx/error.log

# Postfix
postfix check
tail -f /var/log/maillog | grep TLS

# OpenLDAP
slapcat -b "cn=config" | grep TLS
# Nota: as chaves devem pertencer a ldap:ldap!

# PostgreSQL
sudo -u postgres psql -c "SHOW ssl;"
# Nota: as chaves devem pertencer a postgres:postgres!

# certmonger
getcert list
journalctl -u certmonger -f
```

---

## 🎯 Referência Rápida

**Problemas Mais Comuns:**
1. Certificado expirado → Renovar
2. CA faltando → Adicionar ao repositório de confiança
3. Permissões erradas → chmod 600
4. Desajuste cert/chave → Regenerar CSR
5. Desajuste de hostname → Reemitir com SANs
6. Versão TLS → Verificar crypto-policy
7. SELinux negando → restorecon
8. certmonger CA_UNREACHABLE → Verificar IPA/Kerberos

**Emergência:** [Capítulo 33](part-05-troubleshooting/33-emergency-procedures.md)

**Metodologia:** [Capítulo 27](part-05-troubleshooting/27-troubleshooting-methodology.md)

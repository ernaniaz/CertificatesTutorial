# Lab 15: Cenários de Resolução de Problemas

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Diagnosticar um problema de certificado expirado
- Usar ferramentas de resolução de problemas de forma eficaz
- Corrigir certificados expirados
- Seguir uma metodologia estruturada de resolução de problemas

## Pré-requisitos

- **Labs 01-10** concluídos (compreensão de certificados e serviços)
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Mentalidade de resolução de problemas** necessária

## Tempo estimado

**15-20 minutos**

## Visão geral

Cenário real de resolução de problemas! Este laboratório cria um problema específico de certificado e guia você pelo diagnóstico e resolução. É um dos problemas mais comuns que você encontrará em produção.

---

## Estrutura do laboratório

Este laboratório contém atualmente **um cenário implementado**:

```
15-troubleshooting-scenarios/
├── scenario-01-expired-cert/
├── run-all.sh
└── cleanup-all.sh
```

Cada cenário inclui:
- **create-problem.sh** - Configura o problema
- **diagnose.sh** - Passos de diagnóstico para encontrar o problema
- **fix.sh** - Solução para corrigir o problema
- **verify-fix.sh** - Valida se a correção funcionou
- **README.md** - Descrição do cenário e notas de aprendizagem

---

## Instruções

### Execute o cenário

```bash
cd scenario-01-expired-cert
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

Ou use o script auxiliar a partir do diretório do laboratório:

```bash
sudo ./run-all.sh
```

---

## Cenários

### Cenário 01: Certificado expirado

**Problema:** Certificado expirou, causando falhas de conexão

**Sintomas:**
- "certificate has expired"
- Falhas de handshake SSL
- Avisos de segurança no navegador

**Ferramentas:** `openssl x509 -dates`, inspeção de certificados

**Aprendizado:** Gerenciamento do ciclo de vida de certificados, importância da renovação

Consulte `scenario-01-expired-cert/README.md` para detalhes completos do cenário.

---

## Validação

Para verificar se você concluiu este laboratório com sucesso:

```bash
cd scenario-01-expired-cert
sudo ./verify-fix.sh
```

**Resultados esperados:**
- `verify-fix.sh` informa que todas as verificações passaram
- O arquivo de certificado existe em `/etc/pki/tls/certs/expired.crt`
- O certificado é válido e não está expirado
- O certificado é válido por pelo menos 30 dias
- O subject do certificado corresponde a `expired.example.com`

---

## Metodologia de resolução de problemas

Cada cenário segue esta metodologia:

1. **Observar** - Identificar sintomas
2. **Coletar** - Reunir logs e dados de diagnóstico
3. **Analisar** - Determinar causa raiz
4. **Corrigir** - Implementar solução
5. **Verificar** - Confirmar resolução
6. **Documentar** - Registrar para referência futura

---

## Comandos-chave de resolução de problemas

### Inspeção de certificados
```bash
# Visualizar certificado
openssl x509 -in cert.pem -text -noout

# Verificar expiração
openssl x509 -in cert.pem -noout -dates

# Verificar cadeia de certificados
openssl verify -CAfile ca.pem cert.pem

# Verificar se certificado corresponde à chave
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
```

### Teste de conexão
```bash
# Testar conexão TLS
openssl s_client -connect host:443 -servername host

# Mostrar cadeia de certificados
openssl s_client -connect host:443 -showcerts

# Testar versão TLS específica
openssl s_client -connect host:443 -tls1_2

# Verificar cifras disponíveis
openssl s_client -connect host:443 -cipher 'HIGH'
```

### Depuração de serviços
```bash
# Verificar logs do serviço
journalctl -xeu httpd
journalctl -xeu nginx

# Testar configuração
apachectl configtest
nginx -t

# Verificar negações SELinux
ausearch -m avc -ts recent
sealert -a /var/log/audit/audit.log
```

---

## Limpeza

Cada cenário tem sua própria limpeza, ou use a limpeza principal:

```bash
sudo ./cleanup-all.sh
```

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 27: Metodologia de Solução de Problemas de Certificados RHEL
- Capítulo 28: Erros Comuns de Certificados no RHEL
- Capítulo 29: Solução de Problemas Específica por Serviço

**Ferramentas úteis:**
- `openssl` - Canivete suíço para certificados
- `curl` - Testes HTTP/HTTPS
- `journalctl` - Logs do sistema
- `ausearch` - Logs de auditoria SELinux
- `tcpdump` - Captura de pacotes de rede

---

## Próximos passos

Prossiga para o **Lab 16: Procedimentos de Emergência** para aprender técnicas de recuperação rápida.

---

**Nível de dificuldade:** Avançado
**Nota:** Estes cenários simulam problemas reais de produção

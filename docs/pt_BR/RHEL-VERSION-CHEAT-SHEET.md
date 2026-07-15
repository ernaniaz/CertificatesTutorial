# Folha de Referência de Versões RHEL para Certificados

Referência rápida para diferenças de certificados entre as versões do RHEL.

---

## Visão Geral das Versões

| RHEL | Lançado | OpenSSL | Suporte TLS | Crypto-Policies | Recurso Principal |
|------|---------|---------|-------------|-------------------|-------------------|
| **7** | 2014 | 1.0.2k-26 | 1.0/1.1/1.2 | ❌ Não | Configuração manual |
| **8** | 2019 | 1.1.1k-14 | 1.2/1.3 | ✅ **NOVO!** | Políticas em todo o sistema |
| **9** | 2022 | 3.5.5-2 | 1.2/1.3 | ✅ Aprimorado | OpenSSL 3.x, rigoroso |
| **10** | 2025 | 3.5.5-2 | 1.3 pref | ✅ Aprimorado | Preparação PQC, moderno |

---

## Detecção Rápida

```bash
# Verificar versão do RHEL
cat /etc/redhat-release

# Verificar OpenSSL (verificação indireta da versão)
openssl version
# 1.0.2k = RHEL 7
# 1.1.1k = RHEL 8
# 3.5.5  = RHEL 9 ou 10

# Verificar crypto-policies (apenas RHEL 8+)
update-crypto-policies --show 2>/dev/null || echo "RHEL 7 (sem crypto-policies)"
```

---

## Configuração TLS por Versão

### RHEL 7
```apache
# Configuração manual necessária em todo lugar
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
```

### RHEL 8/9/10
```apache
# crypto-policies lidam com isso automaticamente!
# Sem necessidade de SSLProtocol ou SSLCipherSuite
# Apenas incluir os caminhos do certificado
```

---

## Comandos Comuns por Versão

| Tarefa | RHEL 7 | RHEL 8/9/10 |
|--------|--------|-------------|
| **Gerar Chave** | `openssl genrsa -out key 2048` | `openssl genpkey -algorithm RSA -out key` |
| **Verificar Política** | N/A | `update-crypto-policies --show` |
| **Config TLS** | Manual por serviço | Automática via crypto-policies |
| **certmonger** | Básico | Aprimorado (RHEL 9: suporte ACME) |

---

## Solução de Problemas por Versão

### RHEL 7
- Verificar problemas com TLS 1.0/1.1
- Configurações manuais de cifra
- Sem crypto-policies

### RHEL 8
- Verificar crypto-policy primeiro!
- TLS 1.0/1.1 desabilitados em DEFAULT
- Política LEGACY para compatibilidade

### RHEL 9
- Problemas com o provider OpenSSL 3.x
- SHA-1 BLOQUEADO
- Usar `-provider legacy` para algoritmos antigos

### RHEL 10
- Mesmo que RHEL 9
- Padrões ainda mais rigorosos
- Verificar documentação da versão menor

---

## Impacto da Migração

| Migração | Impacto em Certificados | Mudanças Principais |
|----------|-------------------------|---------------------|
| **7→8** | Moderado-Alto | crypto-policies, TLS 1.0/1.1 bloqueados |
| **8→9** | Alto | OpenSSL 3.x, SHA-1 bloqueado, mais rigoroso |
| **9→10** | Baixo | Mesmo OpenSSL, fortalecimento incremental |

---

## Correções Rápidas por Versão

### Erro "no shared cipher"
- **RHEL 7:** Atualizar a configuração de cifra manualmente
- **RHEL 8/9/10:** `sudo update-crypto-policies --set LEGACY` (temp!)

### Certificado SHA-1
- **RHEL 7/8:** Funciona (depreciado)
- **RHEL 9/10:** BLOQUEADO — deve reemitir

### Cliente TLS 1.0
- **RHEL 7:** Funciona por padrão
- **RHEL 8/9/10:** Bloqueado em DEFAULT, usar LEGACY (temp!)

---

**Detalhes Completos:** Ver Capítulos 9-12

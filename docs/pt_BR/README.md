# Tutorial de PKI e Certificados Digitais

**Um guia completo para dominar certificados no Red Hat Enterprise Linux.**

---

## 📘 Sobre Este Tutorial

Este tutorial ensina tudo sobre certificados digitais no RHEL, desde iniciante completo até especialista em solução de problemas.

**Objetivo Principal:** Capacitá-lo a resolver problemas de certificados com confiança em sistemas RHEL.

**Cobertura:**
- Todas as versões do RHEL (7, 8, 9, 10)
- Todos os serviços principais (Apache, NGINX, Postfix, LDAP, Bancos de dados, FreeIPA)
- Automatização completa (certmonger, crypto-policies, Ansible)
- Solução de problemas especializada
- Orientação de migração
- FIPS e conformidade

---

## 🎯 Para Quem é Este Tutorial

- **Administradores RHEL** - Gerencie certificados profissionalmente
- **Engenheiros de Suporte** - Resolva problemas de certificados
- **Equipes de Segurança** - Implemente FIPS e conformidade
- **Engenheiros DevOps** - Automatize o ciclo de vida de certificados
- **Qualquer pessoa** - Que gerencie sistemas RHEL com TLS/SSL

**Pré-requisitos:**
- Conhecimento básico de linha de comando Linux
- Acesso a sistemas RHEL (uma VM serve)
- Não é necessário conhecimento prévio de certificados!

---

## 📚 Estrutura do Tutorial

### PARTE 01: Fundamentos (Capítulos 1-7)
Introdução aos certificados no contexto do RHEL.

### PARTE 02: Gerenciamento Específico por Versão (Capítulos 8-13) ⭐
Mergulho profundo nas diferenças do RHEL 7, 8, 9, 10.

### PARTE 03: Serviços e Configuração TLS (Capítulos 14-21) ⭐
Configure certificados para todos os serviços principais do RHEL.

### PARTE 04: Automatização de Certificados (Capítulos 22-26) ⭐
Automatize o ciclo de vida de certificados com ferramentas RHEL.

### PARTE 05: Solução de Problemas (Capítulos 27-33) ⭐⭐⭐
**O núcleo deste tutorial!** Metodologia completa de solução de problemas.

### PARTE 06: Migração e Atualizações (Capítulos 34-37)
Migre certificados com segurança entre versões do RHEL.

### PARTE 07: Segurança e FIPS (Capítulos 38-41)
FIPS, fortalecimento e auditoria de conformidade.

### APÊNDICES (A-I)
Kubernetes, Vault, Zero Trust, DevSecOps, IoT, VPN, Glossário, Referências.

---

## ⚡ Início Rápido

📖 **Consulte o [Guia de Trilha de Aprendizado](LEARNING-PATH.md) para instruções detalhadas e trilhas de aprendizado.**

### Opção 1: Comece com os Fundamentos
**Para iniciantes completos:**
- Comece no [Capítulo 1: Criptografia, Estrutura PKI e Fundamentos](part-01-fundamentals/01-cryptography-pki-basics.md), depois continue pelo Capítulo 2 e seguintes em ordem
- Siga o [Guia de Trilha de Aprendizado](LEARNING-PATH.md)

### Opção 2: Comece com Solução de Problemas
**Para administradores experientes:**
- Pule para o [Capítulo 27: Metodologia de Solução de Problemas de Certificados RHEL](part-05-troubleshooting/27-troubleshooting-methodology.md)
- Use o [Início Rápido de Solução de Problemas](TROUBLESHOOTING-QUICK-START.md)

### Opção 3: Referência Rápida
**Para consultas rápidas:**
- [Folha de Referência de Versões RHEL para Certificados](RHEL-VERSION-CHEAT-SHEET.md)
- Consulte o [sumário completo](SUMMARY.md)

---

## 🔑 Características Principais

### ✅ Foco em RHEL
Todo o conteúdo é escrito especificamente para RHEL. Sem informações genéricas - apenas comandos específicos do RHEL, ferramentas e melhores práticas.

### ✅ Comparação de Versões
Cada capítulo compara comportamentos entre RHEL 7, 8, 9 e 10. Você sempre saberá qual versão está usando.

### ✅ Exemplos Práticos
151 scripts prontos para produção que você pode copiar e colar. Todos testados em RHEL real.

### ✅ Foco em Solução de Problemas
7 capítulos completos dedicados à resolução sistemática de problemas. Aprenda a diagnosticar QUALQUER problema de certificado.

### ✅ Guia de Migração
Procedimentos passo a passo para migrar certificados entre versões do RHEL (7→8, 8→9).

### ✅ Conformidade FIPS
Guias completos para modo FIPS, fortalecimento e auditoria de conformidade.

---

## 📖 Como Usar Este Tutorial

### Estudantes Iniciantes
1. Leia os capítulos em ordem (1-41)
2. Pratique cada comando em seu sistema RHEL
3. Complete os cenários no final de cada capítulo
4. Consulte o glossário quando encontrar novos termos

**Tempo estimado:** 40-50 horas

### Administradores Experientes
1. Revise a [Folha de Referência de Versões RHEL para Certificados](RHEL-VERSION-CHEAT-SHEET.md)
2. Leia apenas os capítulos específicos da sua versão
3. Foque nos capítulos de solução de problemas (27-33)
4. Use o tutorial como referência

**Tempo estimado:** 15-20 horas

### Engenheiros de Suporte
1. Comece com o [Início Rápido de Solução de Problemas](TROUBLESHOOTING-QUICK-START.md)
2. Leia a Parte 05 completa (solução de problemas)
3. Marque capítulos de serviço relevantes
4. Mantenha aberto para referência durante incidentes

**Tempo estimado:** 10-15 horas

---

## 🎓 Caminhos de Aprendizagem

Veja o [Guia de Trilha de Aprendizado](LEARNING-PATH.md) para trilhas detalhadas por função:
- Iniciante Completo
- Administrador de Sistemas RHEL
- Engenheiro de Suporte
- Engenheiro DevOps
- Arquiteto de Segurança

---

## 💡 Melhores Práticas Destacadas

Este tutorial enfatiza:

### ✅ Usar Ferramentas Nativas do RHEL
- **certmonger** para renovação automática
- **update-ca-trust** para gerenciamento de repositório de confiança
- **crypto-policies** para configuração em todo o sistema

### ✅ Automatização Primeiro
Automatize tudo com certmonger, Ansible ou scripts. Certificados manuais são um risco.

### ✅ Monitoramento de Expiração
Configure alertas 30 dias antes da expiração. Nunca deixe certificados expirarem.

### ✅ Procedimentos de Migração
Sempre teste migrações de certificados antes de atualizar o RHEL.

### ✅ Documentação FIPS
Documente todas as decisões de configuração FIPS para auditorias.

---

## 🔧 Ferramentas RHEL Cobertas

### Ferramentas de Gerenciamento de Certificados
- **certmonger** - Renovação automática de certificados
- **openssl** - Operações de certificados
- **update-ca-trust** - Gerenciamento de repositório de confiança
- **crypto-policies** - Política de criptografia em todo o sistema

### Ferramentas de Solução de Problemas
- **sosreport** - Coleta de dados do sistema
- **openssl verify** - Validação de certificados
- **openssl s_client** - Teste de conexão TLS
- **getcert list** - Status do certmonger

### Ferramentas de Automatização
- **Ansible** - Automatização de configuração
- **certbot** - Let's Encrypt (do EPEL)
- **FreeIPA** - CA empresarial

---

## 📊 Estatísticas do Tutorial

- **41 Capítulos** em 7 partes principais
- **9 Apêndices** de referência
- **151 Scripts** prontos para produção
- **90+ Tabelas** de comparação
- **32 Cartões** de referência rápida
- **50+ Procedimentos** de solução de problemas
- **~27.000 Linhas** de conteúdo

---

## 🆘 Obter Ajuda

### Durante o Aprendizado
- Consulte o **Glossário** (Apêndice H) para definições de termos
- Revise as **Referências** (Apêndice I) para recursos externos
- Consulte o **Guia de Solução de Problemas** (Capítulos 27-33)

### Para Problemas Específicos do RHEL
- Red Hat Customer Portal: https://access.redhat.com
- Documentação RHEL: https://access.redhat.com/documentation
- Red Hat KB: Pesquise códigos de erro específicos

### Para Conceitos PKI Gerais
- OpenSSL Documentation: https://www.openssl.org/docs/
- RFC 5280 (X.509): https://www.rfc-editor.org/rfc/rfc5280
- Let's Encrypt Docs: https://letsencrypt.org/docs/

---

## ✅ O Que Você Aprenderá

Ao completar este tutorial, você poderá:

### Fundamentos
- ✅ Explicar como funcionam os certificados digitais
- ✅ Entender PKI, CAs e cadeias de confiança
- ✅ Trabalhar com ferramentas OpenSSL
- ✅ Gerenciar o repositório de confiança do RHEL

### Específico por Versão
- ✅ Identificar diferenças entre RHEL 7/8/9/10
- ✅ Usar crypto-policies no RHEL 8+
- ✅ Gerenciar certificados em cada versão
- ✅ Lidar com problemas de compatibilidade

### Configuração de Serviços
- ✅ Configurar TLS para Apache e NGINX
- ✅ Proteger Postfix com TLS
- ✅ Configurar LDAPS no OpenLDAP
- ✅ Habilitar TLS para bancos de dados
- ✅ Integrar com FreeIPA
- ✅ Proteger outros serviços RHEL

### Automatização
- ✅ Configurar certmonger para renovação automática
- ✅ Personalizar crypto-policies
- ✅ Integrar Let's Encrypt com certbot
- ✅ Automatizar com Ansible
- ✅ Configurar monitoramento e alertas

### Solução de Problemas ⭐⭐⭐
- ✅ Diagnosticar QUALQUER problema de certificado
- ✅ Resolver erros comuns de certificados
- ✅ Solucionar problemas específicos de serviço
- ✅ Depurar problemas do certmonger
- ✅ Resolver conflitos de crypto-policy
- ✅ Analisar relatórios SOS
- ✅ Executar procedimentos de emergência

### Migração
- ✅ Planejar migrações de certificados
- ✅ Migrar RHEL 7→8
- ✅ Migrar RHEL 8→9
- ✅ Solucionar problemas de migração
- ✅ Validar após a migração

### Segurança
- ✅ Habilitar e usar modo FIPS
- ✅ Gerar certificados conformes FIPS
- ✅ Fortalecer configurações TLS
- ✅ Auditar conformidade
- ✅ Implementar melhores práticas de segurança

---

## 🌟 Comece a Aprender!

**Comece aqui:** [Capítulo 1: Criptografia, Estrutura PKI e Fundamentos →](part-01-fundamentals/01-cryptography-pki-basics.md)

**Ou pule para:** [Início Rápido de Solução de Problemas](TROUBLESHOOTING-QUICK-START.md)

---

*Autor: Ernani Azevedo <azevedo@voipdomain.io>*
*Repositório: [github.com/ernaniaz/CertificatesTutorial](https://github.com/ernaniaz/CertificatesTutorial)*
*Licença: [CC BY 4.0](../../LICENSE.md)*

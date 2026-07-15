# Lab 21: Kubernetes cert-manager

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender a arquitetura e os componentes do cert-manager
- Instalar e configurar minikube para testes locais de Kubernetes
- Implantar cert-manager em um cluster Kubernetes
- Criar múltiplos tipos de issuer (autoassinado, CA, ACME)
- Solicitar e gerenciar certificados usando cert-manager
- Configurar TLS para Kubernetes Ingress
- Entender renovação automática de certificados

## Pré-requisitos

- **Dependências de laboratório:** Labs 01-05 concluídos (noções básicas de certificados)
- **Versão do RHEL:** RHEL 8, 9 ou 10
- **Acesso ao sistema:** Privilégios de root ou sudo necessários
- **Requisitos adicionais:**
  - Mínimo de 2 núcleos de CPU (para minikube)
  - 2GB de RAM disponível
  - 20GB de espaço em disco
  - Conectividade com internet para downloads
  - Docker ou podman instalado (driver do minikube)

## Tempo estimado

**40-50 minutos** (inclui configuração do minikube e implantação do cert-manager)

## Visão geral

cert-manager é um projeto da Cloud Native Computing Foundation (CNCF) que automatiza o gerenciamento de certificados em clusters Kubernetes. Ele atua como um controlador de certificados, solicitando certificados de várias fontes e garantindo que estejam válidos e atualizados.

---

## Arquitetura do cert-manager

### Componentes principais

**Issuer / ClusterIssuer:**
- Define a autoridade certificadora (CA) ou servidor ACME
- Issuer: escopo de namespace
- ClusterIssuer: escopo de cluster

**Certificate:**
- Recurso personalizado do Kubernetes que define o certificado desejado
- Especifica nomes DNS, duração, configurações de renovação
- Resulta em um Kubernetes Secret contendo o certificado

**Controlador:**
- Observa recursos Certificate
- Solicita certificados dos Issuers configurados
- Armazena certificados em Kubernetes Secrets
- Gerencia renovação automática

---

## Instruções

### Passo 1: Instale o Minikube

Instale e inicie o minikube para testes locais de Kubernetes:

```bash
./install-minikube.sh
```

**O que isto faz:**
- Baixa e instala o binário minikube
- Instala kubectl se não estiver presente
- Inicia um cluster Kubernetes local
- Configura contexto kubectl

**Saída orientativa:**
```
Cabeçalho da etapa atual
Mensagens sobre detecção ou instalação de docker/podman, kubectl e minikube
Inicialização ou reaproveitamento do cluster minikube
Verificação final com `kubectl cluster-info` e `kubectl get nodes`
Resumo com o estado real do cluster e os próximos passos
```

**Verificação:**
```bash
kubectl cluster-info
kubectl get nodes
```

---

### Passo 2: Instale o cert-manager

Implante cert-manager no cluster Kubernetes:

```bash
./install-cert-manager.sh
```

**O que isto faz:**
- Aplica as CRDs (definições de recursos personalizados) do cert-manager
- Implanta componentes do cert-manager
- Aguarda pods ficarem prontos
- Verifica instalação

**Saída orientativa:**
```
Cabeçalho da etapa atual
Checagem de pré-requisitos e aplicação dos manifests do cert-manager
Espera de pods e CRDs com mensagens de progresso
Resumo final indicando que o cert-manager ficou instalado e qual script executar em seguida
```

**Verificação:**
```bash
kubectl get pods -n cert-manager
```

---

### Passo 3: Crie issuer autoassinado

Crie um issuer de certificado autoassinado:

```bash
./create-selfsigned-issuer.sh
```

**O que isto faz:**
- Cria ClusterIssuer para certificados autoassinados
- Útil para testes e desenvolvimento
- Certificados assinados pela própria chave privada

**Saída orientativa:**
```
Checagem de pré-requisitos
Criação de `selfsigned-issuer`
Espera breve até o issuer ficar Ready, ou aviso se o status ainda não estiver claro
Resumo com `kubectl get clusterissuer` e `kubectl describe clusterissuer selfsigned-issuer`
```

---

### Passo 4: Crie issuer CA

Crie issuer baseado em CA usando CA personalizada:

```bash
./create-ca-issuer.sh
```

**O que isto faz:**
- Gera certificado e chave CA personalizados
- Armazena CA em Kubernetes Secret
- Cria ClusterIssuer que usa a CA
- Permite emitir certificados assinados pela sua CA

**Saída orientativa:**
```
Geração de uma CA local em `ca-output/`
Criação do Secret `ca-key-pair` no namespace `cert-manager`
Criação de `ca-issuer`
Espera até o issuer ficar Ready ou mostrar um aviso de inicialização
```

---

### Passo 5: Crie issuer Let's Encrypt

Crie issuer ACME para certificados Let's Encrypt:

```bash
./create-letsencrypt-issuer.sh
```

**Notas importantes:**
- ⚠️ Usa ambiente **staging** do Let's Encrypt (seguro para testes)
- ⚠️ Exige nome de domínio válido para uso em produção
- ⚠️ Exige acesso externo para desafio HTTP-01
- 💡 Neste laboratório, crie o issuer para que `./verify.sh` possa confirmar que o ClusterIssuer `letsencrypt-staging` existe e está Ready, mas você não emitirá certificados ACME reais

**Saída orientativa:**
```
Criação de `letsencrypt-staging`
Avisos explicando que o ambiente staging não produz certificados confiáveis para navegadores
Geração de um template separado para produção
Possível espera curta enquanto o cert-manager registra a conta ACME
```

---

### Passo 6: Solicite certificados

> **Obrigatório:** Os passos 3 e 4 devem ser concluídos primeiro. Este script
> requer que tanto o emissor autoassinado quanto o emissor CA existam, e sairá
> com erro se algum estiver ausente.

Solicite certificados usando diferentes issuers:

```bash
./request-certificate.sh
```

**O que isto faz:**
- Verifica se ambos os issuers existem (sai se não)
- Cria recursos Certificate
- Solicita certificado autoassinado
- Solicita certificado assinado por CA
- Aguarda certificados serem emitidos
- Verifica se certificados estão armazenados em Secrets

**Saída orientativa:**
```
Solicitação de `selfsigned-cert` e `ca-signed-cert`
Mensagens de espera enquanto o cert-manager emite os certificados
Confirmação de readiness para cada certificado ou aviso se algum demorar demais
Resumo com os Secrets TLS criados e comandos sugeridos para inspeção
```

**Verificação:**
```bash
kubectl get certificates
kubectl get secrets | grep tls
kubectl describe certificate selfsigned-cert
```

---

### Passo 7: Teste Ingress TLS

Implante aplicação de teste com Ingress TLS:

```bash
./test-ingress-tls.sh
```

**O que isto faz:**
- Implanta aplicação nginx simples
- Cria Service
- Cria Ingress com anotação TLS
- cert-manager cria certificado automaticamente
- Configura Ingress para usar o certificado

**Saída orientativa:**
```
Habilitação ou reaproveitamento do addon/controller de Ingress
Implantação da aplicação de teste, Service e Ingress
Espera enquanto o cert-manager cria o certificado de `test-app.local`
Resumo com recursos implantados, estado do Secret TLS e instruções de acesso (`/etc/hosts`, `curl -k`, `minikube tunnel`)
```

**Verificação:**
```bash
kubectl get ingress
kubectl describe ingress test-app-ingress
kubectl get certificate test-app-tls
```

---

## Validação

Para verificar se o laboratório foi concluído, execute o script de validação:

```bash
./verify.sh
```

**Resultado orientativo:**
```
Série de verificações PASS/FAIL para minikube, kubectl, cert-manager, issuers, certificados, Secret TLS e Ingress
Resumo final com contagem de testes aprovados e falhos
Se tudo estiver correto, mensagem de conclusão do lab
Se algo falhar, bloco de troubleshooting com comandos para revisar pods, logs e certificados
```

---

## Resultado esperado

Após concluir este laboratório, você deve ter:
- ✅ Cluster Kubernetes minikube funcionando
- ✅ cert-manager implantado e operacional
- ✅ Múltiplos issuers de certificados configurados
- ✅ Certificados emitidos e armazenados em Secrets
- ✅ Aplicação de teste com Ingress habilitado para TLS
- ✅ Compreensão de gerenciamento automático de certificados

Você pode verificar executando:
- `kubectl get clusterissuers` (deve mostrar 3 issuers)
- `kubectl get certificates` (deve mostrar múltiplos certificados)
- `kubectl get secrets | grep tls` (deve mostrar secrets de certificados)

---

## Resolução de problemas

### Problema 1: Minikube falha ao iniciar

**Sintoma:**
```
Error: Failed to start minikube
```

**Causa:**
- Docker/podman não instalado ou não em execução
- Recursos de sistema insuficientes
- Virtualização VT-x/AMD-v não habilitada

**Solução:**
```bash
# Verifique se docker está em execução
sudo systemctl status docker

# Verifique recursos do sistema
free -h
df -h

# Tente com driver podman
minikube start --driver=podman

# Ou especifique recursos
minikube start --cpus=2 --memory=2048
```

---

### Problema 2: Pods cert-manager não prontos

**Sintoma:**
```
cert-manager pods in CrashLoopBackOff or Pending state
```

**Causa:**
- Recursos de cluster insuficientes
- CRDs não instalados corretamente
- Problemas de rede

**Solução:**
```bash
# Verifique status dos pods
kubectl get pods -n cert-manager
kubectl describe pod -n cert-manager <pod-name>

# Verifique logs
kubectl logs -n cert-manager deployment/cert-manager

# Reinstale cert-manager
kubectl delete namespace cert-manager
./install-cert-manager.sh
```

---

### Problema 3: Certificado não pronto

**Sintoma:**
```
Certificate status: Issuing (stuck)
```

**Causa:**
- Issuer não configurado corretamente
- Desafio ACME falhando
- Problemas DNS

**Solução:**
```bash
# Verifique detalhes do certificado
kubectl describe certificate <cert-name>

# Verifique logs do cert-manager
kubectl logs -n cert-manager deployment/cert-manager

# Verifique status do issuer
kubectl describe clusterissuer <issuer-name>

# Para problemas autoassinados, recrie issuer
kubectl delete clusterissuer selfsigned-issuer
./create-selfsigned-issuer.sh
```

---

### Problema 4: Comando kubectl não encontrado

**Sintoma:**
```
bash: kubectl: command not found
```

**Causa:**
- kubectl não instalado
- Não está no PATH

**Solução:**
```bash
# Instale kubectl manualmente
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Ou execute install-minikube.sh novamente
./install-minikube.sh
```

---

## Notas específicas por versão

### RHEL 8
- Docker/podman disponíveis nos repositórios padrão
- Pode ser necessário habilitar módulo container-tools
- `sudo dnf module enable container-tools`

### RHEL 9
- Podman recomendado em relação ao Docker
- Ferramentas de container integradas
- Pode ser necessário configurar cgroup v2 para minikube

### RHEL 10
- Versão mais recente do podman
- Suporte completo a runtime de container
- Nenhuma configuração especial necessária

---

## Limpeza

Para redefinir o sistema e remover todos os recursos Kubernetes:

```bash
./cleanup.sh
```

**Aviso:** Isto irá:
- Excluir todos os recursos cert-manager
- Parar e excluir o cluster minikube
- Remover binários minikube e kubectl (opcional)

**Limpeza parcial:**
```bash
# Apenas excluir cert-manager
kubectl delete namespace cert-manager

# Apenas parar minikube (manter para depois)
minikube stop

# Remover minikube completamente
minikube delete
```

---

## Tópicos avançados

### Renovação de certificados

cert-manager renova certificados automaticamente:
- Padrão: renova em 2/3 da validade do certificado
- Configurável via `renewBefore` na spec Certificate
- Monitore renovação: `kubectl describe certificate <name>`

### Múltiplos namespaces

- Use `Issuer` para issuers com escopo de namespace
- Use `ClusterIssuer` para issuers em todo o cluster
- Certificados podem referenciar qualquer tipo

### Considerações de produção

**Let's Encrypt produção:**
- Altere para endpoint ACME de produção
- Implemente consciência de limites de taxa
- Use desafio DNS-01 para wildcards
- Monitore expiração de certificados

**Alta disponibilidade:**
- Execute múltiplas réplicas cert-manager
- Use armazenamento distribuído para contas ACME
- Implemente monitoramento e alertas

---

## Recursos adicionais

**Capítulos relacionados:**
- Apêndice A: Kubernetes cert-manager (teoria detalhada)
- Capítulo 24: Let's Encrypt com Certbot (protocolo ACME)
- Capítulo 25: Automatização Ansible para Certificados (conceitos de automação)

**Documentação:**
- Documentação cert-manager: https://cert-manager.io/docs/
- Documentação Kubernetes: https://kubernetes.io/docs/
- Documentação minikube: https://minikube.sigs.k8s.io/docs/

**Leitura adicional:**
- Protocolo ACME RFC 8555
- Kubernetes Ingress TLS
- Gerenciamento do ciclo de vida de certificados

---

## Próximos passos

Após concluir este laboratório, você pode:
1. **Continuar para o Lab 22:** HashiCorp Vault PKI - Gerenciamento dinâmico de certificados
2. **Revisar:** Apêndice A para arquitetura mais aprofundada do cert-manager
3. **Praticar:** Implantar suas próprias aplicações com TLS
4. **Explorar:** Desafios DNS-01 para certificados wildcard
5. **Integrar:** Conectar cert-manager com CAs externas

---

## Casos de uso do mundo real

**Ambientes de desenvolvimento:**
- Testes TLS locais com certificados autoassinados
- Ambientes staging com Let's Encrypt staging
- Desenvolvimento em equipe com CA compartilhada

**Ambientes de produção:**
- Certificados Let's Encrypt automáticos para serviços públicos
- Integração com PKI empresarial via ACME
- Gerenciamento multi-tenant de certificados
- Automação TLS de microsserviços

---

**Versões do RHEL testadas:** 8, 9, 10
**Nível de dificuldade:** Intermediário/Avançado

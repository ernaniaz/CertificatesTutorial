# Apêndice B: PKI do HashiCorp Vault

![Fluxo PKI Vault](../images/appendix-B-vault-pki-flow.svg)

Vault fornece uma PKI dinâmica onde certificados são emitidos sob demanda com TTLs curtos.

## 1. Por Que Vault?

* Aplicação centralizada de políticas
* Certs dinâmicos de curta duração reduzem necessidades de revogação
* Impulsado por API (REST + CLI)

## 2. Habilitar Motor PKI

```bash
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write pki/root/generate/internal common_name="corp.example" ttl=87600h
vault write pki/config/urls issuing_certificates="https://vault.corp/v1/pki/ca" \
                                    crl_distribution_points="https://vault.corp/v1/pki/crl"
```

## 3. Roles e Emissão

```bash
vault write pki/roles/web allowed_domains="web.corp" allow_subdomains=true max_ttl=72h
vault write pki/issue/web common_name=app01.web.corp ttl=24h
```

## 4. Renovação Automática Sidecar do Agente

```hcl
# vault-agent.hcl
pid_file = "/var/run/agent.pid"
auto_auth {
  method "kubernetes" {
    mount_path = "auth/k8s"
    role       = "web"
  }
  sink "file" {
    config = {
      path = "/etc/tls/web.pem"
    }
  }
}
```


---

## 🧪 Laboratório Prático

**Lab 22: PKI do HashiCorp Vault**

Emissão dinâmica de certificados com Vault

- 📁 **Localização:** `labs/pt_BR/22-vault-pki/`
- ⏱️ **Tempo:** 45-55 minutos
- 🎯 **Nível:** Avançado

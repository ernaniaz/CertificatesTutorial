# Apêndice D: Integração DevSecOps

## PKI em DevSecOps e CI/CD

Integrar gerenciamento de certificados em pipelines CI/CD garante que cada artefato de build e ambiente use identidades confiáveis.

## 1. Assinar Artefatos de Build

* **Contêineres** – cosign, Notary v2.
* **Pacotes** – Assinaturas GPG RPM/DEB.
* **Binários** – Windows Authenticode.

## 2. TLS Automatizado para Ambientes de Prévia

Pipelines acionam `cert-manager` para emitir certs efêmeros para branches de curta duração.

## 3. Exemplo: GitHub Actions com cosign

```yaml
name: Build & Sign
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build image
      run: docker build -t ghcr.io/org/app:${{ github.sha }} .
    - name: Login registry
      run: echo ${{ secrets.GH_TOKEN }} | docker login ghcr.io -u user --password-stdin
    - name: Push image
      run: docker push ghcr.io/org/app:${{ github.sha }}
    - name: Sign image
      env:
        COSIGN_EXPERIMENTAL: "1"
        COSIGN_KEY: ${{ secrets.COSIGN_KEY }}
      run: cosign sign -key env://COSIGN_KEY ghcr.io/org/app:${{ github.sha }}
```

## 4. Portas de Política

Scanners de segurança de cadeia de suprimento verificam assinaturas e aplicam política antes de implantar.

## 5. Gerenciamento de Segredos

Armazenar chaves privadas para assinatura no HashiCorp Vault ou AWS KMS, não em segredos de repo.

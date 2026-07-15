# Appendix D: DevSecOps Integration

## PKI in DevSecOps & CI/CD

Integrating certificate management into CI/CD pipelines ensures every build artifact and environment uses trusted identities.

## 1. Signing Build Artifacts

* **Containers** – cosign, Notary v2.
* **Packages** – RPM/DEB GPG signatures.
* **Binaries** – Windows Authenticode.

## 2. Automated TLS for Preview Environments

Pipelines trigger `cert-manager` to issue ephemeral certs for short-lived branches.

## 3. Example: GitHub Actions with cosign

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

## 4. Policy Gates

Supply-chain security scanners verify signatures and enforce policy before deploy.

## 5. Secrets Management

Store private keys for signing in HashiCorp Vault or AWS KMS, not in repo secrets.

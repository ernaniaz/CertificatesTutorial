# Apéndice D: Integración DevSecOps

## PKI en DevSecOps y CI/CD

Integrar gestión de certificados en pipelines CI/CD asegura que cada artefacto de build y entorno use identidades confiables.

## 1. Firmar Artefactos de Build

* **Contenedores** – cosign, Notary v2.
* **Paquetes** – Firmas GPG RPM/DEB.
* **Binarios** – Windows Authenticode.

## 2. TLS Automatizado para Entornos de Vista Previa

Los pipelines activan `cert-manager` para emitir certs efímeros para branches de corta duración.

## 3. Ejemplo: GitHub Actions con cosign

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

## 4. Puertas de Política

Los escáneres de seguridad de cadena de suministro verifican firmas y aplican política antes de desplegar.

## 5. Gestión de Secretos

Almacenar claves privadas para firma en HashiCorp Vault o AWS KMS, no en secretos de repo.

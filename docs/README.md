# PKI & Digital Certificates Tutorial - Documentation

## Overview

This directory contains a comprehensive PKI & Digital Certificates tutorial available in three languages:
- **English (en_US)**
- **Spanish (es_ES)**
- **Portuguese (pt_BR)**

---

## Quick Start

### Build All Languages

```bash
./build-all.sh
```

### Serve for Development

#### Single Language
```bash
cd en_US && mdbook serve --open    # English
cd es_ES && mdbook serve --open    # Spanish
cd pt_BR && mdbook serve --open    # Portuguese
```

#### All Languages Simultaneously
```bash
./serve-all.sh
```

This will start:
- 📘 English: http://localhost:3000
- 📗 Spanish: http://localhost:3001
- 📙 Portuguese: http://localhost:3002

---

## Directory Structure

```
docs/
├── README.md                     # This file
├── build-all.sh                  # Build script for all languages
├── serve-all.sh                  # Development server for all languages
│
├── en_US/                        # English version
│   ├── book.toml                 # Configuration
│   ├── SUMMARY.md                # Table of contents
│   ├── images/                   # Images
│   ├── part-01-fundamentals/     # 7 chapters
│   ├── part-02-version-specific/ # 6 chapters (RHEL 7-10)
│   ├── part-03-services/         # 8 chapters (Apache, NGINX, etc.)
│   ├── part-04-automation/       # 5 chapters (certmonger, etc.)
│   ├── part-05-troubleshooting/  # 7 chapters
│   ├── part-06-migration/        # 4 chapters (RHEL upgrades)
│   ├── part-07-security/         # 4 chapters (FIPS, hardening)
│   └── appendices/               # 9 appendices
│
├── es_ES/                        # Spanish version
│   ├── book.toml                 # Configuration
│   ├── SUMMARY.md                # Table of contents
│   ├── images/                   # Images
│   ├── part-01-fundamentals/     # 7 chapters
│   ├── part-02-version-specific/ # 6 chapters (RHEL 7-10)
│   ├── part-03-services/         # 8 chapters (Apache, NGINX, etc.)
│   ├── part-04-automation/       # 5 chapters (certmonger, etc.)
│   ├── part-05-troubleshooting/  # 7 chapters
│   ├── part-06-migration/        # 4 chapters (RHEL upgrades)
│   ├── part-07-security/         # 4 chapters (FIPS, hardening)
│   └── appendices/               # 9 appendices
│
├── pt_BR/                        # Portuguese version
│   ├── book.toml                 # Configuration
│   ├── SUMMARY.md                # Table of contents
│   ├── images/                   # Images
│   ├── part-01-fundamentals/     # 7 chapters
│   ├── part-02-version-specific/ # 6 chapters (RHEL 7-10)
│   ├── part-03-services/         # 8 chapters (Apache, NGINX, etc.)
│   ├── part-04-automation/       # 5 chapters (certmonger, etc.)
│   ├── part-05-troubleshooting/  # 7 chapters
│   ├── part-06-migration/        # 4 chapters (RHEL upgrades)
│   ├── part-07-security/         # 4 chapters (FIPS, hardening)
│   └── appendices/               # 9 appendices
│
├── book/                         # Build output directory
│   ├── en_US/                    # English HTML output
│   ├── es_ES/                    # Spanish HTML output
│   └── pt_BR/                    # Portuguese HTML output
│
├── labs/                         # Shared lab files
├── mermaid.min.js                # Mermaid diagram library
└── mermaid-init.js               # Mermaid initialization
```

---

## Content Overview

**Target Audience:** Red Hat Enterprise Linux administrators and engineers

**Structure:**
1. **RHEL Certificate Fundamentals** - Introduction, tools, cryptography basics
2. **RHEL Version-Specific Management** - RHEL 7, 8, 9, 10 differences
3. **RHEL Services & TLS** - Apache, NGINX, Postfix, OpenLDAP, FreeIPA, etc.
4. **RHEL Certificate Automation** - certmonger, crypto-policies, certbot, Ansible
5. **RHEL Certificate Troubleshooting** - Common errors, service-specific issues
6. **RHEL Migration & Upgrades** - Version migration strategies
7. **RHEL Security & FIPS** - FIPS mode, compliance, hardening
8. **Appendices** - Advanced topics (Kubernetes, Vault, Zero Trust, etc.)

---

## Build System

Each language has its own independent `book.toml` configuration:

### English (`en_US/book.toml`)
```toml
[book]
title = "PKI & Digital Certificates Tutorial"
language = "en-US"

[build]
build-dir = "../book/en_US"
```

### Spanish (`es_ES/book.toml`)
```toml
[book]
title = "Tutorial de PKI y Certificados Digitales"
language = "es-ES"

[build]
build-dir = "../book/es_ES"
```

### Portuguese (`pt_BR/book.toml`)
```toml
[book]
title = "Tutorial de PKI e Certificados Digitais"
language = "pt-BR"

[build]
build-dir = "../book/pt_BR"
```

---

## Development Workflow

### Making Changes

1. **Edit content files** (`.md` files in language directories)
2. **Update SUMMARY.md** if adding/removing chapters
3. **Test locally** with `mdbook serve`
4. **Build** with `mdbook build` or `./build-all.sh`
5. **Verify** by opening `book/<lang>/index.html`

### Adding a New Chapter

1. Create file: `LANGUAGE/part-XX-name/NN-chapter-name.md`
2. Add to `LANGUAGE/SUMMARY.md`:
   ```markdown
   - Chapter Title -> part-XX-name/NN-chapter-name.md
   ```
3. Build and test

### Translation Workflow

Each locale lives in its own directory (`en_US/`, `es_ES/`, `pt_BR/`) with matching filenames and paths.

1. **Identify the English source chapter** in `en_US/`
2. **Create or update the translated file** at the same relative path under `es_ES/` or `pt_BR/`
3. **Update the locale `SUMMARY.md`** entry if the chapter title changes
4. **Build and verify** with `./build-all.sh` or `mdbook serve` in the target locale

---

## Prerequisites

### Required Tools

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install mdbook
cargo install mdbook

# Install mdbook-mermaid (for diagrams)
cargo install mdbook-mermaid
```

### Optional Tools

```bash
# For link checking
cargo install mdbook-linkcheck

# For PDF generation
cargo install mdbook-pdf
```

---

## Troubleshooting

### Build Errors

**Problem:** "mdbook: command not found"
**Solution:** Install mdbook (see Prerequisites above)

**Problem:** "file not found" during build
**Solution:** Check SUMMARY.md references match actual file paths

**Problem:** Mermaid diagrams not rendering
**Solution:** Install mdbook-mermaid preprocessor

### Translation Issues

If a chapter exists in `en_US/` but is missing from another locale, add the translated file at the same relative path and update that locale's `SUMMARY.md`.

---

## Contributing

### Content Updates
1. Edit the appropriate `.md` file
2. Verify technical accuracy
3. Check spelling/grammar
4. Test the build

### Translations
1. Copy the English chapter from `en_US/` as a starting point
2. Translate content into `es_ES/` or `pt_BR/` using the same filename and directory path
3. Update the locale's `SUMMARY.md` if needed
4. Build and verify the translated locale

### Style Guidelines
- Use clear, concise language
- Include practical examples
- Add diagrams where helpful (Mermaid)
- Follow existing chapter structure
- Cross-reference related chapters

---

## Additional Resources

- **mdBook Documentation:** https://rust-lang.github.io/mdBook/
- **Mermaid Documentation:** https://mermaid-js.github.io/
- **Build Instructions:** `../BUILD_INSTRUCTIONS.md`

---

**Author**: Ernani Azevedo <azevedo@voipdomain.io>  
**Repository**: [github.com/ernaniaz/CertificatesTutorial](https://github.com/ernaniaz/CertificatesTutorial)  
**License**: [CC BY 4.0](../LICENSE.md)

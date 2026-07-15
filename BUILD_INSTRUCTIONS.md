# Build Instructions for Multi-Language Books

## Overview

This project contains a PKI & Digital Certificates tutorial in three languages:
- **English (en_US)**
- **Spanish (es_ES)**
- **Portuguese (pt_BR)**

Each language has its own independent book configuration.

---

## Prerequisites

Install mdbook and the mermaid preprocessor:

```bash
# Install mdbook
cargo install mdbook

# Install mermaid preprocessor
cargo install mdbook-mermaid
```

If you don't have Rust/Cargo:

```bash
# Install RPM package (RHEL 8+/Fedora)
dnf install cargo

# Or, install Rust manually (includes cargo)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

---

## Building Individual Languages

### Build English Version

```bash
cd docs/en_US
mdbook-mermaid install
mdbook build
```

Output location: `docs/book/en_US/`

### Build Spanish Version

```bash
cd docs/es_ES
mdbook-mermaid install
mdbook build
```

Output location: `docs/book/es_ES/`

### Build Portuguese Version

```bash
cd docs/pt_BR
mdbook-mermaid install
mdbook build
```

Output location: `docs/book/pt_BR/`

---

## Building All Languages at Once

### Option 1: Using the Build Script (Recommended)

```bash
cd docs
./build-all.sh
```

This script will:
- Check for required tools (mdbook, mdbook-mermaid)
- Build all available language versions
- Report build status for each
- Show output locations

### Option 2: Using a Loop

```bash
cd docs
for lang in en_US es_ES pt_BR; do
  echo "Building $lang..."
  cd $lang
  mdbook-mermaid install
  mdbook build
  cd ..
done
```

---

## Serving for Development

### Serve English Version

```bash
cd docs/en_US
mdbook serve --open
```

Default: `http://localhost:3000`

The book will auto-rebuild when you edit markdown files.

### Serve Spanish Version

```bash
cd docs/es_ES
mdbook serve --open --port 3001
```

URL: `http://localhost:3001`

### Serve Portuguese Version

```bash
cd docs/pt_BR
mdbook serve --open --port 3002
```

URL: `http://localhost:3002`

### Serve All Languages Simultaneously

Open three terminals and run each serve command with different ports:

**Terminal 1 (English):**
```bash
cd docs/en_US && mdbook serve --port 3000
```

**Terminal 2 (Spanish):**
```bash
cd docs/es_ES && mdbook serve --port 3001
```

**Terminal 3 (Portuguese):**
```bash
cd docs/pt_BR && mdbook serve --port 3002
```

Or use the serve script:
```bash
cd docs
./serve-all.sh
```

---

## Cleaning Build Outputs

### Clean Individual Language

```bash
cd docs/en_US
mdbook clean
```

### Clean All Languages

```bash
cd docs
for lang in en_US es_ES pt_BR; do
  cd $lang
  mdbook clean
  cd ..
done
```

### Remove All Build Output

```bash
rm -rf docs/book/en_US/
rm -rf docs/book/es_ES/
rm -rf docs/book/pt_BR/
```

---

## Testing the Books

After building, you can test the books by opening the HTML files:

### Using a Web Browser

```bash
# English
firefox docs/book/en_US/index.html

# Spanish
firefox docs/book/es_ES/index.html

# Portuguese
firefox docs/book/pt_BR/index.html
```

### Using Python HTTP Server

```bash
cd docs/book
python3 -m http.server 8000
```

Then navigate to:
- English: `http://localhost:8000/en_US/`
- Spanish: `http://localhost:8000/es_ES/`
- Portuguese: `http://localhost:8000/pt_BR/`

---

## Validating Links

Check for broken links in each language:

```bash
# Install mdbook-linkcheck
cargo install mdbook-linkcheck

# Add to each book.toml:
# [preprocessor.linkcheck]
# command = "mdbook-linkcheck"

# Then build to check links
cd docs/en_US && mdbook build
cd docs/es_ES && mdbook build
cd docs/pt_BR && mdbook build
```

---

## Continuous Integration

### GitHub Actions Example

See `.github/workflows/deploy.yml` for the full workflow. It:

1. Checks out the repository
2. Sets up Rust via `dtolnay/rust-toolchain@stable`
3. Installs `mdbook` and `mdbook-mermaid`
4. Runs `mdbook-mermaid install` + `mdbook build` for each language (en_US, es_ES, pt_BR)
5. Uploads `docs/book/` as a Pages artifact
6. Deploys to GitHub Pages via `actions/deploy-pages@v4`

---

## Development Workflow

### Making Changes

1. **Edit markdown files** in `docs/en_US/` (or other language dirs)
2. **Serve locally** to preview changes:
   ```bash
   cd docs/en_US
   mdbook serve
   ```
3. **Review in browser** at `http://localhost:3000`
4. **Build for production**:
   ```bash
   mdbook build
   ```

### Adding New Chapters

1. **Create markdown file** in appropriate part directory:
   ```bash
   touch docs/en_US/part-XX-name/YY-chapter-name.md
   ```

2. **Update SUMMARY.md** to include the new chapter:
   ```markdown
   - Chapter Title -> part-XX-name/YY-chapter-name.md
   ```

3. **Rebuild** to see changes:
   ```bash
   cd docs/en_US
   mdbook build
   ```

### Adding Images

1. **Place images** in `docs/en_US/images/`:
   ```bash
   cp myimage.png docs/en_US/images/
   ```

2. **Reference in markdown**:
   ```markdown
   Image example -> ../images/myimage.png
   ```

### Adding Mermaid Diagrams

```markdown
```mermaid
graph LR
    A[Subject] -->|Access Request| B[SELinux]
    B -->|Allow/Deny| C[Object]
```
```

Diagrams will render automatically if mdbook-mermaid is installed.

---

## Troubleshooting

### Common Issues

**Issue:** `mdbook: command not found`
**Solution:** Make sure Rust and cargo are installed, then install mdbook:
```bash
dnf install -y cargo || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install mdbook
```

**Issue:** `mermaid preprocessor not found`
**Solution:** Install mdbook-mermaid:
```bash
cargo install mdbook-mermaid
```

**Issue:** Build fails with "file not found"
**Solution:** Check that all files referenced in SUMMARY.md exist:
```bash
# Verify references
cd docs/en_US
grep -E '^\- \[' SUMMARY.md

# Check if files exist
find . -name "*.md" -type f
```

**Issue:** Styles/images not loading
**Solution:** Ensure shared resources are accessible:
```bash
# Check that these exist:
ls docs/mermaid.min.js
ls docs/mermaid-init.js
ls docs/en_US/images/
```

**Issue:** Diagrams not rendering
**Solution:** Verify mermaid preprocessor is configured in book.toml:
```toml
[preprocessor.mermaid]
command = "mdbook-mermaid"
```

**Issue:** Build is slow
**Solution:** Use `mdbook serve` for development (auto-rebuild) instead of running `mdbook build` repeatedly.

---

## Additional Resources

- **mdbook Documentation:** https://rust-lang.github.io/mdBook/
- **mdbook-mermaid:** https://github.com/badboy/mdbook-mermaid
- **Mermaid Syntax:** https://mermaid.js.org/intro/

---

## Quick Reference

| Action | Command |
|--------|---------|
| Build English | `cd docs/en_US && mdbook-mermaid install && mdbook build` |
| Build Spanish | `cd docs/es_ES && mdbook-mermaid install && mdbook build` |
| Build Portuguese | `cd docs/pt_BR && mdbook-mermaid install && mdbook build` |
| Build All | `cd docs && ./build-all.sh` |
| Serve English | `cd docs/en_US && mdbook serve` |
| Serve Spanish | `cd docs/es_ES && mdbook serve --port 3001` |
| Serve Portuguese | `cd docs/pt_BR && mdbook serve --port 3002` |
| Clean All | `cd docs && for lang in en_US es_ES pt_BR; do cd $lang && mdbook clean && cd ..; done` |

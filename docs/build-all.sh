#!/bin/bash

# Build all language versions of the PKI & Certificates book

LANGUAGES=("en_US" "es_ES" "pt_BR")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════╗"
echo "║  Building PKI & Certificates Tutorial - All Languages  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Check if mdbook is installed
if ! command -v mdbook &> /dev/null; then
  echo "❌ Error: mdbook is not installed"
  echo "   Install it with: cargo install mdbook"
  exit 1
fi

# Check if mdbook-mermaid is installed
if ! command -v mdbook-mermaid &> /dev/null; then
  echo "⚠️ Warning: mdbook-mermaid is not installed"
  echo "   Some diagrams may not render properly"
  echo "   Install it with: cargo install mdbook-mermaid"
  echo
fi

# Track success/failure
SUCCESS=0
FAILED=0

for lang in "${LANGUAGES[@]}"; do
  echo "──────────────────────────────────────────────────────────"
  echo "Building: ${lang}"
  echo "──────────────────────────────────────────────────────────"

  cd "${SCRIPT_DIR}/${lang}" || {
    echo "❌ Failed to enter directory: ${lang}"
    FAILED=$((FAILED + 1))
    continue
  }

  mdbook-mermaid install 2>/dev/null
  mdbook build && {
    echo "✅ ${lang} built successfully"
    SUCCESS=$((SUCCESS + 1))
  } || {
    echo "❌ ${lang} build failed"
    FAILED=$((FAILED + 1))
  }

  echo
done

# Copy tracked root pages into the published artifact.
cp "${SCRIPT_DIR}/index.html" "${SCRIPT_DIR}/book/index.html"
cp "${SCRIPT_DIR}/404.html" "${SCRIPT_DIR}/book/404.html"

# If a tracked custom-domain file exists, publish it too.
if [[ -f "${SCRIPT_DIR}/CNAME" ]]; then
  cp "${SCRIPT_DIR}/CNAME" "${SCRIPT_DIR}/book/CNAME"
fi

echo "══════════════════════════════════════════════════════════"
echo "Build Summary:"
echo "  ✅ Successful: ${SUCCESS}"
echo "  ❌ Failed:     ${FAILED}"
echo

if [[ ${FAILED} -eq 0 ]]; then
  echo "🎉 All builds completed successfully!"
  echo
  echo "Output locations:"
  echo "  📘 English:    ${SCRIPT_DIR}/book/en_US/index.html"
  echo "  📗 Spanish:    ${SCRIPT_DIR}/book/es_ES/index.html"
  echo "  📙 Portuguese: ${SCRIPT_DIR}/book/pt_BR/index.html"
  echo
  echo "To view the books, open the index.html files in a web browser"
  echo "or run: cd book && python3 -m http.server 8000"
  exit 0
else
  echo "⚠️ Some builds failed. Please check the errors above."
  exit 1
fi

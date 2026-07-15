#!/bin/bash

# Serve all language versions of the PKI & Certificates book simultaneously

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  Serving PKI & Certificates Tutorial - All Languages  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo

# Check if mdbook is installed
if ! command -v mdbook &> /dev/null; then
  echo "❌ Error: mdbook is not installed"
  echo "   Install it with: cargo install mdbook"
  exit 1
fi

echo "Starting development servers for all languages..."
echo
echo "📘 English:    http://localhost:3000"
echo "📗 Spanish:    http://localhost:3001"
echo "📙 Portuguese: http://localhost:3002"
echo
echo "Press Ctrl+C to stop all servers"
echo
echo "═════════════════════════════════════════════════════════"
echo

# Function to cleanup background processes on exit
cleanup ()
{
  echo
  echo "Stopping all servers..."
  kill $(jobs -p) 2>/dev/null
  exit 0
}

trap cleanup SIGINT SIGTERM

# Ensure mermaid is installed for each language
for lang in en_US es_ES pt_BR; do
  cd "${SCRIPT_DIR}/${lang}" && mdbook-mermaid install 2>/dev/null
done

# Start servers in background
cd "${SCRIPT_DIR}/en_US" && mdbook serve --hostname 0.0.0.0 --port 3000 &
EN_PID=$!

cd "${SCRIPT_DIR}/es_ES" && mdbook serve --hostname 0.0.0.0 --port 3001 &
ES_PID=$!

cd "${SCRIPT_DIR}/pt_BR" && mdbook serve --hostname 0.0.0.0 --port 3002 &
PT_PID=$!

# Wait a bit for servers to start
sleep 2

# Check if all servers are running
if ! kill -0 ${EN_PID} 2>/dev/null; then
  echo "❌ English server failed to start"
fi

if ! kill -0 ${ES_PID} 2>/dev/null; then
  echo "❌ Spanish server failed to start"
fi

if ! kill -0 ${PT_PID} 2>/dev/null; then
  echo "❌ Portuguese server failed to start"
fi

# Wait for user interrupt
wait

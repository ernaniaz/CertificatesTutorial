#!/usr/bin/env bash
#=============================================================================
# Lab 15: Executar tudo
# Script auxiliar para executar o cenário implementado
#
# Uso: ./run-all.sh
# Pré-requisitos: RHEL 7, 8, 9, 10
#=============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

#=============================================================================
# CONFIGURATION
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

print_header ()
{
  local text="${1}"
  local width=57
  local padding=$(( width - ${#text} ))
  local pad=""
  if [[ ${padding} -gt 0 ]]; then
    pad="$(printf '%*s' "${padding}" '')"
  fi
  echo
  echo -e "${CYAN}┌─$(printf '─%.0s' $(seq 1 ${width}))─┐${NC}"
  echo -e "${CYAN}│${NC} ${BOLD}${text}${NC}${pad} ${CYAN}│${NC}"
  echo -e "${CYAN}└─$(printf '─%.0s' $(seq 1 ${width}))─┘${NC}"
  echo
}

print_step ()
{
  echo
  echo -e "  ${BOLD}▸ ${1}${NC}"
}

print_success ()
{
  echo -e "  ${GREEN}✓${NC} ${1}"
}

print_error ()
{
  echo -e "  ${RED}✗${NC} ${1}"
}

print_warning ()
{
  echo -e "  ${YELLOW}⚠${NC} ${1}"
}

print_info ()
{
  echo -e "  ${BLUE}ℹ${NC} ${1}"
}

error_exit ()
{
  print_error "${1}"
  exit 1
}

trap 'error_exit "Erro ocorreu na linha ${LINENO}"' ERR

#=============================================================================
# RHEL VERSION CHECK
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "Este script requer Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9 ou 10."
fi

#=============================================================================
# MAIN
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 15: Cenários de Resolução de Problemas"

SCENARIOS=(
  "scenario-01-expired-cert"
)

PLANNED_SCENARIOS=(
  "scenario-02-wrong-cert"
  "scenario-04-selinux-blocking"
  "scenario-05-hostname-mismatch"
  "scenario-08-permission-issues"
)

echo "Cenário implementado:"
for scenario in "${SCENARIOS[@]}"; do
  echo "  - ${scenario}"
done
echo

MISSING=0
for scenario in "${PLANNED_SCENARIOS[@]}"; do
  if [[ ! -d "${SCRIPT_DIR}/${scenario}" ]]; then
    ((MISSING+=1)) || true
  fi
done

if [[ ${MISSING} -gt 0 ]]; then
  print_warning "${MISSING} cenários adicionais estão documentados no tutorial, mas ainda não estão incluídos neste lab."
  echo "  Planejados: ${PLANNED_SCENARIOS[*]}"
  echo
fi

read -p "Executar scenario-01-expired-cert? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[SsYy]$ ]]; then
  echo "Execute o cenário manualmente:"
  echo "  cd scenario-01-expired-cert"
  echo "  sudo ./create-problem.sh"
  echo "  ./diagnose.sh"
  echo "  sudo ./fix.sh"
  echo "  sudo ./verify-fix.sh"
  exit 0
fi

echo

COMPLETED=0
FAILED=0
SKIPPED=0

for scenario in "${SCENARIOS[@]}"; do
  if [[ ! -d "${SCRIPT_DIR}/${scenario}" ]]; then
    print_warning "Diretório do cenário ausente: ${scenario}"
    ((SKIPPED+=1)) || true
    continue
  fi

  echo
  print_info "========================================"
  print_info "Executando: ${scenario}"
  print_info "========================================"
  echo

  cd "${SCRIPT_DIR}/${scenario}"

  if [[ -f create-problem.sh && -f diagnose.sh && -f fix.sh && -f verify-fix.sh ]]; then
    sudo ./create-problem.sh
    sleep 2
    ./diagnose.sh
    sleep 2
    sudo ./fix.sh
    sleep 2
    if sudo ./verify-fix.sh; then
      ((COMPLETED+=1)) || true
      print_success "${scenario} concluído"
    else
      ((FAILED+=1)) || true
      print_error "${scenario} falhou"
    fi
  else
    print_warning "Cenário não totalmente implementado: ${scenario}"
    ((SKIPPED+=1)) || true
  fi

  cd "${SCRIPT_DIR}"
done

echo
echo "========================================"
print_success "Concluídos: ${COMPLETED}"
print_error "Falharam: ${FAILED}"
if [[ ${SKIPPED} -gt 0 ]]; then
  print_warning "Ignorados: ${SKIPPED}"
fi
echo "========================================"

if [[ ${FAILED} -eq 0 && ${COMPLETED} -gt 0 ]]; then
  print_success "Cenário implementado concluído com sucesso"
  exit 0
elif [[ ${COMPLETED} -eq 0 ]]; then
  print_error "Nenhum cenário foi concluído"
  exit 1
else
  print_error "Execução do cenário terminou com falhas"
  exit 1
fi

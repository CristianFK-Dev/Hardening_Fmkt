#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.5 – Asegurar que los eventos que modifican el entorno de red del sistema se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.5"
ITEM_DESC="Asegurar que los eventos que modifican el entorno de red del sistema se recopilan"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-system_locale.rules"
RULES=(
  "-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale"
  "-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale"
  "-w /etc/issue -p wa -k system-locale"
  "-w /etc/issue.net -p wa -k system-locale"
  "-w /etc/hosts -p wa -k system-locale"
  "-w /etc/networks -p wa -k system-locale"
  "-w /etc/network/ -p wa -k system-locale"
  "-w /etc/netplan/ -p wa -k system-locale"
)

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Este script debe ejecutarse como root."; exit 1; }
}

rule_present() {
  local rule="$1"
  grep -hFxq -- "$rule" /etc/audit/rules.d/*.rules 2>/dev/null
}

add_rule() {
  local rule="$1"
  if rule_present "$rule"; then
    log "[OK] Regla ya presente: $rule"
  else
    run "echo '$rule' >> '$RULE_FILE'"
    log "[OK] Regla añadida: $rule"
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ $DRY_RUN -eq 0 ]]; then
    run "touch '$RULE_FILE'"
    run "chmod 640 '$RULE_FILE'"
  fi

  for rule in "${RULES[@]}"; do
    add_rule "$rule"
  done

}

main "$@"

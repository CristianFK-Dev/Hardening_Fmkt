#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.8 – Asegurar que los eventos que modifican la información de usuario/grupo se recopilan
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.8"
ITEM_DESC="Asegurar que los eventos que modifican la información de usuario/grupo se recopilan"
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
RULE_FILE="/etc/audit/rules.d/50-identity.rules"

RULES=(
"-w /etc/group -p wa -k identity"
"-w /etc/passwd -p wa -k identity"
"-w /etc/gshadow -p wa -k identity"
"-w /etc/shadow -p wa -k identity"
"-w /etc/security/opasswd -p wa -k identity"
"-w /etc/nsswitch.conf -p wa -k identity"
"-w /etc/pam.conf -p wa -k identity"
"-w /etc/pam.d -p wa -k identity"
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
  local r="$1"
  grep -hFxq -- "$r" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if [[ $DRY_RUN -eq 0 ]]; then
    if [[ -f "$RULE_FILE" ]]; then
      BACKUP="${RULE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
      cp -p "$RULE_FILE" "$BACKUP"
      log "[OK] Backup creado: $BACKUP"
    fi
    touch "$RULE_FILE"
    chmod 640 "$RULE_FILE"
  fi

  for rule in "${RULES[@]}"; do
    if rule_present "$rule"; then
      log "[OK] Regla ya presente: $rule"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Añadiría: $rule"
      else
        echo "$rule" >> "$RULE_FILE"
        log "[OK] Regla añadida: $rule"
      fi
    fi
  done
  
  exit 0
}

main "$@"

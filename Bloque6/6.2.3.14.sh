#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.14 Asegurar que se recopilan los eventos que modifican los controles de acceso 
#          obligatorio del sistema
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.14"
ITEM_DESC="Asegurar que se recopilan los eventos que modifican los controles de acceso obligatorio del sistema"
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

RULE_FILE="/etc/audit/rules.d/50-MAC-policy.rules"
RULES=(
"-w /etc/apparmor/ -p wa -k MAC-policy"
"-w /etc/apparmor.d/ -p wa -k MAC-policy"
)

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
run(){ [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root' >&2; exit 1; }; }
rule_present(){
  local rule_to_find="$1"
  grep -hFxq -- "$rule_to_find" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  :> "$LOG_FILE"
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID"
  ensure_root
  if [[ $DRY_RUN -eq 0 ]]; then
    run "touch '$RULE_FILE'"
    run "chmod 640 '$RULE_FILE'"
  fi

  for rule in "${RULES[@]}"; do
    if rule_present "$rule"; then
      log "[OK] Regla presente: $rule"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Añadiría: $rule"
      else
        echo "$rule" >> "$RULE_FILE"
        log "[EXEC] Regla añadida: $rule"
      fi
    fi
  done
  
  exit 0
}

main "$@"

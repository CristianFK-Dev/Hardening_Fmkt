#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.20 Asegurar que la configuración de auditoría sea inmutable
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.20"
ITEM_DESC="Asegurar que la configuración de auditoría sea inmutable"
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
FINAL_RULE_FILE="/etc/audit/rules.d/99-finalize.rules"
RULE="-e 2"

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERROR] Este script debe ejecutarse como root."; exit 1; }
}

rule_present() {
  grep -hFxq -- "$RULE" /etc/audit/rules.d/*.rules 2>/dev/null
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "[INFO] Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  if rule_present; then
    log "[OK] Regla -e 2 ya presente en reglas de auditd"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Añadiría regla inmutable: $RULE en $FINAL_RULE_FILE"
    else
      echo "$RULE" >> "$FINAL_RULE_FILE"
      chmod 640 "$FINAL_RULE_FILE"
      log "[EXEC] Regla inmutable añadida a $FINAL_RULE_FILE"
    fi
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    log "[EXEC] Recargando reglas con augenrules..."
    augenrules --load || true

    if auditctl -s | grep -q "enabled 2"; then
      log "[SUCCESS] Modo inmutable ya está activo"
    else
      log "[INFO] Modo inmutable pendiente. Se activará tras reinicio"
    fi
  fi

}

main "$@"

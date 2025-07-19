#!/usr/bin/env bash
# =============================================================================
# 3.2.1 – Ensure dccp kernel module is not available
# Deshabilita y deniega el módulo DCCP (Datagram Congestion Control Protocol).
# =============================================================================

set -euo pipefail

ITEM_ID="3.2.1"
MOD_NAME="dccp"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

# --- Lógica Principal del Script ---
main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"

  log "=== Remediación ${ITEM_ID}: Deshabilitar ${MOD_NAME} ==="

  # Descargar módulo si está cargado
  if lsmod | grep -q "^${MOD_NAME}\b"; then
    log "Módulo ${MOD_NAME} está actualmente cargado. Intentando descargar..."
    run "modprobe -r ${MOD_NAME}"
  else
    log "Módulo ${MOD_NAME} no está cargado."
  fi

  # Asegurar configuración en /etc/modprobe.d
  local expected_content
  expected_content=$(printf "install %s /bin/false\nblacklist %s" "$MOD_NAME" "$MOD_NAME")

  if [[ -f "$CONF_FILE" ]] && grep -qFx "install ${MOD_NAME} /bin/false" "$CONF_FILE" && grep -qFx "blacklist ${MOD_NAME}" "$CONF_FILE"; then
    log "[OK] El archivo de configuración ${CONF_FILE} ya está correctamente configurado."
  else
    log "El archivo ${CONF_FILE} no está configurado o es incorrecto. Aplicando cambios..."
    if [[ $DRY_RUN -eq 0 ]]; then
      echo "$expected_content" > "$CONF_FILE"
      chmod 644 "$CONF_FILE"
      log "Archivo ${CONF_FILE} creado/actualizado."
    else
      log "[DRY-RUN] Se crearía/actualizaría ${CONF_FILE} con las directivas 'install' y 'blacklist'."
    fi
  fi

  # Verificar si el módulo existe en disco (informativo)
  if modinfo -n "${MOD_NAME}" &>/dev/null; then
    log "Módulo ${MOD_NAME}.ko presente en disco."
  else
    log "Módulo ${MOD_NAME}.ko no se encuentra en disco (posiblemente no instalado o builtin)."
  fi

  log "== Remediación ${ITEM_ID} completada =="
}

main "$@"

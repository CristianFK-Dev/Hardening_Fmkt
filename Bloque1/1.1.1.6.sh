#!/usr/bin/env bash
# =============================================================================
# 1.1.1.6 – Ensure overlayfs kernel module is not available
# Deshabilita y deniega el módulo overlay/overlayfs (CVE-2023-32629, 2640, 0386)
#
# Uso      : sudo ./1.1.1.6.sh [--dry-run] [--force]
#            --dry-run  → solo muestra acciones
#            --force    → continúa incluso si Docker/K8s usan overlay
#
# Registro  : Bloque1/Log/<timestamp>_1.1.1.6.log
# Retorno   : 0 éxito; !=0 error (set -euo pipefail)
# =============================================================================

set -euo pipefail

ITEM_ID="1.1.1.6"
MOD_NAME="overlay"          # nombre real del módulo (.ko)
ALIAS_NAME="overlayfs"      # alias usado por el benchmark
CONF_FILE="/etc/modprobe.d/${MOD_NAME}.conf"

# ---------- parámetros ----------
DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1   ;;
    *) echo "Uso: $0 [--dry-run] [--force]" >&2; exit 1 ;;
  esac
done

# ---------- log ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/Log"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
log() { echo -e "[$(date +%F\ %T)] $*" | tee -a "${LOG_FILE}"; }
run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC] $*"
    eval "$@"
  fi
}

log "=== Remediación ${ITEM_ID}: Deshabilitar ${MOD_NAME}/${ALIAS_NAME} ==="

# ---------- contenedores ----------
if command -v docker &>/dev/null        && docker info --format '{{.Driver}}' 2>/dev/null | grep -qi overlay        && [[ "${FORCE}" -ne 1 ]]; then
  log "ERROR: Docker usa overlay2 → ejecuta con --force para continuar."
  exit 1
fi

# ---------- descargar módulo cargado ----------
if lsmod | grep -q "^${MOD_NAME}\b"; then
  log "Módulo ${MOD_NAME} cargado → descargando"
  run "modprobe -r ${MOD_NAME} || true"
  run "rmmod ${MOD_NAME}     || true"
else
  log "Módulo ${MOD_NAME} no está cargado"
fi

# ---------- /etc/modprobe.d ----------
need_update=0
if [[ -f "${CONF_FILE}" ]]; then
  grep -qE '^\s*install\s+('${MOD_NAME}'|'"${ALIAS_NAME}"')\s+/bin/false' "${CONF_FILE}" || need_update=1
  grep -qE '^\s*blacklist\s+('${MOD_NAME}'|'"${ALIAS_NAME}"')\s*$'          "${CONF_FILE}" || need_update=1
else
  need_update=1
fi

if [[ "${need_update}" -eq 1 ]]; then
  log "Actualizando ${CONF_FILE}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    {
      echo "install ${MOD_NAME} /bin/false"
      echo "install ${ALIAS_NAME} /bin/false"
      echo "blacklist ${MOD_NAME}"
      echo "blacklist ${ALIAS_NAME}"
    } > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
  else
    log "[DRY-RUN] Escribiría líneas install/blacklist en ${CONF_FILE}"
  fi
else
  log "${CONF_FILE} ya contiene las directivas necesarias"
fi

# ---------- módulo en disco ----------
MOD_PATHS=$(modinfo -n "${MOD_NAME}" 2>/dev/null || true)
if [[ -n "${MOD_PATHS}" ]]; then
  log "Módulo ${MOD_NAME}.ko presente en: ${MOD_PATHS}"
else
  log "Módulo ${MOD_NAME}.ko NO existe en disco (posible builtin)"
fi

log "== Remediación ${ITEM_ID} completada =="

exit 0

#!/usr/bin/env bash
# =============================================================================
# Script para Limpiar y Deshabilitar Completamente Auditd
#
# Este script realiza las siguientes acciones:
# - Detiene el servicio auditd.
# - Deshabilita auditd para que no se inicie en el arranque.
# - Elimina todas las reglas de auditoría cargadas del kernel.
# - Borra el archivo de reglas compilado principal (/etc/audit/audit.rules).
# - Borra todos los archivos de reglas personalizados en /etc/audit/rules.d/.
#
# Uso      : sudo ./clean_auditd.sh [--dry-run]
#            --dry-run  → muestra acciones sin aplicar cambios
#
# Registro  : Log/<timestamp>_clean_auditd.log
# Retorno   : 0 éxito; !=0 error
# =============================================================================

set -euo pipefail

ITEM_ID="clean_auditd"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} =~ ^(--dry-run|-n)$ ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    # Este script debe ser llamado por un wrapper que ya es root.
    echo "ERROR: Este script debe ser ejecutado como root." >&2
    exit 1
  fi
}

### MAIN
: > "$LOG_FILE" # Limpia el archivo de log al inicio
ensure_root "$@"
log "=== Inicio del script de limpieza y deshabilitación de Auditd ==="

# 1. Detener el servicio auditd
log "→ Deteniendo el servicio auditd..."
if [[ $DRY_RUN -eq 0 ]]; then
  if systemctl stop auditd; then
    log "[OK] Servicio auditd detenido."
  else
    log "[ERROR] No se pudo detener el servicio auditd. Puede que no esté corriendo o haya un problema."
    # Continuamos para intentar limpiar de todas formas
  fi
else
  log "[DRY-RUN] Detendría el servicio auditd."
fi

# 2. Deshabilitar el servicio auditd para que no se inicie en el arranque
log "→ Deshabilitando el servicio auditd para que no se inicie en el arranque..."
if [[ $DRY_RUN -eq 0 ]]; then
  if systemctl disable auditd; then
    log "[OK] Servicio auditd deshabilitado."
  else
    log "[ERROR] No se pudo deshabilitar el servicio auditd."
  fi
else
  log "[DRY-RUN] Deshabilitaría el servicio auditd."
fi

# 3. Eliminar todas las reglas de auditoría cargadas del kernel
log "→ Eliminando todas las reglas de auditoría cargadas del kernel con 'auditctl -D'..."
if [[ $DRY_RUN -eq 0 ]]; then
  # auditctl -D puede fallar si auditd está en modo inmutable (-e 2) sin reiniciar.
  # Redirigimos stderr a /dev/null para evitar mensajes de error si falla.
  if auditctl -D 2>/dev/null; then
    log "[OK] Reglas de auditoría eliminadas del kernel."
  else
    log "[WARN] No se pudieron eliminar las reglas del kernel con 'auditctl -D'. Esto es normal si el modo inmutable (-e 2) estaba activo sin un reinicio previo. Un reinicio del sistema será necesario para una limpieza completa."
  fi
else
  log "[DRY-RUN] Eliminaría las reglas de auditoría del kernel con 'auditctl -D'."
fi

# 4. Borrar el archivo de reglas compilado principal
log "→ Borrando el archivo de reglas compilado: /etc/audit/audit.rules"
if [[ $DRY_RUN -eq 0 ]]; then
  if rm -f /etc/audit/audit.rules; then
    log "[OK] Archivo /etc/audit/audit.rules eliminado."
  else
    log "[ERROR] No se pudo eliminar /etc/audit/audit.rules."
  fi
else
  log "[DRY-RUN] Borraría el archivo /etc/audit/audit.rules."
fi

# 5. Borrar todos los archivos de reglas personalizados en /etc/audit/rules.d/
log "→ Borrando todos los archivos de reglas personalizados en /etc/audit/rules.d/ (*.rules)..."
if [[ $DRY_RUN -eq 0 ]]; then
  shopt -s nullglob # Para que el bucle no se ejecute si no hay archivos
  for f in /etc/audit/rules.d/*.rules; do
    log "[DEL] Eliminando $f"
    rm -f "$f"
  done
  shopt -u nullglob # Restaura el comportamiento por defecto
  log "[OK] Todos los archivos .rules en /etc/audit/rules.d/ eliminados."
else
  log "[DRY-RUN] Borraría todos los archivos .rules en /etc/audit/rules.d/."
fi

log "=== Limpieza y deshabilitación de Auditd completada. ==="
log "Para asegurar que todas las reglas estén completamente purgadas del kernel (especialmente si el modo inmutable estaba activo), se recomienda un REINICIO COMPLETO del sistema."
log "Ejecute: sudo reboot"

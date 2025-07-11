#!/usr/bin/env bash
# =============================================================================
# 5.2.4 – Ensure users must provide password for privilege escalation
#
#   • Deshabilita entradas NOPASSWD en sudoers y sudoers.d
#   • EXCLUYE a los usuarios root, admin y nessus
#   • Realiza copia de seguridad antes de modificar
#   • Valida la sintaxis con visudo
#   • Soporta modo --dry-run
# =============================================================================
set -euo pipefail

ITEM_ID="5.2.4"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
BACKUP_DIR="/etc/sudoers/hardening_backups"

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

### Funciones auxiliares #######################################################
ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "→ Re-ejecutando con sudo para privilegios de root..."
    exec sudo --preserve-env=PATH "$0" "$@"
  fi
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]    $*"
    eval "$@"
  fi
}
################################################################################

# Parámetros
DRY_RUN=0
[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && DRY_RUN=1

LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

ensure_root
log "=== Remediación ${ITEM_ID}: Eliminar NOPASSWD (excluyendo root, admin, nessus) ==="

PATTERN='^[[:space:]]*[^#].*NOPASSWD'
EXCLUDE='^[[:space:]]*(root|admin|nessus)[[:space:]].*NOPASSWD'
TAG='# DISABLED_BY_HARDENING'

# Archivos objetivo
TARGET_FILES=( /etc/sudoers )
while IFS= read -r -d '' f; do TARGET_FILES+=("$f"); done < <(
  find /etc/sudoers.d -maxdepth 1 -type f ! -name '*~' ! -name '*.bak*' -print0 2>/dev/null
)

MODIFIED=0
for FILE in "${TARGET_FILES[@]}"; do
  [[ -r "$FILE" ]] || { log "Omitiendo $FILE: no legible"; continue; }

  if grep -Eq "$PATTERN" "$FILE"; then
    # Ver si realmente hay algo que cambiar (que no sea root/admin/nessus)
    if grep -Eq "$PATTERN" "$FILE" && ! grep -Eq "$EXCLUDE" "$FILE"; then
      MODIFIED=1
      BACKUP="${BACKUP_DIR}/$(basename "$FILE").$(date +%Y%m%d-%H%M%S)"
      run "cp --preserve=mode,ownership,timestamps '$FILE' '$BACKUP'"

      TMP=$(mktemp)
      run "awk -v tag='$TAG' -v today=\"$(date +%F)\" -v exclude=\"$EXCLUDE\" '
        $0 ~ exclude {print; next}
        $0 ~ /NOPASSWD/ && $0 !~ tag {print tag, today, $0; next}
        {print}
      ' \"$FILE\" > \"$TMP\""

      run "visudo -cf \"$TMP\""
      if [[ $DRY_RUN -eq 0 ]]; then
        mv "$TMP" "$FILE"
        log "→ NOPASSWD deshabilitado en $FILE (root/admin/nessus excluidos)"
      else
        log "[DRY-RUN] Cambios no aplicados en $FILE"
        rm -f "$TMP"
      fi
    else
      log "Solo se encontraron entradas permitidas (root/admin/nessus) en $FILE"
    fi
  else
    log "No se encontró NOPASSWD en $FILE"
  fi
done

[[ $MODIFIED -eq 0 ]] && log "Sistema ya conforme. Sin cambios aplicados."

log "== Remediación ${ITEM_ID} completada =="
exit 0

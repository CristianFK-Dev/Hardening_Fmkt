#!/usr/bin/env bash
# =============================================================================
# 5.2.4 – Asegurar que los usuarios deben proporcionar contraseña para la 
#         escalada de privilegios
# =============================================================================

set -euo pipefail

ITEM_ID="5.2.4"
ITEM_DESC="Asegurar que los usuarios deben proporcionar contraseña para la escalada de privilegios"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/etc/hardening_backups"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="${BLOCK_DIR}/Log/${LOG_SUBDIR}"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
: > "${LOG_FILE}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}
run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]   $*"
    eval "$@"
  fi
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "ERROR: Este script debe ejecutarse como root."; exit 1; }
}

main() {
  ensure_root
  log "=== Remediación ${ITEM_ID}: ${ITEM_DESC} ==="

  PATTERN='^[[:space:]]*[^#].*NOPASSWD'
  EXCLUDE='^[[:space:]]*(root|admin|nessus|nessusauth)[[:space:]].*NOPASSWD'
  TAG='# DISABLED_BY_HARDENING'

  TARGET_FILES=( /etc/sudoers )
  while IFS= read -r -d '' f; do TARGET_FILES+=("$f"); done < <(
    find /etc/sudoers.d -maxdepth 1 -type f ! -name '*~' ! -name '*.bak*' -print0 2>/dev/null
  )

  MODIFIED=0
  for FILE in "${TARGET_FILES[@]}"; do
    [[ -r "$FILE" ]] || { log "Omitiendo $FILE: no legible"; continue; }

    if grep -E "$PATTERN" "$FILE" | grep -qvE "$EXCLUDE"; then
      MODIFIED=1

      BACKUP="${BACKUP_DIR}/$(basename "$FILE").$(date +%Y%m%d-%H%M%S)"
      run "cp --preserve=mode,ownership,timestamps '$FILE' '$BACKUP'"

      TMP=$(mktemp)
      log "Procesando $FILE → $TMP"
      awk -v tag="$TAG" -v today="$(date +%F)" -v exclude="$EXCLUDE" -v pattern="$PATTERN" '
        $0 ~ exclude {print; next}
        $0 ~ pattern && $0 !~ tag {print tag, today, $0; next}
        {print}
      ' "$FILE" > "$TMP"

      run "visudo -cf '$TMP'"

      if [[ $DRY_RUN -eq 0 ]]; then
        mv "$TMP" "$FILE"
        log "→ NOPASSWD deshabilitado en $FILE (excepciones mantenidas)"
      else
        log "[DRY-RUN] Cambios no aplicados en $FILE"
        rm -f "$TMP"
      fi
    else
      log "No se encontraron entradas NOPASSWD para modificar en $FILE"
    fi
  done

  [[ $MODIFIED -eq 0 ]] && log "Sistema ya conforme. Sin cambios aplicados."

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
  
  exit 0
}

main "$@"

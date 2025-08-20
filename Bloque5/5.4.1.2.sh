#!/usr/bin/env bash
# =============================================================================
# 5.4.1.2 – Asegurar que los días mínimos de contraseña estén configurados 
# =============================================================================

set -euo pipefail

ITEM_ID="5.4.1.2"
ITEM_DESC="Asegurar que los días mínimos de contraseña estén configurados"
LOGIN_DEFS="/etc/login.defs"
BACKUP_DIR="/var/backups/login_defs"
DRY_RUN=0
LOG_SUBDIR="exec"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  LOG_SUBDIR="audit"
fi

LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Log/${LOG_SUBDIR}"
mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"; }

run() {
    local cmd="$*"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Pendiente: $cmd"
        return 0
    else
        log "[EXEC] $cmd"
        eval "$@"
        return $?
    fi
}

backup(){ local f=$1; run "cp --preserve=mode,ownership,timestamps '$f' '${BACKUP_DIR}/$(basename "$f").$(date +%Y%m%d-%H%M%S)'"; }

ensure_root() { [[ $EUID -eq 0 ]] || { log "ERROR: Este script debe ejecutarse como root."; exit 1; }; }

patch_login_defs() {
  log "[INFO] Revisando configuración en $LOGIN_DEFS"
  
  if grep -qE '^\s*PASS_MIN_DAYS\s+[0-9]+' "$LOGIN_DEFS"; then
    if grep -qE '^\s*PASS_MIN_DAYS\s+0\b' "$LOGIN_DEFS"; then
      local current_value=$(grep -E '^\s*PASS_MIN_DAYS\s+0\b' "$LOGIN_DEFS" | awk '{print $2}')
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Cambio pendiente en $LOGIN_DEFS"
        log "[DRY-RUN] - Valor actual: PASS_MIN_DAYS = $current_value"
        log "[DRY-RUN] - Valor deseado: PASS_MIN_DAYS = 1"
      else
        backup "$LOGIN_DEFS"
        run "sed -E 's/^\s*PASS_MIN_DAYS\s+0\b/PASS_MIN_DAYS\t1/' -i '$LOGIN_DEFS'"
        log "[SUCCESS] PASS_MIN_DAYS actualizado de $current_value a 1"
      fi
    else
      log "[OK] PASS_MIN_DAYS ya está configurado correctamente"
    fi
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Cambio pendiente en $LOGIN_DEFS"
      log "[DRY-RUN] - Parámetro PASS_MIN_DAYS no existe"
      log "[DRY-RUN] - Se añadirá: PASS_MIN_DAYS = 1"
    else
      backup "$LOGIN_DEFS"
      run "echo -e '\nPASS_MIN_DAYS\t1' >> '$LOGIN_DEFS'"
      log "[SUCCESS] PASS_MIN_DAYS = 1 añadido al archivo"
    fi
  fi
}

patch_users() {
  log "[INFO] Revisando configuración de usuarios"
  local changes_needed=0
  local users_to_change=""

  while IFS=: read -r user pw last min rest; do
    [[ $pw =~ ^\$ ]] || continue
    [[ -z $min || $min -lt 1 ]] || continue
    changes_needed=1
    users_to_change+="$user (actual: $min) "
  done < /etc/shadow

  if [[ $changes_needed -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[DRY-RUN] Usuarios que requieren cambios:"
      log "[DRY-RUN] - Usuarios afectados: $users_to_change"
      log "[DRY-RUN] - Se configurará mindays=1 para estos usuarios"
    else
      while IFS=: read -r user pw last min rest; do
        [[ $pw =~ ^\$ ]] || continue
        [[ -z $min || $min -lt 1 ]] || continue
        run "chage --mindays 1 '$user'"
        log "[SUCCESS] Usuario $user actualizado: mindays=1"
      done < /etc/shadow
    fi
  else
    log "[OK] Todos los usuarios tienen mindays configurado correctamente"
  fi
}

main() {
  ensure_root
  log "[INFO] === Remediación ${ITEM_ID}: ${ITEM_DESC} iniciada ==="
  patch_login_defs
  patch_users
  exit 0
}

main "$@"

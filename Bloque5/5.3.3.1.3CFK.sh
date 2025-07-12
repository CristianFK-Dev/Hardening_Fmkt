#!/usr/bin/env bash
# =============================================================================
# 5.3.3.1.3 – Asegurar que pam_faillock.so use root_unlock_time
# y que /etc/security/faillock.conf tenga even_deny_root o root_unlock_time
# =============================================================================

set -euo pipefail

ITEM_ID="5.3.3.1.3_PAM_Faillock"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
BACKUP_DIR="/etc/pam.d/hardening_backups"

PAM_AUTH_FILE="/etc/pam.d/common-auth"
FAILLOCK_CONF="/etc/security/faillock.conf"
ROOT_UNLOCK_TIME_VALUE="60"

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "→ Re-ejecutando con sudo para privilegios de root..." >&2
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
    log "[EXEC]   $*"
    eval "$@"
  fi
}

DRY_RUN=0
[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && DRY_RUN=1

LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"

ensure_root
log "=== Remediación ${ITEM_ID}: Configurar 'root_unlock_time' en ${PAM_AUTH_FILE} y faillock.conf ==="

# ========== Parte 1: common-auth ==========
if [[ ! -f "$PAM_AUTH_FILE" ]]; then
  log "[ERROR] El archivo ${PAM_AUTH_FILE} no existe. No se puede proceder."
  exit 1
fi

MODIFIED=0
TMP_FILE=$(mktemp)

while IFS= read -r line; do
  if echo "$line" | grep -q -E '\bpam_faillock\.so\b'; then
    if echo "$line" | grep -q -E '\broot_unlock_time='; then
      echo "$line" >> "$TMP_FILE"
      log "La línea ya contiene 'root_unlock_time': $line"
    else
      NEW_LINE="$line"
      if ! echo "$line" | grep -q -E '\beven_deny_root\b'; then
        NEW_LINE="$NEW_LINE even_deny_root"
      fi
      NEW_LINE="$NEW_LINE root_unlock_time=${ROOT_UNLOCK_TIME_VALUE}"
      echo "$NEW_LINE" >> "$TMP_FILE"
      log "Añadida 'root_unlock_time': $NEW_LINE"
      MODIFIED=1
    fi
  else
    echo "$line" >> "$TMP_FILE"
  fi
done < "$PAM_AUTH_FILE"

if [[ $MODIFIED -eq 1 && $DRY_RUN -eq 0 ]]; then
  BACKUP_FILE="${BACKUP_DIR}/$(basename "${PAM_AUTH_FILE}").$(date +%Y%m%d-%H%M%S)"
  cp --preserve=mode,ownership,timestamps "${PAM_AUTH_FILE}" "${BACKUP_FILE}"
  log "Backup creado: ${BACKUP_FILE}"
  mv "$TMP_FILE" "$PAM_AUTH_FILE"
  log "Archivo ${PAM_AUTH_FILE} actualizado."
elif [[ $MODIFIED -eq 1 && $DRY_RUN -eq 1 ]]; then
  log "[DRY-RUN] Cambios no aplicados a ${PAM_AUTH_FILE}"
  rm -f "$TMP_FILE"
else
  log "No se necesitaban cambios en ${PAM_AUTH_FILE}"
  rm -f "$TMP_FILE"
fi

# ========== Parte 2: faillock.conf ==========
if [[ ! -f "$FAILLOCK_CONF" ]]; then
  log "[ERROR] El archivo ${FAILLOCK_CONF} no existe. No se puede proceder con esa parte."
else
  if grep -Eq '^\s*(even_deny_root|root_unlock_time\s*=)' "$FAILLOCK_CONF"; then
    log "Ya existe configuración válida en ${FAILLOCK_CONF}. No se requiere modificación."
  else
    BACKUP_FAILLOCK="${BACKUP_DIR}/$(basename "${FAILLOCK_CONF}").$(date +%Y%m%d-%H%M%S)"
    if [[ $DRY_RUN -eq 0 ]]; then
      cp --preserve=mode,ownership,timestamps "$FAILLOCK_CONF" "$BACKUP_FAILLOCK"
      log "Backup de faillock.conf creado: ${BACKUP_FAILLOCK}"
      {
        echo ""
        echo "# Añadido por ${SCRIPT_NAME} para cumplimiento 5.3.3.1.3"
        echo "even_deny_root"
        echo "root_unlock_time = ${ROOT_UNLOCK_TIME_VALUE}"
      } >> "$FAILLOCK_CONF"
      log "Se añadieron 'even_deny_root' y 'root_unlock_time' a ${FAILLOCK_CONF}"
    else
      log "[DRY-RUN] Añadiría 'even_deny_root' y 'root_unlock_time = ${ROOT_UNLOCK_TIME_VALUE}' a ${FAILLOCK_CONF}"
    fi
  fi
fi

log "== Remediación ${ITEM_ID} completada =="

log "NOTA: Los cambios en PAM requieren cerrar sesión o reiniciar para surtir efecto."

exit 0

------------------------------------------------------------------

/etc/pam.d/common-auth 

# This file is included from other service-specific PAM config files,
# and should contain a list of the authentication modules that define
# the central authentication scheme for use on the system
# (e.g., /etc/shadow, LDAP, Kerberos, etc.).  The default is to use the
# traditional Unix authentication mechanisms.
#
# As of pam 1.0.1-6, this file is managed by pam-auth-update by default.
# To take advantage of this, it is recommended that you configure any
# local modules either before or after the default block, and use
# pam-auth-update to manage selection of other modules.  See
# pam-auth-update(8) for details.

# here are the per-package modules (the "Primary" block)
auth    [success=1 default=ignore]      pam_unix.so nullok
# here's the fallback if no module succeeds
auth    requisite                       pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
auth    required                        pam_permit.so
# and here are more per-package modules (the "Additional" block)
# end of pam-auth-update config


recomendacion 

auth required pam_faillock.so preauth
auth [success=1 default=ignore] pam_unix.so nullok
auth [default=die] pam_faillock.so authfail even_deny_root root_unlock_time=60
auth requisite pam_deny.so
auth required pam_permit.so

-------------------


/etc/security/faillock.conf

even_deny_root
root_unlock_time = 60
deny = 5
unlock_time = 600

-------------------

5.3.3.1.3
Asegurar que los bloqueos por intentos fallidos de contraseña incluyan la cuenta root
sudo vim /etc/security/faillock.conf
even_deny_root
root_unlock_time = 60
deny = 5
unlock_time = 600


✅ Resumen Final
Archivo	¿Qué debe tener?
/etc/security/faillock.conf	even_deny_root o root_unlock_time = 60 (o más)
/etc/pam.d/common-auth	Línea con pam_faillock.so que aplique authfail (y preferentemente preauth también)
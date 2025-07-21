#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.6 Asegurar que el uso de comandos privilegiados se recopila 
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.6"
ITEM_DESC="Asegurar que el uso de comandos privilegiados se recopila"
SCRIPT_NAME="$(basename "$0")"
BLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${BLOCK_DIR}/Log"
LOG_FILE="${LOG_DIR}/${ITEM_ID}.log"

RULE_FILE="/etc/audit/rules.d/50-privileged.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
FILESYSTEMS=$(awk '/nodev/{print $2}' /proc/filesystems | paste -sd,)

DRY_RUN=0
[[ ${1:-} =~ ^(--dry-run|-n)$ ]] && DRY_RUN=1

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG_FILE"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo 'Debe ser root.' >&2; exit 1; }; }

generate_rules() {
  local partition rules
  while read -r partition; do
    [ -z "$partition" ] && continue
    while read -r file; do
      [ -z "$file" ] && continue
      echo "-a always,exit -F path=${file} -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k privileged"
    done < <(find "${partition}" -xdev -perm /6000 -type f 2>/dev/null)
  done < <(findmnt -n -l -k -it "${FILESYSTEMS}" | grep -Pv "noexec|nosuid" | awk '{print $1}')
}

merge_rules() {
  local new_file
  new_file=$(mktemp)
  generate_rules | sort -u > "$new_file"

  if [[ -f "$RULE_FILE" ]]; then
    sort -u "$RULE_FILE" "$new_file" > "${new_file}.merged"
    mv "${new_file}.merged" "$new_file"
  fi
  mv "$new_file" "$RULE_FILE"
  chmod 640 "$RULE_FILE"
}

main() {
  mkdir -p "$LOG_DIR"; :> "$LOG_FILE"; log "Run $SCRIPT_NAME – $ITEM_ID"
  ensure_root

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] Generaría las siguientes reglas:"
    generate_rules | head -n 20
    log "[DRY-RUN] ... (total $(generate_rules | wc -l) reglas)"
    exit 0
  fi

  log "Escaneando archivos privilegiados y generando reglas..."
  merge_rules
  log "Reglas guardadas en $RULE_FILE"
  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
}

main "$@"

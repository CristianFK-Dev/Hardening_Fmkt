#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 6.2.3.6 – Asegurar que el uso de comandos privilegiados se recopila
# -----------------------------------------------------------------------------

set -euo pipefail

ITEM_ID="6.2.3.6"
ITEM_DESC="Asegurar que el uso de comandos privilegiados se recopila"
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

RULE_FILE="/etc/audit/rules.d/50-privileged.rules"
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
FILESYSTEMS=$(awk '/nodev/{print $2}' /proc/filesystems | paste -sd,)

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    log "[EXEC]   $*"
    eval "$@"
  fi
}

ensure_root() {
  [[ $EUID -eq 0 ]] || { log "[ERR] Este script debe ejecutarse como root."; exit 1; }
}

generate_rules() {
  while read -r partition; do
    [[ -z "$partition" ]] && continue
    while read -r file; do
      [[ -z "$file" ]] && continue
      echo "-a always,exit -F path=${file} -F perm=x -F auid>=$UID_MIN -F auid!=unset -k privileged"
    done < <(find "${partition}" -xdev -perm /6000 -type f 2>/dev/null)
  done < <(findmnt -n -l -k -it "$FILESYSTEMS" | grep -Pv "noexec|nosuid" | awk '{print $1}')
}

write_rules_file() {
  local tmp_file
  tmp_file=$(mktemp)

  generate_rules | sort -u > "$tmp_file"

  if [[ -f "$RULE_FILE" ]]; then
    sort -u "$RULE_FILE" "$tmp_file" > "${tmp_file}.merged"
    mv "${tmp_file}.merged" "$tmp_file"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] Se escribirían las reglas en $RULE_FILE"
  else
    mv "$tmp_file" "$RULE_FILE"
    chmod 640 "$RULE_FILE"
    log "[OK] Reglas guardadas en: $RULE_FILE"
  fi
}

main() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log "Iniciando $SCRIPT_NAME – $ITEM_ID ($ITEM_DESC)"
  ensure_root

  write_rules_file

  log "[SUCCESS] ${ITEM_ID} aplicado"
  log "== Remediación ${ITEM_ID}: ${ITEM_DESC} completada =="
}

main "$@"

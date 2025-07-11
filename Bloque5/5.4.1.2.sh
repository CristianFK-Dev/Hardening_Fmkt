\
    #!/bin/bash
    # =============================================================================
    # 5.4.1.2 – Ensure minimum password days is configured
    # =============================================================================
    set -euo pipefail

    ITEM_ID="5.4.1.2"
    LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Log"
    BACKUP_DIR="/var/backups/login_defs"
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

    [[ $EUID -ne 0 ]] && exec sudo --preserve-env=PATH "$0" "$@"

    DRY_RUN=0; [[ $# -gt 0 && $1 == "--dry-run" ]] && DRY_RUN=1
    LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)_${ITEM_ID}.log"
    log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"; }
    run(){ [[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN] $*" || { log "[EXEC]   $*"; eval "$@"; }; }

    LOGIN_DEFS="/etc/login.defs"
    backup(){ local f=$1; run "cp --preserve=mode,ownership,timestamps '$f' '${BACKUP_DIR}/$(basename "$f").$(date +%Y%m%d-%H%M%S)'"; }

    patch_login_defs(){
      log "→ Revisando $LOGIN_DEFS"
      if grep -qE '^\s*PASS_MIN_DAYS\s+[0-9]+' "$LOGIN_DEFS"; then
        if grep -qE '^\s*PASS_MIN_DAYS\s+0\b' "$LOGIN_DEFS"; then
          backup "$LOGIN_DEFS"
          run "sed -E 's/^\s*PASS_MIN_DAYS\s+0\b/PASS_MIN_DAYS\t1/' -i '$LOGIN_DEFS'"
          log "  • PASS_MIN_DAYS cambiado a 1"
        else
          log "  • PASS_MIN_DAYS ya ≥1 – sin cambios"
        fi
      else
        backup "$LOGIN_DEFS"
        run "echo -e '\nPASS_MIN_DAYS\t1' >> '$LOGIN_DEFS'"
        log "  • PASS_MIN_DAYS = 1 añadido"
      fi
    }

    patch_users(){
      log "→ Ajustando mindays de usuarios"
      while IFS=: read -r user pw last min rest; do
        [[ $pw =~ ^\$ ]] || continue
        [[ -z $min || $min -lt 1 ]] || continue
        run "chage --mindays 1 '$user'"
      done < /etc/shadow
    }

    log "=== Remediación $ITEM_ID iniciada (dry-run=$DRY_RUN) ==="
    patch_login_defs
    patch_users
    log "=== Remediación $ITEM_ID completada ==="

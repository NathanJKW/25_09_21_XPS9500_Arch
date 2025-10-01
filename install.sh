#!/usr/bin/env bash
# Modular Arch installer — menu + runner (script-local logs)

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config
# ================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${MODULE_DIR:-$SCRIPT_DIR/modules}"
MODULE_GLOB='[0-9][0-9]-*.sh'
ASSUME_YES="${ASSUME_YES:-true}"   # exported to modules; modules decide whether to use it
MODEL_GUARD="${MODEL_GUARD:-}"      # optional substring to enforce on DMI product_name

# All logs go under ./logs relative to this script
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
SESSION_LOG="$LOG_DIR/session-$(date +%F_%H-%M-%S).log"

# ================================
# Logging
# ================================
log()   { printf '[%(%F %T)T] %s\n' -1 "$*" | tee -a "$SESSION_LOG" >&2; }
ok()    { log "OK: $*"; }
fail()  { log "FAIL: $*"; exit 1; }

# ================================
# TUI helpers
# ================================
print_banner() {
  printf '\n== Modular Arch Installer (menu + runner) ==\n'
  printf ' Modules dir: %s\n Log file:    %s\n\n' "$MODULE_DIR" "$SESSION_LOG"
}

press_enter() {
  printf '\nPress Enter to continue... '; read -r _
}

# ================================
# Module discovery & parsing
# ================================
# Metadata format (first ~50 lines of each module):
#   # meta: id=10 name="Base system" desc="Essentials and services" needs_root=false
# Required keys: id, name
# Optional keys: desc, needs_root (true/false)
# Modules MUST be executable. The harness runs them as:
#   env ASSUME_YES=... bash MODULE_PATH
discover_modules() {
  mapfile -t MODULE_FILES < <(
    find "$MODULE_DIR" -maxdepth 1 -type f -name "$MODULE_GLOB" -print0 \
      | xargs -0 -I{} realpath "{}" | sort
  )
  [[ "${#MODULE_FILES[@]}" -gt 0 ]] || fail "No modules found in $MODULE_DIR"
}

parse_meta() {
  # arg: module_path
  local path="$1"
  local header meta
  header="$(head -n 50 "$path")"
  meta="$(grep -E '^# meta:' <<<"$header" | head -n1 || true)"

  local id="" name="" desc="" needs_root="false"
  if [[ -n "$meta" ]]; then
    meta="${meta#\# meta: }"
    # Extract key="value with spaces" OR key=value-without-spaces
    # Then map them to vars without using eval.
    while IFS= read -r kv; do
      case "$kv" in
        id=*)          id="${kv#id=}";;
        name=*)        name="${kv#name=}";;
        desc=*)        desc="${kv#desc=}";;
        needs_root=*)  needs_root="${kv#needs_root=}";;
      esac
    done < <(grep -oE '([a-z_]+)="[^"]*"|([a-z_]+)=[^[:space:]]+' <<<"$meta")

    # strip surrounding quotes when present
    name="${name%\"}"; name="${name#\"}"
    desc="${desc%\"}"; desc="${desc#\"}"
    id="${id%\"}";    id="${id#\"}"
    needs_root="${needs_root%\"}"; needs_root="${needs_root#\"}"
  fi

  printf '%s|%s|%s|%s\n' "$id" "$name" "$desc" "$needs_root"
}

collect_modules() {
  MODULES_META=()   # each: "index|id|name|desc|needs_root|path|modlog"
  local idx=1
  for f in "${MODULE_FILES[@]}"; do
    local meta id name desc needs_root
    meta="$(parse_meta "$f")"
    IFS='|' read -r id name desc needs_root <<<"$meta"

    # Fallbacks from filename
    [[ -n "$id"   ]] || id="$(basename "$f" | cut -d- -f1)"
    [[ -n "$name" ]] || name="$(basename "$f" .sh)"
    [[ -n "$desc" ]] || desc="(no description)"
    [[ -n "$needs_root" ]] || needs_root="false"

    local modlog="$LOG_DIR/module-$(printf '%02d' "$idx")-$(basename "${f%.sh}")-$(date +%H%M%S).log"
    MODULES_META+=("${idx}|${id}|${name}|${desc}|${needs_root}|${f}|${modlog}")
    idx=$((idx+1))
  done
}

# ================================
# Guards (optional model check; UEFI check is module-specific)
# ================================
guard_model() {
  [[ -z "$MODEL_GUARD" ]] && return 0
  local prod="/sys/devices/virtual/dmi/id/product_name"
  [[ -r "$prod" ]] || fail "Cannot read $prod"
  local name; name="$(<"$prod")"
  [[ "$name" == *"$MODEL_GUARD"* ]] || fail "Model guard '$MODEL_GUARD' not matched (found '$name')"
  ok "Model guard matched: $name"
}

# ================================
# Execution
# ================================
run_module() {
  # arg: "idx|id|name|desc|needs_root|path|modlog"
  local rec="$1"
  local idx id name desc needs_root path modlog
  IFS='|' read -r idx id name desc needs_root path modlog <<<"$rec"

  log "==> [$idx] ${name} (id=${id}) — ${desc}"
  log "    path: $path"
  log "    log : $modlog"

  [[ -x "$path" ]] || fail "Module not executable: $path"

  ( export ASSUME_YES; bash "$path" ) >>"$modlog" 2>&1
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "Module ${name} finished successfully"
  else
    log "Module ${name} FAILED with rc=$rc (see $modlog)"
    return "$rc"
  fi
}

run_all() {
  for rec in "${MODULES_META[@]}"; do
    run_module "$rec" || return $?
  done
  ok "All modules completed"
}

show_menu() {
  printf '\nAvailable modules (discovered in %s):\n' "$MODULE_DIR"
  for rec in "${MODULES_META[@]}"; do
    IFS='|' read -r idx id name desc needs_root path modlog <<<"$rec"
    printf '  %2d) %-24s  %s%s\n' "$idx" "$name" "$desc" \
      "$( [[ "$needs_root" == "true" ]] && printf ' [module will sudo]' || printf '' )"
  done
  cat <<EOF

  a) Run ALL (in order)
  q) Quit
EOF
}

prompt_choice() {
  read -rp "Choice: " choice
  case "$choice" in
    a|A) run_all ;;
    q|Q) exit 0 ;;
    ''|*[!0-9]*) log "Invalid choice"; return 1 ;;
    *)
      local sel="$choice"
      for rec in "${MODULES_META[@]}"; do
        IFS='|' read -r idx _ _ _ _ _ _ <<<"$rec"
        if [[ "$idx" -eq "$sel" ]]; then
          run_module "$rec" || return $?
          return 0
        fi
      done
      log "No such item: $sel"; return 1
      ;;
  esac
}

# ================================
# Main
# ================================
trap 'log "Interrupted"; exit 130' INT
print_banner
guard_model
discover_modules
collect_modules

while true; do
  show_menu
  prompt_choice || true
  press_enter
done

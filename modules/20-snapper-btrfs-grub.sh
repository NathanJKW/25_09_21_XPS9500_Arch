#!/usr/bin/env bash
# meta: id=20 name="Snapper (Btrfs) + GRUB" desc="Install snapper/snap-pac/grub-btrfs, create .snapshots, fstab+mount, enable timers+quota, symlink repo configs, rebuild GRUB, and verify with a test snapshot" needs_root=true
#
# Arch Wiki references (keep aligned in comments):
# - Btrfs: Installation guide → Filesystems → Btrfs
# - Snapper: Create a configuration / Integration with pacman / Timeline & cleanup
# - grub-btrfs: daemon watches snapshots and generates /boot/grub/grub-btrfs.cfg

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ----------------
# Config (override via env)
# ----------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SNAP_CONF_SRC_DIR="${SNAP_CONF_SRC_DIR:-$REPO_ROOT/files/snapper}"
BTRFS_COMP_OPT="${BTRFS_COMP_OPT:-compress=zstd:3}"
KEEP_VERIFY_SNAPSHOT="${KEEP_VERIFY_SNAPSHOT:-false}"   # set true to keep the test snapshot

# ----------------
# Logging
# ----------------
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

# ----------------
# Helpers
# ----------------
require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      exec sudo -E -- bash "$0" "$@"
    else
      fail "This module requires root. Install sudo or run as root."
    fi
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }
fs_is_btrfs() { [[ "$(findmnt -no FSTYPE "$1")" == "btrfs" ]]; }
is_btrfs_subvol() { btrfs subvolume show "$1" >/dev/null 2>&1; }
ensure_dir() { install -d -m 0755 "$1"; }

ensure_subvolume() {
  # per Arch Wiki: Snapper → Create a configuration (expects .snapshots subvolumes)
  local path="$1"
  if [[ -e "$path" ]]; then
    is_btrfs_subvol "$path" || fail "$path exists but is not a Btrfs subvolume"
    return 0
  fi
  log "Creating Btrfs subvolume: $path"
  btrfs subvolume create "$path" >/dev/null
}

ensure_fstab_entry() {
  # ensure_fstab_entry <mountpoint> [<subvol_leaf_name>]
  # Example: ensure_fstab_entry "/.snapshots" ".snapshots"
  local mnt="$1" leaf="${2:-${1##*/}}"

  # Determine the parent mount for this mountpoint (root for /.snapshots, /home for /home/.snapshots)
  local parent
  case "$mnt" in
    "/.snapshots")       parent="/" ;;
    "/home/.snapshots")  parent="/home" ;;
    *)                   parent="/" ;;
  esac

  # Resolve filesystem UUID and parent mount’s subvol path
  local uuid opts parent_subvol subvol_path
  uuid="$(findmnt -no UUID "$parent" || true)"
  [[ -n "$uuid" ]] || fail "Could not resolve UUID for $parent"

  opts="$(findmnt -no OPTIONS "$parent" || true)"
  parent_subvol="$(sed -n 's/.*subvol=\([^,]*\).*/\1/p' <<<"$opts")"

  if [[ -z "$parent_subvol" || "$parent_subvol" == "/" ]]; then
    subvol_path="${leaf}"
  else
    subvol_path="${parent_subvol%/}/${leaf}"
  fi

  if ! grep -qE "[[:space:]]${mnt}[[:space:]]" /etc/fstab; then
    log "Appending fstab entry for ${mnt} (subvol=${subvol_path})"
    printf 'UUID=%s  %s  btrfs  subvol=%s,%s  0 0\n' "$uuid" "$mnt" "$subvol_path" "$BTRFS_COMP_OPT" >> /etc/fstab
  fi
}

mount_if_needed() {
  local mp="$1"
  if mountpoint -q "$mp"; then
    return 0
  fi
  log "Mounting ${mp}"
  mount "$mp"
}

deploy_symlink() {
  # per Arch Wiki: Snapper — configs live in /etc/snapper/configs/*
  local src="$1" dest="$2"
  [[ -f "$src" ]] || fail "Source config not found: $src"
  if [[ -L "$dest" ]]; then
    local target; target="$(readlink -f "$dest" || true)"
    if [[ "$target" == "$(readlink -f "$src")" ]]; then
      ok "Symlink already correct: $dest → $src"
      return 0
    fi
  fi
  if [[ -e "$dest" ]]; then
    log "Backing up existing: $dest → ${dest}.bak.$(date +%s)"
    mv -f "$dest" "${dest}.bak.$(date +%s)"
  fi
  ln -s "$(realpath "$src")" "$dest"
  ok "Symlinked: $dest → $src"
}

verify_snapper_config() {
  local cfg="$1"
  snapper -c "$cfg" list >/dev/null || fail "snapper could not read config '$cfg'"
  ok "snapper config '$cfg' is readable"
}

# Manual generator fallback (first run before daemon notices inotify events)
run_grub_btrfs_generator_if_available() {
  if [[ -x /etc/grub.d/41_snapshots-btrfs ]]; then
    /etc/grub.d/41_snapshots-btrfs || true
  fi
}

verify_grub_btrfs_cfg_present() {
  [[ -s /boot/grub/grub-btrfs.cfg ]] || run_grub_btrfs_generator_if_available
  [[ -s /boot/grub/grub-btrfs.cfg ]] || fail "/boot/grub/grub-btrfs.cfg missing or empty"
  ok "grub-btrfs configuration present"
}

enable_quota_if_needed() {
  # per Arch Wiki: Snapper — qgroups recommended for space-aware cleanup
  local mnt="$1"
  if ! btrfs qgroup show "$mnt" >/dev/null 2>&1; then
    log "Enabling Btrfs quota on $mnt"
    btrfs quota enable "$mnt"
  fi
}

enable_grub_btrfs_daemon() {
  # Upstream daemon requires inotify-tools; harmless if already installed
  pacman -S --needed inotify-tools
  systemctl enable --now grub-btrfsd.service || true
}

force_grub_btrfs_refresh() {
  # Make sure daemon is up, then run the generator once as a belt-and-braces refresh
  enable_grub_btrfs_daemon
  run_grub_btrfs_generator_if_available
}

verify_end_to_end_with_test_snapshot() {
  # Create a test snapshot, ensure it appears in grub-btrfs.cfg, then optionally delete it.
  local desc="install-verify-$(date +%F_%H-%M-%S)"
  log "Creating test snapshot (root): $desc"
  snapper -c root create --type single --description "$desc"

  # Get latest snapshot number for root
  local sn
  sn="$(snapper -c root list --columns number,description | awk -v d="$desc" '$0 ~ d {print $1}' | tail -n1)"
  [[ -n "$sn" ]] || fail "Could not determine test snapshot number"

  # Refresh grub-btrfs and wait briefly for cfg regeneration
  force_grub_btrfs_refresh
  local cfg="/boot/grub/grub-btrfs.cfg"
  local path_regex="/\\.snapshots/${sn}/snapshot"
  local found="false"
  for _ in 1 2 3 4 5; do
    if grep -qE "$path_regex" "$cfg"; then
      found="true"; break
    fi
    sleep 1
  done
  [[ "$found" == "true" ]] || fail "grub-btrfs did not list snapshot $sn in $cfg"

  ok "GRUB sees snapshot #$sn"

  if [[ "${KEEP_VERIFY_SNAPSHOT}" != "true" ]]; then
    log "Deleting test snapshot #$sn"
    snapper -c root delete "$sn"
    force_grub_btrfs_refresh
    ok "Test snapshot cleaned up"
  else
    log "Keeping test snapshot #$sn as requested (KEEP_VERIFY_SNAPSHOT=true)"
  fi
}

# ----------------
# Main
# ----------------
main() {
  require_root "$@"

  ensure_cmd btrfs
  ensure_cmd grub-mkconfig
  ensure_dir /etc/snapper/configs
  ensure_dir "$SNAP_CONF_SRC_DIR"

  fs_is_btrfs / || fail "/ is not on Btrfs"
  [[ -d /home ]] && fs_is_btrfs /home || true

  log "Installing packages: snapper snap-pac grub-btrfs"
  pacman -S --needed snapper snap-pac grub-btrfs

  # .snapshots subvolumes and mounts (per Arch Wiki: Snapper → Create a configuration)
  ensure_subvolume "/.snapshots"
  chown root:root /.snapshots && chmod 0750 /.snapshots
  ensure_fstab_entry "/.snapshots" ".snapshots"
  mount_if_needed "/.snapshots"

  if [[ -d /home ]]; then
    ensure_subvolume "/home/.snapshots"
    chown root:root /home/.snapshots && chmod 0750 /home/.snapshots
    ensure_fstab_entry "/home/.snapshots" ".snapshots"
    mount_if_needed "/home/.snapshots"
  fi
  ok ".snapshots subvolumes present and mounted"

  # Quotas for Snapper cleanup
  enable_quota_if_needed "/"
  [[ -d /home ]] && enable_quota_if_needed "/home" || true
  ok "Btrfs quota/qgroups enabled where applicable"

  # Timers
  systemctl enable --now snapper-timeline.timer
  systemctl enable --now snapper-cleanup.timer
  ok "snapper timers enabled"

  # grub-btrfs daemon + initial generation
  enable_grub_btrfs_daemon
  ok "grub-btrfs daemon enabled"

  # Rebuild GRUB (ensures include line exists) then verify snapshots cfg
  [[ -d /boot/grub ]] || fail "/boot/grub not found (is GRUB installed to this ESP?)"
  grub-mkconfig -o /boot/grub/grub.cfg
  ok "grub.cfg rebuilt"

  force_grub_btrfs_refresh
  verify_grub_btrfs_cfg_present

  # Link repo configs and verify
  deploy_symlink "$SNAP_CONF_SRC_DIR/root" /etc/snapper/configs/root
  verify_snapper_config root
  if [[ -d /home && -f "$SNAP_CONF_SRC_DIR/home" ]]; then
    deploy_symlink "$SNAP_CONF_SRC_DIR/home" /etc/snapper/configs/home
    verify_snapper_config home
  else
    log "Note: skipping /home config (either /home missing or no repo file)"
  fi

  # End-to-end verification
  verify_end_to_end_with_test_snapshot

  ok "Snapper + grub-btrfs setup complete and verified"
}

main "$@"

#!/usr/bin/env bash
# snapper-setup.sh
# Purpose: Reproducible Snapper + Btrfs + GRUB setup for this laptop.
# Style: Clear, boring, safe. Aligned with Arch Wiki practices.
# Modes:
#   --apply  : create subvols, fstab entries, configs, timers, grub-btrfs (DEFAULT)
#   --reset  : revert what this script added, but only if safe (no data loss)

set -euo pipefail

# ===========
# Configuration (adjust only if your username isn't 'nathan')
# ===========
USER_NAME="nathan"
SNAP_SUBVOL_ROOT="@snapshots"       # mounted at /.snapshots
SNAP_SUBVOL_HOME="@home.snapshots"  # mounted at /home/.snapshots
MNT_TOP="/mnt/.btrfs"
FSTAB="/etc/fstab"
SNAP_OPTS="rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2"

# ===========
# Helpers
# ===========
log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

need_root() { [[ "$(id -u)" -eq 0 ]] || die "Run as root (sudo -s)."; }
need_btrfs_root() { findmnt -nt btrfs / >/dev/null || die "/ is not on btrfs."; }

root_source() { findmnt -no SOURCE /; }          # e.g. /dev/nvme0n1p2[/@]
root_block()  { local s; s="$(root_source)"; printf '%s\n' "${s%%\[*}"; } # /dev/nvme0n1p2
root_uuid()   { blkid -s UUID -o value "$(root_block)"; }

ensure_top_mount() {
  mkdir -p "$MNT_TOP"
  if ! mountpoint -q "$MNT_TOP"; then
    mount -t btrfs -o subvolid=5 "$(root_block)" "$MNT_TOP"
  fi
}

cleanup_top_mount() {
  mountpoint -q "$MNT_TOP" && umount "$MNT_TOP" || true
  rmdir "$MNT_TOP" 2>/dev/null || true
}

fstab_has_line() {
  local mnt="$1" sub="$2"
  grep -qE "^[^#].*\s+${mnt//\//\\/}\s+btrfs\s+.*subvol=/${sub//\//\\/}(\s|,)" "$FSTAB"
}

append_fstab_line() {
  local uuid="$1" mnt="$2" sub="$3"
  printf "UUID=%s\t%s\tbtrfs\t%s,subvol=/%s\t0 0\n" "$uuid" "$mnt" "$SNAP_OPTS" "$sub" >> "$FSTAB"
}

remove_fstab_line() {
  local mnt="$1" sub="$2"
  # Edit in-place by filtering out exactly the lines that match our subvol + mount pair.
  cp -a "$FSTAB" "${FSTAB}.bak.$(date +%s)"
  awk -v mnt="$mnt" -v sub="$sub" '
    BEGIN{removed=0}
    {
      line=$0
      if ($0 !~ /^[#]/ && $2==mnt && $3=="btrfs" && $0 ~ ("subvol=/" sub)) {
        removed=1; next
      }
      print line
    }
    END{ if (removed==0) { } }
  ' "$FSTAB" > "${FSTAB}.tmp"
  mv "${FSTAB}.tmp" "$FSTAB"
}

is_subvol_present() { [[ -d "$MNT_TOP/$1" ]]; }
create_subvol_if_missing() {
  local sub="$1"
  if ! is_subvol_present "$sub"; then
    btrfs subvolume create "$MNT_TOP/$sub"
    log "Created subvolume $sub"
  else
    log "Subvolume $sub already exists"
  fi
}

subvol_is_empty_dir() {
  # Basic safety: consider empty if no files and no nested subvols
  local path="$MNT_TOP/$1"
  [[ -d "$path" ]] || return 1
  # No nested subvols?
  if btrfs subvolume list -o "$path" | grep -q .; then
    return 1
  fi
  # No regular files/dirs?
  [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

delete_subvol_if_empty() {
  local sub="$1"
  if ! is_subvol_present "$sub"; then
    log "Subvolume $sub not present"
    return 0
  fi
  if subvol_is_empty_dir "$sub"; then
    btrfs subvolume delete "$MNT_TOP/$sub"
    log "Deleted empty subvolume $sub"
  else
    warn "Refusing to delete non-empty subvolume $sub (manual cleanup required)."
  fi
}

enable_service_now() { systemctl enable --now "$1"; }
disable_service_now() { systemctl disable --now "$1" || true; }

# ===========
# APPLY path
# ===========
apply_setup() {
  need_root
  need_btrfs_root
  trap cleanup_top_mount EXIT

  local uuid
  uuid="$(root_uuid)"
  log "Root device: $(root_block)  UUID=$uuid"
  log "Root source: $(root_source)"

  ensure_top_mount

  # 1) Ensure snapshot subvolumes exist at top-level
  create_subvol_if_missing "$SNAP_SUBVOL_ROOT"
  create_subvol_if_missing "$SNAP_SUBVOL_HOME"

  # 2) Ensure mount points
  mkdir -p /.snapshots /home/.snapshots

  # 3) Ensure fstab lines (idempotent)
  if ! fstab_has_line "/.snapshots" "$SNAP_SUBVOL_ROOT"; then
    append_fstab_line "$uuid" "/.snapshots" "$SNAP_SUBVOL_ROOT"
    log "Added fstab entry for /.snapshots"
  else
    log "fstab entry for /.snapshots already present"
  fi
  if ! fstab_has_line "/home/.snapshots" "$SNAP_SUBVOL_HOME"; then
    append_fstab_line "$uuid" "/home/.snapshots" "$SNAP_SUBVOL_HOME"
    log "Added fstab entry for /home/.snapshots"
  else
    log "fstab entry for /home/.snapshots already present"
  fi

  # 4) Mount snapshot subvolumes
  mount /.snapshots 2>/dev/null || true
  mount /home/.snapshots 2>/dev/null || true

  # 5) Packages (safe if already installed)
  pacman -Sy --needed --noconfirm snapper snap-pac grub-btrfs btrfs-progs inotify-tools

  # 6) Snapper configs for root and home (idempotent)
  if ! snapper -c root get-config >/dev/null 2>&1; then
    snapper -c root create-config /
    log "Created snapper config: root"
  else
    log "Snapper config 'root' exists"
  fi
  if ! snapper -c home get-config >/dev/null 2>&1; then
    snapper -c home create-config /home
    log "Created snapper config: home"
  else
    log "Snapper config 'home' exists"
  fi

  # 7) Snapper policy: conservative retention, allow your user to browse
  configure_snapper_config root
  configure_snapper_config home

  # 8) Permissions per snapper expectations
  chmod 750 /.snapshots /home/.snapshots
  chown root:root /.snapshots /home/.snapshots

  # 9) Enable timers and services
  enable_service_now snapper-timeline.timer
  enable_service_now snapper-cleanup.timer
  enable_service_now grub-btrfsd.service
  enable_service_now btrfs-scrub@-.timer
  enable_service_now btrfs-scrub@home.timer || true

  # 10) Force GRUB config refresh (snapshot menu)
  grub-mkconfig -o /boot/grub/grub.cfg

  # 11) Quick functional smoke test (non-destructive)
  if snapper -c root create -d "Initial test snapshot" >/dev/null; then
    log "Created a test snapshot in 'root' config."
    systemctl restart grub-btrfsd.service
  else
    warn "Could not create test snapshot; investigate snapper configuration."
  fi

  log "Apply complete. Validate with:
    snapper -c root list
    snapper -c home list
    findmnt -nt btrfs
    systemctl status snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service"
}

configure_snapper_config() {
  # Adjusts an existing /etc/snapper/configs/<name> with conservative values.
  local name="$1"
  local cfg="/etc/snapper/configs/$name"
  [[ -f "$cfg" ]] || { warn "Config $cfg missing; skipping."; return 0; }

  # Timeline snapshots on; modest retention; number cleanup enabled.
  sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' "$cfg"
  sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' "$cfg"             # 30m
  sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="6"/' "$cfg"
  sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$cfg"
  sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' "$cfg"
  sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="3"/' "$cfg"
  sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' "$cfg"
  sed -i 's/^NUMBER_CLEANUP=.*/NUMBER_CLEANUP="yes"/' "$cfg"
  sed -i 's/^NUMBER_MIN_AGE=.*/NUMBER_MIN_AGE="1800"/' "$cfg"
  sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="50"/' "$cfg"
  sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="10"/' "$cfg"

  # Allow your user to browse snapshots without sudo.
  if grep -q '^ALLOW_USERS=' "$cfg"; then
    sed -i "s/^ALLOW_USERS=.*/ALLOW_USERS=\"$USER_NAME\"/" "$cfg"
  else
    printf 'ALLOW_USERS="%s"\n' "$USER_NAME" >> "$cfg"
  fi
}

# ===========
# RESET path (safe cleanup)
# ===========
reset_setup() {
  need_root
  need_btrfs_root
  trap cleanup_top_mount EXIT

  ensure_top_mount

  # 1) Stop/disable services and timers we manage
  disable_service_now grub-btrfsd.service
  disable_service_now snapper-timeline.timer
  disable_service_now snapper-cleanup.timer
  disable_service_now btrfs-scrub@-.timer
  disable_service_now btrfs-scrub@home.timer

  # 2) Unmount snapshot mount points if mounted
  umount /.snapshots 2>/dev/null || true
  umount /home/.snapshots 2>/dev/null || true

  # 3) Remove our fstab lines (only those we added)
  if fstab_has_line "/.snapshots" "$SNAP_SUBVOL_ROOT"; then
    remove_fstab_line "/.snapshots" "$SNAP_SUBVOL_ROOT"
    log "Removed fstab entry for /.snapshots"
  else
    log "No fstab entry for /.snapshots from this script"
  fi
  if fstab_has_line "/home/.snapshots" "$SNAP_SUBVOL_HOME"; then
    remove_fstab_line "/home/.snapshots" "$SNAP_SUBVOL_HOME"
    log "Removed fstab entry for /home/.snapshots"
  else
    log "No fstab entry for /home/.snapshots from this script"
  fi

  # 4) Attempt to delete snapshot subvolumes ONLY if empty
  delete_subvol_if_empty "$SNAP_SUBVOL_ROOT"
  delete_subvol_if_empty "$SNAP_SUBVOL_HOME"

  # 5) Leave snapper packages/configs intact by default (safer).
  #    If you *really* want to remove configs, uncomment below.
  #    WARNING: This does not touch snapshots on disk, it only removes configs.
  # if snapper -c root get-config >/dev/null 2>&1; then
  #   snapper -c root delete-config || true
  #   rm -f /etc/snapper/configs/root
  #   log "Removed snapper config 'root'"
  # fi
  # if snapper -c home get-config >/dev/null 2>&1; then
  #   snapper -c home delete-config || true
  #   rm -f /etc/snapper/configs/home
  #   log "Removed snapper config 'home'"
  # fi

  log "Reset complete. Review ${FSTAB}.bak.* if you need to restore a previous fstab."
}

# ===========
# Main
# ===========
mode="${1:---apply}"
case "$mode" in
  --apply) apply_setup ;;
  --reset) reset_setup ;;
  *)
    echo "Usage: $0 [--apply|--reset]"
    exit 2
    ;;
esac

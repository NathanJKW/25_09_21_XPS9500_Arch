# Hyprland Daily-Driver Install Roadmap (Arch Linux)

This document lists everything needed to set up **Hyprland** as a **stable daily-driver** on a minimal Arch Linux install.  
The order is chronological, reflecting how you’d realistically install/configure packages.  

---

## 1. System Resilience & Base Tools

- **btrfs-progs** → Core Btrfs filesystem utilities.  
- **snapper** → Snapshot manager for Btrfs.  
- **snap-pac** → Creates automatic snapshots before pacman upgrades.  
- **grub-btrfs** → Integrates Snapper snapshots into the GRUB boot menu.  
- **git** → Needed for dotfiles, config management, and AUR packages.  
- **base-devel** → Essential build tools (required for AUR helpers like `yay` or `paru`).  

---

## 2. Hyprland Core

- **hyprland** → The compositor itself (pulls in core deps: cairo, mesa, wayland, libseat, libxkbcommon, etc.).  

---

## 3. Session & Permissions

- **systemd** → Provides logind seat/session management.  
- **polkit** → PolicyKit framework for privilege elevation.  
- **hyprpolkitagent** → Polkit authentication agent tailored for Hyprland.  
- **uwsm** → Universal Wayland Session Manager (improves DM + compositor integration).  
- **sddm** → Display/login manager (Qt-based, Wayland support).  
- **greetd** *(alternative)* → Minimal Wayland-native login manager.  
- **sudo** → Privilege escalation tool (not always installed by default).  

---

## 4. Keyring / Secrets

- **gnome-keyring** → Secret storage (Wi-Fi, browser passwords, SSH keys).  
- **libsecret** → Library interface used by apps to access gnome-keyring.  
- **seahorse** *(optional)* → GUI for managing secrets stored in gnome-keyring.  
- **kwallet** *(alternative)* → KDE’s wallet manager.  

---

## 5. System Services

### Audio
- **pipewire** → Modern audio/video server (replaces PulseAudio, JACK).  
- **wireplumber** → PipeWire session/policy manager.  
- **pavucontrol** → GUI mixer for audio devices.  
- **pamixer** → CLI volume control.  

### Networking
- **networkmanager** → Wired & Wi-Fi network manager.  
- **network-manager-applet** → GUI tray applet for controlling NetworkManager.  

### Bluetooth
- **bluez**, **bluez-utils** → Bluetooth stack + utilities.  
- **blueman** → GUI manager for Bluetooth devices.  

### Storage
- **gvfs**, **gvfs-mtp** → Automount USB drives, Android, network shares.  
- **udisks2** → Disk management backend.  
- **ntfs-3g** → NTFS read/write support.  
- **exfatprogs** → exFAT filesystem support.  

### Power (laptops)
- **power-profiles-daemon** → Simple power profile switching.  
- **tlp** → Advanced laptop power management.  
- **upower** → Battery stats provider.  
- **acpid** → ACPI daemon for power button/lid events.  

---

## 6. User Environment (UI Layer)

- **swaync** → Wayland-native notifications + tray + history (recommended).  
- **waybar** → Status bar (network, volume, battery, workspaces).  
- **hyprpaper** → Wallpaper manager.  
- **hypridle** → Idle manager (auto-lock, suspend).  
- **hyprlock** → Screen locker for Hyprland.  
- **wl-clipboard** → Wayland clipboard utilities (`wl-copy`, `wl-paste`).  
- **brightnessctl** → Adjust backlight brightness.  
- **gammastep** → Night light / color temperature control.  

---

## 7. Daily Essentials

- **ttf-dejavu**, **noto-fonts**, **noto-fonts-emoji** → Fonts (text, Unicode, emoji).  
- **alacritty / kitty / foot** → Terminal emulator (choose one).  
- **thunar / dolphin / pcmanfm** → File manager (choose one).  
- **wofi / rofi-wayland / fuzzel** → App launcher/menu (choose one).  
- **xdg-user-dirs** → Creates standard user folders (`Documents`, `Downloads`, etc.).  

---

## 8. Applications

- **firefox / chromium** → Browser (choose one).  
- **libreoffice-fresh** → Office suite.  
- **vlc / mpv** → Media player (choose one).  

---

# ✅ Notes

- **Display Manager**: SDDM is the easiest for beginners; advanced users may prefer `greetd`.  
- **Notifications**: `swaync` is recommended for a full desktop feel; alternatives are `mako` (lightweight) or `dunst` (classic, via XWayland).  
- **Snapshots**: Only needed if you use **Btrfs**; skip if you’re on ext4.  
- **Fonts**: Absolutely necessary — otherwise many apps will render badly or miss Unicode/emoji.  
- **Laptop users**: Strongly recommended to install `tlp`, `upower`, `acpid`, and `power-profiles-daemon`.  

---

# 🖥️ Install Flow Summary

1. **Resilience** (snapper, grub-btrfs, base-devel).  
2. **Hyprland core**.  
3. **Session & permissions** (sddm, polkit, hyprpolkitagent, uwsm).  
4. **Keyring** (gnome-keyring, libsecret).  
5. **System services** (audio, networking, Bluetooth, storage, power).  
6. **UI layer** (swaync, waybar, hyprpaper, hypridle, hyprlock).  
7. **Daily essentials** (fonts, terminal, file manager, launcher).  
8. **Applications** (browser, office, media).  


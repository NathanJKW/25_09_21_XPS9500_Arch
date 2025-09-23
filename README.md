Got it 👍 — here’s your full **polished README** with the tightened-up Arch install guide merged seamlessly with the 
# 25_09_21_XPS9500_Arch

## 🖥️ Preparing a Fresh Arch Install

### 1. Update the Arch installer (from ISO)
```bash
pacman -Syu archinstall
````

---

### 2. Connect to Wi-Fi

1. **List network interfaces**

   ```bash
   ip link
   ```

   Look for something like `wlan0` or `wlp2s0`.

2. **Bring interface up**

   ```bash
   ip link set wlan0 up
   ```

   (replace `wlan0` with your device name)

3. **Use `iwctl` to connect**

   ```bash
   iwctl
   ```

   Inside the prompt:

   ```
   device list
   station wlan0 scan
   station wlan0 get-networks
   station wlan0 connect YOUR_WIFI_NAME
   exit
   ```

   Enter your Wi-Fi password when prompted.

4. **Verify internet**

   ```bash
   ping -c 3 archlinux.org
   ```

---

### 3. Enable SSH (optional but recommended)

1. **Check if installed**

   ```bash
   pacman -Qs openssh
   ```

   If missing:

   ```bash
   pacman -S openssh
   ```

2. **Start and enable service**

   ```bash
   systemctl enable --now sshd
   ```

3. **Verify it’s running**

   ```bash
   systemctl status sshd
   ```

4. **Quick test**

   ```bash
   ssh localhost
   ```

---

# ⚙️ Unattended Arch Provisioning — Module Layout

This project provisions an Arch Linux system (built from a minimal **archinstall** base) using modular steps.
Modules are numbered with a **3-digit scheme**:

* **1st digit** → category
* **2nd + 3rd digits** → subcategory (with gaps left for expansion)

Each module lives under `modules/<number_name>/module.py` and implements an `install(run)` function.
Execution order is determined by the numeric prefix (lowest first).

---

## 📊 Categories & Subcategories

### 0xx — Core System

Things needed on *every* machine before higher layers.

* **000\_core** — base essentials (git, curl, pacman/yay setup, reflector)
* **010\_security** — sudo, polkit (baseline auth, not firewall)
* **020\_system-defaults** — sysctl, journald, logrotate
* **030\_backup** — timeshift, snapper, borg
* **040\_fonts** — system/user fonts (optional early install)

---

### 1xx — Hardware & Platform

Drivers, firmware, power management. Run **before the desktop stack** so GPU/audio/input works.

* **100\_firmware** — fwupd, microcode
* **110\_power** — tlp, auto-cpufreq, thermald
* **120\_input** — libinput, touchpads, special keyboards
* **130\_gpu** — mesa, vulkan, nvidia/amd/intel utils
* **140\_audio** — pipewire, alsa, bluetooth audio
* **150\_network** — networking tools beyond installer defaults
* **160\_devtools** — docker, podman, compilers (kernel-dependent tools)

---

### 2xx — Desktop Stack

Windowing system, login manager, WM/DE, theming.

* **200\_display-server** — Xorg or Wayland base
* **210\_login-manager** — SDDM, GDM, LightDM
* **220\_window-manager** — i3, sway, hyprland, etc.
* **230\_panels-bars** — polybar, waybar
* **240\_theming** — GTK/Qt themes, cursors, icons

---

### 3xx — Applications

Grouped broadly; gaps left for expansion.

* **300\_cli-tools** — shell (zsh/bash), tmux, fzf, ripgrep, etc.
* **320\_editors** — vim/neovim, vscode, IDEs
* **340\_browsers** — firefox, chromium
* **360\_office** — libreoffice, PDF tools
* **380\_media** — players, image viewers, codecs

---

### 4xx — Dotfiles & User Config

Glue that ties your repo/configs into place.

* **400\_dotfiles-core** — clone or update dotfiles repo
* **410\_symlinks** — symlink configs to `$HOME` and `/etc`
* **420\_services** — enable/start wanted systemd services
* **430\_shell-env** — env vars, Xresources, autostarts

---

### 5xx — Security & Policies

Optional hardening, after system is otherwise usable.

* **500\_firewall** — ufw, nftables
* **510\_audit** — auditd, advanced policies

---

### 6xx — Extras / Ecosystems

Nice-to-have, not base system.

* **600\_gaming** — steam, lutris, proton, wine
* **620\_creative** — audio/video production, design tools
* **640\_remote** — tailscale, syncthing, ssh extras

---

## ✅ Recommended Run Order

1. **0xx Core System**
2. **1xx Hardware & Platform**
3. **2xx Desktop Stack**
4. **3xx Applications**
5. **4xx Dotfiles & User Config**
6. **5xx Security & Policies**
7. **6xx Extras / Ecosystems**

This ensures:

* Hardware (1xx) is configured **before** the desktop environment (2xx).
* Security/hardening (5xx) is applied **after** the system is working.

---

## 🛠 How to Add a Module

1. Create a new folder under `modules/` with the correct number and name, e.g.:

   ```
   modules/220_window-manager/module.py
   ```
2. Implement an `install(run)` function inside `module.py`.
3. The `module_loader` will automatically discover and run it.

---

## Example Tree

```
modules/
000_core/
  module.py
020_system-defaults/
  module.py
100_firmware/
  module.py
130_gpu/
  module.py
200_display-server/
  module.py
220_window-manager/
  module.py
300_cli-tools/
  module.py
400_dotfiles-core/
  module.py
410_symlinks/
  module.py
500_firewall/
  module.py
600_gaming/
  module.py
```

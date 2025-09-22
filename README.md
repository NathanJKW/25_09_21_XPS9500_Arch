# 25_09_21_XPS9500_Arch

## Update Arch Installer
pacman -Syu archinstall

## In the **live installer (terminal only)**

1. **Check Wi-Fi device:**

   ```bash
   ip link
   ```

   You should see something like `wlan0` or `wlp2s0`.

2. **Bring interface up:**

   ```bash
   ip link set wlan0 up
   ```

   (replace `wlan0` with your device name)

3. **Use `iwctl` (recommended with Arch ISO):**

   ```bash
   iwctl
   ```

   Then inside the `iwctl` prompt:

   ```
   device list
   station wlan0 scan
   station wlan0 get-networks
   station wlan0 connect YOUR_WIFI_NAME
   exit
   ```

   It will ask for your Wi-Fi password.

4. **Test connection:**

   ```bash
   ping archlinux.org
   ```

---

## Setup SSH

---

### 1. Check if `openssh` is installed

```bash
pacman -Qs openssh
```

* If you see `local/openssh …` → it’s installed.
* If nothing shows → install it:

  ```bash
  sudo pacman -S openssh
  ```

---

### 2. Check if the SSH service is enabled/running

Arch uses **systemd**, so run:

```bash
systemctl status sshd
```

* If it says **“active (running)”**, SSH is already up.
* If it says **“disabled” or “inactive”**, start and enable it:

  ```bash
  sudo systemctl enable --now sshd
  ```

---

### 3. Verify it’s listening on port 22

```bash
ss -tulpn | grep ssh
```

or

```bash
netstat -tulpn | grep ssh
```

(you might need to install `net-tools` for `netstat`)

---

### 4. Test from the same machine

```bash
ssh localhost
```

If it connects, SSH is working locally.

---


Gotcha 👍 — let me clean that up so the Markdown renders nicely and is easy to read in GitHub/GitLab/etc.

Here’s a properly formatted `README.md`:

```markdown
# Unattended Arch Provisioning — Module Layout

This project provisions an Arch Linux system (built from a minimal **archinstall** base) using modular steps.  
Modules are numbered with a **3-digit scheme**:  

- **1st digit** → category  
- **2nd + 3rd digits** → subcategory (with gaps left for expansion)  

Each module lives under `modules/<number_name>/module.py` and implements an `install(run)` function.  
Execution order is determined by the numeric prefix (lowest first).  

---

## 📊 Categories & Subcategories

### 1xx — Core System
Things needed on *every* machine before higher layers.

- **100_core** — base essentials (git, curl, pacman/yay setup, reflector)  
- **110_security** — sudo, polkit, firewall baseline  
- **120_system-defaults** — sysctl, journald, logrotate  
- **130_backup** — timeshift, snapper, borg  

---

### 2xx — Hardware & Platform
Drivers, firmware, power management.  
⚠️ Run **before the desktop stack** so GPU/audio/input works when WM/DE is installed.

- **200_firmware** — fwupd, microcode  
- **210_power** — tlp, auto-cpufreq, thermald  
- **220_input** — libinput, touchpads, special keyboards  
- **230_gpu** — mesa, vulkan, nvidia/amd/intel utils  
- **240_audio** — pipewire, alsa, bluetooth audio  
- **250_network** — networking tools beyond installer defaults (optional)  

---

### 3xx — Desktop Stack
Windowing system, login manager, WM/DE, theming.

- **300_display-server** — Xorg or Wayland base  
- **310_login-manager** — SDDM, GDM, LightDM  
- **320_window-manager** — i3, sway, hyprland, etc.  
- **330_panels-bars** — polybar, waybar  
- **340_fonts** — system/user fonts  
- **350_theming** — GTK/Qt themes, cursors, icons  

---

### 4xx — Applications
Grouped broadly; gaps left for expansion.

- **400_cli-tools** — shell (zsh/bash), tmux, fzf, ripgrep, etc.  
- **420_editors** — vim/neovim, vscode, IDEs  
- **440_browsers** — firefox, chromium  
- **460_office** — libreoffice, PDF tools  
- **480_media** — players, image viewers, codecs  
- **490_devtools** — git, gh, compilers, docker/podman  

---

### 5xx — Dotfiles & User Config
Glue that ties your repo/configs into place.

- **500_dotfiles-core** — clone or update dotfiles repo  
- **510_symlinks** — symlink configs to `$HOME` and `/etc`  
- **520_services** — enable/start wanted systemd services  
- **530_shell-env** — env vars, Xresources, autostarts  

---

### 6xx — Security & Policies
Optional hardening, after system is otherwise usable.

- **600_firewall** — ufw, nftables  
- **610_audit** — auditd, advanced policies  

---

### 7xx — Extras / Ecosystems
Nice-to-have, not base system.

- **700_gaming** — steam, lutris, proton, wine  
- **720_creative** — audio/video production, design tools  
- **740_remote** — tailscale, syncthing, ssh extras  

---

## ✅ Recommended Run Order

1. **1xx Core System**  
2. **2xx Hardware & Platform**  
3. **3xx Desktop Stack**  
4. **4xx Applications**  
5. **5xx Dotfiles & User Config**  
6. **6xx Security & Policies**  
7. **7xx Extras / Ecosystems**

This ensures:  
- Hardware (2xx) is configured **before** the desktop environment (3xx).  
- Security/hardening (6xx) is applied **after** the system is working.  

---


## 🛠 How to Add a Module

1. Create a new folder under `modules/` with the correct number and name, e.g.: 

modules/320\_window-manager/module.py

2. Implement an `install(run)` function inside `module.py`.  
3. The `module_loader` will automatically discover and run it.  

---

## Example Tree


modules/
100\_core/
module.py
200\_firmware/
module.py
300\_display-server/
module.py
320\_window-manager/
module.py
400\_cli-tools/
module.py
500\_dotfiles-core/
module.py
510\_symlinks/
module.py
600\_firewall/
module.py
700\_gaming/
module.py

```

---

Do you want me to go ahead and **generate that folder tree with empty `module.py` stubs (with docstrings)** so you can drop it right into your repo?


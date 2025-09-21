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

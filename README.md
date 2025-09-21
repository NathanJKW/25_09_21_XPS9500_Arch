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


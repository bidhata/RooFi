# RooFi - Advanced WiFi Manager via CLI

```text
 ____   __    __  ____  __  
(  _ \ /  \  /  \(  __)(  ) 
 )   /(  O )(  O )) _)  )(  
(__\_) \__/  \__/(__)  (__) 

**Author:** [@bidhata](https://github.com/bidhata)  
**Version:** 2.2  
**Email:** me@krishnendu.com  

---

## 📌 Overview
When working with remote shells or minimal Linux setups, managing WiFi through the command line can be frustrating. **RooFi** solves this problem by providing a **colorful, interactive, menu-driven WiFi manager** built on top of `nmcli`.

With RooFi, you don’t need to remember long `nmcli` commands. Instead, you get a clean CLI interface with signal bars, connection info, and simple options to control your WiFi.

---

## ✨ Features
- 🔍 **Scan & list available WiFi networks** with colored **signal strength bars** (Red = weak, Yellow = medium, Green = strong).
- 🔑 **Connect to networks** (prompts for password if required).
- 📶 **Show current connection details** (SSID, IP, device).
- 🔄 **Auto-detect wireless interface** (works with `nmcli` or `iw`).
- ❌ **Disconnect from WiFi** instantly.
- 🗑 **Forget/remove saved networks** easily.
- 🔁 **Auto reconnect option** for seamless switching.
- 🎨 **Beautiful, colorful ASCII menu UI** (works even in SSH/TTY sessions).
- 🖥 **Lightweight Bash script** — no dependencies except NetworkManager.

---

## 🚀 Installation
Clone the repository and give execution permission:

```bash
#Install Packages
sudo apt-get install network-manager iw

# Clone RooFi
git clone https://github.com/bidhata/RooFi.git
cd RooFi

# Make script executable
chmod +x RooFi.sh
```

For system-wide use, move it to `/usr/local/bin`:

```bash
sudo mv RooFi.sh /usr/local/bin/roofi
```

Now you can run it anywhere by typing:

```bash
roofi
```

---

## ⚡ Usage
Run the script:

```bash
./RooFi.sh
```

Or (if installed system-wide):

```bash
roofi
```

You will see a colorful interactive menu like this:

```
╔═══════════════════════════════════════════════════════╗
║                RooFi WiFi Manager v2.2               ║
║           Author: Krishnendu Paul @bidhata           ║
║           Email: me@krishnendu.com                  ║
╚═══════════════════════════════════════════════════════╝

Interface: wlan0 | Status: enabled
═══════════════════════════════════════════════════════
Main Menu
───────────────────────────────────────────────────────
1) Show WiFi Status
2) List Available Networks
3) Connect to Network
4) Disconnect from Network
5) Show Saved Networks
6) Turn WiFi On/Off
7) Show Network Details
8) Power Management
9) Advanced Options
10) Hotspot
11) Exit
───────────────────────────────────────────────────────

Select option (1-11): 

```

Just choose an option and follow the prompts.

When scanning networks, RooFi shows signal strength like this:

```
MyWiFiNetwork   ████████░░  80%
OtherNetwork    ████░░░░░░  40%
```

---


## 🔧 Requirements
- Linux system with **NetworkManager** installed
- `nmcli` command available
- Bash shell environment

---

## 🛠 Troubleshooting
- Ensure `NetworkManager` service is running:
  ```bash
  sudo systemctl status NetworkManager
  ```
- If RooFi cannot detect your WiFi interface, check with:
  ```bash
  nmcli device
  iw dev
  ```
- Run with `sudo` if you lack permission to manage WiFi.

---

## 📜 License
This project is licensed under the **GNU GPL 2.0**.

---

## ❤️ Acknowledgments
RooFi was born out of frustration while managing WiFi over SSH and TTY sessions.  
Hopefully, it makes your CLI WiFi management **simple and beautiful**!

---

👉 [Visit the Repository](https://github.com/bidhata/RooFi)

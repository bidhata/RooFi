# RooFi - Advanced WiFi Manager via CLI

![RooFi Logo](https://raw.githubusercontent.com/bidhata/RooFi/main/assets/logo.png)

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
╚═══════════════════════════════════════════════════════╝

1) Scan & List Networks
2) Connect to WiFi
3) Show Current Connection
4) Disconnect
5) Forget Saved Network
6) Auto Reconnect
7) Exit
```

Just choose an option and follow the prompts.

When scanning networks, RooFi shows signal strength like this:

```
MyWiFiNetwork   ████████░░  80%
OtherNetwork    ████░░░░░░  40%
```

---

## 📷 Demo
*(Add a GIF or screenshot here of RooFi in action)*

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
This project is licensed under the **MIT License**.

---

## ❤️ Acknowledgments
RooFi was born out of frustration while managing WiFi over SSH and TTY sessions.  
Hopefully, it makes your CLI WiFi management **simple and beautiful**!

---

👉 [Visit the Repository](https://github.com/bidhata/RooFi)

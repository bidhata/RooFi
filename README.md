# RooFi - Simple WiFi Manager

**Author:** [@bidhata](https://github.com/bidhata)  

RooFi is a **lightweight WiFi manager for Linux** that lets you easily scan, connect, and manage WiFi networks from the **terminal**. Perfect for Raspberry Pi, headless systems, or anyone who prefers the command line over bulky GUI tools.  

---

## ✨ Features
- 📡 Scan available WiFi networks  
- 🔑 Connect to WiFi with SSID + password  
- 🔌 Disconnect from WiFi  
- 📋 View current connection status  
- ⚡ Works without a desktop environment  

---

## 📦 Requirements
- Linux system with WiFi support  
- `bash` shell  
- [`nmcli`](https://developer.gnome.org/NetworkManager/stable/nmcli.html) (usually comes pre-installed with NetworkManager)  

Check if `nmcli` is installed:
```bash
nmcli --version
```
If not installed, you can add it (Debian/Ubuntu):
```bash
sudo apt install network-manager
```

---

## 🚀 Installation

Clone the repository:
```bash
git clone https://github.com/bidhata/RooFi.git
cd RooFi
```

Make the script executable:
```bash
chmod +x RooFi.sh
```

Run it:
```bash
./RooFi.sh
```

---

## 🖥️ Usage

When you run RooFi, you’ll see a simple menu:

```
=========================
 RooFi - WiFi Manager
=========================
1. Scan WiFi Networks
2. Connect to WiFi
3. Disconnect WiFi
4. Show Current Connection
5. Exit
```

---

## 🎬 Demo Walkthrough (ASCII Example)

```
$ ./RooFi.sh

=========================
 RooFi - WiFi Manager
=========================
1. Scan WiFi Networks
2. Connect to WiFi
3. Disconnect WiFi
4. Show Current Connection
5. Exit
Enter choice: 1

Scanning for WiFi networks...

SSID            SIGNAL   SECURITY
Home_Network    85%      WPA2
Cafe_WiFi       65%      WPA
Open_Network    40%      --

=========================
1. Scan WiFi Networks
2. Connect to WiFi
3. Disconnect WiFi
4. Show Current Connection
5. Exit
Enter choice: 2

Enter WiFi SSID: Home_Network
Enter Password: ********

[✔] Successfully connected to Home_Network!

=========================
1. Scan WiFi Networks
2. Connect to WiFi
3. Disconnect WiFi
4. Show Current Connection
5. Exit
Enter choice: 4

Currently connected to: Home_Network
```

---

## 🤝 Contributing

Want to improve RooFi?  
- Fork the repo  
- Make your changes  
- Open a pull request 🚀  

---

## 📜 License

This project is licensed under the MIT License.  

# RipTide: Automatic DVD Ripping & Plex Prep Script for Ubuntu

RipTide is a fully automated installer script for setting up a dual-DVD drive ripping system that rips, encodes, and organizes your DVDs using the Automatic Ripping Machine (ARM) — optimized for Ubuntu.

## 🎯 Features
- ✅ Auto-detects 1 or 2 DVD drives
- ✅ Hardware-accelerated H.265 encoding using NVIDIA NVENC
- ✅ Optional RAM disk for ultra-fast ripping
- ✅ Auto-formats and mounts a user-selected storage drive
- ✅ Fully Dockerized ARM deployment
- ✅ Prepares library for Plex (but does not install Plex)

## 🛠 Requirements
- Ubuntu Desktop or Server (22.04 or newer recommended)
- At least 1 DVD drive (2 supported)
- Optional: NVIDIA GPU with drivers for fast transcoding
- At least 32GB RAM recommended (for RAM disk)

## 🚀 Installation
1. Clone this repo:
```bash
git clone https://github.com/DrPhilyourass/riptide-installer.git
cd riptide-installer
```

2. Make the installer executable:
```bash
chmod +x riptide_installer.sh
```

3. Run the script as root:
```bash
sudo ./riptide_installer.sh
```

4. Follow the prompts to:
- Select your media storage drive
- Format and mount it
- Automatically deploy ARM with your DVD drives

5. After reboot (if needed), insert DVDs — the system will begin ripping automatically.

## 📂 Output
Ripped and encoded movies will appear in:
```
/mnt/nvme_media/Movies/
```
You can point Plex to this folder for automatic indexing.

## ⚠️ Warning
- This script **will format** the selected media drive.
- It does **not install Plex** — only prepares the folder structure.

## 🧠 Credits
- [Automatic Ripping Machine (ARM)](https://github.com/automaticrippingmachine/automatic-ripping-machine)
- HandBrake, MakeMKV, Docker, NVIDIA

## 📜 License
MIT License. See [LICENSE](./LICENSE) for details.

---
**Created by ChatGPT + DrPhilyourass**

#!/bin/bash
# RipTide: Universal Dual-DVD Plex Ripper Setup Script for Ubuntu
# Author: ChatGPT for Luke
# Description: Auto-installs ARM DVD ripper, sets up Docker, GPU support, RAM disk, and Plex-ready paths

set -e

### ✅ Check for root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root: sudo ./riptide_installer.sh"
  exit 1
fi

### ✅ Check for Ubuntu
if ! grep -qi ubuntu /etc/os-release; then
  echo "❌ This script only supports Ubuntu."
  exit 1
fi

### ✅ Confirm installation
echo "⚠️ This script will install packages, configure your drives, and may format a disk."
echo "Proceed only if you understand and approve."
read -p "Continue? (y/n): " confirm
[[ $confirm != "y" ]] && exit 1

### ✅ Install dependencies
apt update && apt install -y docker.io docker-compose curl jq zenity lsb-release

### ✅ Enable Docker
systemctl enable docker
systemctl start docker

### ✅ Check for NVIDIA GPU + Drivers
if ! command -v nvidia-smi &> /dev/null; then
  echo "⚠️ NVIDIA drivers not found. GPU encoding will not work until drivers are installed."
fi

### ✅ Install NVIDIA container runtime (optional, safe to skip)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
apt update && apt install -y nvidia-docker2 || true
systemctl restart docker

### ✅ Setup RAM disk
mkdir -p /mnt/ramdisk
if ! grep -q "/mnt/ramdisk" /etc/fstab; then
  echo "tmpfs /mnt/ramdisk tmpfs defaults,size=16G 0 0" >> /etc/fstab
fi
mount /mnt/ramdisk

### ✅ Choose or confirm media drive
echo "📦 Available block devices:"
lsblk -dpno NAME,SIZE | grep -v "/loop"
echo ""
read -p "Enter the device to use for storing movies (e.g., /dev/nvme0n1): " MEDIA_DEV
if [ ! -b "$MEDIA_DEV" ]; then
  echo "❌ Invalid device: $MEDIA_DEV"
  exit 1
fi

read -p "⚠️ WARNING: This will format $MEDIA_DEV to ext4. Continue? (y/n): " confirm_format
[[ $confirm_format != "y" ]] && exit 1

mkfs.ext4 -F "$MEDIA_DEV"
mkdir -p /mnt/nvme_media
if ! grep -q "$MEDIA_DEV" /etc/fstab; then
  echo "$MEDIA_DEV /mnt/nvme_media ext4 defaults 0 2" >> /etc/fstab
fi
mount "$MEDIA_DEV" /mnt/nvme_media
mkdir -p /mnt/nvme_media/Movies

### ✅ Detect DVD drives
echo "🔍 Scanning for DVD drives..."
DVD_DEVICES=($(lsblk -S | grep -i dvd | awk '{print $1}' | sed 's/^/\/dev\//'))
if [[ ${#DVD_DEVICES[@]} -eq 0 ]]; then
  echo "❌ No DVD drives found. Connect at least one."
  exit 1
fi

### ✅ Build ARM drive config
drive_yaml=""
i=0
for dev in "${DVD_DEVICES[@]}"; do
  drive_yaml+="  - name: DVD_$((i+1))\n    device: $dev\n    type: dvd\n    mode: auto\n"
  ((i++))
done

### ✅ Setup ARM config and folders
mkdir -p /opt/riptide/presets
cat <<EOF > /opt/riptide/arm.yaml
drives:
$drive_yaml
raw_path: /mnt/ramdisk/raw
encoded_path: /mnt/ramdisk/encoded

post_process:
  use_handbrake: true
  handbrake_preset: nvenc_h265_fast
  handbrake_extra_args: "--audio-lang-list eng --all-audio"

file_actions:
  - action: move
    src: "{{encoded_path}}/*.mkv"
    dest: "/mnt/nvme_media/Movies/"
    rename: "{{title}} ({{year}}).mkv"
  - action: eject
EOF

### ✅ HandBrake preset
cat <<EOF > /opt/riptide/presets/nvenc_h265_fast.json
{
  "PresetList": [
    {
      "PresetName": "nvenc_h265_fast",
      "PresetDescription": "Fast H.265 encode using NVENC for DVDs",
      "VideoEncoder": "nvenc_h265",
      "VideoQuality": 23,
      "AudioList": [{"AudioEncoder": "copy:ac3"}],
      "Container": "mkv"
    }
  ]
}
EOF

### ✅ Docker Compose
cat <<EOF > /opt/riptide/docker-compose.yml
version: "3.9"
services:
  arm:
    image: automaticrippingmachine/automatic-ripping-machine:latest
    container_name: riptide
    restart: unless-stopped
    privileged: true
    devices:
EOF
for dev in "${DVD_DEVICES[@]}"; do
  echo "      - $dev:$dev" >> /opt/riptide/docker-compose.yml
done
cat <<EOF >> /opt/riptide/docker-compose.yml
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
    volumes:
      - /mnt/ramdisk:/mnt/ramdisk
      - /mnt/nvme_media:/mnt/nvme_media
      - /opt/riptide/arm.yaml:/etc/arm/config/arm.yaml
      - /opt/riptide/presets:/etc/arm/presets
EOF

### ✅ Start RipTide
cd /opt/riptide
docker-compose up -d

echo "\n✅ RipTide is fully installed! Insert 1 or 2 DVDs to begin ripping."
echo "💾 Encoded movies will appear in: /mnt/nvme_media/Movies/"
echo "💡 Plex can now be pointed at that folder. Enjoy!"

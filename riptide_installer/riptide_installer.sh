#!/bin/bash

set -e

# --- Show legal and functionality warning ---
zenity --warning --width=400 --height=150 \
  --title="⚠️ RipTide Warning" \
  --text="⚠️ WARNING\n\nThis script will format the selected media drive.\n\nIt does NOT install Plex — only prepares the folder structure for it.\n\nClick OK to continue or Cancel to abort." \
  || exit 1

# --- Detect system (boot) drive ---
boot_device=$(lsblk -no PKNAME $(df / | tail -1 | awk '{print $1}'))

# --- Get list of all non-boot drives ---
drive_options=$(lsblk -o NAME,RM,SIZE,MODEL -dn | awk -v boot="$boot_device" '$1 != boot { print "/dev/"$1 " (" $3 "B, " $4 ")" }')

if [[ -z "$drive_options" ]]; then
  zenity --error --title="No Eligible Drives Found" --text="No drives available for formatting (excluding system/boot drive).\nPlease connect an external or secondary drive."
  exit 1
fi

# --- Prompt user to select a drive ---
selected=$(echo "$drive_options" | zenity --list \
  --title="Select a Drive to Format" \
  --text="Select the target drive you want to format:\n(System/boot drive is excluded automatically)" \
  --column="Available Drives" \
  --height=300 --width=500)

if [[ -z "$selected" ]]; then
  zenity --info --text="Operation canceled by user."
  exit 1
fi

# --- Extract /dev/sdX from selection string ---
selected_device=$(echo "$selected" | awk '{print $1}')

# --- Final confirmation before wipe ---
zenity --question --title="Final Confirmation" \
  --text="Are you absolutely sure you want to format:\n\n<b>$selected_device</b>\n\nThis action is irreversible." \
  --width=400 --height=200 \
  --ok-label="Wipe it" --cancel-label="Cancel"

if [[ $? -ne 0 ]]; then
  zenity --info --text="Drive wipe canceled."
  exit 1
fi

# --- Wipe, format, and set up media directory (via pkexec for privilege escalation) ---
pkexec bash <<EOF
set -e

# Unmount just in case
umount ${selected_device}* 2>/dev/null || true

# Wipe the drive
dd if=/dev/zero of=$selected_device bs=4M status=progress || exit 1
sync

# Create new GPT partition table
parted -s $selected_device mklabel gpt
parted -s $selected_device mkpart primary ext4 1MiB 100%

# Format to ext4
mkfs.ext4 -F ${selected_device}1

# Create mount point
mkdir -p /mnt/riptide_media

# Mount the drive
mount ${selected_device}1 /mnt/riptide_media

# Create standard Plex directories
mkdir -p /mnt/riptide_media/Movies
mkdir -p /mnt/riptide_media/TV
mkdir -p /mnt/riptide_media/Music
chmod -R 755 /mnt/riptide_media

EOF

zenity --info --title="RipTide Ready" --text="The drive has been wiped, formatted as ext4, mounted at /mnt/riptide_media, and is ready for Plex.\n\nYou may now proceed to install Plex or configure ARM."


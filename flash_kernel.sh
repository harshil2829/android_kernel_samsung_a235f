#!/system/bin/sh
# On-Device Live Kernel Flasher for Samsung Galaxy A23 (SM-A235F)
# Made by @rajput_harshil

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}    Samsung Galaxy A23 (SM-A235F) Kernel Flasher    ${NC}"
echo -e "${YELLOW}           Made by: @rajput_harshil                 ${NC}"
echo -e "${CYAN}====================================================${NC}"

if [ "$(id -u)" != "0" ]; then
  echo -e "${RED}[!] Please run as root (su)${NC}"
  exit 1
fi

BOOT_BLOCK=""
for p in /dev/block/bootdevice/by-name/boot /dev/block/by-name/boot /dev/block/platform/soc/*/by-name/boot; do
  if [ -e "$p" ]; then
    BOOT_BLOCK="$p"
    break
  fi
done

if [ -z "$BOOT_BLOCK" ]; then
  echo -e "${RED}[!] Cannot locate boot partition block device!${NC}"
  exit 1
fi

echo -e "${GREEN}[+] Detected boot partition: ${BOOT_BLOCK}${NC}"

DIR="$(dirname "$0")"
IMG=""
if [ -f "${DIR}/boot.img" ]; then
  IMG="${DIR}/boot.img"
elif [ -f "/sdcard/boot.img" ]; then
  IMG="/sdcard/boot.img"
fi

if [ -n "$IMG" ]; then
  echo -e "[+] Flashing ${IMG} directly to ${BOOT_BLOCK}..."
  dd if="${IMG}" of="${BOOT_BLOCK}" bs=4096
  sync
  echo -e "${GREEN}[✔] Kernel Boot Image flashed successfully!${NC}"
  echo -e "${YELLOW}[!] Reboot your device to activate the new kernel.${NC}"
  exit 0
fi

echo -e "${RED}[!] No boot.img found in script directory or /sdcard/${NC}"
exit 1

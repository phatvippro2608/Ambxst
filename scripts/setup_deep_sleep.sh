#!/usr/bin/env bash
# === Helper script to enable S3 Deep Sleep (mem_sleep_default=deep) ===

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}ℹ  Checking current sleep mode...${NC}"
if grep -q "\[deep\]" /sys/power/mem_sleep 2>/dev/null; then
  echo -e "${GREEN}✔  S3 Deep Sleep is ALREADY active on this system! ([deep])${NC}"
else
  echo -e "${YELLOW}⚠  Current sleep mode is not [deep]. Activating temporarily...${NC}"
  echo deep | sudo tee /sys/power/mem_sleep || true
fi

# Enable in systemd-boot if present
if [[ -d /boot/loader/entries ]]; then
  echo -e "${BLUE}ℹ  Detected systemd-boot. Adding mem_sleep_default=deep to boot entries...${NC}"
  for entry in /boot/loader/entries/*.conf; do
    if [[ -f "$entry" ]] && ! grep -q "mem_sleep_default=deep" "$entry"; then
      sudo sed -i '/^options/ s/$/ mem_sleep_default=deep/' "$entry"
      echo -e "${GREEN}✔  Updated $entry${NC}"
    fi
  done
fi

# Enable in GRUB if present
if [[ -f /etc/default/grub ]]; then
  echo -e "${BLUE}ℹ  Detected GRUB. Adding mem_sleep_default=deep to /etc/default/grub...${NC}"
  if ! grep -q "mem_sleep_default=deep" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mem_sleep_default=deep /' /etc/default/grub
    if command -v update-grub >/dev/null 2>&1; then
      sudo update-grub
    elif command -v grub-mkconfig >/dev/null 2>&1; then
      sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
    echo -e "${GREEN}✔  Updated GRUB configuration!${NC}"
  fi
fi

echo -e "${GREEN}✔  Deep Sleep configuration complete!${NC}"

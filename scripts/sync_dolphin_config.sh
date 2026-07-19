#!/usr/bin/env bash
# === Sync Dolphin, GTK & Printing Configuration for Ambxst ===

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$REPO_DIR/assets/dolphin"

# Styling & MIME Packages
PACMAN_PACKAGES=(
  # Qt6/Dolphin styling
  qt6ct kvantum kvantum-qt5 papirus-icon-theme
  # Dolphin thumbnailers
  ffmpegthumbs kdegraphics-thumbnailers kimageformats kdesdk-thumbnailers
  # Desktop portal & MIME
  kio-fuse xdg-desktop-portal-gtk xdg-utils
  # Printer utility drivers & cups
  cups cups-filters cups-pdf foomatic-db-engine hplip libcups libcupsfilters libppd system-config-printer
  # Screen sleep manager
  hypridle
)

AUR_PACKAGES=(
  wps-office-mime-cn
)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ  $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✔  $1${NC}" >&2; }
log_warn() { echo -e "${YELLOW}⚠  $1${NC}" >&2; }
log_error() { echo -e "${RED}✖  $1${NC}" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

backup() {
  log_info "Backing up local configuration files to $ASSETS_DIR..."
  mkdir -p "$ASSETS_DIR"
  
  cp_if_exists() {
    if [[ -f "$1" ]]; then
      cp "$1" "$2"
      log_success "Backed up $(basename "$1")"
    else
      log_warn "File not found: $1"
    fi
  }

  cp_if_exists "$HOME/.config/dolphinrc" "$ASSETS_DIR/dolphinrc"
  cp_if_exists "$HOME/.config/kdeglobals" "$ASSETS_DIR/kdeglobals"
  cp_if_exists "$HOME/.config/qt6ct/qt6ct.conf" "$ASSETS_DIR/qt6ct.conf"
  cp_if_exists "$HOME/.config/Kvantum/kvantum.kvconfig" "$ASSETS_DIR/kvantum.kvconfig"
  cp_if_exists "$HOME/.config/mimeapps.list" "$ASSETS_DIR/mimeapps.list"
  cp_if_exists "$HOME/.config/gtk-3.0/settings.ini" "$ASSETS_DIR/gtk3_settings.ini"
  cp_if_exists "$HOME/.config/gtk-4.0/settings.ini" "$ASSETS_DIR/gtk4_settings.ini"
  cp_if_exists "$HOME/.config/hypr/hypridle.conf" "$ASSETS_DIR/hypridle.conf"
  
  # Backup CUPS printers config and PPDs (requires sudo)
  log_info "Backing up CUPS printers configurations (requires sudo)..."
  if [[ -f /etc/cups/printers.conf ]]; then
    sudo cp /etc/cups/printers.conf "$ASSETS_DIR/printers.conf"
    sudo chown "$USER:$USER" "$ASSETS_DIR/printers.conf"
    log_success "Backed up printers.conf"
  fi
  if [[ -d /etc/cups/ppd ]]; then
    rm -rf "$ASSETS_DIR/ppd"
    sudo cp -r /etc/cups/ppd "$ASSETS_DIR/ppd"
    sudo chown -R "$USER:$USER" "$ASSETS_DIR/ppd"
    log_success "Backed up PPD driver files"
  fi
  
  log_success "Backup completed successfully!"
}

restore() {
  log_info "Installing required packages..."
  
  # Install pacman packages
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
  
  # Install AUR packages
  if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
    AUR_HELPER=""
    if has_cmd yay; then
      AUR_HELPER="yay"
    elif has_cmd paru; then
      AUR_HELPER="paru"
    fi
    
    if [[ -n "$AUR_HELPER" ]]; then
      log_info "Installing AUR packages using $AUR_HELPER..."
      $AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}"
    else
      log_warn "No AUR helper (yay/paru) found. Please install manually: ${AUR_PACKAGES[*]}"
    fi
  fi
  
  log_info "Restoring configuration files..."
  mkdir -p "$HOME/.config" "$HOME/.config/qt6ct" "$HOME/.config/Kvantum" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/hypr"
  
  cp_file() {
    if [[ -f "$1" ]]; then
      cp "$1" "$2"
      log_success "Restored $(basename "$2")"
    else
      log_error "Config source missing: $1"
    fi
  }

  cp_file "$ASSETS_DIR/dolphinrc" "$HOME/.config/dolphinrc"
  cp_file "$ASSETS_DIR/kdeglobals" "$HOME/.config/kdeglobals"
  cp_file "$ASSETS_DIR/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
  cp_file "$ASSETS_DIR/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"
  cp_file "$ASSETS_DIR/mimeapps.list" "$HOME/.config/mimeapps.list"
  cp_file "$ASSETS_DIR/gtk3_settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
  cp_file "$ASSETS_DIR/gtk4_settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
  cp_file "$ASSETS_DIR/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
  
  # Restore CUPS printers config and PPDs (requires sudo)
  log_info "Restoring CUPS printers configurations (requires sudo)..."
  if [[ -f "$ASSETS_DIR/printers.conf" ]]; then
    sudo cp "$ASSETS_DIR/printers.conf" /etc/cups/printers.conf
    sudo chown root:cups /etc/cups/printers.conf
    sudo chmod 600 /etc/cups/printers.conf
    log_success "Restored printers.conf"
  fi
  if [[ -d "$ASSETS_DIR/ppd" ]]; then
    sudo cp -r "$ASSETS_DIR/ppd" /etc/cups/
    sudo chown -R root:cups /etc/cups/ppd
    sudo chmod 755 /etc/cups/ppd
    sudo chmod 644 /etc/cups/ppd/* 2>/dev/null || true
    log_success "Restored PPD driver files"
  fi
  log_info "Restarting CUPS service to apply changes..."
  sudo systemctl restart cups || sudo systemctl restart org.cups.cupsd || true

  log_info "Updating system caches..."
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
  gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  sudo update-mime-database /usr/share/mime 2>/dev/null || true
  sudo gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark 2>/dev/null || true
  
  log_success "Restore completed successfully! Please restart Dolphin."
}

case "$1" in
  backup)
    backup
    ;;
  restore)
    restore
    ;;
  *)
    echo "Usage: $0 {backup|restore}"
    exit 1
    ;;
esac

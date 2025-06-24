#!/usr/bin/env bash

# postinstall_nixos_hyprland.sh
# Interactive post-installation setup for NixOS desktop with Hyprland.

set -euo pipefail

GREEN="[1;32m"
RED="[1;31m"
YELLOW="[1;33m"
BLUE="[1;34m"
RESET="[0m"

ask() {
  local prompt="$1" default=${2:-Y} reply
  while true; do
    if [[ $default == Y ]]; then
      read -rp "$prompt [Y/n]: " reply
      reply=${reply:-Y}
    else
      read -rp "$prompt [y/N]: " reply
      reply=${reply:-N}
    fi
    case "$reply" in
      [Yy]*) return 0;;
      [Nn]*) return 1;;
      *) echo "Please answer yes or no.";;
    esac
  done
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run this script as root.${RESET}"
    exit 1
  fi
}

check_nixos() {
  if [[ ! -f /etc/os-release ]] || ! grep -q '^ID=nixos' /etc/os-release; then
    echo -e "${RED}This script must run on NixOS.${RESET}"
    exit 1
  fi
}

prompt_username() {
  while true; do
    read -rp "Enter your main (non-root) username: " USERNAME
    if id "$USERNAME" &>/dev/null; then
      break
    else
      echo -e "${RED}User '$USERNAME' not found.${RESET}"
    fi
  done
}

install_home_manager() {
  if command -v home-manager &>/dev/null; then
    echo -e "${GREEN}Home Manager already installed.${RESET}"
    return
  fi
  if ask "Home Manager not found. Install it?" Y; then
    echo -e "${BLUE}Installing Home Manager...${RESET}"
    if ! nix-channel --list | grep -q home-manager; then
      nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
      nix-channel --update
    fi
    nix-shell '<home-manager>' -A install
  fi
}

prompt_dotfiles() {
  read -rp "Enter URL or path to your dotfiles repo: " DOTFILES_REPO
  local target="/home/$USERNAME/dotfiles"
  if [[ -e $target ]]; then
    if ask "$target exists. Remove and re-clone?" N; then
      rm -rf "$target"
    else
      return
    fi
  fi
  sudo -u "$USERNAME" git clone "$DOTFILES_REPO" "$target"
}

link_configs() {
  local df="/home/$USERNAME/dotfiles"
  local cfg="/home/$USERNAME/.config"
  declare -A paths=([Hyprland]=hypr [Waybar]=waybar [Fish]=fish [Fuzzel]=fuzzel [Scripts]=scripts)
  for app in "${!paths[@]}"; do
    local src="$df/${paths[$app]}" dest="$cfg/${paths[$app]}"
    [[ -e $src ]] || continue
    if ask "Install $app config from $src to $dest?" Y; then
      mkdir -p "$(dirname "$dest")"
      if ask "Symlink instead of copy?" Y; then
        ln -sfn "$src" "$dest"
      else
        rm -rf "$dest"
        cp -r "$src" "$dest"
      fi
    fi
  done
}

choose_install_method() {
  if ask "Manage packages with Home Manager? (otherwise system configuration)" Y; then
    INSTALL_METHOD=home
  else
    INSTALL_METHOD=system
  fi
}

append_system_config() {
  local conf=/etc/nixos/configuration.nix
  local bak=/etc/nixos/configuration.nix.bak.$(date +%s)
  cp "$conf" "$bak"
  echo -e "${BLUE}Backup saved to $bak${RESET}"
  if ! grep -q hyprland "$conf"; then
    cat >> "$conf" <<'CFG'

# Added by postinstall_nixos_hyprland.sh
{ pkgs, ... }:
{
  programs.hyprland.enable = true;
  programs.waybar.enable = true;
  programs.fuzzel.enable = true;
  programs.fish.enable = true;
  environment.systemPackages = with pkgs; [ matugen ollama foot kitty ];
  services.ollama.enable = true;
}
CFG
  fi
  nixos-rebuild switch
}

append_home_config() {
  local hm=/home/$USERNAME/.config/home-manager/home.nix
  local dir="$(dirname "$hm")"
  mkdir -p "$dir"
  local group="$(id -gn "$USERNAME" 2>/dev/null || true)"
  if [[ -n $group ]]; then
    chown -R "$USERNAME":"$group" "$dir"
  else
    chown -R "$USERNAME" "$dir"
  fi
  if [[ -f $hm ]]; then
    cp "$hm" "$hm.bak.$(date +%s)"
  fi
  sudo -u "$USERNAME" bash -c "cat >> '$hm'" <<'HMCFG'

# Added by postinstall_nixos_hyprland.sh
{ pkgs, ... }:
{
  programs.hyprland.enable = true;
  programs.waybar.enable = true;
  programs.fuzzel.enable = true;
  programs.fish.enable = true;
  home.packages = with pkgs; [ matugen ollama foot kitty ];
  services.ollama.enable = true;
}
HMCFG
  sudo -u "$USERNAME" home-manager switch
}

setup_ollama() {
  systemctl enable --now ollama.service
  if ask "Preload Ollama models?" N; then
    read -rp "Model names (space-separated): " models
    for m in $models; do
      sudo -u "$USERNAME" ollama pull "$m"
    done
  fi
}

set_fish_default() {
  if ask "Set fish as default shell for $USERNAME?" Y; then
    local fish_path=$(command -v fish)
    if ! grep -q "$fish_path" /etc/shells; then
      echo "$fish_path" >> /etc/shells
    fi
    chsh -s "$fish_path" "$USERNAME"
  fi
}

auto_mount_drives() {
  echo -e "${BLUE}Available block devices:${RESET}"
  lsblk -o NAME,MOUNTPOINT,SIZE,TYPE | grep -E '^sd|^nvme'
  read -rp "Enter device names to auto-mount (space-separated, blank to skip): " devs
  [[ -z $devs ]] && return
  local conf=/etc/nixos/configuration.nix
  for d in $devs; do
    local mp="/mnt/$d"
    mkdir -p "$mp"
    cat >> "$conf" <<EOF
fileSystems."$mp" = {
  device = "/dev/$d";
  fsType = "auto";
};
EOF
  done
}

final_prompt() {
  if ask "Reboot now?" N; then
    reboot
  else
    echo -e "${GREEN}Setup finished. Reboot when convenient.${RESET}"
  fi
}

main() {
  require_root
  check_nixos
  prompt_username
  install_home_manager
  prompt_dotfiles
  link_configs
  choose_install_method
  if [[ $INSTALL_METHOD == home ]]; then
    append_home_config
  else
    append_system_config
  fi
  setup_ollama
  set_fish_default
  auto_mount_drives
  final_prompt
}

main "$@"

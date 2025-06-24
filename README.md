# NixOS Hyprland Post-Install Script

This repository contains a single Bash script `postinstall_nixos_hyprland.sh` to help set up a Hyprland-based desktop on a freshly installed NixOS system.

## Features
- Verifies the script is run on NixOS as root
- Prompts for the main user account
- Optional installation of Home Manager
- Clones your dotfiles repository
- Offers to link or copy configs for Hyprland, Waybar, Fish, Fuzzel and custom scripts
- Installs and enables Hyprland, Waybar, Fuzzel, Matugen, Ollama, Fish shell and common terminals
- Lets you choose between editing system configuration or using Home Manager
- Sets up and optionally preloads Ollama models
- Sets Fish as the default shell
- Detects additional drives and optionally adds them to configuration
- Prompts to reboot when finished

## Usage
1. **Clone this repo** or copy the script onto your new NixOS install.
2. Run the script as root:
   ```bash
   sudo ./postinstall_nixos_hyprland.sh
   ```
3. Follow the interactive prompts. Have your dotfiles repository URL handy.

### Dotfiles Layout Example
Your dotfiles repo should contain subdirectories like:
```
hypr/
waybar/
fish/
fuzzel/
scripts/
```
These will be linked or copied into `~/.config`.

## Troubleshooting
- Ensure you have network connectivity for cloning repos and installing packages.
- If `home-manager` commands fail, check that the channel was added correctly.
- Edit `/etc/nixos/configuration.nix` or your `home.nix` manually if needed and rerun `nixos-rebuild switch` or `home-manager switch`.

## After Reboot
- Log in and start Hyprland with `Hyprland` or via your display manager.
- Waybar and Fuzzel should be available with your configurations.
- Verify Ollama with `ollama list` and run models as desired.


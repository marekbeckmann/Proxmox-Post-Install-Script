# Proxmox-Post-Install-Script

This script is designed to be run after a fresh install of Proxmox VE. It will install a number of packages and configure a number of settings to make the system more secure and usable.

## Installation

## Quick run (default settings)

```bash
wget -qLO https://raw.githubusercontent.com/marekbeckmann/Proxmox-Post-Install-Script/main/config.ini && \
bash -c "$(wget -qLO - https://raw.githubusercontent.com/marekbeckmann/Proxmox-Post-Install-Script/main/post-install.sh)"
```

## Run with custom settings

```bash
wget -qLO https://raw.githubusercontent.com/marekbeckmann/Proxmox-Post-Install-Script/main/config.ini && \
wget -qLO https://raw.githubusercontent.com/marekbeckmann/Proxmox-Post-Install-Script/main/settings.ini && \
wget -qLO https://raw.githubusercontent.com/marekbeckmann/Proxmox-Post-Install-Script/main/post-install.sh
```

Edit `settings.ini` and change the settings to your liking. After that, run the script with the following command:

```bash
bash post-install.sh -s settings.ini
```


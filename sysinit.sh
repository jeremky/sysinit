#!/bin/bash

# Catch failures anywhere in a pipe (e.g. curl | sh)
set -o pipefail

# Colored messages
error() { echo -e "\033[0;31m❯ $*\033[0m"; }
message() { echo -e "\033[0;36m──────────\033[0m\n\033[0;32m❯ $*\033[0m"; }
warning() { echo -e "\033[0;33m❯ $*\033[0m\n\033[0;36m──────────\033[0m"; }

# Helpers
read_list() { grep -v -e '#' -e '^\s*$' "$1"; }

require_distro() {
  local d
  for d in "$@"; do
    [[ "$distro" == "$d" ]] && return 0
  done
  error "${FUNCNAME[1]} is only available on: $*"
  return 1
}

detect_distro() {
  [[ -f /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID" in
    debian | ubuntu) echo debian ;;
    fedora | solus | steamos) echo "$ID" ;;
    *) [[ " $ID_LIKE " == *" debian "* ]] && echo debian ;;
  esac
}

pkg_update() {
  case "$distro" in
    debian) sudo apt update && sudo apt -y full-upgrade ;;
    fedora) sudo dnf -y upgrade ;;
    solus) sudo eopkg -y upgrade ;;
    *)
      error "No package manager available on $distro"
      return 1
      ;;
  esac
}

pkg_install() {
  [[ $# -eq 0 ]] && return 0
  case "$distro" in
    debian) sudo apt -y install "$@" ;;
    fedora) sudo dnf -y install "$@" ;;
    solus) sudo eopkg -y install "$@" ;;
    *)
      error "No package manager available on $distro"
      return 1
      ;;
  esac
}

# Functions
install_packages() {
  warning "Updating packages"
  pkg_update || {
    error "Error while updating packages"
    return 1
  }
  echo
  if [[ -f "$list" ]]; then
    warning "Installing packages"
    local pkgs
    mapfile -t pkgs < <(read_list "$list")
    pkg_install "${pkgs[@]}" || {
      error "Error while installing packages"
      return 1
    }
    message "Package installation complete"
    echo
  fi
}

enable_flathub() {
  if [[ "$distro" == debian ]]; then
    pkg_install flatpak gnome-software gnome-software-plugin-flatpak || return 1
  elif ! command -v flatpak >/dev/null; then
    pkg_install flatpak || return 1
  fi
  warning "Enabling Flathub"
  sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || {
    error "Error while enabling Flathub"
    return 1
  }
  message "Flathub enabled"
  echo
}

install_flatpaks() {
  if [[ -f "$apps" ]]; then
    warning "Installing flatpaks"
    local pkgs
    mapfile -t pkgs < <(read_list "$apps")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    sudo flatpak install -y --system flathub "${pkgs[@]}" || {
      error "Error while installing flatpaks"
      return 1
    }
    message "Flatpak installation complete"
    echo
  fi
}

install_npm() {
  if [[ -f "$nodenpm" ]]; then
    warning "Installing npm packages"
    pkg_install nodejs || {
      error "Error while installing nodejs"
      return 1
    }
    local pkgs
    mapfile -t pkgs < <(read_list "$nodenpm")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    sudo npm -g install "${pkgs[@]}" || {
      error "Error while installing npm packages"
      return 1
    }
    message "npm package installation complete"
    echo
  fi
}

install_herdr() {
  warning "Installing herdr"
  curl -fsSL https://herdr.dev/install.sh | sh || {
    error "Error while installing herdr"
    return 1
  }
  message "herdr installation complete"
  echo
}

install_claude() {
  warning "Installing claude"
  curl -fsSL https://claude.ai/install.sh | bash || {
    error "Error while installing claude"
    return 1
  }
  message "claude installation complete"
  echo
}

install_hytale() {
  warning "Installing Hytale"
  local file=/tmp/hytale-launcher-latest.flatpak
  wget -O "$file" https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak || {
    error "Error while downloading Hytale"
    return 1
  }
  sudo flatpak install -y --system "$file" || {
    error "Error while installing Hytale"
    return 1
  }
  message "Hytale installation complete"
  echo
}

init_passwd() {
  require_distro steamos || return 1
  warning "Changing password for $USER"
  passwd || {
    error "Error while changing password"
    exit 1
  }
  message "Password changed"
  echo
}

enable_unattended() {
  require_distro debian || return 1
  pkg_install unattended-upgrades || {
    error "Error while installing unattended-upgrades"
    return 1
  }
  warning "Enabling unattended upgrades"
  local file=/etc/apt/apt.conf.d/20auto-upgrades
  printf '%s\n' \
    'APT::Periodic::Update-Package-Lists "1";' \
    'APT::Periodic::Unattended-Upgrade "1";' | sudo tee "$file" || {
    error "Failed to write $file"
    return 1
  }
  message "Unattended upgrades enabled"
  echo
}

disable_sudofile() {
  require_distro debian || return 1
  warning "Disabling the .sudo_as_admin_successful file"
  local file=/etc/sudoers.d/010_sudofile
  echo "Defaults !admin_flag" | sudo tee "$file" || {
    error "Failed to write $file"
    return 1
  }
  sudo chmod 440 "$file" || {
    error "Failed to chmod $file"
    return 1
  }
  message ".sudo_as_admin_successful file disabled"
  echo
}

configure_ufw() {
  require_distro debian || return 1
  pkg_install ufw || return 1
  warning "Enabling ufw firewall"
  sudo ufw allow from 192.168.1.0/24
  sudo ufw allow 22/tcp
  sudo ufw --force enable
  message "ufw enabled"
  echo
}

configure_sshd() {
  if [[ ! -d /etc/ssh/sshd_config.d ]]; then
    error "SSH is not installed"
    return 1
  fi
  warning "Securing SSH"
  local conf="/etc/ssh/sshd_config.d/$USER.conf"
  sudo tee "$conf" <<EOF
# Secure Config
X11Forwarding no
AllowUsers $USER
HostKey /etc/ssh/ssh_host_ed25519_key
PasswordAuthentication yes
KbdInteractiveAuthentication no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com
HostKeyAlgorithms ssh-ed25519
EOF
  systemctl is-enabled -q sshd || sudo systemctl enable sshd || {
    error "Error while enabling SSH"
    exit 1
  }
  sudo systemctl restart sshd || {
    error "Error while restarting SSH"
    exit 1
  }
  message "SSH secured. Edit $conf to disable password login after importing your ed25519 key"
  echo
}

# Distro detection
distro=$(detect_distro)
if [[ -z "$distro" ]]; then
  error "Unsupported distribution (supported: debian, fedora, solus, steamos)"
  exit 1
fi
func="$1"

# Config files
dir="$(dirname "$0")/config/$distro"
cfg="$dir/config.cfg"
list="$dir/packages.cfg"
apps="$dir/flatpaks.cfg"
nodenpm="$dir/npm.cfg"

if [[ ! -f "$cfg" ]]; then
  error "File $cfg not found"
  exit 1
fi

if [[ -n "$func" ]] && ! declare -f "$func" >/dev/null; then
  error "Function $func not found"
  exit 1
fi

# Privileges
if [[ "$EUID" -eq 0 ]]; then
  error "Run this script as a regular user (without sudo)"
  exit 1
fi
if [[ "$distro" != steamos ]]; then
  sudo -v || {
    error "sudo privileges required"
    exit 1
  }
fi

# Execution
if [[ -n "$func" ]]; then
  "$func"
  exit $?
fi

while read -r line <&3; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  if declare -f "$line" >/dev/null; then
    "$line"
  else
    error "No function matches parameter $line"
    exit 1
  fi
done 3<"$cfg"

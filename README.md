# sysinit

A single script that automates installing and configuring Debian/Ubuntu, Fedora,
Solus and SteamOS. It replaces `aptinit`, `dnfinit`, `solusinit` and `steaminit`.

The distribution is detected from `/etc/os-release` (any `ID_LIKE=debian` is
treated as `debian`). Its configuration is loaded from `config/<distro>/`.

## Features

| Function             | Description                                               | Distros               |
| -------------------- | --------------------------------------------------------- | --------------------- |
| `install_packages`   | updates the system and installs `packages.cfg`            | debian, fedora, solus |
| `enable_flathub`     | installs flatpak if needed and adds Flathub               | all                   |
| `install_flatpaks`   | installs the apps listed in `flatpaks.cfg`                | all                   |
| `install_npm`        | installs Node.js and the global npm packages in `npm.cfg` | debian, fedora, solus |
| `install_herdr`      | installs the herdr multiplexer for the current user       | all                   |
| `install_claude`     | installs Claude Code for the current user                 | all                   |
| `install_hytale`     | downloads and installs the Hytale flatpak                 | all                   |
| `init_passwd`        | changes the password of the current user                  | steamos               |
| `enable_unattended`  | enables unattended upgrades                               | debian                |
| `disable_sudofile`   | stops creating `~/.sudo_as_admin_successful`              | debian                |
| `configure_ufw`      | installs and enables the ufw firewall                     | debian                |
| `configure_sshd`     | hardens the OpenSSH server                                | all                   |

> [!IMPORTANT]
> `configure_sshd` writes its config to `/etc/ssh/sshd_config.d/<user>.conf`.
> Password login stays enabled so you can't get locked out: disable it once
> your ed25519 key is imported.
>
> On SteamOS, keep `init_passwd` first in `config.cfg`: the `deck` user has no
> password until it runs, so `sudo` can't be used before that.
>
> `install_npm` installs packages globally (`npm -g`). Run `sudo npm -g update`
> to update them.

## Configuration

Each distro has its own folder in `config/`:

```txt
config/
├── debian/   config.cfg packages.cfg
├── fedora/   config.cfg packages.cfg
├── solus/    config.cfg packages.cfg flatpaks.cfg npm.cfg
└── steamos/  config.cfg flatpaks.cfg
```

`config.cfg` lists the functions to run, in order. Comment out the ones you
don't want to use.

## Usage

Run the script as a regular user. It calls `sudo` when it needs to:

```bash
./sysinit.sh                      # runs config/<distro>/config.cfg
./sysinit.sh configure_sshd       # runs a single function
```

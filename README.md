# BedrockServerTermux

A management system for running a Minecraft Bedrock Dedicated Server on Android via Termux. The server runs inside a Debian proot environment, using box64 to execute the x86_64 server binary on ARM devices.

## Requirements

- [Termux](https://termux.dev) (F-Droid build recommended)

## Installation

**1. Set up the Debian proot environment (run in Termux):**

```bash
curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh | bash
```

Alternatively, download and run separately:

```bash
wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh
bash setup_proot.sh
```

This installs `proot-distro`, installs Debian, and creates a `pdd` command for entering the environment.

Optionally, create a symlink to access the Debian filesystem directly from Termux:

```bash
ln -s $PREFIX/var/lib/proot-distro/containers/debian/rootfs ~/debian
```

**2. Enter Debian and run the setup script:**

```bash
pdd
curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh | bash
```

Alternatively, download and run separately:

```bash
pdd
wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh
bash setup.sh
```

This installs dependencies (`box64`, `jq`, `unzip`, etc.), downloads the manager, and creates the `bds` command.

## Usage

Enter the proot environment and launch the manager:

```bash
pdd
bds
```

This presents the following menu:

```
1) Run server
2) Install / Update server
3) Backup server
4) Rename server
5) Delete server
0) Exit
```

### Initial setup

1. From the menu, select **2) Install / Update server**
2. Select a version (Latest Stable, Latest Preview/Beta, or a specific version number)
3. Select or create a target folder
4. Wait for the download and extraction to complete
5. From the menu, select **1) Run server** and choose the installed server

### Backups

**3) Backup server** supports three backup types:
- Full server
- World data only
- Server configuration only (`server.properties`, `permissions.json`, `allowlist.json`, `valid_known_packs.json`)

Backups are saved to `~/Bedrock Server/Backups/<server_name>/` as `.tar.gz` archives.

Installing or updating a server automatically backs up the existing `worlds/` directory before files are overwritten.

## File structure

```
Bedrock Server/
├── manage.sh
├── menu/
│   ├── install.sh
│   ├── run.sh
│   ├── backup.sh
│   ├── rename.sh
│   └── delete.sh
├── Data/
│   └── <server_name>/
│       ├── bedrock_server
│       ├── version.txt
│       ├── server.properties
│       └── worlds/
└── Backups/
    └── <server_name>/
        └── <server_name>_<type>_<timestamp>.tar.gz
```

## Notes

- All commands (`bds`, install, run, etc.) must be executed as root within the Debian proot.
- Multiple servers may be installed concurrently in separate folders under `Data/`.
- To stop a running server, press `Ctrl+C`. Unexpected crashes trigger an automatic restart after five seconds.

## License

MIT

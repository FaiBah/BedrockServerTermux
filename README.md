# BedrockServerTermux

A management system for running a Minecraft Bedrock Dedicated Server on Android via Termux. The server runs inside a Debian proot environment, using box64 to execute the x86_64 server binary on ARM devices.

## Requirements

- Termux (F-Droid build recommended)

## Installation

1. Set up the Debian proot environment (run in Termux):

curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh | bash

Alternatively, download and run separately:

wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh
bash setup_proot.sh

This installs proot-distro, installs Debian, and creates a pdd command for entering the environment.

Optionally, create a symlink to access the Debian filesystem directly from Termux:

ln -s $PREFIX/var/lib/proot-distro/containers/debian/rootfs ~/debian

2. Enter Debian and run the setup script:

pdd
curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh | bash

Alternatively, download and run separately:

pdd
wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh
bash setup.sh

This installs dependencies (box64, jq, unzip, etc.), downloads the manager, and creates the bds command.

## Usage

Enter the proot environment and launch the manager:

pdd
bds

This presents the following menu:

1) Run server
2) Install / Update server
3) Backup server
4) Rename server
5) Delete server
6) Update manager
0) Exit

## File structure

Bedrock Server/
├── manage.sh
├── menu/
│   ├── [*].sh
├── Servers/
│   └── <server_name>/
│       ├── bedrock_server
│       ├── version.txt
│       ├── server.properties
│       └── worlds/
└── Backups/
    └── <server_name>/
        └── <server_name>_<type>_<timestamp>.tar.gz

## Notes

- All commands (bds, install, run, etc.) must be executed as root within the Debian proot.
- Multiple servers may be installed concurrently in separate folders under Servers/.
- To stop a running server, press Ctrl+C.
- Unexpected server crashes trigger an automatic restart after five seconds.

## License

MIT

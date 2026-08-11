# BedrockServerTermux

> Run a **Minecraft Bedrock Dedicated Server** on Android via **Termux** — inside a Debian proot, powered by **box64** to run the x86_64 server binary on ARM.

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Termux](https://img.shields.io/badge/Termux-required-000000?logo=gnu-bash&logoColor=white)
![Debian](https://img.shields.io/badge/env-Debian%20proot-A81D33?logo=debian&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 📋 Requirements

- 📱 [Termux](https://termux.dev) (F-Droid build recommended)

---

## ⚙️ Installation

### 1️⃣ Set up the Debian proot environment (in Termux)

```bash
curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh | bash
```

<details>
<summary>Or download and run separately</summary>

```bash
wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_proot.sh
bash setup_proot.sh
```
</details>

This installs `proot-distro`, installs Debian, and creates a **`pdd`** command to enter the environment.

💡 Optional — symlink the project folder for easy access from Termux:

```bash
ln -s $PREFIX/var/lib/proot-distro/containers/debian/rootfs/root/BedrockServerTermux ~/BedrockServerTermux
```

### 2️⃣ Enter Debian and run the setup script

```bash
pdd
curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh | bash
```

<details>
<summary>Or download and run separately</summary>

```bash
pdd
wget https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh
bash setup.sh
```
</details>

This installs dependencies (`box64`, `jq`, `unzip`, etc.), downloads the manager, and creates the **`bds`** command.

---

## 🚀 Usage

```bash
pdd
bds
```

```
1) Run server
2) Install / Update server
3) Backup server
4) Rename server
5) Delete server
6) Update manager
0) Exit
```

---

## 🗂️ File Structure

```
BedrockServerTermux/
├── manage.sh
├── menu/
│   └── [*].sh
├── Servers/
│   └── <server_name>/
│       ├── bedrock_server
│       ├── version.txt
│       ├── server.properties
│       └── worlds/
└── Backups/
    └── <server_name>/
        └── <server_name>_<type>_<timestamp>.tar.gz
```

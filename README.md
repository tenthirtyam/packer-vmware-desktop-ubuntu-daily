<!--
SPDX-License-Identifier: MIT
SPDX-FileCopyrightText: Ryan Johnson
-->

# Ubuntu Server Daily Build for VMware Desktop Hypervisors

Automated Ubuntu Server virtual machine builder using Packer and VMware Fusion/Workstation. This
project creates baseline Ubuntu Server virtual machines from the latest daily builds with automated
provisioning using `cloud-init`.

## Features

- **Latest Ubuntu Server**: Uses daily builds from Ubuntu's official repository.
- **Automated Setup**: Fully automated virtual machine creation with `cloud-init`.
- **Cross-Platform**: Supports both VMware Fusion (macOS) and VMware Workstation (Windows/Linux).
- **Architecture Support**: Works with both AMD64 and ARM64 architectures.
- **Secure Random Passwords**: Cryptographically secure password generation.
- **Override Support**: Customize virtual machine settings without modifying core files.
- **Force Build**: Automatically overwrites an existing build with a clean build.

## Prerequisites

### Required Software

- [Packer](https://www.packer.io/) (>= 1.0)
- [VMware Fusion 26H1](https://www.vmware.com/products/fusion.html) (macOS) or [VMware Workstation 26H1](https://www.vmware.com/products/workstation-pro.html) (Windows/Linux) or later
- `curl`: Downloading ISO files.
- `openssl`: Password encryption.

### Optional Software

- [Task](https://taskfile.dev/): Alternative to Make for running project tasks.
- [Prettier](https://prettier.io/): Formatting JSON, Markdown, and YAML.
- [ShellCheck](https://www.shellcheck.net/): Linting the build script (`make lint`).

## Project Layout

```text
├── Makefile / Taskfile.yml   # format, validate, build, clean
├── iso/                      # downloaded ISOs (gitignored)
├── output/                   # built VMs (gitignored)
└── src/
    ├── ubuntu-daily.pkr.hcl
    ├── ubuntu-daily.sh
    ├── overrides.pkrvars.hcl.example
    ├── reference/            # locale, keyboard, timezone data
    └── data/                 # cloud-init seed files
```

## Quick Start

1. **Clone the repository** — clone the repository and change into the project directory.

   ```bash
   git clone https://github.com/tenthirtyam/packer-vmware-desktop-ubuntu-daily
   cd packer-vmware-desktop-ubuntu-daily
   ```

2. **Run the build** — start a build with Make, Task, or the shell script directly.

   ```bash
   make build
   # or: task build
   # or: ./src/ubuntu-daily.sh
   ```

3. **Wait for completion** — the build runs unattended. See [Build Process](#build-process) for details.

## Configuration

### Default Settings

| Setting         | Value                                                   |
| --------------- | ------------------------------------------------------- |
| Virtual machine | `ubuntu-YYYYMMDD-{arch}` (e.g. `ubuntu-20260101-arm64`) |
| Username        | `ubuntu`                                                |
| Password        | Cryptographically secure random (12 characters)         |
| Memory          | 4 GB                                                    |
| Disk            | 20 GB                                                   |
| CPUs            | 2 cores                                                 |
| Locale          | `en_US.UTF-8`                                           |
| Keyboard layout | `us`                                                    |
| Timezone        | `UTC`                                                   |

### Development Tasks

| Description                          | Make                | Task                |
| ------------------------------------ | ------------------- | ------------------- |
| Format files                         | `make format`       | `task format`       |
| Check formatting                     | `make format-check` | `task format-check` |
| Lint the build script                | `make lint`         | `task lint`         |
| Initialize Packer plugins            | `make init`         | `task init`         |
| Validate the configuration           | `make validate`     | `task validate`     |
| Build the virtual machine image      | `make build`        | `task build`        |
| Remove output and build from scratch | `make rebuild`      | `task rebuild`      |
| Remove built virtual machine output  | `make clean`        | `task clean`        |
| Remove downloaded ISO files          | `make clean-iso`    | `task clean-iso`    |
| List all targets                     | `make help`         | `task`              |

`format` and `fmt` are aliases in both Make and Task.

Pass build arguments with `make build ARGS="--password=foo"`, `make rebuild ARGS="--password=foo"`,
or `task build -- --password=foo` / `task rebuild -- --password=foo`.

### Customization Options

#### Password Security

- **Auto-generated**: A cryptographically secure 12-character password is generated using OpenSSL when `--password` is not provided.
- **Custom passwords**: Pass `--password=your_password` to the build script, or use `ARGS` / `task build --` as shown above.

#### ISO Source

By default, the build script discovers the newest Ubuntu Server `daily-live/current` repository
automatically. To pin a specific release track, set `ISO_BASE_URL` before building:

```bash
ISO_BASE_URL="https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current" make build
```

#### Fixed Directories

- ISO files: `./iso/` (created automatically)
- Virtual machine output: `./output/` (created automatically)

#### Override Configuration

Create a `src/overrides.pkrvars.hcl` file to customize settings without modifying the main configuration:

```bash
# Copy the example file.
cp src/overrides.pkrvars.hcl.example src/overrides.pkrvars.hcl

# Edit with your preferred settings.
vi src/overrides.pkrvars.hcl
```

#### Common Override Examples

```hcl
# Hardware Settings
vm_cpu = 4
vm_memory = 12288
vm_disk_size = 102400

# Locale & Timezone Settings
locale = "en_GB"
keyboard_layout = "uk"
timezone = "Europe/London"

# Extended Timeout Settings
ssh_timeout = "30m"
shutdown_timeout = "20m"
```

The build script automatically detects and uses `src/overrides.pkrvars.hcl` if present.

## Build Process

The build process follows these steps:

1. **Validation**: The script checks for required tools and dependencies.
2. **Password Generation**: A cryptographically secure random password is created.
3. **ISO Download**: The latest Ubuntu Server daily ISO is downloaded.
4. **Checksum Verification**: The integrity of the Ubuntu Server ISO is validated.
5. **Packer Initialization**: The Packer plugins are initialized.
6. **Configuration Validation**: The Packer configuration is validated.
7. **Virtual Machine Creation**: The virtual machine is created and configured.
8. **Guest OS Installation**: The Ubuntu Server guest operating system is installed automatically using `cloud-init`.
9. **Post-Processing**: A snapshot is created and temporary files are cleaned up.

## Output

After successful completion, you'll find the virtual machine in `output/`.

## Sponsor

[![Sponsor](https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)][sponsor]&nbsp;&nbsp;
[![Buy me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=white)][buy-me-a-coffee]

## License

Copyright &copy; Ryan Johnson

Licensed under the [MIT License][license].

[license]: LICENSE
[sponsor]: https://github.com/sponsors/tenthirtyam
[buy-me-a-coffee]: https://buymeacoffee.com/tenthirtyam

<!--
SPDX-License-Identifier: MIT
SPDX-FileCopyrightText: 2025-2026 Ryan Johnson
-->

# Ubuntu Server Daily Build for VMware Desktop Hypervisors

Automated Ubuntu Server virtual machine builder using Packer and VMware Fusion/Workstation. This project creates baseline Ubuntu Server virtual machines from the latest daily builds with automated provisioning using `cloud-init`.

## Features

- **Latest Ubuntu Server**: Uses daily builds from Ubuntu's official repository.
- **Automated Setup**: Fully automated virtual machine creation with cloud-init
- **Cross-Platform**: Supports both VMware Fusion (macOS) and VMware Workstation (Windows/Linux)
- **Architecture Support**: Works with both AMD64 and ARM64 architectures.
- **Secure Random Passwords**: Cryptographically secure password generation.
- **Override Support**: Customize virtual machine settings without modifying core files.
- **Force Build**: Automatically overwrites existing VMs for clean builds.

## Prerequisites

### Required Software

- [Packer](https://www.packer.io/) (>= 1.0)
- [VMware Fusion 13](https://www.vmware.com/products/fusion.html) (macOS) or [VMware Workstation 17](https://www.vmware.com/products/workstation-pro.html) (Windows/Linux)
- `curl` - for downloading ISO files
- `openssl` - for password encryption

## Quick Start

1. **Clone the repository**

   ```bash
   git clone https://github.com/tenthirtyam/packer-vmware-desktop-ubuntu-daily
   cd packer-vmware-desktop-ubuntu-daily
   ```

2. **Run the build script**

   ```bash
   ./ubuntu-daily.sh
   ```

3. **Wait for completion**
   The script will automatically:
   - Download the latest Ubuntu Server daily ISO
   - Validate checksums
   - Overwrite any existing VMs
   - Build the virtual machine using Packer
   - Create a snapshot
   - Clean up temporary files

## Configuration

### Default Settings

- **VM Name**: `ubuntu-YYYYMMDD-{arch}` (e.g., `ubuntu-20250911-arm64`)
- **Username**: `ubuntu`
- **Password**: Cryptographically secure random (12 characters)
- **Memory**: 4GB
- **Disk**: 20GB
- **CPUs**: 2 cores
- **Locale**: `en_US.UTF-8`
- **Keyboard Layout**: `us`
- **Timezone**: `UTC`

### Customization Options

#### Usage Options

```bash
# Use auto-generated secure password.
./ubuntu-daily.sh

# Use custom password (prompts securely).
./ubuntu-daily.sh --password=<your_password>

# Show help.
./ubuntu-daily.sh --help
```

#### Password Security

- **Auto-generated**: Cryptographically secure (12 characters) using OpenSSL.
- **Custom passwords**: Prompted securely (no echo) with confirmation.
- **No command-line exposure**: Passwords never appear in shell history.
- **Validation**: Ensures passwords are not empty and match confirmation.

#### Fixed Directories

- ISO Files: `./iso/` (created automatically)
- Virtual Machine Output: `./output/` (created automatically)

#### Override Configuration

Create an `overrides.pkrvars.hcl` file to customize the settings without modifying the main configuration:

```bash
# Copy the example file.
cp overrides.pkrvars.hcl.example overrides.pkrvars.hcl

# Edit with your preferred settings.
vim overrides.pkrvars.hcl
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

The script automatically detects and uses `overrides.pkrvars.hcl` if present.

## Build Process

The build process follows these steps:

1. **Validation**: Checks for required tools and dependencies
2. **Password Generation**: Creates cryptographically secure random password
3. **ISO Download**: Downloads the latest Ubuntu Server daily ISO
4. **Checksum Verification**: Validates ISO integrity
5. **Packer Initialization**: Initializes Packer plugins
6. **Configuration Validation**: Validates Packer configuration
7. **VM Creation**: Creates and configures the virtual machine
8. **OS Installation**: Automated Ubuntu installation via cloud-init
9. **Post-Processing**: Creates snapshot and cleans up files

## Output

After successful completion, you'll find the virtual machine in `output/`.

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## Sponsor

[![Sponsor](https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)][sponsor]&nbsp;&nbsp;
[![Buy me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=white)][buy-me-a-coffee]

## License

Copyright &copy; 2025-2026 Ryan Johnson

Licensed under the [MIT License][license].

[license]: LICENSE
[sponsor]: https://github.com/sponsors/tenthirtyam
[buy-me-a-coffee]: https://buymeacoffee.com/tenthirtyam

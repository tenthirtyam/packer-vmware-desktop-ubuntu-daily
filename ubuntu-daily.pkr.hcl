/*
    SPDX-License-Identifier: MIT
    SPDX-FileCopyrightText: 2025 Ryan Johnson

    Description:
    Ubuntu Server Daily Build build definition.
    Packer Plugin for VMware Desktop Hypervisors: 'vmware-iso' builder.
*/

//  BLOCK: packer
//  The Packer configuration.

packer {
  required_version = "~> 1"
  required_plugins {
    vmware = {
      source  = "github.com/hashicorp/vmware"
      version = "~> 1"
    }
  }
}

//  BLOCK: variables
//  Defines the variables.

variable "date_format" {
  type        = string
  description = "The date format for the virtual machine."
  default     = "2006-01-02"
  // The default date format is set to ISO 8601: YYYY-MM-DD.
}

variable "arch" {
  type = string
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "The architecture must be either 'amd64' or 'arm64'."
  }
}

variable "locale" {
  type        = string
  description = "The locale for the virtual machine."
  default     = "en_US"
}

variable "keyboard_layout" {
  type        = string
  description = "The keyboard layout for the virtual machine."
  default     = "us"
}

variable "timezone" {
  type        = string
  description = "The timezone for the virtual machine."
  default     = "UTC"
}

variable "firmware" {
  type        = string
  description = "The firmware for the virtual machine."
  default     = "efi" // Default firmware is set to 'efi'.
  // For ARM64, the firmware is automatically set to 'efi'.
}

variable "iso_file" {
  type        = string
  description = "The ISO file for the virtual machine."
}

variable "iso_url" {
  type        = string
  description = "The URL for the ISO file."
}

variable "iso_checksum" {
  type        = string
  description = "The checksum for the ISO file."
}

variable "iso_checksum_type" {
  type        = string
  description = "The checksum type for the ISO file."
  default     = "sha256"
}

variable "ssh_username" {
  type        = string
  description = "The SSH username for the virtual machine."
}

variable "ssh_password" {
  type        = string
  description = "The SSH password for the virtual machine."
  sensitive   = true
}

variable "ssh_password_encrypted" {
  type        = string
  description = "The encrypted SSH password for the virtual machine."
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "The SSH timeout for the virtual machine."
  default     = "20m"
}

variable "vm_name" {
  type        = string
  description = "The base name for the virtual machine."
}

variable "vm_hostname" {
  type        = string
  description = "The hostname for the virtual machine."
}

variable "vm_hardware_version" {
  type        = string
  description = "The hardware version for the virtual machine."
  default     = "21"
}

variable "guest_os_type" {
  type        = string
  description = "The guest OS type for the virtual machine."
  default     = "ubuntu-64"
  // For ARM64, the guest OS type is automatically set to 'arm-ubuntu-64'.
}

variable "vm_headless_enabled" {
  type        = bool
  description = "Enable headless mode for the virtual machine build."
  default     = false
}

variable "vm_cpu" {
  type        = number
  description = "The number of CPUs for the virtual machine."
  validation {
    condition     = var.vm_cpu >= 1
    error_message = "The number of CPUs must be at least 1."
  }
  default = 2
}

variable "vm_cpu_cores" {
  type        = number
  description = "The number of CPU cores for the virtual machine."
  validation {
    condition     = var.vm_cpu_cores >= 1
    error_message = "The number of CPU cores must be at least 1."
  }
  default = 1
}

variable "vm_memory" {
  type        = number
  description = "The memory size for the virtual machine in MB."
  validation {
    condition     = var.vm_memory >= 1024
    error_message = "The memory size must be at least 1024 MB."
  }
  default = 4096
}

variable "vm_disk_size" {
  type        = number
  description = "The disk size for the virtual machine in MB."
  validation {
    condition     = var.vm_disk_size >= 10024
    error_message = "The disk size must be at least 10024 MB."
  }
  default = 20480
}

variable "vm_disk_type_id" {
  type        = number
  description = "The disk type ID for the virtual machine."
  validation {
    condition     = var.vm_disk_type_id >= 0 && var.vm_disk_type_id <= 5
    error_message = "The disk type ID must be between 0 and 5."
  }
  default = 0 // Growable virtual disk contained in a single file (monolithic sparse).
}

variable "vm_disk_adapter_type" {
  type        = string
  description = "The disk adapter type for the virtual machine."
  default     = "sata"
  // For ARM64, the disk adapter type is automatically set to NVMe.
}

variable "vm_cdrom_adapter_type" {
  type        = string
  description = "The CD-ROM adapter type for the virtual machine."
  default     = "ide"
  // For ARM64, the CD-ROM adapter type is automatically set to SATA.
}

variable "vm_network_adapter_type" {
  type        = string
  description = "The network adapter type for the virtual machine."
  default     = "e1000e"
  // For ARM64, the network adapter type is automatically set to VMXNET3.
}

variable "vm_network" {
  type        = string
  description = "The network for the virtual machine."
  default     = "nat"
}

variable "vm_usb_enabled" {
  type        = bool
  description = "Enable USB for the virtual machine."
  default     = false
  // For ARM64, this is automatically set to 'true'.
}

variable "vm_sound_enabled" {
  type        = bool
  description = "Enable sound for the virtual machine."
  default     = false
}

variable "shutdown_command" {
  type        = string
  description = "The shutdown command for the virtual machine."
  default     = "sudo shutdown -P now"
}

variable "shutdown_timeout" {
  type        = string
  description = "The shutdown timeout for the virtual machine."
  default     = "15m"
}

variable "boot_wait" {
  type        = string
  description = "The boot wait time for the virtual machine."
  default     = "5s"
}

variable "output_directory" {
  type        = string
  description = "The output directory for the virtual machine."
  default     = "output"
}

//  BLOCK: locals
//  Defines the local variables.

locals {
  locales = {
    valid = jsondecode(file("locales.json"))
  }
  layouts = {
    valid = jsondecode(file("keyboard_layouts.json"))
  }
  timezones = {
    valid = flatten([for tz in jsondecode(file("timezones.json")) : tz.utc])
  }
  boot_command_efi = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
  boot_command_bios = [
    "<esc><wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
  build_date           = formatdate(var.date_format, timestamp())
  firmware              = var.arch == "arm64" ? "efi" : var.firmware
  boot_command         = var.firmware == "efi" ? local.boot_command_efi : local.boot_command_bios
  guest_os_type        = var.arch == "arm64" ? "arm-ubuntu-64" : var.guest_os_type
  disk_adapter_type    = var.arch == "arm64" ? "nvme" : var.disk_adapter_type
  cdrom_adapter_type   = var.arch == "arm64" ? "sata" : var.vm_cdrom_adapter_type
  network_adapter_type = var.arch == "arm64" ? "vmxnet3" : var.vm_network_adapter_type
  usb_enabled          = var.arch == "arm64" ? true : var.vm_usb_enabled
  vmx_data = var.arch == "arm64" ? {
    "usb_xhci.present" = true
  } : {}
  http_content = {
    "/meta-data" = file("${abspath(path.root)}/data/meta-data")
    "/user-data" = templatefile("${abspath(path.root)}/data/user-data.pkrtpl.hcl", {
      hostname        = var.vm_hostname
      username        = var.ssh_username
      password        = var.ssh_password_encrypted
      locale          = var.locale
      keyboard_layout = var.keyboard_layout
      timezone        = var.timezone
    })
  }
  iso_target_path = "${path.cwd}/iso/"
  iso_urls = [
    "file:${local.iso_target_path}/${var.iso_file}",
    "${var.iso_url}"
  ]
  iso_checksum = "${var.iso_checksum_type}:${var.iso_checksum}"
  output_path  = "${var.output_directory}/${local.build_date}"
}

//  BLOCK: source
//  Defines the builder configuration blocks.

source "vmware-iso" "ubuntu-daily" {
  vm_name              = var.vm_name
  version              = var.vm_hardware_version
  guest_os_type        = local.guest_os_type
  firmware              = local.firmware
  cpus                 = var.vm_cpu
  cores                = var.vm_cpu_cores
  memory               = var.vm_memory
  disk_size            = var.vm_disk_size
  disk_type_id         = var.vm_disk_type_id
  disk_adapter_type    = local.disk_adapter_type
  cdrom_adapter_type   = local.cdrom_adapter_type
  iso_urls             = local.iso_urls
  iso_checksum         = local.iso_checksum
  iso_target_path      = local.iso_target_path
  network_adapter_type = local.network_adapter_type
  network              = var.vm_network
  usb                  = local.usb_enabled
  sound                = var.vm_sound_enabled
  headless             = var.vm_headless_enabled
  snapshot_name        = local.build_date
  http_content         = local.http_content
  boot_wait            = var.boot_wait
  boot_command         = local.boot_command
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = var.ssh_timeout
  shutdown_command     = var.shutdown_command
  shutdown_timeout     = var.shutdown_timeout
  output_directory     = local.output_path
  vmx_data             = local.vmx_data
}

//  BLOCK: build
//  Defines the builders to run, provisioners, and post-processors.

build {
  sources = ["source.vmware-iso.ubuntu-daily"]
}

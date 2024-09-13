/*
    description:
    Ubuntu Server Daily Build build definition.
    Packer Plugin for VMware Desktop Hypervisors: 'vmware-iso' builder.
*/

//  BLOCK: packer
//  The Packer configuration.

packer {
  required_version = ">= 1.11.0"
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vmware"
      version = ">= 1.1.0"
    }
  }
}

//  BLOCK: variables
//  Defines the variables.

variable "arch" {
  type = string
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "The architecture must be either 'amd64' or 'arm64'."
  }
}

variable "iso_file" {
  type        = string
  description = "The file name of the ISO to use for the build."
}

variable "iso_url" {
  type        = string
  description = "The URL to download the ISO from."
}

variable "iso_checksum" {
  type        = string
  description = "The checksum of the ISO file."
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

variable "vm_base_name" {
  type        = string
  description = "The base name for the virtual machine."
}

variable "vm_hostname" {
  type        = string
  description = "The hostname for the virtual machine."
}

//  BLOCK: locals
//  Defines the local variables.

locals {
  build_date    = formatdate("YYYY-MM-DD", timestamp())
  build_time    = formatdate("HH:mm:ss", timestamp())
  guest_os_type = var.arch == "arm64" ? "ubuntu-64-arm" : "ubuntu-64"
  http_content = {
    "/meta-data" = file("${abspath(path.root)}/data/meta-data")
    "/user-data" = templatefile("${abspath(path.root)}/data/user-data.pkrtpl.hcl", {
      vm_hostname            = var.vm_hostname
      ssh_username           = var.ssh_username
      ssh_password           = var.ssh_password
      ssh_password_encrypted = var.ssh_password_encrypted
    })
  }
  iso_target_path = "${path.cwd}/iso/"
  output_path     = "output/${local.build_date}/${local.build_time}"
}

//  BLOCK: source
//  Defines the builder configuration blocks.

source "vmware-iso" "ubuntu-daily" {
  vm_name       = "${var.vm_base_name}-${local.build_date}"
  guest_os_type = "ubuntu-64"
  version       = "21"
  headless      = false
  memory        = 8172
  cpus          = 2
  cores         = 2
  disk_size     = 81920
  sound         = true
  disk_type_id  = 0
  iso_urls = [
    "file:${local.iso_target_path}/${var.iso_file}",
    "${var.iso_url}"
  ]
  iso_checksum     = "sha256:${var.iso_checksum}"
  iso_target_path  = local.iso_target_path
  output_directory = local.output_path
  snapshot_name    = "clean"
  http_content     = local.http_content
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "20m"
  shutdown_command = "sudo shutdown -P now"
  shutdown_timeout = "15m"
  boot_wait        = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
}

//  BLOCK: build
//  Defines the builders to run, provisioners, and post-processors.

build {
  sources = ["source.vmware-iso.ubuntu-daily"]
}

#!/usr/bin/env bash

# Set the variables:
ARCH="amd64" # amd64 or arm64)
VM_BASE_NAME="ubuntu"
VM_HOSTNAME="ubuntu-daily"
GUEST_USERNAME="packer"
GUEST_PASSWORD="VMw@re123!"

################################
# DO NOT EDIT BELOW THIS LINE! #
################################

# Determine the directory of the script:
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Generate the encrypted password:
GUEST_PASSWORD_SALT=$(openssl rand -base64 6)
GUEST_PASSWORD_ENCRYPTED=$(echo -n "${GUEST_PASSWORD}" | openssl passwd -6 -stdin -salt $GUEST_PASSWORD_SALT)

# Get the latest ISO URL and checksum:
ISO_BASE_URL="https://cdimage.ubuntu.com/ubuntu-server/daily-live/current"
ISO_NAME=$(curl -s "${ISO_BASE_URL}/" | grep -o "href=\"[^\"]*live-server-${ARCH}.iso\"" | sed 's/href="//; s/"$//' | head -n 1)
ISO_URL="${ISO_BASE_URL}/${ISO_NAME}"
ISO_DIR="${SCRIPT_DIR}/iso"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"
ISO_FILE=$(basename "${ISO_PATH}")
ISO_CHECKSUM=$(curl -s "${ISO_BASE_URL}/SHA256SUMS" | grep "${ISO_NAME}" | awk '{print $1}')

# Build an Ubuntu Server Daily Template for VMware Fusion:
echo -e "\e[38;5;39m-------------------------------------------------------------------------------------------------------\e[0m"
echo -e "\e[38;5;39m  Building an Ubuntu Server Daily Template for VMware Desktop Hypervisors. Standby...                  \e[0m"
echo -e "\e[38;5;39m                                                                                                       \e[0m"
echo -e "\e[38;5;39m  Date:     $(date)                                                                                    \e[0m"
echo -e "\e[38;5;39m  URL:      ${ISO_URL}                                                                                 \e[0m"
echo -e "\e[38;5;39m  Checksum: ${ISO_CHECKSUM}                                                                            \e[0m"
echo -e "\e[38;5;39m                                                                                                       \e[0m"
echo -e "\e[38;5;39m  Checking for existing ISO file...                                                                    \e[0m"

# Create the iso directory if it does not exist
mkdir -p "${ISO_DIR}"

# Download the ISO file if it does not exist or if the checksum does not match the latest.
if [ -f "${ISO_PATH}" ]; then
  echo -e "\e[38;5;39m  The ISO file already exists. Verifying checksum...\e[0m"
  CURRENT_CHECKSUM=$(shasum -a 256 "${ISO_PATH}" | awk '{print $1}')
  if [ "${CURRENT_CHECKSUM}" != "${ISO_CHECKSUM}" ]; then
    echo -e "\e[38;5;39m  The checksum does not match. Downloading the latest ISO...\e[0m"
    curl -o "${ISO_PATH}" "${ISO_URL}"
  else
    echo -e "\e[38;5;39m  Checksum matches. Proceeding with the build.\e[0m"
  fi
else
  echo -e "\e[38;5;39m  The ISO file does not exist. Downloading...\e[0m"
  curl -o "${ISO_PATH}" "${ISO_URL}"
fi

echo -e "\e[38;5;39m-------------------------------------------------------------------------------------------------------\e[0m"

packer init .
packer build -force \
  -var "arch=$ARCH" \
  -var "iso_file=$ISO_FILE" \
  -var "iso_url=$ISO_URL" \
  -var "iso_checksum=$ISO_CHECKSUM" \
  -var "vm_base_name=$VM_BASE_NAME" \
  -var "vm_hostname=$VM_HOSTNAME" \
  -var "ssh_username=$GUEST_USERNAME" \
  -var "ssh_password=$GUEST_PASSWORD" \
  -var "ssh_password_encrypted=$GUEST_PASSWORD_ENCRYPTED" \
  .

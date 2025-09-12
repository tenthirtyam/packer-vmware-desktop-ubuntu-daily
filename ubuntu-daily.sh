#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Ryan Johnson

set -euo pipefail

# Check if a required command is available in PATH and exit if not found.
require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf "\033[31m[ERROR]\033[0m Required command '%s' not found in PATH. Please install it.\n" "$1"
		exit 1
	fi
}

# Detect and return the VMware desktop hypervisor version information.
detect_hypervisor() {
	if ! vmx_path=$(command -v vmware-vmx); then
		echo "[ERROR] Error finding 'vmware-vmx' in PATH. Ensure VMware Fusion or VMware Workstation is installed."
		return 1
	fi

	version_output=$(${vmx_path} -v 2>&1)
	if [[ -z ${version_output} ]]; then
		echo "[ERROR] Error retrieving version information. Ensure VMware Fusion or VMware Workstation is operational."
		return 1
	fi

	version=$(echo "${version_output}" | tr -d '\n' | grep -oE "VMware (Fusion|Workstation) [0-9]+\.[0-9]+\.[0-9]+ build-[0-9]+")
	if [[ -z ${version} ]]; then
		echo "[ERROR] Error parsing version from output: ${version_output}"
		return 1
	fi

	echo "${version}"
}

# Generate a random 12-character password using OpenSSL.
generate_password() {
	openssl rand -base64 12 | tr -d "=+/" | cut -c1-12
}

# Detect the system architecture and return standardized format (amd64/arm64).
detect_architecture() {
	local arch_map
	if ! arch_map=$(uname -m); then
		printf "\033[31m[ERROR]\033[0m Failed to detect architecture\n" >&2
		return 1
	fi
	case "${arch_map}" in
	x86_64) echo "amd64" ;;
	arm64 | aarch64) echo "arm64" ;;
	*)
		printf "\033[31m[ERROR]\033[0m Unsupported architecture: '%s'\n" "${arch_map}" >&2
		return 1
		;;
	esac
}

# Download a file with progress indication and percentage display.
download_with_progress() {
	local url="$1"
	local output_file="$2"
	local total_size
	total_size=$(curl -sI "${url}" | grep -i content-length | awk '{print $2}' | tr -d '\r' || echo "0")

	if [[ ${total_size} -gt 0 ]]; then
		# Use silent mode to avoid curl's progress bar interfering
		curl -s -o "${output_file}" "${url}" &
		local curl_pid=$!

		printf "\e[32m  => Downloading latest:\e[0m \e[35m0%%\e[0m"
		while kill -0 "${curl_pid}" 2>/dev/null; do
			if [[ -f ${output_file} ]]; then
				local current_size
				current_size=$(wc -c <"${output_file}" 2>/dev/null || echo "0")
				if [[ ${current_size} -gt 0 ]]; then
					local percent
					percent=$(((current_size * 100) / total_size))
					printf "\r\e[32m  => Downloading latest:\e[0m \e[35m%d%%\e[0m" "${percent}"
				fi
			fi
			sleep 1
		done
		printf "\r\e[32m  => Downloading latest:\e[0m \e[35m100%%\e[0m\n"
	else
		# Fallback for unknown file size - use silent mode with simple progress
		printf "\e[32m  => Downloading latest:\e[0m \e[35mIn progress...\e[0m\n"
		curl -s -o "${output_file}" "${url}"
	fi

	printf "\e[32m  => Download completed.\e[0m\n"
}

# Validate a file's SHA256 checksum against the expected value.
validate_checksum() {
	local file_path="$1"
	local expected_checksum="$2"

	printf "\e[32m  => Validating checksum...\e[0m\n"
	local actual_checksum
	actual_checksum=$(shasum -a 256 "${file_path}" | awk '{print $1}')

	if [[ ${actual_checksum} == "${expected_checksum}" ]]; then
		printf "\e[32m  => Checksum validated.\e[0m\n"
		return 0
	else
		printf "\033[31m  => Checksum validation failed.\033[0m\n"
		return 1
	fi
}

# Validate checksum and return status for download decision.
validate_and_handle_checksum() {
	local file_path="$1"
	local expected_checksum="$2"

	validate_checksum "${file_path}" "${expected_checksum}"
	local result=$?

	if [[ ${result} -ne 0 ]]; then
		printf "\e[32m  => Checksum mismatch, re-downloading...\e[0m\n"
		return 1
	fi
	return 0
}

# Validate checksum and exit the script if validation fails.
validate_checksum_or_exit() {
	local file_path="$1"
	local expected_checksum="$2"

	validate_checksum "${file_path}" "${expected_checksum}"
	local result=$?

	if [[ ${result} -ne 0 ]]; then
		exit 1
	fi
}

# Download the Ubuntu ISO file if needed, with checksum validation.
download() {
	if ! mkdir -p "${ISO_DIR}"; then
		printf "\033[31m  => Failed to create directory: %s\033[0m\n" "${ISO_DIR}"
		exit 1
	fi

	local need_download=false

	if [[ -f ${ISO_PATH} ]]; then
		printf "\e[32m  => ISO file found, validating...\e[0m\n"
		if ! validate_and_handle_checksum "${ISO_PATH}" "${ISO_CHECKSUM}"; then
			need_download=true
		fi
	else
		printf "\e[32m  => ISO file not found, downloading...\e[0m\n"
		need_download=true
	fi

	if [[ ${need_download} == true ]]; then
		# Remove old ISO file if it exists to ensure clean download
		if [[ -f ${ISO_PATH} ]]; then
			rm -f "${ISO_PATH}"
		fi
		download_with_progress "${ISO_URL}" "${ISO_PATH}"
		validate_checksum_or_exit "${ISO_PATH}" "${ISO_CHECKSUM}"
	fi
}

# Initialize Packer by running packer init command.
initialize() {
	printf "\e[32m  => Initializing Packer...\e[0m\n"

	if init_output=$(packer init . 2>&1); then
		printf "\e[32m  => Initialized successfully.\e[0m\n"
	else
		printf "\033[31m  => Initialization failed.\033[0m\n"
		printf "%s\n" "${init_output}"
		exit 1
	fi
}

# Validate the Packer configuration before building.
validate() {
	printf "\e[32m  => Validating configuration...\e[0m\n"

	if validate_output=$(packer validate "${PACKER_VARS[@]}" . 2>&1); then
		printf "\e[32m  => Validated successfully.\e[0m\n"
	else
		printf "\033[31m  => Validation failed.\033[0m\n"
		printf "%s\n" "${validate_output}"
		exit 1
	fi
}

# Build the VM image using Packer with the configured variables.
build() {
	printf "\e[32m  => Building the machine image...\e[0m\n\n"
	if ! mkdir -p "${OUTPUT_DIR}"; then
		printf "\033[31m  => Failed to create output directory: %s\033[0m\n" "${OUTPUT_DIR}"
		exit 1
	fi
	packer build --force "${PACKER_VARS[@]}" .
}

# Display a summary of the configuration before starting the build process.
summary() {
	printf "\e[35m-------------------------------------------------------------------------------------\e[0m\n\n"
	printf "\e[35m  Hypervisor:\e[0m  \e[32m%s\e[0m\n" "${HYPERVISOR}"
	printf "\e[35m  Guest OS:\e[0m    \e[32m%s\e[0m\n" "${GUEST_FULL_NAME} ${GUEST_ARCH}"
	printf "\e[35m  ISO:\e[0m         \e[32m%s\e[0m\n" "${ISO_FILE}"
	printf "\e[35m  Checksum:\e[0m    \e[32m%s\e[0m\n" "${ISO_CHECKSUM}"
	printf "\e[35m  VM Name:\e[0m     \e[32m%s\e[0m\n" "${GUEST_NAME}"
	printf "\e[35m  Hostname:\e[0m    \e[32m%s\e[0m\n" "${GUEST_HOSTNAME}"
	printf "\e[35m  Username:\e[0m    \e[32m%s\e[0m\n" "${GUEST_USERNAME}"
	printf "\e[35m  Password:\e[0m    \e[32m%s\e[0m\n\n" "${GUEST_PASSWORD}"
	printf "\e[35m  Status:\e[0m\n\n"
}

# Main function that orchestrates the entire VM building process.
main() {

	local password=""

	while [[ $# -gt 0 ]]; do
		case $1 in
		--password=*)
			password="${1#*=}"
			shift
			;;
		--help | -h)
			printf "Usage: %s [OPTIONS]\n" "$0"
			printf "\nOptions:\n"
			printf "  --password=PASS    Set custom password\n"
			printf "  --help, -h         Show this help message\n"
			printf "\nDirectories:\n"
			printf "  ISO files:     ./iso/ (created automatically)\n"
			printf "  VM output:     ./output/ (created automatically)\n"
			printf "\nNote: Existing VMs are automatically overwritten.\n"
			printf "\nExamples:\n"
			printf "  %s                           # Auto-generated password\n" "$0"
			printf "  %s --password=mypass123      # Custom password\n" "$0"
			exit 0
			;;
		-*)
			printf "Unknown option: %s\n" "$1"
			printf "Use --help for usage information.\n"
			exit 1
			;;
		*)
			printf "Unknown argument: %s\n" "$1"
			printf "Use --help for usage information.\n"
			exit 1
			;;
		esac
	done

	for cmd in "${COMMANDS[@]}"; do
		require_command "${cmd}"
	done

	HYPERVISOR=$(detect_hypervisor)
	if [[ -z ${HYPERVISOR} ]]; then
		exit 1
	fi

	GUEST_PASSWORD="${password:-$(generate_password)}"
	GUEST_HOSTNAME=$(echo "${GUEST_SHORT_NAME}-${GUEST_DATE}-${GUEST_ARCH}" | tr '[:upper:]' '[:lower:]')
	GUEST_PASSWORD_SALT=$(openssl rand -base64 6)
	GUEST_PASSWORD_ENCRYPTED=$(printf '%s' "${GUEST_PASSWORD}" | openssl passwd -6 -stdin -salt "${GUEST_PASSWORD_SALT}")
	GUEST_PASSWORD_ENCRYPTED_ESCAPED=$(printf '%s' "${GUEST_PASSWORD_ENCRYPTED}" | sed "s/'/'\\\\''/g")
	GUEST_NAME="${GUEST_HOSTNAME}"

	declare -a PACKER_VARS=(
		"-var" "arch=${GUEST_ARCH}"
		"-var" "ssh_username=${GUEST_USERNAME}"
		"-var" "ssh_password=${GUEST_PASSWORD}"
		"-var" "ssh_password_encrypted=${GUEST_PASSWORD_ENCRYPTED_ESCAPED}"
		"-var" "vm_name=${GUEST_NAME}"
		"-var" "vm_hostname=${GUEST_HOSTNAME}"
		"-var" "iso_file=${ISO_FILE}"
		"-var" "iso_url=${ISO_URL}"
		"-var" "iso_checksum=${ISO_CHECKSUM}"
		"-var" "output_directory=${OUTPUT_DIR}"
	)

	if [[ -f "overrides.pkrvars.hcl" ]]; then
		PACKER_VARS+=("-var-file" "overrides.pkrvars.hcl")
		printf "\e[33m  => Using overrides from overrides.pkrvars.hcl\e[0m\n"
	fi

	summary
	download
	initialize
	validate
	build
}

# Get the directory where this script is located.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Set default directories for downloads and output.
DEFAULT_DOWNLOAD_DIR="${SCRIPT_DIR}/iso"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/output"

# Initialize working directories.
DOWNLOAD_DIR="${DEFAULT_DOWNLOAD_DIR}"
ISO_DIR="${DOWNLOAD_DIR}"
OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"

# Required commands for the script to function.
COMMANDS=("packer" "vmware-vmx" "curl" "shasum" "openssl")

# Guest OS configuration.
GUEST_SHORT_NAME="Ubuntu"
GUEST_FULL_NAME="Ubuntu Server"
GUEST_USERNAME=$(echo "${GUEST_SHORT_NAME}" | tr '[:upper:]' '[:lower:]')

# Detect system architecture.
GUEST_ARCH=$(detect_architecture)
if [[ -z ${GUEST_ARCH} ]]; then
	echo "[ERROR] Failed to detect architecture."
	exit 1
fi

# Determine the date in YYYYMMDD format:
GUEST_DATE=$(date +%Y%m%d)
if [[ -z ${GUEST_DATE} ]]; then
	echo "[ERROR] Error determining the date."
	exit 1
fi

# Retrieve the latest ISO URL and checksum:
ISO_BASE_URL="https://cdimage.ubuntu.com/ubuntu-server/daily-live/current"

# Get both ISO name and checksum in parallel for efficiency using temporary files
ISO_NAME_FILE=$(mktemp)
CHECKSUMS_FILE=$(mktemp)

# Cleanup temporary files on exit
trap 'rm -f "${ISO_NAME_FILE}" "${CHECKSUMS_FILE}"' EXIT

{
	if iso_name=$(curl -s "${ISO_BASE_URL}/" | grep -o "href=\"[^\"]*live-server-${GUEST_ARCH}.iso\"" | sed 's/href="//; s/"$//' | head -n 1); then
		echo "${iso_name}" >"${ISO_NAME_FILE}"
	else
		echo "[ERROR] Failed to retrieve ISO name from Ubuntu repository." >&2
		exit 1
	fi
} &

{
	if checksums=$(curl -s "${ISO_BASE_URL}/SHA256SUMS"); then
		echo "${checksums}" >"${CHECKSUMS_FILE}"
	else
		echo "[ERROR] Failed to retrieve checksums from Ubuntu repository." >&2
		exit 1
	fi
} &

# Wait for both downloads to complete
wait

# Read results from temporary files
ISO_NAME=$(cat "${ISO_NAME_FILE}")
CHECKSUMS=$(cat "${CHECKSUMS_FILE}")

# Validate we got the data
if [[ -z ${ISO_NAME} ]]; then
	echo "[ERROR] Failed to retrieve ISO name from Ubuntu repository."
	exit 1
fi

if [[ -z ${CHECKSUMS} ]]; then
	echo "[ERROR] Failed to retrieve checksums from Ubuntu repository."
	exit 1
fi

# Extract checksum for our specific ISO
ISO_CHECKSUM=$(echo "${CHECKSUMS}" | grep "${ISO_NAME}" | awk '{print $1}')
if [[ -z ${ISO_CHECKSUM} ]]; then
	echo "[ERROR] Failed to find checksum for ${ISO_NAME}."
	exit 1
fi

ISO_URL="${ISO_BASE_URL}/${ISO_NAME}"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"
ISO_FILE=$(basename "${ISO_PATH}")

main "$@"

printf "\e[35m-------------------------------------------------------------------------------------\e[0m\n"

#!/bin/bash
# install_prerequisites.sh - Install required dependencies for Spotify Toolbox (jq, curl, openssl, base64)

set -e

missing=()
for cmd in jq curl openssl base64; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
    echo "All prerequisites are already installed."
    return 0 2>/dev/null || exit 0
fi

echo "Missing prerequisites: ${missing[*]}"
echo "Attempting to install..."

install_mac() {
    if command -v brew >/dev/null 2>&1; then
        brew install "${missing[@]}"
    else
        echo "Homebrew not found. Please install Homebrew and rerun this script."
        exit 1
    fi
}

install_ubuntu() {
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
}

install_fedora() {
    sudo dnf install -y "${missing[@]}"
}

install_arch() {
    sudo pacman -Sy --noconfirm "${missing[@]}"
}

install_windows() {
    if command -v choco >/dev/null 2>&1; then
        choco install -y "${missing[@]}"
    elif command -v scoop >/dev/null 2>&1; then
        scoop install "${missing[@]}"
    else
        echo "Neither Chocolatey nor Scoop is installed."
        echo "Which package manager would you like to install?"
        select pm in "Chocolatey" "Scoop"; do
            case $pm in
                "Chocolatey")
                    echo "Installing Chocolatey..."
                    powershell.exe -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" || { echo "Failed to install Chocolatey."; exit 1; }
                    echo "Chocolatey installed. Installing prerequisites..."
                    choco install -y "${missing[@]}"
                    break
                    ;;
                "Scoop")
                    echo "Installing Scoop..."
                    powershell.exe -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy RemoteSigned -scope CurrentUser; iwr -useb get.scoop.sh | iex" || { echo "Failed to install Scoop."; exit 1; }
                    echo "Scoop installed. Installing prerequisites..."
                    scoop install "${missing[@]}"
                    break
                    ;;
                *)
                    echo "Please choose 1 or 2."
                    ;;
            esac
        done
    fi
}

case "$(uname -s)" in
    Darwin)
        install_mac
        ;;
    Linux)
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    install_ubuntu
                    ;;
                fedora)
                    install_fedora
                    ;;
                arch)
                    install_arch
                    ;;
                *)
                    echo "Unsupported Linux distribution. Please install: ${missing[*]} manually."
                    exit 1
                    ;;
            esac
        else
            echo "Unknown Linux distribution. Please install: ${missing[*]} manually."
            exit 1
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        install_windows
        ;;
    *)
        echo "Unsupported OS. Please install: ${missing[*]} manually."
        exit 1
        ;;
esac

echo "All prerequisites installed."

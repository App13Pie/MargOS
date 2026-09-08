#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

# Enable RPM Fusion
dnf5 -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm"

# Upgrade System
dnf5 -y upgrade --refresh

# WiFi Connectivity
dnf5 -y install brcmfmac-firmware

# Cleanup
dnf5 -y clean all

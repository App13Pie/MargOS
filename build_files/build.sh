#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

# Cleanup
dnf5 -y clean all

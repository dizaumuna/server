# Copyright (C) 2026 diza u muna
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!/bin/bash
set -e
chmod +x *
chmod +x scripts/*
chmod +x tools/*

LOG_STEP_IN() {
    echo "  - $1"
}

LOG_STEP_OUT() {
    echo "  - $1"
}

CREATE_WORKDIR () {
    if [ ! -d "workdir" ]; then
        mkdir workdir
    fi
}

GRAY='\033[1;90m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Port
source scripts/port.sh

# Debloat
source scripts/debloat.sh

# Build images
source scripts/build_images.sh

# Create ZIP
source scripts/create_zip.sh

# Upload to PixelDrain
curl -X POST "https://pixeldrain.com/api/file" -u":c3156ef7-e07c-4e2c-8d7a-53239e816184" -F "file=@miatoll_id_global-ota_full-OOS-user-15.0.zip"
LOG_STEP_IN "Build completed."

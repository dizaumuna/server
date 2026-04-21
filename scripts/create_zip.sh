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

mkdir -p out/
rm -rf product.img system.img system_ext.img vendor.img
mv super.img out/

cd out

# Download binaries
LOG_STEP_IN "Downloading binaries for ZIP..."
curl -# -L -o miatoll.zip https://github.com/dizaumuna/dizaumuna/releases/download/gn/miatoll.zip

unzip miatoll.zip

rm miatoll.zip

# Download LineageOS boot.img for miatoll.
LOG_STEP_IN "Downloading Kriyoki Kernel for miatoll..."
curl -# -L -o boot.img https://github.com/dizaumuna/dizaumuna/releases/download/gn/new-boot.img

LOG_STEP_IN "Creating flashable ZIP file..."
zip -8 -r "miatoll_id_global-ota_full-OOS-user-15.0.zip" *
mv miatoll_id_global-ota_full-OOS-user-15.0.zip  ..
cd ..

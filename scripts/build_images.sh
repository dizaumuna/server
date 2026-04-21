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

LOG_STEP_IN "Building images, this may take a while..."

PADDING=3

python3 tools/fspatch.py workdir/basevendor/vendor workdir/basevendor/config/vendor_fsconfig.txt
python3 tools/fspatch.py workdir/port/system/system workdir/port/system/config/system_fs_config
python3 tools/fspatch.py workdir/port/system_ext/system_ext workdir/port/system_ext/config/system_ext_fs_config
python3 tools/fspatch.py workdir/port/product/product workdir/port/product/config/product_fs_config
echo "/system_ext/apex/com\.android\.vndk\.v30\.apex u:object_r:system_file:s0" >> workdir/port/system_ext/config/system_ext_file_contexts
sed -i 's|^\(/system/my_[^ ]*\) u:object_r:system_file:s0|\1(/.*)?    u:object_r:system_file:s0|' workdir/port/system/config/system_file_contexts
mv workdir/basevendor/config/vendor_fsconfig.txt workdir/basevendor/config/vendor_fs_config
mv workdir/basevendor/config/vendor_contexts.txt workdir/basevendor/config/vendor_file_contexts

# we will give 10mb extra
EXTRA=10485760

build_image() {
  NAME=$1
  ROOTFS=$2
  CONFIG_DIR=$3

  echo "  - Processing $NAME..."

  if [ ! -d "$ROOTFS" ]; then
    echo "  - [!] $NAME has no rootfs ($ROOTFS)"
    return
  fi

  SIZE=$(du -sb "$ROOTFS" | cut -f1)
  PAD_SIZE=$((SIZE + SIZE * PADDING / 100 + EXTRA))

  FS_CONFIG="$CONFIG_DIR/${NAME}_fs_config"
  CONTEXTS="$CONFIG_DIR/${NAME}_file_contexts"

  ARGS=""

  [ -f "$FS_CONFIG" ] && ARGS="$ARGS -C $FS_CONFIG"
  [ -f "$CONTEXTS" ] && ARGS="$ARGS -S $CONTEXTS"

  echo "  - Old size: $SIZE "
  echo "  - New size: $PAD_SIZE"

  ./tools/make_ext4fs \
    -s \
    -L $NAME \
    -a $NAME \
    -J \
    -T 1 \
    $ARGS \
    -l $PAD_SIZE \
    ${NAME}.img \
    "$ROOTFS"

  echo "  - Saving .size for each image, this may take a while..."
  sleep 10
  echo $PAD_SIZE > $NAME.size

  if [ $? -eq 0 ]; then
    echo "  - Successfully builded $NAME."
  else
    echo "  - Failed while building $NAME."
  fi

  echo
}

build_image \
  "system" \
  "workdir/port/system/system" \
  "workdir/port/system/config"

build_image \
  "system_ext" \
  "workdir/port/system_ext/system_ext" \
  "workdir/port/system_ext/config"

build_image \
  "product" \
  "workdir/port/product/product" \
  "workdir/port/product/config"

build_image \
  "vendor" \
  "workdir/basevendor/vendor" \
  "workdir/basevendor/config"

# build super.img
mkdir -p out
./tools/lpmake --metadata-size=67108864 \
--metadata-slots=2 \
--device-size=8589934592 \
--super-name=super \
--group qti_dynamic_partitions:8200000000 \
--partition system:readonly:$(cat system.size):qti_dynamic_partitions \
--partition system_ext:readonly:$(cat system_ext.size):qti_dynamic_partitions \
--partition vendor:readonly:$(cat vendor.size):qti_dynamic_partitions \
--partition product:readonly:$(cat product.size):qti_dynamic_partitions \
-i system=system.img \
-i system_ext=system_ext.img \
-i vendor=vendor.img \
-i product=product.img \
-o super.img

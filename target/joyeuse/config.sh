# SPDX-License-Identifier: GPL-3.0-only
#
# Device configuration for Redmi Note 9 Pro (joyeuse)
# Maintainer: diza u muna
#

# Device configuration
TARGET_DEVICE="joyeuse"
TARGET_ARCH="arm64"
TARGET_SOC="SM7125"

# Filesystem configuration
TARGET_FS="ext4"

# Hardware-related configuration
TARGET_HAS_SIDEFP=true
TARGET_HAVE_QUADCAM=true
TARGET_HAS_NFC=false
TARGET_HAS_IR=false
TARGET_HAS_WARP_CHARGE=false
TARGET_HAS_VOOC_CHARGE=false

# OS-related configuration
TARGET_NEEDS_IMPORT=true
TARGET_IMPORT_PARTITIONS="my_manifest my_heytap my_engineering my_bigball my_carrier my_stock my_region my_product"

# Partition-related configurations
TARGET_IS_AB=false
TARGET_HAS_VIRTUAL_AB=false
TARGET_SUPER_SIZE=8589934592
TARGET_SUPER_GROUP="qti_dynamic_partitions"
TARGET_SUPER_METADATA_SIZE=67108864
TARGET_SUPER_METADATA_SLOTS=2

# Base ROM ~ Port ROM File Types
TARGET_BASEROM_TYPE="dat.br"
TARGET_PORTROM_TYPE="payload"

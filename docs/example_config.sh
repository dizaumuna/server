# SPDX-License-Identifier: GPL-3.0-only
#
# Device configuration for <deviceName> (<deviceCodeName>
# Maintainer: <maintainerName>
#

# Make sure you delete commented <> lines. Also this line too.

# Device configuration
TARGET_DEVICE_NAME="Redmi Note 9 Pro" # <device name>
TARGET_DEVICE="joyeuse" # <device codename>
TARGET_ARCH="arm64" # <device arch>
TARGET_SOC="SM7125" # <device SoC>

# Filesystem configuration
TARGET_FS="ext4" # <device fs type>

# Hardware-related configuration
TARGET_HAS_SIDEFP=true # <device side fingerprint>
TARGET_HAVE_QUADCAM=true # <device quad camera setup>
TARGET_HAS_NFC=true # <device nfc feature>
TARGET_HAS_IR=false # <device ir blaster feature>
TARGET_HAS_WARP_CHARGE=false # <warp charge, if you don't know make it false>
TARGET_HAS_VOOC_CHARGE=false # <vooc charge, if you don't know make it false>

# OS-related configuration
TARGET_NEEDS_IMPORT=true # <needs import my_xxx or not>
TARGET_IMPORT_PARTITIONS="my_manifest my_heytap my_engineering my_bigball. my_carrier my_stock my_region my_product"

# Partition-related configurations
TARGET_IS_AB=false # <a/b partition style, you can check it with fastboot getvar all>
TARGET_HAS_VIRTUAL_AB=false # <virtual a/b partition style, you can check it on orangefox>
TARGET_SUPER_SIZE=8589934592 # <super partition size>
TARGET_SUPER_GROUP="qti_dynamic_partitions" # <cluster name, if you don't know and porting to snapdragon use default, for mssi (mtk) use "main">
TARGET_SUPER_METADATA_SIZE=67108864 # <super metadata size>
TARGET_SUPER_METADATA_SLOTS=2 # <super metadata slots>
TARGET_BASEROM_TYPE="dat.br" # <base rom type, you can check it by extracting zip. Only payload, dat.br, img and dat supported>
TARGET_PORTROM_TYPE="payload" # <port rom type, you can check it by extracting zip. Only payload, dat.br, img and dat supported>
TARGET_BUILD_SUPER=true # <build super or not, true or false>

# Out ZIP type
TARGET_ZIP_TYPE="image" # <out zip type. Only image, new.dat and new.dat.br supported>

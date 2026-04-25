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
echo -e "${GRAY}Applying platform patches${RESET}"
echo "import /my_bigball/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_carrier/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_company/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_engineering/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_heytap/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_manifest/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_preload/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_product/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_region/build.prop" >> workdir/basevendor/vendor/build.prop
echo "import /my_stock/build.prop" >> workdir/basevendor/vendor/build.prop
echo -e "     ${GREEN}File modified: build.prop${RESET}"

LOG_STEP_IN "Porting OnePlus vendor to joyeuse..."
sudo cp -rf workdir/port/vendor/vendor/etc/group workdir/basevendor/vendor/etc/
sudo cp -rf workdir/port/vendor/vendor/etc/passwd workdir/basevendor/vendor/etc/
echo -e "     ${GREEN}File modified: group${RESET}"
echo -e "     ${GREEN}File modified: passwd${RESET}"

LOG_STEP_IN "Processing overlays from OnePlus to Xiaomi..."
rm -rf workdir/basevendor/vendor/overlay/*
sudo cp -r workdir/port/vendor/vendor/overlay/* workdir/basevendor/vendor/overlay/

LOG_STEP_IN "Downloading PermissionController.apk"
curl -L -# -o PermissionController.apk https://github.com/dizaumuna/dizaumuna/releases/download/gn/PermissionController.apk

mkdir -p workdir/port/product/product/priv-app/PermissionController/
mv PermissionController.apk workdir/port/product/product/priv-app/PermissionController/
echo -e "     ${GREEN}File modified: PermissionController.apk${RESET}"

LOG_STEP_IN "Removing old PermissionController.apk..."
mkdir -p tmp/apex_extracted
mv workdir/port/system/system/system/apex/com.google.android.permission.apex tmp/
cd tmp/
unzip com.google.android.permission.apex -d apex_extracted/
sudo debugfs -w apex_extracted/apex_payload.img -R "rm /priv-app/GooglePermissionController@341810000/GooglePermissionController.apk"
cd apex_extracted/
zip -r0 ../com.google.android.permission.apex . --exclude "*.apex"
cd ../..
mv tmp/com.google.android.permission.apex workdir/port/system/system/system/apex/
rm -rf tmp

echo -e "${GRAY}Applying device patches${RESET}"
LOG_STEP_IN "Processing lib and sensor files..."
mkdir -p workdir/basevendor/vendor/odm/lib

sudo cp -r workdir/port/vendor/vendor/lib/libAlgoProcess.so workdir/basevendor/vendor/odm/lib/

mkdir -p workdir/basevendor/vendor/odm/lib64

sudo cp -r workdir/port/vendor/vendor/lib64/libAlgoProcess.so workdir/basevendor/vendor/odm/lib64/

sed -i 's/<fqname>@1.0::ISensorsCalibrate\/default<\/fqname>/<fqname>@1.0::ISensorsCalibrate\/default<\/fqname>\n    <\/hal>\n    <hal format="hidl">\n        <n>android.hardware.sensors<\/name>\n        <transport>hwbinder<\/transport>\n        <version>2.0<\/version>\n        <interface>\n            <n>ISensors<\/name>\n            <instance>default<\/instance>\n        <\/interface>\n        <fqname>@2.0::ISensors\/default<\/fqname>/' workdir/basevendor/vendor/etc/vintf/manifest.xml

echo -e "     ${GREEN}File modified: libAlgoProcess.so${RESET}"
echo -e "     ${GREEN}File modified: manifest.xml${RESET}"

LOG_STEP_IN "Disabling File Encryption..."
sed -i 's/,inlinecrypt//g;s/,fileencryption=ice//g;s/,wrappedkey//g;s/,reservedsize=128M//g' workdir/basevendor/vendor/etc/fstab.default
sed -i 's/,inlinecrypt//g;s/,fileencryption=ice//g;s/,wrappedkey//g;s/,reservedsize=128M//g' workdir/basevendor/vendor/etc/fstab.emmc
echo -e "     ${GREEN}File modified: fstab.emmc / fstab.default${RESET}"
echo "#builded by dizaumuna" >> workdir/basevendor/vendor/build.prop

echo -e "${GRAY}Applying OS-various patches${RESET}"
LOG_STEP_IN "Commenting ro.product.first_api_level from my_manifest/build.prop..."
sed -i 's/ro.product.first_api_level=30/#ro.product.first_api_level=30/g' workdir/port/my_manifest/my_manifest/build.prop
echo -e "     ${GREEN}File modified: build.prop${RESET}"

LOG_STEP_IN "Patching ZygoteInitExtImpl in framework.jar..."
ROOT_DIR="$(pwd)"
FRAMEWORK_JAR="$ROOT_DIR/workdir/port/system/system/system/framework/framework.jar"
PATCH_WORKDIR="$ROOT_DIR/tmp/framework_patch"
rm -rf "$PATCH_WORKDIR"
mkdir -p "$PATCH_WORKDIR/jar"

cd "$PATCH_WORKDIR/jar"
jar xf "$FRAMEWORK_JAR"
cd "$ROOT_DIR"

python3 - "$PATCH_WORKDIR/jar" "$FRAMEWORK_JAR" << 'PYEOF'
import sys, os, zipfile, struct

jar_dir = sys.argv[1]
framework_jar = sys.argv[2]

TARGET_CLASS = b'Lcom/android/internal/os/ZygoteInitExtImpl;'
TARGET_METHOD = b'addBootEvent'

# DEX format: find method code and noop it
# We replace the method body with: return-void (opcode 0x0e)
# Strategy: find the string "addBootEvent" in string pool, trace to method_ids,
# find code_item, patch first instruction to return-void

def patch_method_in_dex(dex_data):
    data = bytearray(dex_data)

    # Find addBootEvent string in dex string pool
    method_str = b'addBootEvent'
    idx = data.find(method_str)
    if idx == -1:
        return None

    # Dex header: method_ids_size at 0x58, method_ids_off at 0x5C
    method_ids_size = struct.unpack_from('<I', data, 0x58)[0]
    method_ids_off = struct.unpack_from('<I', data, 0x5C)[0]

    # code_items_off via class_defs
    class_defs_size = struct.unpack_from('<I', data, 0x60)[0]
    class_defs_off = struct.unpack_from('<I', data, 0x64)[0]

    # string_ids_off to resolve string indices
    string_ids_off = struct.unpack_from('<I', data, 0x3C)[0]
    string_ids_size = struct.unpack_from('<I', data, 0x38)[0]

    # Find string_id index for "addBootEvent"
    target_str_idx = None
    for i in range(string_ids_size):
        str_off = struct.unpack_from('<I', data, string_ids_off + i * 4)[0]
        # Read ULEB128 length then string
        length = data[str_off]
        s = data[str_off + 1: str_off + 1 + length]
        if s == method_str:
            target_str_idx = i
            break

    if target_str_idx is None:
        return None

    # Find method_id with this name string index
    patched = False
    for i in range(method_ids_size):
        off = method_ids_off + i * 8
        name_idx = struct.unpack_from('<I', data, off + 4)[0]
        if name_idx != target_str_idx:
            continue

        # Found method — now find its code_item via class_defs
        for c in range(class_defs_size):
            coff = class_defs_off + c * 32
            class_data_off = struct.unpack_from('<I', data, coff + 24)[0]
            if class_data_off == 0:
                continue

            pos = class_data_off
            def read_uleb128(pos):
                result, shift = 0, 0
                while True:
                    b = data[pos]; pos += 1
                    result |= (b & 0x7f) << shift
                    if not (b & 0x80): break
                    shift += 7
                return result, pos

            sf, pos = read_uleb128(pos)
            im, pos = read_uleb128(pos)
            vm, pos = read_uleb128(pos)
            dm, pos = read_uleb128(pos)

            prev_method_idx = 0
            for _ in range(dm + vm):
                diff, pos = read_uleb128(pos)
                prev_method_idx += diff
                access_flags, pos = read_uleb128(pos)
                code_off, pos = read_uleb128(pos)
                if prev_method_idx == i and code_off != 0:
                    # code_item: registers_size(2), ins_size(2), outs_size(2), tries_size(2), debug_info_off(4), insns_size(4)
                    insns_off = code_off + 16
                    # Write return-void: opcode 0x0e, padding 0x00
                    data[insns_off] = 0x0e
                    data[insns_off + 1] = 0x00
                    patched = True
                    print(f"Patched addBootEvent at code offset 0x{code_off:x}")
                    break
            if patched:
                break
        if patched:
            break

    return bytes(data) if patched else None

target_dex = None
for fname in sorted(os.listdir(jar_dir)):
    if not fname.startswith('classes') or not fname.endswith('.dex'):
        continue
    fpath = os.path.join(jar_dir, fname)
    with open(fpath, 'rb') as f:
        dex = f.read()
    if TARGET_CLASS in dex and TARGET_METHOD in dex:
        target_dex = (fname, fpath, dex)
        print(f"Found target in {fname}")
        break

if not target_dex:
    print("ZygoteInitExtImpl not found in any dex, skipping")
    sys.exit(0)

fname, fpath, dex = target_dex
patched_dex = patch_method_in_dex(dex)

if patched_dex is None:
    print("Patch failed, skipping")
    sys.exit(0)

with open(fpath, 'wb') as f:
    f.write(patched_dex)

with zipfile.ZipFile(framework_jar, 'w', compression=zipfile.ZIP_STORED) as zout:
    for f in os.listdir(jar_dir):
        fp = os.path.join(jar_dir, f)
        if os.path.isfile(fp):
            zout.write(fp, f)

print("framework.jar patched and rebuilt successfully")
PYEOF

rm -rf "$PATCH_WORKDIR"
echo -e "     ${GREEN}File modified: framework.jar${RESET}"

LOG_STEP_IN "Processing OnePlus fixes..."
mv workdir/port/my_manifest/my_manifest workdir/port/system/system/
mv workdir/port/my_bigball/my_bigball workdir/port/system/system/
mv workdir/port/my_carrier/my_carrier workdir/port/system/system/
mv workdir/port/my_preload/my_preload workdir/port/system/system/
mv workdir/port/my_product/my_product workdir/port/system/system/
mv workdir/port/my_company/my_company workdir/port/system/system/
mv workdir/port/my_heytap/my_heytap workdir/port/system/system/
mv workdir/port/my_stock/my_stock workdir/port/system/system/
mv workdir/port/my_engineering/my_engineering workdir/port/system/system/
mv workdir/port/my_region/my_region workdir/port/system/system/

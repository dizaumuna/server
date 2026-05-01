#!/bin/bash
# buildROM.sh

SOURCE_FP="Redmi/miatoll_global/miatoll:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys"
TARGET_FP="OnePlus/OnePlus8T/OnePlus8T:14/RP1A.201005.001/2111291807:user/release-keys"
BUILD_DATE="%Y-%M-%d"
ANDROID="14"
OXYGENOS="14"
AUTHOR="diza u muna"

LOGINFO () {
    echo "$(date '+%Y-%m-%d-%H') - INFO - $1"
}

LOGWARN () {
    echo "$(date '+%Y-%m-%d-%H') - WARN - $1"
}

LOGERROR () {
    echo "$(date '+%Y-%m-%d-%H') - ERROR - $1"
}

# make the scripts executable, and exit if any command fails
set -euo pipefail
chmod +x bin/*
chmod +x *

# install pdg system-wide
wget https://github.com/ssut/payload-dumper-go/releases/download/1.3.0/payload-dumper-go_1.3.0_linux_amd64.tar.gz -O pdg.tar.gz > /dev/null
tar -xvzf pdg.tar.gz > /dev/null && sudo mv payload-dumper-go /usr/local/bin
pip3 install brotli
rm pdg.tar.gz LICENSE README.md

# Change URL1 with your Port ROM url
# Change URL2 with your Stock ROM url
URL1="https://gauss-componentotacostmanual-sg.allawnofs.com/remove-321c974e5931c5438d3cf3b7104102ac/component-ota/24/10/09/c6654c8a15d7487bb5a5c87708ad46af.zip"
URL2="https://bn.d.miui.com/V14.0.3.0.SJZMIXM/miui_JOYEUSEGlobal_V14.0.3.0.SJZMIXM_df17e3fabf_12.0.zip"

if [ ! -f "firmwaretarget.zip" ] || [ ! -f "firmwaresource.zip" ]; then
    LOGINFO "Downloading target firmware"
    curl -# -L -o firmwaretarget.zip "$URL1"
    LOGINFO "Downloading source firmware"
    curl -# -L -o firmwaretarget.zip "$URL2"
else
    LOGWARN "Firmware already exists, skipping download"
fi

if [ ! -d "workdir" ]; then
    LOGINFO "Creating workdir"
    mkdir -p workdir
    mkdir -p workdir/target
    mkdir -p workdir/source
else
    LOGWARN "Workdir already exists, skipping mkdir"
fi

unzip firmwaretarget.zip payload.bin -d workdir/target/ > /dev/null
unzip firmwaresource.zip vendor.* -d workdir/source/ > /dev/null
LOGINFO "Extracting target firmware"
payload-dumper-go -o workdir/target/ \
-p system,system_ext,product,vendor,my_manifest,my_heytap,my_company,my_engineering,my_bigball,my_carrier,my_stock,my_preload,my_region,my_product workdir/target/payload.bin > /dev/null

# use python script to convert dat.br to img
python bin/sdat2img_brotli.py -d workdir/source/vendor.new.dat.br -t workdir/source/vendor.transfer.list -o workdir/source/vendor.img

imgs=(
  system
  system_ext
  vendor
  my_manifest
  my_preload
  my_region
  my_stock
  my_product
  my_heytap
  my_bigball
  my_carrier
  my_engineering
  my_company
)

for img in "${imgs[@]}"; do
  ./bin/extract.erofs -i "workdir/target/${img}.img" -o workdir/target -x > /dev/null
  LOGINFO "Extracted target ${img}.img"
done

rm -rf firmwaretarget.zip
rm -rf firmwaresource.zip
rm -rf workdir/target/payload.bin

LOGINFO "Cleaning up target firmware"

clean=(
  my_manifest
  my_preload
  my_region
  my_stock
  my_product
  my_heytap
  my_bigball
  my_carrier
  my_engineering
  my_company
  system
  system_ext
  vendor
)

for img in "${clean[@]}"; do
  rm -rf "workdir/target/${img}.img"
  LOGINFO "Removed ${img}.img"
done
# extract ext image
LOGINFO "Extracting source firmware"
mkdir -p workdir/source/vendor
mkdir -p workdir/source/config
python3 bin/extractor.py workdir/source/vendor.img workdir/source/vendor

# Clean-up
rm -rf workdir/source/vendor.img

LOGINFO "Moving OnePlus partitions to system/"

parts=(
  my_bigball
  my_carrier
  my_company
  my_engineering
  my_heytap
  my_manifest
  my_preload
  my_product
  my_region
  my_stock
)

for part in "${parts[@]}"; do
  mv "workdir/target/$part" workdir/target/system/
  LOGINFO "Moved $part to target firmware"
done

BASE="workdir/target/system"

delete() {
  local target="$1"

  if [[ -e "$target" ]]; then
    LOGINFO "Deleting $target"
    rm -rf "$target"
  else
    LOGINFO "Skipping app $target"
  fi
}

delete_list() {
  local base_path="$1"
  shift

  for item in "$@"; do
    delete "$base_path/$item"
  done
}

for f in "$BASE/my_bigball/del-app-pre/"*; do
  delete "$f"
done

for f in "$BASE/my_bigball/del-app/"*; do
  delete "$f"
done

# my_bigball/priv-app
delete_list "$BASE/my_bigball/priv-app" \
  Google_Files \
  GoogleDialer \
  Messages \
  GlobalSearch

# my_bigball/app
delete_list "$BASE/my_bigball/app" \
  Drive \
  CalendarGoogle \
  Google_Lens \
  Google_Wallet \
  GoogleContacts \
  Meet \
  YTMusic \
  Photos \
  Videos

# my_product/priv-app
delete_list "$BASE/my_product/priv-app" \
  OnePlusCamera

# my_stock/app
delete_list "$BASE/my_stock/app" \
  RomUpdate \
  ChildrenSpace \
  OppoWeather2 \
  OplusOperationManual \
  Calculator2 \
  Clock \
  FileManager \
  SceneMode \
  SmartSideBar

# my_stock/del-app
delete_list "$BASE/my_stock/del-app" \
  OppoRelax \
  OPForum

# my_stock/priv-app
delete_list "$BASE/my_stock/priv-app" \
  Games \
  LinktoWindows

LOGINFO "Copying group and passwd from target to source firmware"
rm -rf workdir/source/vendor/etc/group
rm -rf workdir/source/vendor/etc/passwd
cp -a workdir/target/vendor/etc/group workdir/source/vendor/etc/
cp -a workdir/target/vendor/etc/passwd workdir/source/vendor/etc/

LOGINFO "Deleting prop ro.product.first_api_level in my_manifest"
sed -i '/^ro\.product\.first_api_level=30$/d' workdir/target/my_manifest/build.prop

prop=(
  /my_bigball/build.prop
  /my_carrier/build.prop
  /my_company/build.prop
  /my_engineering/build.prop
  /my_heytap/build.prop
  /my_manifest/build.prop
  /my_preload/build.prop
  /my_product/build.prop
  /my_region/build.prop
  /my_stock/build.prop
)

for path in "${prop[@]}"; do
  echo "import $path" >> workdir/source/vendor/build.prop
  LOGINFO "Adding import prop with $path on workdir/source/vendor/build.prop"
done

LOGINFO "Replacing OnePlus overlays"
rm -rf workdir/source/vendor/overlay/*
cp -a workdir/target/vendor/overlay/* workdir/source/vendor/overlay/

LOGINFO "Adding debug props"
sed -i \
-e 's/^ro\.debuggable=0$/ro.debuggable=1/' \
-e 's/^ro\.force\.debuggable=0$/ro.force.debuggable=1/' \
-e 's/^ro\.adb\.secure=1$/ro.adb.secure=0/' \
workdir/target/system/system/build.prop

#LOGINFO "Removing encryption in fstab"
# todo: add removing

LOGINFO "Building images"
PADDING=3

python3 bin/fspatch.py workdir/source/vendor workdir/source/config/vendor_fsconfig.txt > /dev/null
python3 bin/fspatch.py workdir/target/system workdir/target/config/system_fs_config > /dev/null
python3 bin/fspatch.py workdir/target/system_ext workdir/target/config/system_ext_fs_config > /dev/null

sed -i 's|^\(/system/my_[^ ]*\) u:object_r:system_file:s0|\1(/.*)?    u:object_r:system_file:s0|' workdir/target/config/system_file_contexts

mv workdir/source/config/vendor_fsconfig.txt workdir/source/config/vendor_fs_config
mv workdir/source/config/vendor_contexts.txt workdir/source/config/vendor_file_contexts

build_image() {
  NAME=$1
  ROOTFS=$2
  CONFIG_DIR=$3

  SIZE=$(du -sb "$ROOTFS" | cut -f1)
  PAD_SIZE=$((SIZE + SIZE * PADDING / 100))

  FS_CONFIG="$CONFIG_DIR/${NAME}_fs_config"
  CONTEXTS="$CONFIG_DIR/${NAME}_file_contexts"

  ARGS=""

  [ -f "$FS_CONFIG" ] && ARGS="$ARGS -C $FS_CONFIG"
  [ -f "$CONTEXTS" ] && ARGS="$ARGS -S $CONTEXTS"

  ./bin/make_ext4fs \
    -s \
    -L $NAME \
    -a $NAME \
    -J \
    -T 1 \
    $ARGS \
    -l $PAD_SIZE \
    ${NAME}.img \
    "$ROOTFS"
  echo $PAD_SIZE > $NAME.size

  echo
}

LOGINFO "Building OS images"

build_image \
  "system" \
  "workdir/target/system" \
  "workdir/target/config" > /dev/null

build_image \
  "system_ext" \
  "workdir/target/system_ext" \
  "workdir/target/config" > /dev/null

build_image \
  "vendor" \
  "workdir/source/vendor" \
  "workdir/source/config" > /dev/null

# product is a ext4 image so it does not requires a extraction or build.
mv workdir/target/product.img .

LOGINFO "Building OS super image"
./bin/lpmake --metadata-size=67108864 \
--metadata-slots=2 \
--device-size=8589934592 \
--super-name=super \
--group qti_dynamic_partitions:8589934592 \
--partition system:readonly:$(cat system.size):qti_dynamic_partitions \
--partition system_ext:readonly:$(cat system_ext.size):qti_dynamic_partitions \
--partition vendor:readonly:$(cat vendor.size):qti_dynamic_partitions \
--partition product:readonly:$(stat -c%s product.img):qti_dynamic_partitions \
-i system=system.img \
-i system_ext=system_ext.img \
-i vendor=vendor.img \
-i product=product.img \
-o super.img

LOGINFO "Creating flashable ZIP"
mkdir -p out
mkdir -p out/META-INF
mkdir -p out/META-INF/com/
mv over-the-air/* out/META-INF/com/

LOGINFO "Writing updater-script"
cat <<EOF > out/META-INF/com/google/android/updater-script
ui_print("***********************************************");
ui_print("Target: $TARGET_FP");
ui_print("Source: $SOURCE_FP");
ui_print("***********************************************");
ui_print("Build Date: $BUILD_DATE")
ui_print("Builded on PortMation!")

ui_print("Patching super image unconditionally...");
show_progress(0.100000, 0);
package_extract_file("super.img", "/dev/block/by-name/super");

show_progress(0.020000, 10);
sleep(3);

ui_print("Patching boot image unconditionally...");
package_extract_file("boot.img", "/dev/block/bootdevice/by-name/boot");

set_progress(1.000000);
EOF

cd out/
LOGINFO "Downloading LineageOS boot for miatoll"
curl -# -L -o boot.img https://mirrorbits.lineageos.org/full/miatoll/20260323/boot.img
mv ../super.img .
zip -8 -r "MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip" *
cd ..
mv out/MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip .
rm -rf out/*
mv MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip out/

LOGINFO "Build finished. Out ZIP is in out/ folder."

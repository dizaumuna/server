#!/bin/bash
# buildROM.sh

SOURCE_FP="Redmi/miatoll_global/miatoll:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys"
TARGET_FP="OnePlus/OnePlus8T/OnePlus8T:14/RP1A.201005.001/2111291807:user/release-keys"
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
tar -xvzf pdg.tar.gz > /dev/null
sudo mv payload-dumper-go /usr/local/bin
pip3 install brotli
rm pdg.tar.gz
rm LICENSE
rm README.md


# Change URL1 with your Port ROM url
# Change URL2 with your Stock ROM url
URL1="https://gauss-componentotacostmanual-sg.allawnofs.com/remove-321c974e5931c5438d3cf3b7104102ac/component-ota/24/10/09/c6654c8a15d7487bb5a5c87708ad46af.zip"
URL2="https://bn.d.miui.com/V14.0.3.0.SJZMIXM/miui_JOYEUSEGlobal_V14.0.3.0.SJZMIXM_df17e3fabf_12.0.zip"

if [ ! -f "firmwaretarget.zip" ] || [ ! -f "firmwaresource.zip" ]; then
    LOGINFO "Downloading target firmware"
    curl -# -L -o firmwaretarget.zip "$URL1" > /dev/null
    LOGINFO "Downloading source firmware"
    curl -# -L -o firmwaresource.zip "$URL2" > /dev/null
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

# target firmware should have payload.bin btw else it's gonna fail lmao
unzip firmwaretarget.zip payload.bin -d workdir/target/ > /dev/null

# same as target one
unzip firmwaresource.zip vendor.* -d workdir/source/ > /dev/null


# use pdg to dump partitions from payload.bin
LOGINFO "Extracting target firmware"
payload-dumper-go -o workdir/target/ \
-p system,system_ext,product,vendor,my_manifest,my_heytap,my_company,my_engineering,my_bigball,my_carrier,my_stock,my_preload,my_region,my_product workdir/target/payload.bin > /dev/null

# use python script to convert dat.br to img
python bin/sdat2img_brotli.py -d workdir/source/vendor.new.dat.br -t workdir/source/vendor.transfer.list -o workdir/source/vendor.img

# extract erofs images
./bin/extract.erofs -i workdir/target/system.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/system_ext.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/vendor.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_manifest.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_preload.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_region.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_stock.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_product.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_heytap.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_bigball.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_carrier.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_engineering.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/my_company.img -o workdir/target -x > /dev/null
rm -rf firmwaretarget.zip
rm -rf firmwaresource.zip
rm -rf workdir/target/payload.bin

# Clean-up
rm -rf workdir/target/my_manifest.img
rm -rf workdir/target/my_preload.img
rm -rf workdir/target/my_region.img
rm -rf workdir/target/my_stock.img
rm -rf workdir/target/my_product.img
rm -rf workdir/target/my_heytap.img
rm -rf workdir/target/my_bigball.img
rm -rf workdir/target/my_carrier.img
rm -rf workdir/target/my_engineering.img
rm -rf workdir/target/my_company.img
rm -rf workdir/target/system.img
rm -rf workdir/target/system_ext.img
rm -rf workdir/target/vendor.img

# extract ext image
LOGINFO "Extracting source firmware"
mkdir -p workdir/source/vendor
mkdir -p workdir/source/config
python3 bin/extractor.py workdir/source/vendor.img workdir/source/vendor

# Clean-up
rm -rf workdir/source/vendor.img

LOGINFO "Moving OnePlus partitions to system/"
mv workdir/target/my_bigball workdir/target/system/
mv workdir/target/my_carrier workdir/target/system/
mv workdir/target/my_company workdir/target/system/
mv workdir/target/my_engineering workdir/target/system/
mv workdir/target/my_heytap workdir/target/system/
mv workdir/target/my_manifest workdir/target/system/
mv workdir/target/my_preload workdir/target/system/
mv workdir/target/my_product workdir/target/system/
mv workdir/target/my_region workdir/target/system/
mv workdir/target/my_stock workdir/target/system/


####################################################
#                 Debloating                       #
LOGINFO "Debloating system"
rm -rf workdir/target/system/system/my_bigball/del-app-pre/*
rm -rf workdir/target/system/system/my_bigball/del-app/*

# my_bigball/priv-app
rm -rf workdir/target/system/system/my_bigball/priv-app/Google_Files
rm -rf workdir/target/system/system/my_bigball/priv-app/GoogleDialer
rm -rf workdir/target/system/system/my_bigball/priv-app/Messages
rm -rf workdir/target/system/system/my_bigball/priv-app/GlobalSearch

# my_bigball/app
rm -rf workdir/target/system/system/my_bigball/app/Drive
rm -rf workdir/target/system/system/my_bigball/app/CalendarGoogle
rm -rf workdir/target/system/system/my_bigball/app/Google_Lens
rm -rf workdir/target/system/system/my_bigball/app/Google_Wallet
rm -rf workdir/target/system/system/my_bigball/app/GoogleContacts
rm -rf workdir/target/system/system/my_bigball/app/Meet
rm -rf workdir/target/system/system/my_bigball/app/YTMusic
rm -rf workdir/target/system/system/my_bigball/app/Photos
rm -rf workdir/target/system/system/my_bigball/app/Videos

# my_product/priv-app
rm -rf workdir/target/system/system/my_product/priv-app/OnePlusCamera

# my_stock/app
rm -rf workdir/target/system/system/my_stock/app/RomUpdate
rm -rf workdir/target/system/system/my_stock/app/ChildrenSpace
rm -rf workdir/target/system/system/my_stock/app/OppoWeather2
rm -rf workdir/target/system/system/my_stock/app/OplusOperationManual
rm -rf workdir/target/system/system/my_stock/app/Calculator2
rm -rf workdir/target/system/system/my_stock/app/Clock
rm -rf workdir/target/system/system/my_stock/app/FileManager
rm -rf workdir/target/system/system/my_stock/app/SceneMode
rm -rf workdir/target/system/system/my_stock/app/SmartSideBar

# my_stock/del-app
rm -rf workdir/target/system/system/my_stock/del-app/OppoRelax
rm -rf workdir/target/system/system/my_stock/del-app/OPForum

# my_stock/priv-app
rm -rf workdir/target/system/system/my_stock/priv-app/Games
rm -rf workdir/target/system/system/my_stock/priv-app/LinktoWindows
########################################################

# port rom (real)
LOGINFO "Copying group and passwd from target to source firmware"
rm -rf workdir/source/vendor/etc/group
rm -rf workdir/source/vendor/etc/passwd
cp -a workdir/target/vendor/etc/group workdir/source/vendor/etc/
cp -a workdir/target/vendor/etc/passwd workdir/source/vendor/etc/

LOGINFO "Deleting prop ro.product.first_api_level in my_manifest"
sed -i '/^ro\.product\.first_api_level=30$/d' workdir/target/system/my_manifest/build.prop

LOGINFO "Adding import props to vendor/build.prop"
echo "import /my_bigball/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_carrier/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_company/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_engineering/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_heytap/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_manifest/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_preload/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_product/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_region/build.prop" >> workdir/source/vendor/build.prop
echo "import /my_stock/build.prop" >> workdir/source/vendor/build.prop

LOGINFO "Replacing OnePlus overlays"
rm -rf workdir/source/vendor/overlay/*
cp -a workdir/target/vendor/overlay/* workdir/source/vendor/overlay/

LOGINFO "Adding debug lines"
sed -i \
-e 's/^ro\.debuggable=0$/ro.debuggable=1/' \
-e 's/^ro\.force\.debuggable=0$/ro.force.debuggable=1/' \
-e 's/^ro\.adb\.secure=1$/ro.adb.secure=0/' \
workdir/target/system/system/build.prop

LOGINFO "Removing encryption in fstab"
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


# build super.img
LOGINFO "Building super image"
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

# Create flashable zip
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

zip -8 -r "MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip" *
cd ..
mv out/MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip .
rm -rf out/*
mv MIATOLL-ota_full-global-OxygenOS_14.0-userdebug.zip out/

LOGINFO "Build finished. Out ZIP is in out/ folder."
LOGINFO "Thanks for using my script."

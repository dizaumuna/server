#!/bin/bash
# buildROM.sh

set -euo pipefail

SOURCE_FP="Redmi/miatoll_global/miatoll:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys"
TARGET_FP="qti/missi/missi:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
ANDROID="15"
AUTHOR="diza u muna"
DATE="%Y-%m-%d"

VENDOR="workdir/source/vendor"
BUILTS="builts"

LOGINFO()  { echo "$(date '+%Y-%m-%d-%H') - INFO - $1"; }
LOGWARN()  { echo "$(date '+%Y-%m-%d-%H') - WARN - $1"; }
LOGERROR() { echo "$(date '+%Y-%m-%d-%H') - ERROR - $1"; }

die() { LOGERROR "$1"; exit 1; }

chmod +x bin/*
chmod +x ./*.sh

wget https://github.com/ssut/payload-dumper-go/releases/download/1.3.0/payload-dumper-go_1.3.0_linux_amd64.tar.gz -O pdg.tar.gz > /dev/null
tar -xvzf pdg.tar.gz > /dev/null
sudo mv payload-dumper-go /usr/local/bin
pip3 install brotli
rm pdg.tar.gz LICENSE README.md

URL1="https://bn.d.miui.com/OS2.0.212.0.VOBCNXM/haotian-ota_full-OS2.0.212.0.VOBCNXM-user-15.0-ebd7ade4e1.zip"
URL2="https://bn.d.miui.com/V14.0.3.0.SJZMIXM/miui_JOYEUSEGlobal_V14.0.3.0.SJZMIXM_df17e3fabf_12.0.zip"

if [ ! -f "firmwaretarget.zip" ] || [ ! -f "firmwaresource.zip" ]; then
    LOGINFO "Downloading target firmware"
    curl -# -L -o firmwaretarget.zip "$URL1"
    LOGINFO "Downloading source firmware"
    curl -# -L -o firmwaresource.zip "$URL2"
else
    LOGWARN "Firmware already exists, skipping download"
fi

if [ ! -d "workdir" ]; then
    LOGINFO "Creating workdir"
    mkdir -p workdir/target workdir/source
else
    LOGWARN "Workdir already exists, skipping mkdir"
fi

unzip firmwaretarget.zip payload.bin -d workdir/target/ > /dev/null
unzip firmwaresource.zip vendor.* -d workdir/source/ > /dev/null

LOGINFO "Extracting target firmware"
payload-dumper-go -o workdir/target/ \
    -p system,system_ext,product,vendor \
    workdir/target/payload.bin > /dev/null

python bin/sdat2img_brotli.py -d workdir/source/vendor.new.dat.br -t workdir/source/vendor.transfer.list -o workdir/source/vendor.img

./bin/extract.erofs -i workdir/target/system.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/system_ext.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/product.img -o workdir/target -x > /dev/null
./bin/extract.erofs -i workdir/target/vendor.img -o workdir/target -x > /dev/null

rm -rf firmwaretarget.zip firmwaresource.zip workdir/target/payload.bin
rm -rf workdir/target/my_manifest.img workdir/target/my_preload.img workdir/target/my_region.img
rm -rf workdir/target/my_stock.img workdir/target/my_product.img workdir/target/my_heytap.img
rm -rf workdir/target/my_bigball.img workdir/target/my_carrier.img workdir/target/my_engineering.img
rm -rf workdir/target/my_company.img workdir/target.img workdir/target_ext.img workdir/target/vendor.img

LOGINFO "Extracting source firmware"
mkdir -p workdir/source/vendor workdir/source/config
python3 bin/extractor.py workdir/source/vendor.img workdir/source/vendor
rm -rf workdir/source/vendor.img

LOGINFO "Copying group and passwd"
rm -rf workdir/source/vendor/etc/group workdir/source/vendor/etc/passwd
cp -a workdir/target/vendor/etc/group workdir/source/vendor/etc/
cp -a workdir/target/vendor/etc/passwd workdir/source/vendor/etc/

LOGINFO "Adding debug props"
sed -i \
    -e 's/^ro\.debuggable=0$/ro.debuggable=1/' \
    -e 's/^ro\.force\.debuggable=0$/ro.force.debuggable=1/' \
    -e 's/^ro\.adb\.secure=1$/ro.adb.secure=0/' \
    workdir/target/system/system/build.prop

LOGINFO "Applying vendor port patches"

sed_prop() {
    local FILE="$1" KEY="$2" VAL="$3"
    if grep -q "^${KEY}=" "$FILE"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$FILE"
    else
        echo "${KEY}=${VAL}" >> "$FILE"
    fi
}

patch_build_prop() {
    local F="$VENDOR/build.prop"
    sed_prop "$F" "ro.vendor.build.date"                        "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "$F" "ro.vendor.build.date.utc"                    "26061989"
    sed_prop "$F" "ro.vendor.build.fingerprint"                 "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "$F" "ro.vendor.build.id"                          "AQ3A.240812.002"
    sed_prop "$F" "ro.vendor.build.security_patch"              "2025-06-01"
    sed_prop "$F" "ro.vendor.build.version.incremental"         "OS2.0.212.0.VOBCNXM"
    sed_prop "$F" "ro.vendor.build.version.release"             "15"
    sed_prop "$F" "ro.vendor.build.version.release_or_codename" "15"
    sed_prop "$F" "ro.bootimage.build.date"                     "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "$F" "ro.bootimage.build.date.utc"                 "26061989"
    sed_prop "$F" "ro.bootimage.build.fingerprint"              "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "$F" "ro.product.vendor.name"                      "joyeuse"
    sed_prop "$F" "ro.product.vendor.model"                     "M2003J6B2G"
    sed_prop "$F" "ro.product.vendor.marketname"                "Redmi Note 9 Pro"
    sed_prop "$F" "ro.product.vendor.cert"                      "M2003J6B2G"
    sed_prop "$F" "ro.surface_flinger.enable_frame_rate_override" "false"
    sed_prop "$F" "ro.surface_flinger.set_display_power_timer_ms" "1000"
    sed_prop "$F" "ro.surface_flinger.set_idle_timer_ms"        "4000"
    sed_prop "$F" "ro.surface_flinger.set_touch_timer_ms"       "4000"
    sed_prop "$F" "ro.vendor.audio.voice.change.support"        "true"
    sed_prop "$F" "ro.vendor.audio.voice.change.version"        "2"
    sed_prop "$F" "ro.vendor.audio.voice.change.youme.support"  "true"
    sed_prop "$F" "ro.vendor.audio.voice.volume.boost"          "manual"
    sed_prop "$F" "ro.vendor.audio.sfx.scenario"                "true"
    sed_prop "$F" "ro.vendor.audio.misound.bluetooth.enable"    "true"
    sed_prop "$F" "persist.vendor.fingerprint.sensor_type"      "side"
    sed_prop "$F" "persist.vendor.side.fp.near.feature.support" "true"
    sed_prop "$F" "ro.hardware.fp.sideCap"                      "true"
    sed_prop "$F" "ro.vendor.nfc.RF.conf.items"                 "8"
    sed_prop "$F" "ro.vendor.nfc.customRF"                      "1"
    sed_prop "$F" "ro.vendor.nfc.debounce_field_on"             "1"
    sed_prop "$F" "ro.vendor.nfc.disable.i2c"                   "false"
    sed_prop "$F" "ro.vendor.nfc.dispatch_optim"                "2"
    sed_prop "$F" "ro.vendor.nfc.field_on_debounce"             "800"
    sed_prop "$F" "ro.vendor.nfc.mibeam.version"                "3"
    sed_prop "$F" "ro.vendor.nfc.mibeam"                        "1"
    sed_prop "$F" "ro.vendor.nfc.repair"                        "1"
    sed_prop "$F" "ro.vendor.nfc.secure_display_optim"          "1"
    sed_prop "$F" "ro.vendor.nfc.selectcard"                    "1"
    sed_prop "$F" "ro.vendor.nfc.wallet_fusion"                 "1"
    sed_prop "$F" "ro.telephony.iwlan_operation_mode"           "legacy"
    sed_prop "$F" "sys.haptic.flick.light"                      "7,2"
    sed_prop "$F" "sys.haptic.mesh.heavy"                       "8,2"
    sed_prop "$F" "sys.haptic.mesh.normal"                      "5,2"
    sed_prop "$F" "sys.haptic.mesh.light"                       "5,1"
    sed_prop "$F" "sys.haptic.pickup"                           "2,2"
    sed_prop "$F" "sys.haptic.scroll.edge"                      "7,0"
    sed_prop "$F" "sys.haptic.hold"                             "4,0"
    sed_prop "$F" "persist.vendor.touchfeature.gameturbotool.version" "v3"
    sed_prop "$F" "ro.vendor.sensor.maxbrightness"              "500"
    sed_prop "$F" "persist.vendor.qcom.bluetooth.soc"           "cherokee"
    sed_prop "$F" "vendor.display.disable_hw_recovery_dump"     "1"
    sed_prop "$F" "vendor.display.disable_ui_3d_tonemap"        "1"
    sed_prop "$F" "vendor.display.dataspace_saturation_matrix"  "1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0"
    sed_prop "$F" "vendor.display.comp_mask"                    "0"
    sed_prop "$F" "vendor.display.svi.config"                   "1"
    sed_prop "$F" "vendor.display.svi.config_path"              "/vendor/etc/SVIConfig.xml"
    sed_prop "$F" "vendor.mm.enable.qcom_parser"                "63963135"
    sed_prop "$F" "vendor.pasr.activemode.enabled"              "true"
    sed_prop "$F" "vendor.power.pasr.enabled"                   "true"
    sed_prop "$F" "ro.miui.pm.install.buffer.size"              "49152"
    sed_prop "$F" "ro.miui.pm.install.speedinstall"             "/data/apk-tmp"
}

patch_odm_build_prop() {
    local F="$VENDOR/odm/etc/build.prop"
    [ -f "$F" ] || die "odm/etc/build.prop not found"
    sed_prop "$F" "ro.odm.build.date"                        "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "$F" "ro.odm.build.date.utc"                    "26061989"
    sed_prop "$F" "ro.odm.build.fingerprint"                 "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "$F" "ro.odm.build.id"                          "AQ3A.240812.002"
    sed_prop "$F" "ro.odm.build.tags"                        "release-keys"
    sed_prop "$F" "ro.odm.build.type"                        "user"
    sed_prop "$F" "ro.odm.build.version.incremental"         "OS2.0.212.0.VOBCNXM"
    sed_prop "$F" "ro.odm.build.version.release"             "15"
    sed_prop "$F" "ro.odm.build.version.release_or_codename" "15"
    sed_prop "$F" "ro.product.odm.name"                      "joyeuse"
    sed_prop "$F" "ro.product.odm.model"                     "M2003J6B2G"
    sed_prop "$F" "ro.product.odm.marketname"                "Redmi Note 9 Pro"
    sed_prop "$F" "ro.product.odm.cert"                      "M2003J6B2G"
    for PROP in \
        "debug.game.video.speed=true" \
        "debug.game.video.support=true" \
        "persist.sys.power.default.powermode=1" \
        "persist.vendor.accelerate.charge=true" \
        "persist.vendor.battery.health.optimise=true" \
        "persist.vendor.battery.health=true" \
        "persist.vendor.night.charge=true" \
        "persist.vendor.smartchg=22" \
        "ro.config.hw_quickpoweron=true" \
        "ro.odm.mm.vibrator.audio_haptic_support=true" \
        "ro.vendor.audio.volume_super_index_add=10" \
        "ro.vendor.audio.volume_super_percent=200" \
        "ro.vendor.audio.volume_super_streamtype=8" \
        "sys.haptic.lowPowerMode=true" \
        "sys.haptic.media=true" \
        "sys.haptic.onetrack=true" \
        "vendor.wallpaper.color.flag=BK"; do
        KEY="${PROP%%=*}"
        VAL="${PROP#*=}"
        grep -q "^${KEY}=" "$F" || echo "${KEY}=${VAL}" >> "$F"
    done
}

patch_fstab() {
    for FSTAB in "$VENDOR/etc/fstab.default" "$VENDOR/etc/fstab.emmc"; do
        [ -f "$FSTAB" ] || continue
        sed -i 's|wait,logical,first_stage_mount,avb=vbmeta_system,avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey|wait,logical,first_stage_mount|g' "$FSTAB"
        sed -i 's|wait,logical,first_stage_mount,avb=vbmeta_system|wait,logical,first_stage_mount|g' "$FSTAB"
        sed -i 's|wait,logical,first_stage_mount,avb\b|wait,logical,first_stage_mount|g' "$FSTAB"
        sed -i 's|latemount,wait,check,formattable,fileencryption=ice,wrappedkey,|latemount,wait,check,formattable,wrappedkey,|g' "$FSTAB"
    done
}

patch_selinux_file_contexts() {
    local F="$VENDOR/etc/selinux/vendor_file_contexts"
    [ -f "$F" ] || return
    sed -i 's#(vendor|sustem/vendor)#(vendor|system/vendor)#g' "$F"
}

patch_wifi_cfg() {
    local F="$VENDOR/etc/wifi/WCNSS_qcom_cfg.ini"
    [ -f "$F" ] || return
    sed -i 's/^gChannelBondingMode24GHz=0$/gChannelBondingMode24GHz=1/' "$F"
    sed -i 's/^sae_enabled=0$/sae_enabled=1/' "$F"
}

patch_camera_settings() {
    local F="$VENDOR/etc/camera/camxoverridesettings.txt"
    [ -f "$F" ] || return
    sed -i '/^advanceFeatureMask=0x7E7$/d' "$F"
}

patch_perf_config() {
    local F="$VENDOR/etc/perf/perfconfigstore.xml"
    [ -f "$F" ] || return
    sed -i '/<Prop Name="vendor.iop.enable_iop" Value="0" \/>/d' "$F"
}

patch_init_target_rc() {
    local F="$VENDOR/etc/init/hw/init.target.rc"
    [ -f "$F" ] || return
    sed -i 's|cnss_diag -q -f -t HELIUM|cnss_diag -q -t HELIUM|' "$F"
}

patch_ueventd() {
    local F="$VENDOR/ueventd.rc"
    [ -f "$F" ] || return
    sed -i 's|/dev/diag                 0660   system     oem_2901|/dev/diag                 0666   system     oem_2901|' "$F"
}

copy_builts() {
    [ -d "$BUILTS" ] || die "builts/ not found"

    cp_file() {
        local FILENAME="$1" DST_REL="$2"
        local DST="$VENDOR/$DST_REL"
        local SUBDIR SRC
        SUBDIR="$(dirname "$DST_REL")"
        case "$DST_REL" in
            lib64/*) SRC="$BUILTS/lib64/${SUBDIR#lib64/}/$FILENAME" ;;
            lib/*)   SRC="$BUILTS/lib/${SUBDIR#lib/}/$FILENAME" ;;
            *)       SRC="$BUILTS/$FILENAME" ;;
        esac
        [ -f "$SRC" ] || { echo "Warn: $SRC not found, skipping"; return; }
        mkdir -p "$(dirname "$DST")"
        cp -a "$SRC" "$DST"
    }

    cp_file "perfboostsconfig.xml"      "etc/perf/perfboostsconfig.xml"
    cp_file "commonresourceconfigs.xml" "etc/perf/commonresourceconfigs.xml"
    cp_file "FrameworksResTarget.apk"   "overlay/FrameworksResTarget.apk"
    cp_file "fstab.qcom"                "etc/fstab.qcom"

    for F in $(ls "$BUILTS/lib/soundfx/"); do
        cp_file "$F" "lib/soundfx/$F"
        cp_file "$F" "lib64/soundfx/$F"
    done

    for F in $(ls "$BUILTS/lib/camera/"); do
        cp_file "$F" "lib/camera/$F"
        cp_file "$F" "lib64/camera/$F"
    done

    for F in $(ls "$BUILTS/lib64/camera/" | grep -v '/'); do
        cp_file "$F" "lib64/camera/$F"
    done

    for F in $(ls "$BUILTS/lib64/camera/components/"); do
        cp_file "$F" "lib64/camera/components/$F"
    done
}

DEBLOAT=(
    workdir/target/product/data-app/BaiduIME
    workdir/target/product/data-app/iFlytekIME
    workdir/target/product/data-app/MIService
    workdir/target/product/data-app/MIUICalculator
    workdir/target/product/data-app/MIUICalendar
    workdir/target/product/data-app/MIUICleanMaster
    workdir/target/product/data-app/MIUICompass
    workdir/target/product/data-app/MIUIDeskClock
    workdir/target/product/data-app/MIUIHuanji
    workdir/target/product/data-app/MIUIMiDrive
    workdir/target/product/data-app/MIUINotes
    workdir/target/product/data-app/MIUISecurityManager
    workdir/target/product/data-app/MIUIWeather
    workdir/target/product/data-app/MIUIScanner
    workdir/target/product/data-app/MIUIGallery # tmp
    workdir/target/product/data-app/MIUISoundRecorderTargetSdk30
    workdir/target/product/data-app/MIUIEmail
    workdir/target/product/data-app/wps-lite
    workdir/target/product/app/MIUIFileExplorer
    workdir/target/product/app/MIUIReporter
    workdir/target/product/app/Music
    workdir/target/product/app/SogouIME
    workdir/target/product/app/Updater
    workdir/target/product/app/MiSound
    workdir/target/product/app/TrichromeLibrary64
    workdir/target/product/app/VoiceAssistAndroidT
    workdir/target/product/app/WebViewGoogle64
    workdir/target/product/priv-app/MIShare
    workdir/target/product/priv-app/MIUIBrowser
    workdir/target/product/priv-app/MiuiBarrage
    workdir/target/product/priv-app/MiuiCamera
    workdir/target/product/priv-app/MiuiExtraPhoto
    workdir/target/product/priv-app/NewCall
    workdir/target/product/priv-app/MiuiBarrage
    workdir/target/product/priv-app/GmsCore # tmp
)

for D in "${DEBLOAT[@]}"; do
    rm -rf "$D"
done

patch_build_prop
patch_odm_build_prop
patch_fstab
patch_selinux_file_contexts
patch_wifi_cfg
patch_camera_settings
patch_perf_config
patch_init_target_rc
patch_ueventd
copy_builts

LOGINFO "Building images"
PADDING=3

python3 bin/fspatch.py workdir/source/vendor workdir/source/config/vendor_fsconfig.txt > /dev/null
python3 bin/fspatch.py workdir/target/system workdir/target/config/system_fs_config > /dev/null
python3 bin/fspatch.py workdir/target/system_ext workdir/target/config/system_ext_fs_config > /dev/null

mv workdir/source/config/vendor_fsconfig.txt workdir/source/config/vendor_fs_config
mv workdir/source/config/vendor_contexts.txt workdir/source/config/vendor_file_contexts

build_image() {
    local NAME="$1" ROOTFS="$2" CONFIG_DIR="$3"
    local SIZE PAD_SIZE FS_CONFIG CONTEXTS ARGS=""

    SIZE=$(du -sb "$ROOTFS" | cut -f1)
    PAD_SIZE=$((SIZE + SIZE * PADDING / 100))
    FS_CONFIG="$CONFIG_DIR/${NAME}_fs_config"
    CONTEXTS="$CONFIG_DIR/${NAME}_file_contexts"

    [ -f "$FS_CONFIG" ] && ARGS="$ARGS -C $FS_CONFIG"
    [ -f "$CONTEXTS" ] && ARGS="$ARGS -S $CONTEXTS"

    ./bin/make_ext4fs -s -L "$NAME" -a "$NAME" -J -T 1 $ARGS -l "$PAD_SIZE" "${NAME}.img" "$ROOTFS"
    echo "$PAD_SIZE" > "${NAME}.size"
}

build_image "system"     "workdir/target/system"        "workdir/target/config" > /dev/null
build_image "system_ext" "workdir/target/system_ext"    "workdir/target/config" > /dev/null
build_image "product"    "workdir/target/product"       "workdir/target/config" > /dev/null
build_image "vendor"     "workdir/source/vendor"        "workdir/source/config" > /dev/null

LOGINFO "Building super image"
./bin/lpmake \
    --metadata-size=67108864 \
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
mkdir -p out/META-INF/com/
mv over-the-air/* out/META-INF/com/

cat <<EOF > out/META-INF/com/google/android/updater-script
ui_print("***********************************************");
ui_print("Target: $TARGET_FP");
ui_print("Source: $SOURCE_FP");
ui_print("***********************************************");
ui_print("Build date: $DATE");

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
zip -8 -r "MIATOLL-ota_full-global-HyperOS-2.0.212.0.VOBCNXM-userdebug.zip" *
cd ..
mv out/MIATOLL-ota_full-global-HyperOS-2.0.212.0.VOBCNXM-userdebug.zip .
rm -rf out/*
mv MIATOLL-ota_full-global-HyperOS-2.0.212.0.VOBCNXM-userdebug.zip out/

LOGINFO "Build finished. Out ZIP is in out/ folder."

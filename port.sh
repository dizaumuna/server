#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# ColorOS / OxygenOS / Realme UI
# Author: dizaumuna
#
 
set -e
trap 'echo "[ERROR] Line $LINENO: $BASH_COMMAND" >&2' ERR
trap 'echo "[port.sh] Script interrupted." >&2; exit 1' SIGINT
 
if [[ "$OSTYPE" == "darwin"* ]]; then
    shopt -s expand_aliases
    alias sed=gsed grep=ggrep find=gfind du=gdu stat=gstat date=gdate
fi
 
WORK_DIR=$(pwd)
BUILD_START=${SECONDS}
PADDING=3
EXTRA=10485760
VENDOR="baserom/vendor"
 
chmod +x bin/*
 
log_info()    { echo -e "  - $1"; }
log_info_in() { echo -e "    - $1"; }
 
BASEROM="${1:-}"
PORTROM="${2:-}"
 
if [[ -z "$BASEROM" || -z "$PORTROM" ]]; then
    echo "Usage: $0 <baserom> <portrom>"
    echo "  baserom : path to base ROM zip"
    echo "  portrom : path to port ROM zip"
    exit 1
fi
 
check_tools() {
    local missing=()
    for tool in "$@"; do
        command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Missing tools: ${missing[*]}"
        log_info "Run bin/install_dependencies.sh first."
        exit 1
    fi
}
 
get_prop() {
    local file="$1" key="$2"
    { grep "^${key}=" "$file" 2>/dev/null || true; } | awk 'NR==1' | cut -d'=' -f2-
}
 
set_prop() {
    local file="$1" prop="$2"
    grep -q "^${prop%%=*}=" "$file" || echo "$prop" >> "$file"
}
 
force_prop() {
    local file="$1" prop="$2"
    local key="${prop%%=*}"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${prop}|" "$file"
    else
        echo "$prop" >> "$file"
    fi
}
 
detect_device() {
    local zip="$1"
    local name
    name=$(basename "$zip")
    if [[ "$name" =~ [Mm][Ii][Uu][Ii]_([A-Za-z0-9]+)[Gg]lobal ]]; then
        echo "${BASH_REMATCH[1],,}"
    elif [[ "$name" =~ [Mm][Ii][Uu][Ii]_([A-Za-z0-9]+)_ ]]; then
        echo "${BASH_REMATCH[1],,}"
    elif [[ "$name" =~ ^([a-zA-Z0-9_]+)_ ]]; then
        echo "${BASH_REMATCH[1],,}"
    else
        echo "joyeuse"
    fi
}
 
load_config() {
    local device="$1"
    local cfg="target/${device}/config.sh"
    if [[ ! -f "$cfg" ]]; then
        log_info "Target config not found: $cfg"
        exit 1
    fi
    source "$cfg"
    cat "$cfg"
}
 
detect_img_type() {
    local img="$1"

    if command -v file >/dev/null 2>&1; then
        local info
        info=$(file -b "$img")

        if echo "$info" | grep -qi "erofs"; then
            echo "erofs"
            return
        fi

        if echo "$info" | grep -qi "ext4"; then
            echo "ext"
            return
        fi
    fi

    local name
    name=$(basename "$img")

    if [[ "$name" == *my_manifest* || "$name" == *my_heytap* || "$name" == *my_engineering* ]]; then
        echo "erofs"
        return
    fi
    
    if hexdump -C "$img" 2>/dev/null | head -n 20 | grep -qi "EROFS"; then
        echo "erofs"
        return
    fi

    echo "ext"
}
 
extract_img() {
    local img="$1"
    local outdir="$2"
    local name
    name=$(basename "$img" .img)
 
    if [[ ! -f "$img" ]]; then
        log_info_in "$img not found, skipping."
        return
    fi
 
    local fstype
    fstype=$(detect_img_type "$img")
 
    mkdir -p "$outdir/$name"
 
    if [[ "$fstype" == "erofs" ]]; then
        log_info_in "Extracting $name.img"
        bin/extract.erofs -i "$img" -o "$outdir/$name" -x > /dev/null 2>&1 \
            || { log_info "extract.erofs failed on $img"; exit 1; }
        mkdir -p portrom/vendor/
        bin/extract.erofs -i portrom/vendor.img -o portrom/vendor -x > /dev/null 2>&1
    else
        log_info_in "Extracting $name.img"
        mkdir -p "$outdir/config"
        python3 bin/extractor.py "$img" "$outdir/$name/" \
            || { log_info "extractor.py failed on $img"; exit 1; }
    fi
 
    rm -f "$img"
}
 
extract_baserom_datbr() {
    local zip="$1"
    log_info "Processing $TARGET_DEVICE_NAME firmware"
    mkdir -p baserom/raw baserom/vendor baserom/config
 
    unzip -q "$zip" -d baserom/raw > /dev/null
 
    for f in baserom/raw/*; do
        fname=$(basename "$f")
        name="${fname%%.*}"
        ext="${fname#*.}"
        if [[ "$name" =~ [0-9]$ ]]; then
            newname=$(echo "$name" | sed 's/[0-9]\+\(\.[^0-9]\+\)/\1/g' | sed 's/\.\./\./g')
            mv -f "$f" "baserom/raw/${newname}.${ext}"
        fi
    done
 
    if [[ -f baserom/raw/vendor.new.dat.br ]]; then
        log_info_in "Decompressing vendor.new.dat.br"
        python3 bin/sdat2img_brotli.py \
            -d baserom/raw/vendor.new.dat.br \
            -t baserom/raw/vendor.transfer.list \
            -o baserom/vendor.img
    else
        log_info "vendor.new.dat.br not found!"
        exit 1
    fi
}
 
extract_baserom_payload() {
    local zip="$1"
    log_info "Processing $TARGET_DEVICE_NAME firmware"
    mkdir -p baserom/raw
    unzip -q "$zip" payload.bin -d baserom/raw > /dev/null
    bin/payload-dumper-go -p vendor -o baserom/ baserom/raw/payload.bin > /dev/null
}
 
extract_baserom_img() {
    local zip="$1"
    log_info "Processing $TARGET_DEVICE_NAME firmware"
    mkdir -p baserom/raw
    unzip -q "$zip" "vendor.img" -d baserom/raw 2>/dev/null || \
    unzip -q "$zip" "vendor_a.img" -d baserom/raw 2>/dev/null || true
    find baserom/raw -name "vendor*.img" -exec mv -f {} baserom/vendor.img \;
}
 
extract_portrom() {
    local zip="$1"
    local type="$2"
    log_info "Processing OnePlus 12R firmware"
    mkdir -p portrom
 
    if [[ "$type" == "payload" ]]; then
        unzip -q "$zip" payload.bin -d portrom/
        local parts="system,system_ext,vendor,product"
        for part in my_manifest my_heytap my_engineering my_bigball my_carrier my_stock my_region my_product; do
            parts="${parts},${part}"
        done
        bin/payload-dumper-go -p "$parts" -o portrom/ portrom/payload.bin > /dev/null
        rm -f portrom/payload.bin
    elif [[ "$type" == "img" ]]; then
        local targets=()
        for part in system system_ext vendor product my_manifest my_product my_stock my_region my_company my_preload; do
            targets+=("${part}.img" "${part}_a.img" "${part}_b.img")
        done
        unzip -q "$zip" "${targets[@]}" -d portrom/ 2>/dev/null || true
        find portrom/ -name "*_a.img" | while read -r f; do
            base=$(basename "$f" _a.img)
            mv -f "$f" "portrom/${base}.img"
        done
    else
        log_info "Unknown portrom type: $type"
        exit 1
    fi
}
 
move_my_partitions_to_system() {
    mv portrom/my_product/my_product     portrom/system/system/
    mv portrom/my_manifest/my_manifest   portrom/system/system/
    mv portrom/my_bigball/my_bigball     portrom/system/system/
    mv portrom/my_carrier/my_carrier     portrom/system/system/
    mv portrom/my_heytap/my_heytap       portrom/system/system/
    mv portrom/my_stock/my_stock         portrom/system/system/
    mv portrom/my_engineering/my_engineering portrom/system/system/
    mv portrom/my_region/my_region       portrom/system/system/
}
 
patch_file_contexts() {
    log_info "Patching file contexts"
 
    if [[ -f baserom/config/vendor_fsconfig.txt ]]; then
        mv baserom/config/vendor_fsconfig.txt baserom/config/vendor_fs_config
    fi
    if [[ -f baserom/config/vendor_contexts.txt ]]; then
        mv baserom/config/vendor_contexts.txt baserom/config/vendor_file_contexts
    fi
 
    [[ -f baserom/config/vendor_file_contexts ]] && \
        python3 bin/fspatch.py baserom/vendor baserom/config/vendor_fs_config > /dev/null
 
    python3 bin/fspatch.py portrom/system/system       portrom/system/config/system_fs_config > /dev/null
    python3 bin/fspatch.py portrom/system_ext/system_ext portrom/system_ext/config/system_ext_fs_config > /dev/null
    python3 bin/fspatch.py portrom/product/product     portrom/product/config/product_fs_config > /dev/null
 
    local sys_ctx="portrom/system/config/system_file_contexts"
    if [[ -f "$sys_ctx" ]]; then
        sed -i 's|^\(/system/my_[^ ]*\) u:object_r:system_file:s0|\1(/.*)?    u:object_r:system_file:s0|' "$sys_ctx"
    fi
}
 
patch_props() {
    local FILE="$VENDOR/build.prop"

    log_in "Replacing ro.vendor.build.security_patch 2023-02-01 with 2023-04-01 in vendor/build.prop"
    sed -i 's/ro.vendor.build.security_patch=2023-02-01/ro.vendor.build.security_patch=2023-04-01/' "$FILE"
    log_in "Replacing ro.product.board=joyeuse with miatoll in vendor/build.prop"
    sed -i 's/ro.product.board=joyeuse/ro.product.board=miatoll/' "$FILE"
    log_in "Replacing joyeuse/special_ro.prop comment with miatoll in vendor/build.prop"
    sed -i 's|# from device/xiaomi/joyeuse/special_ro.prop|# from device/xiaomi/miatoll/special_ro.prop|' "$FILE"
    log_in "Replacing joyeuse/system_12.prop comment with miatoll in vendor/build.prop"
    sed -i 's|# from device/xiaomi/joyeuse/system_12.prop|# from device/xiaomi/miatoll/system_12.prop|' "$FILE"
    log_in "Replacing '# enable temp dds' block with thermal configs block in vendor/build.prop"
    sed -i 's/# enable temp dds/#thermal configs path\nsys.thermal.data.path=\/data\/vendor\/thermal\/\n\n#enable temp dds/' "$FILE"
    log_in "Removing persist.vendor.radio.manual_nw_rej_ct=1 from vendor/build.prop"
    sed -i '/persist.vendor.radio.manual_nw_rej_ct=1/d' "$FILE"
    log_in "Replacing ro.build.version.release=12 with 15 in vendor/build.prop"
    sed -i 's/ro.build.version.release=12/ro.build.version.release=15/' "$FILE"
    log_in "Replacing end of joyeuse/system_12.prop comment with miatoll in vendor/build.prop"
    sed -i 's|# end of device/xiaomi/joyeuse/system_12.prop|# end of device/xiaomi/miatoll/system_12.prop|' "$FILE"
    log_in "Replacing joyeuse/special_rw.prop comment with miatoll in vendor/build.prop"
    sed -i 's|# from device/xiaomi/joyeuse/special_rw.prop|# from device/xiaomi/miatoll/special_rw.prop|' "$FILE"
    log_in "Replacing ro.vendor.build.date with miatoll date in vendor/build.prop"
    sed -i 's/ro.vendor.build.date=Tue Mar  7 12:12:31 CST 2023/ro.vendor.build.date=Mon Apr 10 17:14:21 CST 2023/' "$FILE"
    log_in "Replacing ro.vendor.build.date.utc with miatoll value in vendor/build.prop"
    sed -i 's/ro.vendor.build.date.utc=1678162351/ro.vendor.build.date.utc=1681118061/' "$FILE"
    log_in "Replacing ro.vendor.build.fingerprint with miatoll in vendor/build.prop"
    sed -i 's|ro.vendor.build.fingerprint=Redmi/joyeuse_global/joyeuse:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys|ro.vendor.build.fingerprint=Redmi/miatoll_global/miatoll:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys|' "$FILE"
    log_in "Replacing ro.vendor.build.id=RKQ1.211019.001 with AQ3A.240912.001 in vendor/build.prop"
    sed -i 's/ro.vendor.build.id=RKQ1.211019.001/ro.vendor.build.id=AQ3A.240912.001/' "$FILE"
    log_in "Removing ro.vendor.build.version.incremental from vendor/build.prop"
    sed -i '/ro.vendor.build.version.incremental=V14.0.3.0.SJZMIXM/d' "$FILE"
    log_in "Replacing ro.vendor.build.version.release_or_codename=12 with 15 in vendor/build.prop"
    sed -i 's/ro.vendor.build.version.release_or_codename=12/ro.vendor.build.version.release_or_codename=15/' "$FILE"
    log_in "Replacing ro.vendor.build.version.sdk=30 with 35 in vendor/build.prop"
    sed -i 's/ro.vendor.build.version.sdk=30/ro.vendor.build.version.sdk=35/' "$FILE"
    log_in "Replacing ro.product.vendor.device=joyeuse with miatoll in vendor/build.prop"
    sed -i 's/ro.product.vendor.device=joyeuse/ro.product.vendor.device=miatoll/' "$FILE"
    log_in "Replacing ro.product.vendor.model with Redmi Note 9 Pro Max in vendor/build.prop"
    sed -i 's/ro.product.vendor.model=Redmi Note 9 Pro$/ro.product.vendor.model=Redmi Note 9 Pro Max/' "$FILE"
    log_in "Replacing ro.product.vendor.name=joyeuse_global with miatoll in vendor/build.prop"
    sed -i 's/ro.product.vendor.name=joyeuse_global/ro.product.vendor.name=miatoll/' "$FILE"
    log_in "Replacing ro.product.vendor.marketname with Redmi Note 9 Pro Max in vendor/build.prop"
    sed -i 's/ro.product.vendor.marketname=$/ro.product.vendor.marketname=Redmi Note 9 Pro Max/' "$FILE"
    log_in "Adding # ro.product.mod_device=miatoll after marketname in vendor/build.prop"
    sed -i '/ro.product.vendor.marketname=Redmi Note 9 Pro Max/a # ro.product.mod_device=miatoll' "$FILE"
    log_in "Replacing ro.bootimage.build.date with miatoll date in vendor/build.prop"
    sed -i 's/ro.bootimage.build.date=Tue Mar 7 12:12:31 CST 2023/ro.bootimage.build.date=Mon Apr 10 17:14:21 CST 2023/' "$FILE"
    log_in "Replacing ro.bootimage.build.date.utc with miatoll value in vendor/build.prop"
    sed -i 's/ro.bootimage.build.date.utc=1678162351/ro.bootimage.build.date.utc=1681118061/' "$FILE"
    log_in "Replacing ro.bootimage.build.fingerprint with miatoll in vendor/build.prop"
    sed -i 's|ro.bootimage.build.fingerprint=Redmi/joyeuse_global/joyeuse:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys|ro.bootimage.build.fingerprint=Redmi/miatoll_global/miatoll:12/RKQ1.211019.001/V14.0.3.0.SJZMIXM:user/release-keys|' "$FILE"
    log_in "Replacing ro.control_privapp_permissions=enforce with empty in vendor/build.prop"
    sed -i 's/ro.control_privapp_permissions=enforce/ro.control_privapp_permissions=/' "$FILE"
    log_in "Replacing ro.frp.pst active line with commented out in vendor/build.prop"
    sed -i 's|^ro.frp.pst=/dev/block/bootdevice/by-name/frp|#ro.frp.pst=/dev/block/bootdevice/by-name/frp|' "$FILE"
    log_in "Removing ro.product.mod_device=joyeuse_global from vendor/build.prop"
    sed -i '/ro.product.mod_device=joyeuse_global/d' "$FILE"
    log_in "Removing ro.vendor.se.type=HCE,UICC from vendor/build.prop"
    sed -i '/ro.vendor.se.type=HCE,UICC/d' "$FILE"
        log_in "Adding miatoll tweak props block at end of vendor/build.prop"
    cat >> "$FILE" << 'EOF'
persist.sys.disable_rescue=true
persist.vendor.fingerprint.sensor_type=side
#vendor.display.enable_default_color_mode=0
persist.sys.ui.hw=true
persist.sys.ui.vsync=true
debug.composition.type=gpu
debug.egl.hw=1
dalvik.vm.heapsize=512m
dalvik.vm.execution-mode=int:jit
persist.sys.strictmode.enable=true
persist.sys.stay_on_while_plugged_in=1
persist.audio.fluence.speaker=true
persist.audio.fluence.headset=true
persist.sys.audio.deep_buffer=true
persist.sys.usb.mtp=1
persist.sys.usb.config=mtp,adb
ro.sf.enable_hwc_vds=true
ro.sf.render_engine=parallel
debug.sf.hw=1
hwui.render_dirty_regions=false
persist.sys.ui.hw=1
ro.hwui.texture_cache_size=88
ro.hwui.layer_cache_size=58
ro.hwui.r_buffer_cache_size=9
ro.hwui.gradient_cache_size=1
persist.sys.oplus.nandswap.condition=true
persist.xd.d2w=true
persist.sys.fw.bg_apps_limit=48
ro.vendor.qti.sys.fw.bservice_enable=true
persist.sys.fw.empty_app_percent=50
persist.sys.fw.use_trim_settings=true
persist.sys.fw.trim_empty_percent=100
persist.sys.fw.trim_enable_memory=2147483648
persist.sys.fw.trim_cache_percent=100
persist.sys.fw.bservice_age=120000
persist.sys.fw.bservice_limit=6
persist.sys.fw.bservice_enable=true
# this firmware is builded on Builder-miatoll
# the owner of Builder-miatoll is diza u muna
EOF
}
 
patch_odm() {
        local FILE="$VENDOR/odm/etc/build.prop"

    log_in "Replacing odm/etc/build.prop content with miatoll version"
    cat > "$FILE" << 'EOF'
ro.soc.model=SDM720G
ro.oplus.display.screenSizeInches.primary=6.67
ro.build.device_family=OPSM8550
ro.product.oplus.cpuinfo=SDM720G
ro.vendor.qti.va_odm.support=1
import /my_bigball/build.prop
import /my_carrier/build.prop
import /my_company/build.prop
import /my_engineering/build.prop
import /my_heytap/build.prop
import /my_preload/build.prop
import /my_product/build.prop
import /my_region/build.prop
import /my_stock/build.prop
import /my_manifest/build.prop
import /vendor/custom_props/properties/${ro.boot.hwname}_build.prop
EOF
}

add_custom_props () {
    mkdir -p custom_props && mkdir -p custom_props/properties/
    log_in "Adding custom_props for miatoll devices"
    echo "ro.vendor.oplus.camera.frontCamSize=16MP" >> custom_props/properties/curtana_build.prop
    echo "ro.vendor.oplus.camera.backCamSize=64MP+8MP+5MP+2MP" >> custom_props/properties/curtana_build.prop
    echo "ro.vendor.oplus.market.name=Redmi Note 9S/9Pro/10Lite" >> custom_props/properties/curtana_build.prop
    echo "ro.vendor.oplus.market.enname=Redmi Note 9S/9Pro/10Lite" >> custom_props/properties/curtana_build.prop
    echo "ro.product.model=M2003J6A1G" >> custom_props/properties/curtana_build.prop

    echo "ro.vendor.oplus.camera.frontCamSize=32MP" >> custom_props/properties/excalibur_build.prop
    echo "ro.vendor.oplus.camera.backCamSize=64MP+8MP+5MP+2MP" >> custom_props/properties/excalibur_build.prop
    echo "ro.vendor.oplus.market.name=Redmi Note 9 Pro Max" >> custom_props/properties/excalibur_build.prop
    echo "ro.vendor.oplus.market.enname=Redmi Note 9 Pro Max" >> custom_props/properties/excalibur_build.prop
    echo "ro.product.model=M2003J6B1I" >> custom_props/properties/excalibur_build.prop

    echo "ro.vendor.oplus.camera.frontCamSize=16MP" >> custom_props/properties/gram_build.prop
    echo "ro.vendor.oplus.camera.backCamSize=48MP+8MP+5MP+2MP" >> custom_props/properties/gram_build.prop
    echo "ro.vendor.oplus.market.name=Xiaomi Poco M2 Pro" >> custom_props/properties/gram_build.prop
    echo "ro.vendor.oplus.market.enname=Xiaomi Poco M2 Pro" >> custom_props/properties/gram_build.prop
    echo "ro.product.model=POCO M2 Pro" >> custom_props/properties/gram_build.prop

    echo "ro.vendor.oplus.camera.frontCamSize=16MP" >> custom_props/properties/joyeuse_build.prop
    echo "ro.vendor.oplus.camera.backCamSize=64MP+8MP+5MP+2MP" >> custom_props/properties/joyeuse_build.prop
    echo "ro.vendor.oplus.market.name=Redmi Note 9 Pro" >> custom_props/properties/joyeuse_build.prop
    echo "ro.vendor.oplus.market.enname=Redmi Note 9 Pro" >> custom_props/properties/joyeuse_build.prop
    echo "ro.product.model=M2003J6B2G" >> custom_props/properties/joyeuse_build.prop
}

patch_odm_media_profiles() {
    local FILE="$VENDOR/odm/etc/media_profiles_V1_0.xml"

    log_in "Replacing FIXME comment with author signature in odm/etc/media_profiles_V1_0.xml"
    sed -i 's|        FIXME:\n.*\n.*\n.*\n.*||' "$FILE"
    python3 -c "
import re, sys
content = open('$FILE').read()
content = re.sub(
    r'FIXME:.*?for other applications, we do\s*\n\s*not perform any checks at all\.',
    'authored by diza u muna',
    content, flags=re.DOTALL
)
open('$FILE', 'w').write(content)
"
}

patch_audio_effects() {
    local FILE="$VENDOR/etc/audio_effects.xml"

    log_in "Adding dirac library entry in etc/audio_effects.xml"
    sed -i 's|        <library name="misoundfx" path="libmisoundfx.so"/>|        <library name="misoundfx" path="libmisoundfx.so"/>\n        <library name="dirac" path="libdirac.so"/>|' "$FILE"

    log_in "Adding dirac effect entry in etc/audio_effects.xml"
    sed -i 's|        <effect name="misoundfx" library="misoundfx" uuid="5b8e36a5-144a-4c38-b1d7-0002a5d5c51b"/>|        <effect name="misoundfx" library="misoundfx" uuid="5b8e36a5-144a-4c38-b1d7-0002a5d5c51b"/>\n        <effect name="dirac" library="dirac" uuid="e069d9e0-8329-11df-9168-0002a5d5c51b"/>|' "$FILE"
}

patch_audio_io_policy() {
    local FILE="$VENDOR/etc/audio_io_policy.conf"

    log_in "Replacing voip_rx flags order in etc/audio_io_policy.conf"
    sed -i 's/flags AUDIO_OUTPUT_FLAG_VOIP_RX|AUDIO_OUTPUT_FLAG_DIRECT/flags AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_VOIP_RX/' "$FILE"

    log_in "Replacing compress_offload_24 formats with full list in etc/audio_io_policy.conf"
    sed -i 's/formats AUDIO_FORMAT_PCM_24_BIT_OFFLOAD|AUDIO_FORMAT_FLAC|AUDIO_FORMAT_ALAC|AUDIO_FORMAT_APE|AUDIO_FORMAT_VORBIS|AUDIO_FORMAT_WMA|AUDIO_FORMAT_WMA_PRO/formats AUDIO_FORMAT_MP3|AUDIO_FORMAT_PCM_24_BIT_OFFLOAD|AUDIO_FORMAT_FLAC|AUDIO_FORMAT_ALAC|AUDIO_FORMAT_APE|AUDIO_FORMAT_AAC_LC|AUDIO_FORMAT_AAC_HE_V1|AUDIO_FORMAT_AAC_HE_V2|AUDIO_FORMAT_VORBIS|AUDIO_FORMAT_WMA|AUDIO_FORMAT_WMA_PRO|AUDIO_FORMAT_AAC_ADTS_LC|AUDIO_FORMAT_AAC_ADTS_HE_V1|AUDIO_FORMAT_AAC_ADTS_HE_V2/' "$FILE"

    log_in "Removing record_24bit block from etc/audio_io_policy.conf"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(r'  record_24bit \{[^}]+\}\n', '', content)
open('$FILE', 'w').write(content)
"

    log_in "Removing record_32bit block from etc/audio_io_policy.conf"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(r'  record_32bit \{[^}]+\}\n', '', content)
open('$FILE', 'w').write(content)
"

    log_in "Replacing record_compress_16 sampling_rates with 48000|96000 in etc/audio_io_policy.conf"
    sed -i '/record_compress_16/,/}/ s/sampling_rates 8000|16000|32000|44100|48000|88200|96000|176400|192000/sampling_rates 48000|96000/' "$FILE"

    log_in "Adding voip_tx and low_latency_voip_tx blocks at end of etc/audio_io_policy.conf"
    sed -i 's/^}$/  voip_tx {\n    flags AUDIO_INPUT_FLAG_VOIP_TX\n    formats AUDIO_FORMAT_PCM_16_BIT\n    sampling_rates 8000|16000|32000|48000\n    bit_width 16\n    app_type 69946\n  }\n  low_latency_voip_tx {\n    flags AUDIO_INPUT_FLAG_VOIP_TX|AUDIO_INPUT_FLAG_FAST\n    formats AUDIO_FORMAT_PCM_16_BIT\n    sampling_rates 48000\n    bit_width 16\n    app_type 69946\n  }\n}/' "$FILE"
}

patch_audio_platform_info() {
    local FILE="$VENDOR/etc/audio_platform_info_intcodec.xml"

    log_in "Replacing input_mic_max_count 4 with 2 in etc/audio_platform_info_intcodec.xml"
    sed -i 's/<param key="input_mic_max_count" value="4"\/>/<param key="input_mic_max_count" value="2"\/>/' "$FILE"

    log_in "Removing CTS test device entry from etc/audio_platform_info_intcodec.xml"
    sed -i '/<!-- Add for CTS test -->/d' "$FILE"
    sed -i '/SND_DEVICE_IN_VOICE_RECOG_USB_HEADSET_MIC_CTS/d' "$FILE"
}

patch_audio_policy_configuration() {
    local FILE="$VENDOR/etc/audio_policy_configuration.xml"

    log_in "Replacing copyright year 2016-2017, 2019 with 2016-2020 in etc/audio_policy_configuration.xml"
    sed -i 's/Copyright (c) 2016-2017, 2019/Copyright (c) 2016-2020/' "$FILE"

    log_in "Adding call_screen_mode_supported to globalConfiguration in etc/audio_policy_configuration.xml"
    sed -i 's/<globalConfiguration speaker_drc_enabled="true"\/>/<globalConfiguration speaker_drc_enabled="true" call_screen_mode_supported="true"\/>/' "$FILE"

    log_in "Adding Primary Audio HAL comment before primary module in etc/audio_policy_configuration.xml"
    sed -i 's/        <module name="primary" halVersion="2.0">/        <!-- Primary Audio HAL -->\n        <module name="primary" halVersion="2.0">/' "$FILE"

    log_in "Replacing attachedDevices order and removing Speaker Safe, adding FM Tuner in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''            <attachedDevices>
                <item>Speaker</item>
                <item>Speaker Safe</item>
                <item>Earpiece</item>
                <item>Telephony Tx</item>
                <item>Built-In Mic</item>
                <item>Built-In Back Mic</item>'''
new = '''            <attachedDevices>
                <item>Earpiece</item>
                <item>Speaker</item>
                <item>Telephony Tx</item>
                <item>Built-In Mic</item>
                <item>Built-In Back Mic</item>'''
content = content.replace(old, new)
content = content.replace('                <item>Telephony Rx</item>', '                <item>FM Tuner</item>\n                <item>Telephony Rx</item>', 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing primary output and voip_rx mixPort definitions in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''                <mixPort name=\"primary output\" role=\"source\" flags=\"AUDIO_OUTPUT_FLAG_PRIMARY|AUDIO_OUTPUT_FLAG_FAST\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>'''
new = '''                <mixPort name=\"voip_rx\" role=\"source\"
                         flags=\"AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_VOIP_RX\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000,32000,48000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO\"/>
                </mixPort>
                <mixPort name=\"primary output\" role=\"source\" flags=\"AUDIO_OUTPUT_FLAG_FAST|AUDIO_OUTPUT_FLAG_PRIMARY\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_24_BIT_PACKED\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>'''
content = content.replace(old, new)
open('$FILE', 'w').write(content)
"

    log_in "Replacing raw mixPort flags in etc/audio_policy_configuration.xml"
    sed -i 's/flags="AUDIO_OUTPUT_FLAG_RAW|AUDIO_OUTPUT_FLAG_FAST"/flags="AUDIO_OUTPUT_FLAG_FAST"/' "$FILE"

    log_in "Removing hifi_playback from before deep_buffer, adding after deep_buffer with mmap/compress/direct_pcm in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
content = content.replace('                <mixPort name=\"hifi_playback\" role=\"source\" />\n                <mixPort name=\"deep_buffer\"', '                <mixPort name=\"deep_buffer\"', 1)
old_deep = '                             samplingRates=\"44100,48000\"\n                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>\n                </mixPort>'
new_deep = '''                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>
                <mixPort name=\"mmap_no_irq_out\" role=\"source\" flags=\"AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_MMAP_NOIRQ\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>
                <mixPort name=\"hifi_playback\" role=\"source\" />
                <mixPort name=\"compress_passthrough\" role=\"source\"
                        flags=\"AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_COMPRESS_OFFLOAD|AUDIO_OUTPUT_FLAG_NON_BLOCKING\">
                    <profile name=\"\" format=\"dynamic\"
                             samplingRates=\"dynamic\" channelMasks=\"dynamic\"/>
                </mixPort>
                <mixPort name=\"direct_pcm\" role=\"source\"
                        flags=\"AUDIO_OUTPUT_FLAG_DIRECT\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_8_24_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000,352800,384000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_24_BIT_PACKED\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000,352800,384000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                  <profile name=\"\" format=\"AUDIO_FORMAT_PCM_32_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000,352800,384000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                </mixPort>'''
content = content.replace(old_deep, new_deep, 1)
open('$FILE', 'w').write(content)
"

    log_in "Adding FLAC/ALAC/APE/DTS/DTS_HD/AAC_ADTS profiles and dsd_compress_passthrough to compressed_offload in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '                    <profile name=\"\" format=\"AUDIO_FORMAT_AAC_HE_V2\"\n                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"\n                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>\n                </mixPort>\n                <mixPort name=\"voice_tx\"'
new = '''                    <profile name=\"\" format=\"AUDIO_FORMAT_FLAC\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_ALAC\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_APE\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000,128000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_AAC_HE_V2\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_DTS\"
                             samplingRates=\"32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_DTS_HD\"
                             samplingRates=\"32000,44100,48000,64000,88200,96000,128000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_2POINT1,AUDIO_CHANNEL_OUT_QUAD,AUDIO_CHANNEL_OUT_PENTA,AUDIO_CHANNEL_OUT_5POINT1,AUDIO_CHANNEL_OUT_6POINT1,AUDIO_CHANNEL_OUT_7POINT1\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_AAC_ADTS_LC\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_AAC_ADTS_HE_V1\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_AAC_ADTS_HE_V2\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,64000,88200,96000\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                </mixPort>
                <mixPort name=\"dsd_compress_passthrough\" role=\"source\"
                         flags=\"AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_COMPRESS_OFFLOAD|AUDIO_OUTPUT_FLAG_NON_BLOCKING\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_DSD\"
                             samplingRates=\"2822400,5644800\"
                             channelMasks=\"AUDIO_CHANNEL_OUT_STEREO,AUDIO_CHANNEL_OUT_MONO\"/>
                </mixPort>
                <mixPort name=\"voice_tx\"'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing joyeuse mmap_no_irq_out and voip_rx sink mixPorts with hotword input in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''                <mixPort name=\"mmap_no_irq_out\" role=\"source\" flags=\"AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_MMAP_NOIRQ\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>
                <mixPort name=\"voip_rx\" role=\"source\"
                         flags=\"AUDIO_OUTPUT_FLAG_VOIP_RX\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                           samplingRates=\"8000,16000,32000,48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </mixPort>
                <mixPort name=\"incall_music_uplink\"'''
new = '''                <mixPort name=\"hotword input\" role=\"sink\" flags=\"AUDIO_INPUT_FLAG_HW_HOTWORD\" maxActiveCount=\"0\" >
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO\"/>
                </mixPort>
                <mixPort name=\"incall_music_uplink\"'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing primary input and fast input mixPorts with miatoll versions in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''                <mixPort name=\"primary input\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_8_24_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3\"/>
                </mixPort>
                <mixPort name=\"fast input\" role=\"sink\" flags=\"AUDIO_INPUT_FLAG_FAST\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_8_24_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3\"/>
                </mixPort>
                <mixPort name=\"hifi_input\" role=\"sink\" />'''
new = '''                <mixPort name=\"primary input\" role=\"sink\" maxOpenCount=\"2\" maxActiveCount=\"2\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </mixPort>
                <mixPort name=\"uplink downlink input\" role=\"sink\" flags=\"AUDIO_INPUT_FLAG_INCALL_UPLINK_DOWNLINK\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </mixPort>
                <mixPort name=\"voip_tx\" role=\"sink\"
                         flags=\"AUDIO_INPUT_FLAG_VOIP_TX\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000,32000,48000\" channelMasks=\"AUDIO_CHANNEL_IN_MONO\"/>
                </mixPort>
                <mixPort name=\"usb_surround_sound\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,88200,96000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3,AUDIO_CHANNEL_INDEX_MASK_4,AUDIO_CHANNEL_IN_5POINT1,AUDIO_CHANNEL_INDEX_MASK_6,AUDIO_CHANNEL_IN_7POINT1,AUDIO_CHANNEL_INDEX_MASK_8\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_32_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,88200,96000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_5POINT1,AUDIO_CHANNEL_INDEX_MASK_6,AUDIO_CHANNEL_IN_7POINT1,AUDIO_CHANNEL_INDEX_MASK_8\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_FLOAT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,88200,96000,176400,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_5POINT1,AUDIO_CHANNEL_INDEX_MASK_6,AUDIO_CHANNEL_IN_7POINT1,AUDIO_CHANNEL_INDEX_MASK_8\"/>
                </mixPort>
                <mixPort name=\"record_24\" role=\"sink\" maxOpenCount=\"2\" maxActiveCount=\"2\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_24_BIT_PACKED\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,96000,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3,AUDIO_CHANNEL_INDEX_MASK_4\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_8_24_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,96000,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3,AUDIO_CHANNEL_INDEX_MASK_4\"/>
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_FLOAT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000,96000,192000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK,AUDIO_CHANNEL_INDEX_MASK_3,AUDIO_CHANNEL_INDEX_MASK_4\"/>
                </mixPort>'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing voip_tx sink mixPort with hifi_input+fast_input at end of mixPorts in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''                <mixPort name=\"voip_tx\" role=\"sink\"
                         flags=\"AUDIO_INPUT_FLAG_VOIP_TX\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000,32000,48000\" channelMasks=\"AUDIO_CHANNEL_IN_MONO\"/>
                </mixPort>
            </mixPorts>'''
new = '''                <mixPort name=\"voice_rx\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000,48000\" channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO\"/>
                </mixPort>
                <mixPort name=\"hifi_input\" role=\"sink\" />
                <mixPort name=\"fast input\" role=\"sink\"
                         flags=\"AUDIO_INPUT_FLAG_FAST\">
                     <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                              samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                              channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </mixPort>
            </mixPorts>'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing devicePorts section in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''            <devicePorts>
                <devicePort tagName=\"Earpiece\" type=\"AUDIO_DEVICE_OUT_EARPIECE\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"Speaker\" type=\"AUDIO_DEVICE_OUT_SPEAKER\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"Speaker Safe\" type=\"AUDIO_DEVICE_OUT_SPEAKER_SAFE\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"BT SCO\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"BT SCO Headset\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO_HEADSET\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"BT SCO Car Kit\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO_CARKIT\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"Telephony Tx\" type=\"AUDIO_DEVICE_OUT_TELEPHONY_TX\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"USB Device Out\" type=\"AUDIO_DEVICE_OUT_USB_DEVICE\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"USB Headset Out\" type=\"AUDIO_DEVICE_OUT_USB_HEADSET\" role=\"sink\">
                </devicePort>
                <devicePort tagName=\"BT A2DP Out\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_A2DP\" role=\"sink\"
                            encodedFormats=\"AUDIO_FORMAT_LDAC AUDIO_FORMAT_APTX AUDIO_FORMAT_APTX_HD AUDIO_FORMAT_AAC AUDIO_FORMAT_SBC\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"44100,48000,88200,96000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"BT A2DP Headphones\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_HEADPHONES\" role=\"sink\"
                            encodedFormats=\"AUDIO_FORMAT_LDAC AUDIO_FORMAT_APTX AUDIO_FORMAT_APTX_HD AUDIO_FORMAT_AAC AUDIO_FORMAT_SBC\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"44100,48000,88200,96000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"BT A2DP Speaker\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_SPEAKER\" role=\"sink\"
                            encodedFormats=\"AUDIO_FORMAT_LDAC AUDIO_FORMAT_APTX AUDIO_FORMAT_APTX_HD AUDIO_FORMAT_AAC AUDIO_FORMAT_SBC\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"44100,48000,88200,96000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"Built-In Mic\" type=\"AUDIO_DEVICE_IN_BUILTIN_MIC\" role=\"source\">
                </devicePort>
                <devicePort tagName=\"Built-In Back Mic\" type=\"AUDIO_DEVICE_IN_BACK_MIC\" role=\"source\">
                </devicePort>
                <devicePort tagName=\"BT SCO Headset Mic\" type=\"AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET\" role=\"source\">
                </devicePort>
                <devicePort tagName=\"Telephony Rx\" type=\"AUDIO_DEVICE_IN_TELEPHONY_RX\" role=\"source\">
                </devicePort>
                <!-- TODO: Enable multi-channel recording -->
                <devicePort tagName=\"USB Device In\" type=\"AUDIO_DEVICE_IN_USB_DEVICE\" role=\"source\">
                </devicePort>
                <devicePort tagName=\"USB Headset In\" type=\"AUDIO_DEVICE_IN_USB_HEADSET\" role=\"source\">'''
new = '''            <devicePorts>
                <!-- Output devices declaration, i.e. Sink DEVICE PORT -->
                <devicePort tagName=\"Earpiece\" type=\"AUDIO_DEVICE_OUT_EARPIECE\" role=\"sink\">
                   <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                            samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO\"/>
                </devicePort>
                <devicePort tagName=\"Speaker\" role=\"sink\" type=\"AUDIO_DEVICE_OUT_SPEAKER\" address=\"\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"Wired Headset\" type=\"AUDIO_DEVICE_OUT_WIRED_HEADSET\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"Wired Headphones\" type=\"AUDIO_DEVICE_OUT_WIRED_HEADPHONE\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"Line\" type=\"AUDIO_DEVICE_OUT_LINE\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"BT SCO\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO\"/>
                </devicePort>
                <devicePort tagName=\"BT SCO Headset\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO_HEADSET\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO\"/>
                </devicePort>
                <devicePort tagName=\"BT SCO Car Kit\" type=\"AUDIO_DEVICE_OUT_BLUETOOTH_SCO_CARKIT\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO\"/>
                </devicePort>
                <devicePort tagName=\"Telephony Tx\" type=\"AUDIO_DEVICE_OUT_TELEPHONY_TX\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"HDMI\" type=\"AUDIO_DEVICE_OUT_AUX_DIGITAL\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,16000,22050,32000,44100,48000,64000,88200,96000,128000,176400,192000\" channelMasks=\"dynamic\"/>
                </devicePort>
                <devicePort tagName=\"Proxy\" type=\"AUDIO_DEVICE_OUT_PROXY\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,16000,22050,32000,44100,48000,64000,88200,96000,128000,176400,192000\" channelMasks=\"dynamic\"/>
                </devicePort>
                <devicePort tagName=\"FM\" type=\"AUDIO_DEVICE_OUT_FM\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\" channelMasks=\"AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"USB Device Out\" type=\"AUDIO_DEVICE_OUT_USB_DEVICE\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"44100,48000,64000,88200,96000,128000,176400,192000\" channelMasks=\"dynamic\"/>
                </devicePort>
                <devicePort tagName=\"USB Headset Out\" type=\"AUDIO_DEVICE_OUT_USB_HEADSET\" role=\"sink\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"44100,48000,64000,88200,96000,128000,176400,192000\" channelMasks=\"dynamic\"/>
                </devicePort>

                <!-- Input devices declaration, i.e. Source DEVICE PORT -->
                <devicePort tagName=\"Built-In Mic\" type=\"AUDIO_DEVICE_IN_BUILTIN_MIC\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </devicePort>
                <devicePort tagName=\"Built-In Back Mic\" type=\"AUDIO_DEVICE_IN_BACK_MIC\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </devicePort>
                <devicePort tagName=\"FM Tuner\" type=\"AUDIO_DEVICE_IN_FM_TUNER\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO\"/>
                </devicePort>
                <devicePort tagName=\"Wired Headset Mic\" type=\"AUDIO_DEVICE_IN_WIRED_HEADSET\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,11025,12000,16000,22050,24000,32000,44100,48000\"
                             channelMasks=\"AUDIO_CHANNEL_IN_MONO,AUDIO_CHANNEL_IN_STEREO,AUDIO_CHANNEL_IN_FRONT_BACK\"/>
                </devicePort>
                <devicePort tagName=\"BT SCO Headset Mic\" type=\"AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000\" channelMasks=\"AUDIO_CHANNEL_IN_MONO\"/>
                </devicePort>
                <devicePort tagName=\"Telephony Rx\" type=\"AUDIO_DEVICE_IN_TELEPHONY_RX\" role=\"source\">
                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_16_BIT\"
                             samplingRates=\"8000,16000,48000\" channelMasks=\"AUDIO_CHANNEL_IN_MONO\"/>
                </devicePort>
                <devicePort tagName=\"USB Device In\" type=\"AUDIO_DEVICE_IN_USB_DEVICE\" role=\"source\">
                </devicePort>
                <devicePort tagName=\"USB Headset In\" type=\"AUDIO_DEVICE_IN_USB_HEADSET\" role=\"source\">'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing routes section in etc/audio_policy_configuration.xml"
    python3 -c "
content = open('$FILE').read()
old = '''            <routes>
                <route type=\"mix\" sink=\"Earpiece\"
                       sources=\"primary output,raw,deep_buffer,mmap_no_irq_out,voip_rx\"/>
                <route type=\"mix\" sink=\"Speaker\"
                       sources=\"primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx\"/>
                <route type=\"mix\" sink=\"Speaker Safe\"
                       sources=\"primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx\"/>
                <route type=\"mix\" sink=\"BT SCO\"
                       sources=\"primary output,raw,deep_buffer,voip_rx\"/>
                <route type=\"mix\" sink=\"BT SCO Headset\"
                       sources=\"primary output,raw,deep_buffer,voip_rx\"/>
                <route type=\"mix\" sink=\"BT SCO Car Kit\"
                       sources=\"primary output,raw,deep_buffer,voip_rx\"/>
                <route type=\"mix\" sink=\"USB Device Out\"
                       sources=\"primary output,raw,deep_buffer,compressed_offload,hifi_playback,mmap_no_irq_out,voip_rx\"/>
                <route type=\"mix\" sink=\"USB Headset Out\"
                       sources=\"primary output,raw,deep_buffer,compressed_offload,hifi_playback,mmap_no_irq_out,voip_rx\"/>
                <route type=\"mix\" sink=\"Telephony Tx\"
                       sources=\"voice_tx,incall_music_uplink\"/>
                <route type=\"mix\" sink=\"primary input\"
                       sources=\"Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"fast input\"
                       sources=\"Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"voice_rx\"
                       sources=\"Telephony Rx\"/>
                <route type=\"mix\" sink=\"hifi_input\" sources=\"USB Device In,USB Headset In\" />
                <route type=\"mix\" sink=\"mmap_no_irq_in\"
                       sources=\"Built-In Mic,Built-In Back Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"voip_tx\"
                       sources=\"Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"BT A2DP Out\"
                       sources=\"primary output,deep_buffer,compressed_offload,voip_rx\"/>
                <route type=\"mix\" sink=\"BT A2DP Headphones\"
                       sources=\"primary output,deep_buffer,compressed_offload,voip_rx\"/>
                <route type=\"mix\" sink=\"BT A2DP Speaker\"
                       sources=\"primary output,deep_buffer,compressed_offload,voip_rx\"/>
            </routes>'''
new = '''            <!-- route declaration, i.e. list all available sources for a given sink -->
            <routes>
                <route type=\"mix\" sink=\"Earpiece\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx,mmap_no_irq_out\"/>
                <route type=\"mix\" sink=\"Speaker\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx,mmap_no_irq_out\"/>
                <route type=\"mix\" sink=\"Wired Headset\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,dsd_compress_passthrough,voip_rx,mmap_no_irq_out\"/>
                <route type=\"mix\" sink=\"Wired Headphones\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,dsd_compress_passthrough,voip_rx,mmap_no_irq_out\"/>
                <route type=\"mix\" sink=\"Line\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,dsd_compress_passthrough,voip_rx,mmap_no_irq_out\"/>
                <route type=\"mix\" sink=\"HDMI\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,compress_passthrough,voip_rx\"/>
                <route type=\"mix\" sink=\"Proxy\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload\"/>
                <route type=\"mix\" sink=\"FM\"
                       sources=\"primary output\"/>
                <route type=\"mix\" sink=\"BT SCO\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx\"/>
                <route type=\"mix\" sink=\"BT SCO Headset\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx\"/>
                <route type=\"mix\" sink=\"BT SCO Car Kit\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx\"/>
                <route type=\"mix\" sink=\"USB Device Out\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx,mmap_no_irq_out,hifi_playback\"/>
                <route type=\"mix\" sink=\"USB Headset Out\"
                       sources=\"primary output,raw,deep_buffer,direct_pcm,compressed_offload,voip_rx,mmap_no_irq_out,hifi_playback\"/>
                <route type=\"mix\" sink=\"Telephony Tx\"
                       sources=\"voice_tx,incall_music_uplink\"/>
                <route type=\"mix\" sink=\"hotword input\"
                       sources=\"Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"voice_rx\"
                       sources=\"Telephony Rx\"/>
                <route type=\"mix\" sink=\"primary input\"
                       sources=\"Built-In Mic,Built-In Back Mic,Wired Headset Mic,BT SCO Headset Mic,USB Device In,USB Headset In,Telephony Rx\"/>
                <route type=\"mix\" sink=\"uplink downlink input\"
                       sources=\"Wired Headset Mic,BT SCO Headset Mic,USB Device In,USB Headset In,Telephony Rx\"/>
                <route type=\"mix\" sink=\"voip_tx\"
                       sources=\"Built-In Mic,Built-In Back Mic,Wired Headset Mic,BT SCO Headset Mic,USB Device In,USB Headset In,Telephony Rx\"/>
                <route type=\"mix\" sink=\"usb_surround_sound\"
                       sources=\"USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"record_24\"
                       sources=\"Built-In Mic,Built-In Back Mic,Wired Headset Mic,BT SCO Headset Mic\"/>
                <route type=\"mix\" sink=\"mmap_no_irq_in\"
                       sources=\"Built-In Mic,Built-In Back Mic,Wired Headset Mic,USB Device In,USB Headset In\"/>
                <route type=\"mix\" sink=\"hifi_input\" sources=\"USB Device In,USB Headset In\" />
                <route type=\"mix\" sink=\"fast input\"
                       sources=\"Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In,Wired Headset Mic\"/>
            </routes>'''
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"

    log_in "Replacing inline a2dp module with xi:include in etc/audio_policy_configuration.xml"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(
    r'        <module name=\"a2dp\" halVersion=\"2\.0\">.*?</module>',
    '        <xi:include href=\"/vendor/etc/a2dp_in_audio_policy_configuration.xml\"/>',
    content, flags=re.DOTALL
)
open('$FILE', 'w').write(content)
"

    log_in "Fixing r_submix include path in etc/audio_policy_configuration.xml"
    sed -i 's|href="r_submix_audio_policy_configuration.xml"|href="/vendor/etc/r_submix_audio_policy_configuration.xml"|' "$FILE"

    log_in "Adding bluetooth_audio_policy_configuration include in etc/audio_policy_configuration.xml"
    sed -i 's|        <xi:include href="/vendor/etc/r_submix_audio_policy_configuration.xml"/>|        <xi:include href="/vendor/etc/r_submix_audio_policy_configuration.xml"/>\n\n        <!-- Bluetooth Audio HAL -->\n        <xi:include href="/vendor/etc/bluetooth_audio_policy_configuration.xml"/>|' "$FILE"

    log_in "Fixing volume include paths in etc/audio_policy_configuration.xml"
    sed -i 's|href="audio_policy_volumes.xml"|href="/vendor/etc/audio_policy_volumes.xml"|' "$FILE"
    sed -i 's|href="default_volume_tables.xml"|href="/vendor/etc/default_volume_tables.xml"|' "$FILE"
}

patch_audio_policy_volumes() {
    local FILE="$VENDOR/etc/audio_policy_volumes.xml"

    log_in "Replacing VOICE_CALL EARPIECE first point -2400 with -2500 in etc/audio_policy_volumes.xml"
    sed -i '/AUDIO_STREAM_VOICE_CALL.*DEVICE_CATEGORY_EARPIECE/,/\/volume/ s/<point>0,-2400<\/point>/<point>0,-2500<\/point>/' "$FILE"

    log_in "Replacing AUDIO_STREAM_SYSTEM SPEAKER ref curve with manual points in etc/audio_policy_volumes.xml"
    python3 -c "
content = open('$FILE').read()
old = '    <volume stream=\"AUDIO_STREAM_SYSTEM\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\"\n                                         ref=\"DEFAULT_SYSTEM_VOLUME_CURVE\"/>'
new = '''    <volume stream=\"AUDIO_STREAM_SYSTEM\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\">
        <point>1,-4400</point>
        <point>57,-2400</point>
        <point>71,-2100</point>
        <point>85,-1900</point>
        <point>100,-1700</point>
    </volume>'''
content = content.replace(old, new)
open('$FILE', 'w').write(content)
"

    log_in "Replacing AUDIO_STREAM_ENFORCED_AUDIBLE SPEAKER ref curve with manual points in etc/audio_policy_volumes.xml"
    python3 -c "
content = open('$FILE').read()
old = '    <volume stream=\"AUDIO_STREAM_ENFORCED_AUDIBLE\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\"\n                                                   ref=\"DEFAULT_SYSTEM_VOLUME_CURVE\"/>'
new = '''    <volume stream=\"AUDIO_STREAM_ENFORCED_AUDIBLE\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\">
        <point>1,-3400</point>
        <point>71,-2400</point>
        <point>100,-2000</point>
    </volume>'''
content = content.replace(old, new)
open('$FILE', 'w').write(content)
"

    log_in "Replacing AUDIO_STREAM_DTMF SPEAKER ref curve with manual points in etc/audio_policy_volumes.xml"
    python3 -c "
content = open('$FILE').read()
old = '    <volume stream=\"AUDIO_STREAM_DTMF\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\"\n                                       ref=\"DEFAULT_SYSTEM_VOLUME_CURVE\"/>'
new = '''    <volume stream=\"AUDIO_STREAM_DTMF\" deviceCategory=\"DEVICE_CATEGORY_SPEAKER\">
        <point>1,-3700</point>
        <point>71,-2100</point>
        <point>100,-1100</point>
    </volume>'''
content = content.replace(old, new)
open('$FILE', 'w').write(content)
"
}

patch_default_volume_tables() {
    local FILE="$VENDOR/etc/default_volume_tables.xml"

    log_in "Replacing DEFAULT_SYSTEM_VOLUME_CURVE last point -600 with 0 in etc/default_volume_tables.xml"
    sed -i '0,/<point>100,-600<\/point>/ s/<point>100,-600<\/point>/<point>100,0<\/point>/' "$FILE"

    log_in "Replacing DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE points in etc/default_volume_tables.xml"
    sed -i 's/<point>1,-4950<\/point>/<point>1,-5800<\/point>/' "$FILE"
    sed -i 's/<point>20,-3350<\/point>/<point>20,-4000<\/point>/' "$FILE"

    log_in "Replacing last point -1000 with 0 (two occurrences) in etc/default_volume_tables.xml"
    sed -i 's/<point>100,-1000<\/point>/<point>100,0<\/point>/g' "$FILE"
}

patch_fstab() {
    for f in fstab.default fstab.emmc; do
        local FILE="$VENDOR/etc/$f"

        log_in "Removing AVB flags from system/system_ext/product/vendor in etc/$f"
        sed -i 's/wait,logical,first_stage_mount,avb=vbmeta_system,avb_keys=\/avb\/q-gsi.avbpubkey:\/avb\/r-gsi.avbpubkey:\/avb\/s-gsi.avbpubkey/wait,logical,first_stage_mount/' "$FILE"
        sed -i 's/wait,logical,first_stage_mount,avb=vbmeta_system/wait,logical,first_stage_mount/' "$FILE"
        sed -i 's/wait,logical,first_stage_mount,avb/wait,logical,first_stage_mount/' "$FILE"

        log_in "Removing fileencryption/wrappedkey/quota flags from userdata in etc/$f"
        sed -i 's/latemount,wait,check,formattable,fileencryption=ice,wrappedkey,quota,reservedsize=128M,checkpoint=fs/latemount,wait,check,formattable,reservedsize=128M,checkpoint=fs/' "$FILE"

        log_in "Replacing zramsize=1073741824 with zramsize=4096M in etc/$f"
        sed -i 's/zramsize=1073741824/zramsize=4096M/' "$FILE"
    done
}

patch_group_passwd() {
    log_in "Adding vendor_launcher and vendor_saures to etc/group"
    cat >> "$VENDOR/etc/group" << 'EOF'
vendor_launcher::2988:
vendor_saures::2989:
EOF

    log_in "Adding vendor_launcher and vendor_saures to etc/passwd"
    cat >> "$VENDOR/etc/passwd" << 'EOF'
vendor_launcher::2988:2988::/:/bin/sh
vendor_saures::2989:2989::/:/bin/sh
EOF
}

patch_init_qcom_factory() {
    local FILE="$VENDOR/etc/init/hw/init.qcom.factory.rc"

    log_in "Adding author signature at end of etc/init/hw/init.qcom.factory.rc"
    printf '\n\n\n# authored by diza u muna.' >> "$FILE"
}

patch_init_qcom_rc() {
    local FILE="$VENDOR/etc/init/hw/init.qcom.rc"

    log_in "Adding init.custom_xd.rc import in etc/init/hw/init.qcom.rc"
    sed -i 's|import /vendor/etc/init/hw/init.qcom.test.rc|import /vendor/etc/init/hw/init.qcom.test.rc\nimport /vendor/etc/init/hw/init.custom_xd.rc|' "$FILE"

    log_in "Adding start systemService on boot in etc/init/hw/init.qcom.rc"
    sed -i 's/on boot$/on boot\n    start systemService/' "$FILE"

    log_in "Adding systemService service definition in etc/init/hw/init.qcom.rc"
    sed -i 's|    # limit discard size to 128MB in order to avoid long IO latency\n    write /sys/block/sda/queue/discard_max_bytes 134217728|    # limit discard size to 128MB in order to avoid long IO latency\n    write /sys/block/sda/queue/discard_max_bytes 134217728\n\nservice systemService /vendor/bin/systemService\n       class main\n    user root\n       group shell|' "$FILE"
    # sed above may fail on multiline; use python3 instead
    python3 -c "
content = open('$FILE').read()
old = '    write /sys/block/sda/queue/discard_max_bytes 134217728\n\n# msm specific files'
new = '    write /sys/block/sda/queue/discard_max_bytes 134217728\n\nservice systemService /vendor/bin/systemService\n       class main\n    user root\n       group shell\n\n# msm specific files'
content = content.replace(old, new, 1)
open('$FILE', 'w').write(content)
"
}

patch_init_target_rc() {
    local FILE="$VENDOR/etc/init/hw/init.target.rc"

    log_in "Replacing cnss_diag flags -q -f -t with -q -t in etc/init/hw/init.target.rc"
    sed -i 's|cnss_diag -q -f -t HELIUM|cnss_diag -q -t HELIUM|' "$FILE"

    log_in "Adding trailing newline at end of etc/init/hw/init.target.rc"
    echo "" >> "$FILE"
}

patch_thermal_engine_rc() {
    local FILE="$VENDOR/etc/init/init_thermal-engine.rc"

    log_in "Commenting out thermal-engine service in etc/init/init_thermal-engine.rc"
    python3 -c "
content = open('$FILE').read()
old = '''service thermal-engine /vendor/bin/thermal-engine
       class main
       user root
       group root
       socket thermal-send-client stream 0660 system oem_2907
       socket thermal-recv-client stream 0660 system oem_2907
       socket thermal-recv-passive-client stream 0660 system oem_2907
       socket thermal-send-rule stream 0660 system oem_2907

on property:sys.boot_completed=1
       restart thermal-engine'''
new = '''# service thermal-engine /vendor/bin/thermal-engine
       # class main
       # user root
       # group root
       # socket thermal-send-client stream 0660 system oem_2907
       # socket thermal-recv-client stream 0660 system oem_2907
       # socket thermal-recv-passive-client stream 0660 system oem_2907
       # socket thermal-send-rule stream 0660 system oem_2907

# on property:sys.boot_completed=1
       # restart thermal-engine'''
content = content.replace(old, new)
open('$FILE', 'w').write(content)
"
}

patch_selinux() {
    log_in "Replacing 'sustem' typo with 'system' in etc/selinux/vendor_file_contexts"
    sed -i 's|(vendor|sustem/vendor)|(vendor|system/vendor)|' "$VENDOR/etc/selinux/vendor_file_contexts"

    log_in "Replacing precompiled_sepolicy.plat hash in etc/selinux/"
    echo "506031746a363e32bf6bc24a7d552c2ba77df8dc069835f15cccb6e72110104f" > "$VENDOR/etc/selinux/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256"

    log_in "Replacing precompiled_sepolicy.product hash in etc/selinux/"
    echo "a679a0438c691aa4557bf80c3c0d076a2d1ae709b32e8f52cddf8ba109aa0030" > "$VENDOR/etc/selinux/precompiled_sepolicy.product_sepolicy_and_mapping.sha256"

    log_in "Replacing precompiled_sepolicy.system_ext hash in etc/selinux/"
    echo "289aa0e0f85a5b969caf9f57847bbbb5a157ea3dec6fc8ebe17d12ff92d7c2bd" > "$VENDOR/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256"
}

patch_thermal_engine_map() {
    local FILE="$VENDOR/etc/thermal-engine-map.conf"

    log_in "Replacing thermal-engine-map.conf entries with joyeuse-suffixed names"
    cat > "$FILE" << 'EOF'
[0:thermal-engine-normal-joyeuse.conf]
[1:thermal-engine-high-joyeuse.conf]
[2:thermal-engine-extreme-joyeuse.conf]
[8:thermal-engine-phone-joyeuse.conf]
[9:thermal-engine-sgame-joyeuse.conf]
[10:thermal-engine-nolimits-joyeuse.conf]
[11:thermal-engine-class0-joyeuse.conf]
[12:thermal-engine-camera-joyeuse.conf]
[13:thermal-engine-pubgmhd-joyeuse.conf]
[14:thermal-engine-youtobe-joyeuse.conf]
[15:thermal-engine-arvr-joyeuse.conf]
[16:thermal-engine-tgame-joyeuse.conf]
EOF
}

patch_vintf_manifest() {
    local FILE="$VENDOR/etc/vintf/manifest.xml"

    log_in "Removing android.hardware.nfc HAL block from etc/vintf/manifest.xml"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(r'    <hal format=\"hidl\">\n        <name>android\.hardware\.nfc</name>.*?</hal>\n', '', content, flags=re.DOTALL)
open('$FILE', 'w').write(content)
"

    log_in "Removing android.hardware.secure_element HAL block from etc/vintf/manifest.xml"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(r'    <hal format=\"hidl\">\n        <name>android\.hardware\.secure_element</name>.*?</hal>\n', '', content, flags=re.DOTALL)
open('$FILE', 'w').write(content)
"

    log_in "Removing vendor.nxp.hardware.nfc HAL block from etc/vintf/manifest.xml"
    python3 -c "
import re
content = open('$FILE').read()
content = re.sub(r'    <hal format=\"hidl\">\n        <name>vendor\.nxp\.hardware\.nfc</name>.*?</hal>\n', '', content, flags=re.DOTALL)
open('$FILE', 'w').write(content)
"
}

patch_wifi() {
    local FILE="$VENDOR/etc/wifi/WCNSS_qcom_cfg.ini"

    log_in "Replacing gChannelBondingMode24GHz=0 with 1 in etc/wifi/WCNSS_qcom_cfg.ini"
    sed -i 's/gChannelBondingMode24GHz=0/gChannelBondingMode24GHz=1/' "$FILE"

    log_in "Replacing sae_enabled=0 with 1 in etc/wifi/WCNSS_qcom_cfg.ini"
    sed -i 's/sae_enabled=0/sae_enabled=1/' "$FILE"
}

patch_qcril_sql() {
    local FILE="$VENDOR/radio/qcril_database/upgrade/0_initial.sql"

    log_in "Adding MCC 454 emergency entries to radio/qcril_database/upgrade/0_initial.sql"
    sed -i "/INSERT INTO \"qcril_emergency_source_mcc_table\" VALUES('450','911','','');/a INSERT INTO \"qcril_emergency_source_mcc_table\" VALUES('454','112','','');\nINSERT INTO \"qcril_emergency_source_mcc_table\" VALUES('454','110','','');\nINSERT INTO \"qcril_emergency_source_mcc_table\" VALUES('454','999','','');\nINSERT INTO \"qcril_emergency_source_mcc_table\" VALUES('454','911','','');" "$FILE"
}

patch_ueventd() {
    log_in "Replacing /dev/diag permission 0660 with 0666 in ueventd.rc"
    sed -i 's|/dev/diag                 0660   system     oem_2901|/dev/diag                 0666   system     oem_2901|' "$VENDOR/ueventd.rc"
}
 
patch_semi_vendor() {
    rm -rf baserom/vendor/etc/group baserom/vendor/etc/passwd
    cp -r portrom/vendor/vendor/etc/group baserom/vendor/etc/
    cp -r portrom/vendor/vendor/etc/passwd baserom/vendor/etc/
    cp -rf portrom/vendor/vendor/overlay/* baserom/vendor/overlay/
}
 
patch_apk() {
    local apk="$1"
    local func="$2"
    shift 2
    local name
    name=$(basename "$apk" .apk)
    mkdir -p tmp
    cp -f "$apk" "tmp/${name}.bak"
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o "tmp/${name}" > /dev/null
    python3 bin/patchmethod_v2.py "tmp/${name}" "$func" "$@" > /dev/null
    java -jar bin/apktool/APKEditor.jar b -f -i "tmp/${name}" -o "$apk" > /dev/null
}
 
patch_services_jar() {
    local jar="portrom/system/system/framework/services.jar"
    [[ -f "$jar" ]] || { log_info_in "services.jar not found, skipping."; return; }
 
    log_info "Decompiling services.jar"
    mkdir -p tmp/services
    cp -f "$jar" tmp/services.jar
    java -jar bin/apktool/APKEditor.jar d -f -i tmp/services.jar -o tmp/services 2> /dev/null
 
    local scan_pkg
    scan_pkg=$(find tmp/services -type f -name "ScanPackageUtils.smali")
    if [[ -f "$scan_pkg" ]]; then
        log_info "Patching method "assertMinSignatureSchemeIsValid" in smali" 
        python3 bin/patchmethod_v2.py "$scan_pkg" assertMinSignatureSchemeIsValid 2> /dev/null
    fi
 
    while IFS= read -r smali_file; do
        local method_line
        method_line=$(grep -n "getMinimumSignatureSchemeVersionForTargetSdk" "$smali_file" | cut -d':' -f1 || true)
        [[ -z "$method_line" ]] && continue
 
        local reg
        reg=$(tail -n +"${method_line}" "$smali_file" | grep -m1 "move-result" | tr -dc '0-9' || true)
        [[ -z "$reg" ]] && continue
 
        local end_line
        end_line=$(awk -v ML="$method_line" 'NR>=ML && /move-result /{print NR; exit}' "$smali_file")
        [[ -z "$end_line" ]] && continue
        log_info "Patching method getMinimumSignatureSchemeVersionForTargetSdk in $(basename "$smali_file")"
 
        sed -i "${method_line},${end_line}d" "$smali_file"
        sed -i "${method_line}i\\    const/4 v${reg}, 0x0" "$smali_file"
    done < <(find tmp/services/smali -type f -name "*.smali" \
        -exec grep -l "getMinimumSignatureSchemeVersionForTargetSdk" {} \;)
 
    local reconcile
    reconcile=$(find tmp/services -type f -name "ReconcilePackageUtils.smali")
    if [[ -f "$reconcile" ]]; then
        local match
        log_info "Patching method "ALLOW_NON_PRELOADS_SYSTEM_SHAREDUIDS" in smali"
        match=$(grep -n "sput-boolean .*ALLOW_NON_PRELOADS_SYSTEM_SHAREDUIDS" "$reconcile" | head -n1)
        if [[ -n "$match" ]]; then
            local lno reg2
            lno=$(echo "$match" | cut -d':' -f1)
            reg2=$(echo "$match" | sed -n 's/.*sput-boolean \([^,]*\),.*/\1/p')
            sed -i "${lno}i\\    const/4 ${reg2}, 0x1" "$reconcile"
        fi
    fi
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/services -o "$jar" > /dev/null
}
 
patch_heytap_speech_assist() {
    local apk
    apk=$(find portrom/ -name "HeyTapSpeechAssist.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "HeyTapSpeechAssist.apk not found, skipping."; return; }
 
    log_info "Decompiling HeyTapSpeechAssist"
    mkdir -p tmp
    cp -f "$apk" tmp/HeyTapSpeechAssist.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/HeyTapSpeechAssist > /dev/null
 
    local smali
    smali=$(find tmp/HeyTapSpeechAssist -type f -name "AiCallCommonBean.smali")
    log_info "Patching method "getSupportAiCall" with true in smali"
    [[ -f "$smali" ]] && python3 bin/patchmethod_v2.py "$smali" getSupportAiCall -return true 2> /dev/null
 
    find tmp/HeyTapSpeechAssist -type f -name "*.smali" -exec \
        sed -i "s/sget-object \([vp][0-9]\+\), Landroid\/os\/Build;->MODEL:Ljava\/lang\/String;/const-string \1, \"PLG110\"/g" {} +
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/HeyTapSpeechAssist -o "$apk" 2> /dev/null
}
 
patch_ota_apk() {
    local apk
    apk=$(find portrom/ -name "OTA.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "OTA.apk not found, skipping."; return; }
 
    log_info "Decompiling OTA"
    mkdir -p tmp
    cp -f "$apk" tmp/OTA.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/OTA 2> /dev/null
    log_info "Patching method "ro.boot.vbmeta.device_state" with locked in baksmali"
    python3 bin/patchmethod_v2.py -d tmp/OTA -k ro.boot.vbmeta.device_state -k locked -return false > /dev/null
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/OTA -o "$apk" 2> /dev/null
}
 
patch_aiunit_apk() {
    local apk
    apk=$(find portrom/ -name "AIUnit.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "AIUnit.apk not found, skipping."; return; }
 
    local MODEL="PLG110"
 
    log_info "Decompiling AIUnit"
    mkdir -p tmp
    cp -f "$apk" tmp/AIUnit.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/AIUnit 2> /dev/null
 
    find tmp/AIUnit -type f -name "*.smali" -exec \
        sed -i "s/sget-object \([vp][0-9]\+\), Landroid\/os\/Build;->MODEL:Ljava\/lang\/String;/const-string \1, \"${MODEL}\"/g" {} +
 
    local unit_smali
    unit_smali=$(find tmp/AIUnit -type f -name "UnitConfig.smali")
    log_info "Spoofing model for AI features in smali"
    if [[ -f "$unit_smali" ]]; then
        python3 bin/patchmethod_v2.py "$unit_smali" isAllWhiteConditionMatch > /dev/null
        python3 bin/patchmethod_v2.py "$unit_smali" isWhiteConditionsMatch > /dev/null
        python3 bin/patchmethod_v2.py "$unit_smali" isSupport > /dev/null
    fi
 
    local unit_json
    unit_json=$(find tmp/AIUnit -type f -name "unit_config_list.json")
    if [[ -f "$unit_json" ]] && command -v jq &>/dev/null; then
        local EXTENDED_MODELS=("PJF110" "PEEM00" "PEDM00" "LE2120" "LE2121" "LE2123" "KB2000" "KB2001" "KB2005" "KB2003" "LE2110" "LE2111" "LE2112" "LE2113" "IN2010" "IN2011" "IN2012" "IN2013" "IN2020" "IN2021" "IN2022" "IN2023")
        jq --arg models_str "${EXTENDED_MODELS[*]}" '
            ($models_str | split(" ")) as $new_models
            | map(
                if has("whiteModels") and (.whiteModels | type) == "string" then
                    .whiteModels as $current |
                    if $current == "" then
                        .whiteModels = ($new_models | join(","))
                    else
                        ($current | split(",")) as $existing |
                        ($new_models | map(select(. as $m | $existing | index($m) == null))) as $unique |
                        if ($unique | length) > 0 then
                            .whiteModels = $current + "," + ($unique | join(","))
                        else . end
                    end
                else . end
                | if has("minAndroidApi") then .minAndroidApi = 30 else . end
            )
        ' "$unit_json" > "${unit_json}.bak" && mv "${unit_json}.bak" "$unit_json"
    fi
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/AIUnit -o "$apk" 2> /dev/null
}
 
patch_oplus_launcher() {
    local apk
    apk=$(find portrom/ -name "OplusLauncher.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "OplusLauncher.apk not found, skipping."; return; }
 
    log_info "Decompiling OplusLauncher"
    mkdir -p tmp
    cp -f "$apk" tmp/OplusLauncher.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/OplusLauncher 2> /dev/null
 
    local smali
    log_info "Patching method "getFirstApiLevel" in smali"
    smali=$(find tmp/OplusLauncher -type f -path "*/com/oplus/basecommon/util/SystemPropertiesHelper.smali")
    if [[ -f "$smali" ]]; then
        python3 bin/patchmethod_v2.py "$smali" getFirstApiLevel ".locals 1\n\tconst/16 v0, 0x22\n\treturn v0" > /dev/null
    fi
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/OplusLauncher -o "$apk" 2> /dev/null
}
 
patch_systemui_apk() {
    local apk
    apk=$(find portrom/ -name "SystemUI.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "SystemUI.apk not found, skipping."; return; }
 
    log_info "Decompiling SystemUI"
    mkdir -p tmp
    cp -f "$apk" tmp/SystemUI.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/SystemUI 2> /dev/null
 
    local smooth_smali
    smooth_smali=$(find tmp/SystemUI -type f -name "SmoothTransitionController.smali")
    if [[ -f "$smooth_smali" ]]; then
        python3 bin/patchmethod_v2.py "$smooth_smali" setPanoramicStatusForApplication 2> /dev/null
        python3 bin/patchmethod_v2.py "$smooth_smali" setPanoramicSupportAllDayForApplication 2> /dev/null
    fi
 
    local aod_smali
    aod_smali=$(find tmp/SystemUI -type f -name "AODDisplayUtil.smali")
    [[ -f "$aod_smali" ]] && \
        python3 bin/patchmethod_v2.py "$aod_smali" isPanoramicProcessTypeNotSupportAllDay -return false 2> /dev/null
 
    python3 bin/patchmethod_v2.py -d tmp/SystemUI -n isCtsTest -return false 2> /dev/null
 
    local feature_smali
    feature_smali=$(find tmp/SystemUI -type f -path "*/systemui/common/feature/FeatureOption.smali")
    [[ -f "$feature_smali" ]] && \
        python3 bin/patchmethod_v2.py "$feature_smali" isSupportMyDevice -return true 2> /dev/null
 
    while IFS= read -r sxml; do
        sed -i "s/style\/null/7f1403f6/g" "$sxml"
    done < <(find tmp/SystemUI -name "styles.xml")
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/SystemUI -o "$apk" 2> /dev/null
}
 
patch_aod_apk() {
    local apk
    apk=$(find portrom/ -name "Aod.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "Aod.apk not found, skipping."; return; }
 
    log_info "Decompiling AOD"
    mkdir -p tmp
    cp -f "$apk" tmp/Aod.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Aod 2> /dev/null
 
    local common_smali settings_smali
    common_smali=$(find tmp/Aod -type f -path "*/com/oplus/aod/util/CommonUtils.smali")
    settings_smali=$(find tmp/Aod -type f -path "*/com/oplus/aod/util/SettingsUtils.smali")
    log_info "Patching method "isSupportFullAod" with true in smali"
    [[ -f "$common_smali" ]] && python3 bin/patchmethod_v2.py "$common_smali" isSupportFullAod -return true 2> /dev/null
    log_info "Patching method "getKeyAodAllDaySupportSettings" with true in smali"
    [[ -f "$settings_smali" ]] && python3 bin/patchmethod_v2.py "$settings_smali" getKeyAodAllDaySupportSettings -return true 2> /dev/null
 
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Aod -o "$apk" 2> /dev/null
}
 
patch_settings_apk() {
    log_info "Decompiling Settings"
    mkdir -p tmp
    mv portrom/system_ext/system_ext/priv-app/Settings/Settings.apk tmp/
    cd tmp/
 
    curl -# -L -o apktool.jar "https://github.com/iBotPeaches/Apktool/releases/download/v3.0.1/apktool_3.0.1.jar"
    java -jar apktool.jar d Settings.apk
    cd Settings/res/xml
 
 sed -i '/<\/PreferenceScreen>/i\
    <com.oplus.settings.widget.preference.SettingsPreferenceCategory>\
        <Preference android:title="Brought to you by @dizaumuna" android:summary="Thanks to miatoll community for helping.">\
            <intent android:action="android.intent.action.VIEW" android:data="https://github.com/dizaumuna" />\
        </Preference>\
    </com.oplus.settings.widget.preference.SettingsPreferenceCategory>' device_version_info.xml
 
    cd ../../
    java -jar ../apktool.jar b -o Settings_patched.apk 2> /dev/null
    mv Settings_patched.apk ../
    cd ..
    keytool -genkey -v -keystore signkey.keystore -alias signkey \
        -keyalg RSA -keysize 2048 -validity 10000
    jarsigner -keystore signkey.keystore Settings_patched.apk signkey
    mv Settings_patched.apk "$WORK_DIR/portrom/system_ext/system_ext/priv-app/Settings/Settings.apk"
    cd "$WORK_DIR"
}
 
patch_gallery_apk() {
    local apk
    apk=$(find portrom/ -name "OppoGallery2.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "OppoGallery2.apk not found, skipping."; return; }
 
    log_info "Decompiling OppoGallery2"
    mkdir -p tmp
    cp -f "$apk" tmp/OppoGallery2.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Gallery 2> /dev/null
    python3 bin/patchmethod_v2.py -d tmp/Gallery \
        -k "const-string.*\"ro.product.first_api_level\"" \
        -hook " const/16 reg, 0x22"
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Gallery -o "$apk" 2> /dev/null
}
 
patch_battery_apk() {
    local apk
    apk=$(find portrom/ -name "Battery.apk" | head -n1)
    [[ -f "$apk" ]] || { log_info_in "Battery.apk not found, skipping."; return; }
    [[ -f "devices/common/patch_battery_soh.txt" ]] || { log_info_in "patch_battery_soh.txt not found, skipping Battery patch."; return; }
 
    log_info "Decompiling Battery"
    mkdir -p tmp
    cp -f "$apk" tmp/Battery.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Battery 2> /dev/null
    log_info "Patching method "getUIsohValue" in smali"
    python3 bin/patchmethod_v2.py -d tmp/Battery -k "getUIsohValue" -m devices/common/patch_battery_soh.txt 2> /dev/null
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Battery -o "$apk" 2> /dev/null
}
 
build_image() {
    local NAME="$1"
    local ROOTFS="$2"
    local CONFIG_DIR="$3"
 
    local SIZE PAD_SIZE FS_CONFIG CONTEXTS ARGS
    SIZE=$(du -sb "$ROOTFS" | cut -f1)
    PAD_SIZE=$((SIZE + SIZE * PADDING / 100 + EXTRA))
    FS_CONFIG="$CONFIG_DIR/${NAME}_fs_config"
    CONTEXTS="$CONFIG_DIR/${NAME}_file_contexts"
    ARGS=""
 
    [[ -f "$FS_CONFIG" ]] && ARGS="$ARGS -C $FS_CONFIG"
    [[ -f "$CONTEXTS" ]] && ARGS="$ARGS -S $CONTEXTS"
 
    ./bin/make_ext4fs -s -L "$NAME" -a "$NAME" -J -T 1 $ARGS -l "$PAD_SIZE" "${NAME}.img" "$ROOTFS"
    echo "$PAD_SIZE" > "${NAME}.size"
}
 
compress_images() {
    log_info "Compressing images"
    python3 bin/img2sdat/img2sdat.py system.img     -o out -v 4 -p system > /dev/null
    python3 bin/img2sdat/img2sdat.py system_ext.img -o out -v 4 -p system_ext > /dev/null
    python3 bin/img2sdat/img2sdat.py product.img    -o out -v 4 -p product > /dev/null
    python3 bin/img2sdat/img2sdat.py vendor.img     -o out -v 4 -p vendor > /dev/null
    rm -rf system.img system_ext.img product.img vendor.img
}
 
add_apex30() {
    log_info "Downloading Android VNDK V30"
    curl -# -L -o com.android.vndk.v30.apex "https://github.com/dizaumuna/server/releases/download/resources/com.android.vndk.v30.apex"
    mv com.android.vndk.v30.apex portrom/system_ext/system_ext/apex/
    echo "system_ext/apex/com.android.vndk.v30.apex 0 0 0644" >> portrom/system_ext/config/system_ext_fs_config
    echo "/system_ext/apex/com\.android\.vndk\.v30\.apex u:object_r:system_file:s0" >> portrom/system_ext/config/system_ext_file_contexts
}
 
package_zip() {
    log_info "Downloading miatoll-binaries"
    cd out/
    curl -# -L -o miatoll.zip "https://github.com/dizaumuna/server/releases/download/resources/miatoll.zip"
    unzip miatoll.zip
    rm miatoll.zip
 
    log_info "Downloading custom kernel for miatoll"
    curl -# -L -o boot.img "https://github.com/dizaumuna/server/releases/download/resources/boot.img"
 
    while true; do
        local s
        s=$(tr -dc 'a-z0-9' </dev/urandom | head -c 12)
        [[ $(grep -o '[0-9]' <<<"$s" | wc -l) -ge 3 ]] || continue
        local file="miatoll_eu_global-ota_full-OS15.0.0.CPH2685-user-15.0-${s}.zip"
        zip -r "$file" *
        mv "$file" "$WORK_DIR/"
        echo "$file" > "$WORK_DIR/output.txt"
        break
    done

    cd "$WORK_DIR"
    rm -rf out/
}

build_recovery() {
    log_info "Building OrangeFox Recovery for miatoll"

    git clone https://gitlab.com/OrangeFox/misc/scripts.git -b master
    cd scripts
    sudo bash setup/android_build_env.sh
    cd "$WORK_DIR"

    mkdir -p "$WORK_DIR/OrangeFox"
    cd "$WORK_DIR/OrangeFox"
    git clone https://gitlab.com/OrangeFox/sync.git -b master 2> /dev/null
    cd sync
    ./orangefox_sync.sh --branch 12.1 --path "$WORK_DIR/OrangeFox/fox_12.1" 2> /dev/null
    cd "$WORK_DIR/OrangeFox/fox_12.1"

    git clone https://github.com/iput-object/ofox-device_xiaomi_miatoll -b 12.1 ./device/xiaomi/miatoll 2> /dev/null

    set +e
    source build/envsetup.sh
    export ALLOW_MISSING_DEPENDENCIES=true
    set -e

    lunch twrp_miatoll-eng && make clean && mka adbd recoveryimage 2> /dev/null

    local recovery_img
    recovery_img=$(find out/target/product/miatoll -name "OrangeFox*.img" | head -n1)
    [[ -z "$recovery_img" ]] && recovery_img=$(find out/target/product/miatoll -name "recovery.img" | head -n1)

    if [[ -z "$recovery_img" ]]; then
        log_info "recovery.img not found after build!"
        exit 1
    fi

    mv "$recovery_img" "$WORK_DIR/out/recovery.img"
    cd "$WORK_DIR"
    rm -rf OrangeFox scripts
    log_info "OrangeFox recovery built successfully."
}
 
debloat() {
    local BASE="portrom/system/system"
    local APEX_BASE="workdir/port/system_ext/system_ext"
 
    local PATHS="
my_bigball/app/Facebook-appmanager
my_bigball/app/GoogleContacts
my_bigball/app/GPay3
my_bigball/app/LatinImeGoogle
my_bigball/app/Meet
my_bigball/app/Photos
my_bigball/del-app-pre/Drive_del
my_bigball/del-app-pre/Facebook
my_bigball/del-app-pre/GoogleFindMyDevice
my_bigball/del-app-pre/GoogleHome
my_bigball/del-app-pre/GoogleOne
my_bigball/del-app-pre/Videos_del
my_bigball/del-app-pre/YTMusic_del
my_bigball/etc/sysconfig/com.google.android.dialer.support.xml
my_bigball/framework/com.google.android.dialer.support.jar
my_bigball/overlay/GmsConfigOverlayASI
my_bigball/overlay/GmsConfigOverlayCommonCN
my_bigball/overlay/GmsConfigOverlayCommonEx
my_bigball/overlay/GmsConfigOverlayComms
my_bigball/overlay/OplusConfigOverlayComms
my_bigball/priv-app/Facebook-installer
my_bigball/priv-app/Facebook-services
my_bigball/priv-app/GoogleDialer
my_bigball/priv-app/Messages
my_bigball/priv-app/PlayAutoInstallConfig_OnePlus
my_bigball/priv-app/SearchSelector
my_product/app/CalendarGoogle
my_product/app/Chrome64
my_product/app/Gmail2
my_product/app/GoogleLens
my_product/app/GoogleLocationHistory
my_product/app/Maps
my_product/app/OplusCamera
my_product/app/talkback
my_product/app/YouTube
my_product/app/WebViewGoogle64
my_product/app/TrichromeLibrary64
my_product/del-app/ConsumerIRApp
my_product/priv-app/GoogleFiles
my_product/priv-app/GoogleVelvet_CTS
my_product/priv-app/Phonesky
my_product/priv-app/Wellbeing
my_product/priv-app/SOSHelper
my_product/overlay/SystemUIFingerprintRes_13_0_COSMOS.apk
my_product/overlay/SystemUIFingerprintRes_13_0_FIREWORKS.apk
my_product/overlay/SystemUIFingerprintRes_13_0_FY.apk
my_product/overlay/SystemUIFingerprintRes_13_0_NONE.apk
my_product/overlay/SystemUIFingerprintRes_13_0_QY.apk
my_product/overlay/SystemUIFingerprintRes_13_0_RIPPLE.apk
my_product/overlay/SystemUIFingerprintRes_13_0_STRIPE.apk
my_product/overlay/SystemUIFingerprintRes_13_0_SW.apk
my_product/overlay/SystemUIFingerprintRes_Halo.apk
my_stock/app/BeaconLink
my_stock/app/Browser
my_stock/app/ChildrenSpace
my_stock/app/CloudService
my_stock/app/FloatAssistant
my_stock/app/KeKePay
my_stock/app/OplusOperationManual
my_stock/app/OplusSecurityKeyboard
my_stock/app/PhoneNOAreaInquireProvider
my_stock/app/Portrait
my_stock/app/SceneMode
my_stock/app/SecurePay
my_stock/app/SoftsimRedteaRoaming
my_stock/app/SmartSideBar
my_stock/app/Calculator2
my_stock/app/FileManager
my_stock/del-app/BackupAndRestore
my_stock/del-app/INOnePlusStore
my_stock/del-app/OPBreathMode
my_stock/del-app/OPForum
my_stock/del-app/Pictorial
my_stock/del-app/NewSoundRecorder
my_stock/del-app/OppoNote2
my_stock/del-app/OppoTranslation
my_stock/priv-app/BlackListApp
my_stock/priv-app/dmp
my_stock/priv-app/HeyCast
my_stock/priv-app/KeKeMarket
my_stock/priv-app/LinktoWindows
my_stock/priv-app/NumberRecognition
"
    for p in $PATHS; do
        log_info_in "Deleting $p"
        rm -rf "${BASE}/${p}"
    done
 
    rm -rf "${APEX_BASE}/apex/com.android.vndk.v33.apex"
}
 
main() {
    local device
    device=$(detect_device "$BASEROM")
    load_config "$device"
 
    check_tools python3 java curl unzip zip jq xxd strings
 
    log_info "Cleaning up before processing"
    rm -rf baserom portrom repack tmp out *.img *.size
 
    case "$TARGET_BASEROM_TYPE" in
        dat.br)  extract_baserom_datbr "$BASEROM" ;;
        payload) extract_baserom_payload "$BASEROM" ;;
        img)     extract_baserom_img "$BASEROM" ;;
        *) log_info "Unknown TARGET_BASEROM_TYPE: $TARGET_BASEROM_TYPE"; exit 1 ;;
    esac
 
    extract_portrom "$PORTROM" "$TARGET_PORTROM_TYPE"
    extract_img baserom/vendor.img baserom
 
    for part in system system_ext product; do
        extract_img "portrom/${part}.img" portrom
    done
 
    for part in my_manifest my_heytap my_engineering my_bigball my_carrier my_stock my_region my_product; do
        extract_img "portrom/${part}.img" portrom || true
    done
 
    move_my_partitions_to_system
    patch_props
    patch_odm
    add_custom_props
    patch_odm_media_profiles
    patch_audio_effects
    patch_audio_io_policy
    patch_audio_platform_info
    patch_audio_policy_configuration
    patch_audio_policy_volumes
    patch_default_volume_tables
    patch_fstab
    patch_group_passwd
    patch_init_qcom_factory
    patch_init_qcom_rc
    patch_init_target_rc
    patch_thermal_engine_rc
    patch_selinux
    patch_thermal_engine_map
    patch_vintf_manifest
    patch_wifi
    patch_qcril_sql
    patch_ueventd
    patch_file_contexts
    patch_semi_vendor
    debloat
    add_apex30
 
    mkdir -p tmp
 
    patch_services_jar
    patch_heytap_speech_assist
    patch_ota_apk
    patch_aiunit_apk
    patch_oplus_launcher
    patch_systemui_apk
    patch_aod_apk
   # patch_settings_apk
    patch_gallery_apk
    patch_battery_apk
 
    rm -rf tmp
 
    log_info "Building OS images"
    build_image "system"     "portrom/system/system"          "portrom/system/config" 2> /dev/null
    build_image "system_ext" "portrom/system_ext/system_ext"  "portrom/system_ext/config" 2> /dev/null
    build_image "product"    "portrom/product/product"         "portrom/product/config" 2> /dev/null
    build_image "vendor"     "baserom/vendor"                  "baserom/config" 2> /dev/null
 
    mkdir -p out
    # build_recovery
    compress_images
    package_zip
 
    local elapsed=$(( SECONDS - BUILD_START ))
    log_info "Build finished in $(( elapsed / 60 ))m $(( elapsed % 60 ))s"
}
 
main

#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# ColorOS / OxygenOS / Realme UI
# Author: dizaumuna
#

set -e
trap 'echo "[ERROR] Line $LINENO: $BASH_COMMAND" >&2' ERR

WORK_DIR=$(pwd)
BUILD_START=${SECONDS}
PADDING=3
EXTRA=10485760

source functions.sh

chmod +x *
chmod +x bin/*

log_info()  { echo -e "\033[1;34m[$(date +%H:%M:%S)] $*\033[0m"; }
log_ok()    { echo -e "\033[1;32m[$(date +%H:%M:%S)] $*\033[0m"; }
log_warn()  { echo -e "\033[1;33m[$(date +%H:%M:%S)] $*\033[0m"; }
log_err()   { echo -e "\033[1;31m[$(date +%H:%M:%S)] $*\033[0m"; }

BASEROM="${1:-}"
PORTROM="${2:-}"

if [[ -z "$BASEROM" || -z "$PORTROM" ]]; then
    echo "Usage: $0 <baserom> <portrom>"
    echo "  baserom : path to base ROM zip"
    echo "  portrom : path to port ROM zip"
    exit 1
fi

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
        log_err "Config not found: $cfg"
        exit 1
    fi
    source "$cfg"
    cat "$cfg"
}

extract_baserom_datbr() {
    local zip="$1"
    log_info "Extracting base firmware..."
    mkdir -p baserom/raw baserom/vendor baserom/config

    unzip -q "$zip" -d baserom/raw

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
        log_info "Converting vendor.new.dat.br → vendor.img"
        python3 bin/sdat2img_brotli.py \
            -d baserom/raw/vendor.new.dat.br \
            -t baserom/raw/vendor.transfer.list \
            -o baserom/vendor.img
        log_ok "vendor.img created"
    else
        log_err "vendor.new.dat.br not found in base ROM."
        exit 1
    fi
}

extract_baserom_payload() {
    local zip="$1"
    log_info "Extracting base ROM [payload format]..."
    mkdir -p baserom/raw
    unzip -q "$zip" payload.bin -d baserom/raw
    bin/payload-dumper-go -p vendor -o baserom/ baserom/raw/payload.bin > /dev/null
    log_ok "vendor.img extracted from payload."
}

extract_baserom_img() {
    local zip="$1"
    log_info "Extracting base ROM [img format]..."
    mkdir -p baserom/raw
    unzip -q "$zip" "vendor.img" -d baserom/raw 2>/dev/null || \
    unzip -q "$zip" "vendor_a.img" -d baserom/raw 2>/dev/null || true
    find baserom/raw -name "vendor*.img" -exec mv -f {} baserom/vendor.img \;
    log_ok "vendor.img extracted successfully."
}

extract_portrom() {
    local zip="$1"
    local type="$2"
    log_info "Extracting port ROM [$type format]..."
    mkdir -p portrom

    if [[ "$type" == "payload" ]]; then
        unzip -q "$zip" payload.bin -d portrom/
        local parts="system,system_ext,vendor,product"
        for part in my_manifest my_heytap my_engineering my_bigball my_carrier my_stock my_region my_product; do
            parts="${parts},${part}"
        done
        log_info "Dumping partitions: $parts"
        bin/payload-dumper-go -p "$parts" -o portrom/ portrom/payload.bin > /dev/null
        rm -f portrom/payload.bin
        log_ok "Port ROM partitions extracted."
    elif [[ "$type" == "img" ]]; then
        local targets=()
        for part in system system_ext vendor product my_manifest my_product my_stock my_region my_company my_preload; do
            targets+=("${part}.img" "${part}_a.img" "${part}_b.img")
        done
        unzip -q "$zip" "${targets[@]}" -d portrom/ 2>/dev/null || true
        find portrom/ -name "*_a.img" | while read f; do
            base=$(basename "$f" _a.img)
            mv -f "$f" "portrom/${base}.img"
        done
        log_ok "Port ROM img files extracted."
    else
        log_err "Unknown portrom type: $type"
        exit 1
    fi
}

mount_ext_img() {
    local img="$1"
    local outdir="$2"
    local name
    name=$(basename "$img" .img)
    mkdir -p "$outdir/$name" "$outdir/config"
    log_info "Extracting [ext] $name"
    python3 bin/extractor.py "$img" "$outdir/$name/"
    log_ok "$name extracted."
}

mount_erofs_img() {
    local img="$1"
    local outdir="$2"
    local name
    name=$(basename "$img" .img)
    mkdir -p "$outdir/$name"
    log_info "Extracting [erofs] image $name"
    bin/extract.erofs -i "$img" -o "$outdir/$name" -x > /dev/null 2>&1

    mkdir -p "$outdir/vendor"
    log_info "Extracting [erofs] vendor"
    bin/extract.erofs -i portrom/vendor.img -o "$outdir/vendor" -x > /dev/null 2>&1
}

extract_img() {
    local img="$1"
    local outdir="$2"
    if [[ ! -f "$img" ]]; then
        log_warn "$img not found, skipping."
        return
    fi
    local fstype
    fstype=$(file "$img" | grep -o 'Linux.*filesystem\|EROFS' | head -1 || true)
    if echo "$fstype" | grep -qi "erofs"; then
        mount_erofs_img "$img" "$outdir"
    else
        mount_ext_img "$img" "$outdir"
    fi
}

move_my_partitions_to_system() {
    mv portrom/my_product/my_product   portrom/system/system/
    mv portrom/my_manifest/my_manifest portrom/system/system/
    mv portrom/my_bigball/my_bigball   portrom/system/system/
    mv portrom/my_carrier/my_carrier   portrom/system/system/
    mv portrom/my_heytap/my_heytap     portrom/system/system/
    mv portrom/my_stock/my_stock       portrom/system/system/
    mv portrom/my_engineering/my_engineering portrom/system/system/
    mv portrom/my_region/my_region     portrom/system/system/
}

patch_file_contexts() {
    log_info "Patching file contexts..."

    if [[ -f baserom/config/vendor_fsconfig.txt ]]; then
        mv baserom/config/vendor_fsconfig.txt baserom/config/vendor_fs_config
    fi
    if [[ -f baserom/config/vendor_contexts.txt ]]; then
        mv baserom/config/vendor_contexts.txt baserom/config/vendor_file_contexts
    fi

    [[ -f baserom/config/vendor_file_contexts ]] && \
        python3 bin/fspatch.py baserom/vendor baserom/config/vendor_fs_config

    python3 bin/fspatch.py portrom/system/system portrom/system/config/system_fs_config
    python3 bin/fspatch.py portrom/system_ext/system_ext portrom/system_ext/config/system_ext_fs_config
    python3 bin/fspatch.py portrom/product/product portrom/product/config/product_fs_config

    local sys_ctx="portrom/system/config/system_file_contexts"
    if [[ -f "$sys_ctx" ]]; then
        sed -i 's|^\(/system/my_[^ ]*\) u:object_r:system_file:s0|\1(/.*)?    u:object_r:system_file:s0|' "$sys_ctx"
    fi

    log_ok "File contexts patched."
}

patch_port_buildprops() {
    log_info "Patching my_product build.prop..."
    local my_product_prop="portrom/system/system/my_product/build.prop"
    sed -i 's/ro.sf.lcd_density=560/ro.sf.lcd_density=440/' "$my_product_prop"
    sed -i 's/ro.oplus.display.screenhole.positon=596,40:668,112/# ro.oplus.display.screenhole.positon=596,40:668,112\nro.oplus.display.screenhole.positon=519,36:569,86/' "$my_product_prop"
    sed -i 's/ro.vendor.display.sensortype=2/# ro.vendor.display.sensortype=2/' "$my_product_prop"
    sed -i 's/^persist.oplus.display.vrr=1$/# persist.oplus.display.vrr=1/' "$my_product_prop"
    sed -i 's/^persist.oplus.display.vrr.adfr=2$/# persist.oplus.display.vrr.adfr=2/' "$my_product_prop"
    sed -i 's/^persist.oplus.display.vrr.adfr.scale=129$/# persist.oplus.display.vrr.adfr.scale=129/' "$my_product_prop"
    sed -i 's/^vendor.display.use_layer_ext=1$/# vendor.display.use_layer_ext=1/' "$my_product_prop"
    sed -i 's/ro.oplus.density.fhd_default=480/ro.oplus.density.fhd_default=440/' "$my_product_prop"
    sed -i 's/ro.oplus.resolution.low=1080,2376/ro.oplus.resolution.low=1080,2400/' "$my_product_prop"
    sed -i '/ro.oplus.gaussianlevel=3/d' "$my_product_prop"
    echo "debug.sf.disable_client_composition_cache=0" >> "$my_product_prop"
    log_ok "my_product build.prop patched."

    log_info "Patching my_product permissions..."
    local allnet="portrom/system/system/my_product/etc/permissions/com.oppo.features_allnet_android.xml"
    local display_feat="portrom/system/system/my_product/etc/permissions/oplus.product.display_features.xml"
    local video_feat="portrom/system/system/my_product/etc/permissions/oplus.product.feature_video_unique.xml"
    sed -i 's/<feature name="android.hardware.biometrics.face" \/>$/<!-- <feature name="android.hardware.biometrics.face" \/>  -->/' "$allnet"
    sed -i 's/<feature name="oppo.common.support.curved.display" \/>$/<!-- <feature name="oppo.common.support.curved.display" \/> -->/' "$allnet"
    sed -i 's/<oplus-feature name="oplus.software.fingeprint_optical_enabled"\/>$/<!-- <oplus-feature name="oplus.software.fingeprint_optical_enabled"\/> -->/' "$display_feat"
    sed -i 's/<feature name="oplus.software.video.sr_support"\/>$/<!-- <feature name="oplus.software.video.sr_support"\/> -->/' "$video_feat"
    sed -i 's/<feature name="oplus.software.video.osie_support"\/>$/<!-- <feature name="oplus.software.video.osie_support"\/> -->/' "$video_feat"
    log_ok "my_product permissions patched."

    log_info "Patching system build.prop..."
    local sys_prop="portrom/system/system/system/build.prop"
    sed -i 's/dalvik.vm.minidebuginfo=true/dalvik.vm.minidebuginfo=false/' "$sys_prop"
    sed -i 's/dalvik.vm.dex2oat-minidebuginfo=true/dalvik.vm.dex2oat-minidebuginfo=false/' "$sys_prop"
    log_ok "system build.prop patched."
}

patch_port_init() {
    log_info "Patching init.rc..."
    sed -i 's/write \/proc\/sys\/kernel\/panic_on_oops 1/write \/proc\/sys\/kernel\/panic_on_oops 0/' \
        portrom/system/system/system/etc/init/hw/init.rc

    log_info "Patching init.usb.rc..."
    sed -i '/vendor.sys.usb.adb.disabled/d' portrom/system/system/system/etc/init/hw/init.usb.rc
    sed -i '/persist.vendor.usb.config/d' portrom/system/system/system/etc/init/hw/init.usb.rc
    sed -i '/persist.sys.usb.config.*persist.vendor/d' portrom/system/system/system/etc/init/hw/init.usb.rc

    log_info "Patching init.usb.configfs.rc..."
    local configfs_rc="portrom/system/system/system/etc/init/hw/init.usb.configfs.rc"
    sed -i '/setusbconfig to/d' "$configfs_rc"
    sed -i '/sys.usb.config=\* && property:sys.usb.configfs=1/d' "$configfs_rc"
    sed -i '/rmdir.*rndis.gs4/d' "$configfs_rc"

    cat >> "$configfs_rc" << 'EOF'

on property:sys.usb.config=rndis && property:sys.usb.configfs=1
    mkdir /config/usb_gadget/g1/functions/rndis.gs4
    write /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration "rndis"
    symlink /config/usb_gadget/g1/functions/rndis.gs4 /config/usb_gadget/g1/configs/b.1/f1
    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
    setprop sys.usb.state ${sys.usb.config}

on property:sys.usb.config=rndis,adb && property:sys.usb.configfs=1
    start adbd

on property:sys.usb.ffs.ready=1 && property:sys.usb.config=rndis,adb && property:sys.usb.configfs=1
    mkdir /config/usb_gadget/g1/functions/rndis.gs4
    write /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration "rndis_adb"
    symlink /config/usb_gadget/g1/functions/rndis.gs4 /config/usb_gadget/g1/configs/b.1/f1
    symlink /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/f2
    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
    setprop sys.usb.state ${sys.usb.config}
EOF

    log_ok "init files patched."
}

patch_port_vendor() {
    log_info "Patching vendor build.prop..."
    local vendor_prop="baserom/vendor/build.prop"
    sed -i '/sys.thermal.data.path/d' "$vendor_prop"
    sed -i 's/ro.control_privapp_permissions=$/ro.control_privapp_permissions=enforce/' "$vendor_prop"
    sed -i 's/#ro.frp.pst/ro.frp.pst/' "$vendor_prop"
    sed -i '/persist.vendor.radio.manual_nw_rej_ct/d' "$vendor_prop"
    cat >> "$vendor_prop" << 'EOF'
persist.vendor.radio.manual_nw_rej_ct=1
ro.product.mod_device=joyeuse_global
ro.vendor.se.type=HCE,UICC
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

# ro.surface_flinger.use_color_management=true
# ro.surface_flinger.protected_contents=true
# ro.surface_flinger.use_content_detection_for_refresh_rate=true
# ro.surface_flinger.set_touch_timer_ms=200
# ro.surface_flinger.force_hwc_copy_for_virtual_displays=true
# ro.surface_flinger.max_frame_buffer_acquired_buffers=3
# ro.surface_flinger.max_virtual_display_dimension=4096
# ro.surface_flinger.supports_background_blur=1
# ro.surface_flinger.has_wide_color_display=true
# ro.surface_flinger.has_HDR_display=true
# ro.surface_flinger.wcg_composition_dataspace=143261696
# ro.surface_flinger.enable_frame_rate_override=false
EOF
    log_ok "vendor build.prop patched."

    log_info "Patching ODM build.prop..."
    cat >> baserom/vendor/odm/etc/build.prop << 'EOF'
ro.soc.model=SDM720G
ro.oplus.display.screenSizeInches.primary=6.67
ro.build.device_family=OPSM8550
ro.product.oplus.cpuinfo=SDM720G
ro.vendor.qti.va_odm.support=1
import /my_bigball/build.prop
import /my_carrier/build.prop
import /my_engineering/build.prop
import /my_heytap/build.prop
import /my_region/build.prop
import /my_stock/build.prop
import /my_manifest/build.prop
EOF
    log_ok "ODM build.prop patched."
}

disable_encryption() {
    log_info "Removing file encryption from fstab..."
    for fstab in baserom/vendor/etc/fstab.default baserom/vendor/etc/fstab.emmc; do
        [[ -f "$fstab" ]] || continue
        sed -i 's/,inlinecrypt\b//g; s/,fileencryption=ice,wrappedkey\b//g' "$fstab"
    done
    log_ok "File encryption removed."
}

disable_avb() {
    log_info "Disabling Android Verified Boot..."
    while IFS= read -r fstab; do
        sed -i 's/,avb_keys=[^ ]*//g' "$fstab"
        sed -i 's/,avb=vbmeta_system//g' "$fstab"
        sed -i 's/,avb=vbmeta_vendor//g' "$fstab"
        sed -i 's/,avb=vbmeta//g' "$fstab"
        sed -i 's/,avb//g' "$fstab"
    done < <(find baserom/ portrom/ -name "fstab.*" 2>/dev/null)
    log_ok "AVB disabled."
}

patch_semi_vendor() {
    log_info "Semi-patching vendor..."
    rm -rf baserom/vendor/etc/group
    rm -rf baserom/vendor/etc/passwd
    cp -r portrom/vendor/vendor/etc/group baserom/vendor/etc/
    cp -r portrom/vendor/vendor/etc/passwd baserom/vendor/etc/
    cp -rf portrom/vendor/vendor/overlay/* baserom/vendor/overlay/
    log_ok "Vendor semi-patched."
}

patch_apk() {
    local apk="$1"
    local func="$2"
    shift 2
    local name
    name=$(basename "$apk" .apk)
    mkdir -p tmp
    cp -f "$apk" "tmp/${name}.bak"
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o "tmp/${name}"
    python3 bin/patchmethod_v2.py "tmp/${name}" "$func" "$@"
    java -jar bin/apktool/APKEditor.jar b -f -i "tmp/${name}" -o "$apk"
}

patch_services_jar() {
    local jar="portrom/system/system/framework/services.jar"
    [[ -f "$jar" ]] || { log_warn "services.jar not found, skipping."; return; }

    log_info "Patching services.jar..."
    mkdir -p tmp/services
    cp -f "$jar" tmp/services.jar
    java -jar bin/apktool/APKEditor.jar d -f -i tmp/services.jar -o tmp/services

    local scan_pkg
    scan_pkg=$(find tmp/services -type f -name "ScanPackageUtils.smali")
    if [[ -f "$scan_pkg" ]]; then
        python3 bin/patchmethod_v2.py "$scan_pkg" assertMinSignatureSchemeIsValid && \
            log_ok "ScanPackageUtils patched."
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

        sed -i "${method_line},${end_line}d" "$smali_file"
        sed -i "${method_line}i\\    const/4 v${reg}, 0x0" "$smali_file"
        log_ok "getMinimumSignatureSchemeVersionForTargetSdk patched in $(basename "$smali_file")"
    done < <(find tmp/services/smali -type f -name "*.smali" \
        -exec grep -l "getMinimumSignatureSchemeVersionForTargetSdk" {} \;)

    local reconcile
    reconcile=$(find tmp/services -type f -name "ReconcilePackageUtils.smali")
    if [[ -f "$reconcile" ]]; then
        local match
        match=$(grep -n "sput-boolean .*ALLOW_NON_PRELOADS_SYSTEM_SHAREDUIDS" "$reconcile" | head -n1)
        if [[ -n "$match" ]]; then
            local lno reg2
            lno=$(echo "$match" | cut -d':' -f1)
            reg2=$(echo "$match" | sed -n 's/.*sput-boolean \([^,]*\),.*/\1/p')
            sed -i "${lno}i\\    const/4 ${reg2}, 0x1" "$reconcile"
            log_ok "ALLOW_NON_PRELOADS_SYSTEM_SHAREDUIDS patched."
        fi
    fi

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/services -o "$jar"
    log_ok "services.jar patched."
}

patch_heytap_speech_assist() {
    local apk
    apk=$(find portrom/ -name "HeyTapSpeechAssist.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "HeyTapSpeechAssist.apk not found, skipping."; return; }

    log_info "Patching HeyTapSpeechAssist.apk (AI Call unlock)..."
    mkdir -p tmp
    cp -f "$apk" tmp/HeyTapSpeechAssist.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/HeyTapSpeechAssist

    local smali
    smali=$(find tmp/HeyTapSpeechAssist -type f -name "AiCallCommonBean.smali")
    [[ -f "$smali" ]] && python3 bin/patchmethod_v2.py "$smali" getSupportAiCall -return true

    find tmp/HeyTapSpeechAssist -type f -name "*.smali" -exec \
        sed -i "s/sget-object \([vp][0-9]\+\), Landroid\/os\/Build;->MODEL:Ljava\/lang\/String;/const-string \1, \"PLG110\"/g" {} +

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/HeyTapSpeechAssist -o "$apk"
    log_ok "HeyTapSpeechAssist.apk patched."
}

patch_ota_apk() {
    local apk
    apk=$(find portrom/ -name "OTA.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "OTA.apk not found, skipping."; return; }

    log_info "Patching OTA.apk (dm-verity bypass)..."
    mkdir -p tmp
    cp -f "$apk" tmp/OTA.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/OTA
    python3 bin/patchmethod_v2.py -d tmp/OTA -k ro.boot.vbmeta.device_state -k locked -return false
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/OTA -o "$apk"
    log_ok "OTA.apk patched."
}

patch_aiunit_apk() {
    local apk
    apk=$(find portrom/ -name "AIUnit.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "AIUnit.apk not found, skipping."; return; }

    local MODEL="PLG110"

    log_info "Patching AIUnit.apk (AI feature unlock, model=$MODEL)..."
    mkdir -p tmp
    cp -f "$apk" tmp/AIUnit.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/AIUnit

    find tmp/AIUnit -type f -name "*.smali" -exec \
        sed -i "s/sget-object \([vp][0-9]\+\), Landroid\/os\/Build;->MODEL:Ljava\/lang\/String;/const-string \1, \"${MODEL}\"/g" {} +

    local unit_smali
    unit_smali=$(find tmp/AIUnit -type f -name "UnitConfig.smali")
    if [[ -f "$unit_smali" ]]; then
        python3 bin/patchmethod_v2.py "$unit_smali" isAllWhiteConditionMatch
        python3 bin/patchmethod_v2.py "$unit_smali" isWhiteConditionsMatch
        python3 bin/patchmethod_v2.py "$unit_smali" isSupport
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

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/AIUnit -o "$apk"
    log_ok "AIUnit.apk patched."
}

patch_oplus_launcher() {
    local apk
    apk=$(find portrom/ -name "OplusLauncher.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "OplusLauncher.apk not found, skipping."; return; }

    log_info "Patching OplusLauncher.apk (RAM display)..."
    mkdir -p tmp
    cp -f "$apk" tmp/OplusLauncher.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/OplusLauncher

    local smali
    smali=$(find tmp/OplusLauncher -type f -path "*/com/oplus/basecommon/util/SystemPropertiesHelper.smali")
    if [[ -f "$smali" ]]; then
        python3 bin/patchmethod_v2.py "$smali" getFirstApiLevel ".locals 1\n\tconst/16 v0, 0x22\n\treturn v0"
    fi

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/OplusLauncher -o "$apk"
    log_ok "OplusLauncher.apk patched."
}

patch_systemui_apk() {
    local apk
    apk=$(find portrom/ -name "SystemUI.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "SystemUI.apk not found, skipping."; return; }

    log_info "Patching SystemUI.apk..."
    mkdir -p tmp
    cp -f "$apk" tmp/SystemUI.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/SystemUI

    local smooth_smali
    smooth_smali=$(find tmp/SystemUI -type f -name "SmoothTransitionController.smali")
    if [[ -f "$smooth_smali" ]]; then
        python3 bin/patchmethod_v2.py "$smooth_smali" setPanoramicStatusForApplication
        python3 bin/patchmethod_v2.py "$smooth_smali" setPanoramicSupportAllDayForApplication
    fi

    local aod_smali
    aod_smali=$(find tmp/SystemUI -type f -name "AODDisplayUtil.smali")
    [[ -f "$aod_smali" ]] && \
        python3 bin/patchmethod_v2.py "$aod_smali" isPanoramicProcessTypeNotSupportAllDay -return false

    python3 bin/patchmethod_v2.py -d tmp/SystemUI -n isCtsTest -return false

    local feature_smali
    feature_smali=$(find tmp/SystemUI -type f -path "*/systemui/common/feature/FeatureOption.smali")
    [[ -f "$feature_smali" ]] && \
        python3 bin/patchmethod_v2.py "$feature_smali" isSupportMyDevice -return true

    while IFS= read -r sxml; do
        sed -i "s/style\/null/7f1403f6/g" "$sxml"
    done < <(find tmp/SystemUI -name "styles.xml")

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/SystemUI -o "$apk"
    log_ok "SystemUI.apk patched."
}

patch_aod_apk() {
    local apk
    apk=$(find portrom/ -name "Aod.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "Aod.apk not found, skipping."; return; }

    log_info "Patching AOD.apk (force AOD always-on)..."
    mkdir -p tmp
    cp -f "$apk" tmp/Aod.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Aod

    local common_smali settings_smali
    common_smali=$(find tmp/Aod -type f -path "*/com/oplus/aod/util/CommonUtils.smali")
    settings_smali=$(find tmp/Aod -type f -path "*/com/oplus/aod/util/SettingsUtils.smali")

    [[ -f "$common_smali" ]] && python3 bin/patchmethod_v2.py "$common_smali" isSupportFullAod -return true
    [[ -f "$settings_smali" ]] && python3 bin/patchmethod_v2.py "$settings_smali" getKeyAodAllDaySupportSettings -return true

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Aod -o "$apk"
    log_ok "Aod.apk patched."
}

patch_settings_apk() {
    log_info "Patching Settings.apk..."

    mkdir -p tmp
    mv portrom/system_ext/system_ext/priv-app/Settings/Settings.apk tmp/
    cd tmp/

    curl -# -L -o apktool.jar "https://github.com/iBotPeaches/Apktool/releases/download/v3.0.1/apktool_3.0.1.jar"
    java -jar apktool.jar d Settings.apk
    cd Settings/res/xml

    sed -i '/<com.oplus.settings.widget.preference.SettingsPreferenceCategory>/,/<\/PreferenceScreen>/c\
        </com.oplus.settings.widget.preference.SettingsPreferenceCategory>\
        <com.oplus.settings.widget.preference.SettingsPreferenceCategory>\
            <Preference android:title="Brought to you by @dizaumuna" android:summary="Thanks to miatoll community for helping.">\
                <intent android:action="android.intent.action.VIEW" android:data="https://github.com/dizaumuna" />\
            </Preference>\
        </com.oplus.settings.widget.preference.SettingsPreferenceCategory>\
    </PreferenceScreen>' device_version_info.xml

    cd ../../
    java -jar ../apktool.jar b -o Settings_patched.apk
    mv Settings_patched.apk ../
    cd ..
    keytool -genkey -v -keystore signkey.keystore -alias signkey \
        -keyalg RSA -keysize 2048 -validity 10000
    jarsigner -keystore signkey.keystore Settings_patched.apk signkey
    mv Settings_patched.apk "$WORK_DIR/portrom/system_ext/system_ext/priv-app/Settings/Settings.apk"
    cd "$WORK_DIR"
    log_ok "Settings.apk patched."
}

patch_gallery_apk() {
    local apk
    apk=$(find portrom/ -name "OppoGallery2.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "OppoGallery2.apk not found, skipping."; return; }

    log_info "Patching OppoGallery2.apk (AI Editor unlock)..."
    mkdir -p tmp
    cp -f "$apk" tmp/OppoGallery2.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Gallery
    python3 bin/patchmethod_v2.py -d tmp/Gallery \
        -k "const-string.*\"ro.product.first_api_level\"" \
        -hook " const/16 reg, 0x22"
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Gallery -o "$apk"
    log_ok "OppoGallery2.apk patched."
}

patch_battery_apk() {
    local apk
    apk=$(find portrom/ -name "Battery.apk" | head -n1)
    [[ -f "$apk" ]] || { log_warn "Battery.apk not found, skipping."; return; }
    [[ -f "devices/common/patch_battery_soh.txt" ]] || { log_warn "patch_battery_soh.txt not found, skipping Battery patch."; return; }

    log_info "Patching Battery.apk (SOH unlock)..."
    mkdir -p tmp
    cp -f "$apk" tmp/Battery.bak
    java -jar bin/apktool/APKEditor.jar d -f -i "$apk" -o tmp/Battery
    python3 bin/patchmethod_v2.py -d tmp/Battery -k "getUIsohValue" -m devices/common/patch_battery_soh.txt
    java -jar bin/apktool/APKEditor.jar b -f -i tmp/Battery -o "$apk"
    log_ok "Battery.apk patched."
}

build_image() {
    local NAME="$1"
    local ROOTFS="$2"
    local CONFIG_DIR="$3"

    echo "  - Processing build of $NAME..."

    if [[ ! -d "$ROOTFS" ]]; then
        echo "  - [!] $NAME has no rootfs ($ROOTFS)"
        return
    fi

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

    echo "  - Successfully built $NAME."
    echo
}

build_super() {
    local group="$TARGET_SUPER_GROUP"
    local super_size="$TARGET_SUPER_SIZE"
    local meta_size="$TARGET_SUPER_METADATA_SIZE"
    local meta_slots="$TARGET_SUPER_METADATA_SLOTS"

    log_info "Building super.img"
    mkdir -p out

    local lpargs
    lpargs="--metadata-size=${meta_size} \
    --metadata-slots=${meta_slots} \
    --device-size=${super_size} \
    --super-name=super \
    --group ${group}:${super_size}"

    for part in system system_ext vendor product; do
        local img="${part}.img"
        local size_file="${part}.size"
        if [[ -f "$img" ]]; then
            local sz
            if [[ -f "$size_file" ]]; then
                sz=$(cat "$size_file")
            else
                sz=$(stat -c%s "$img")
            fi
            lpargs="$lpargs --partition ${part}:readonly:${sz}:${group} -i ${part}=${img}"
        fi
    done

    eval bin/lpmake $lpargs -o out/super.img
}

add_apex30() {
    log_info "Downloading Android VNDK 30..."
    curl -# -L -o com.android.vndk.v30.apex "https://github.com/dizaumuna/server/releases/download/resources/com.android.vndk.v30.apex"
    mv com.android.vndk.v30.apex portrom/system_ext/system_ext/apex/
    echo "system_ext/apex/com.android.vndk.v30.apex 0 0 0644" >> portrom/system_ext/config/system_ext_fs_config
    echo "/system_ext/apex/com\.android\.vndk\.v30\.apex u:object_r:system_file:s0" >> portrom/system_ext/config/system_ext_file_contexts
    log_ok "Finished successfully."
}

build_recovery() {
    log_info "Building OrangeFox Recovery for miatoll..."

    git clone https://gitlab.com/OrangeFox/misc/scripts.git -b master
    cd scripts
    sudo bash setup/android_build_env.sh
    cd "$WORK_DIR"

    mkdir -p "$WORK_DIR/OrangeFox"
    cd "$WORK_DIR/OrangeFox"
    git clone https://gitlab.com/OrangeFox/sync.git -b master
    cd sync
    ./orangefox_sync.sh --branch 12.1 --path "$WORK_DIR/OrangeFox/fox_12.1"
    cd "$WORK_DIR/OrangeFox/fox_12.1"

    git clone https://github.com/iput-object/ofox-device_xiaomi_miatoll -b 12.1 ./device/xiaomi/miatoll

    set +e
    source build/envsetup.sh
    export ALLOW_MISSING_DEPENDENCIES=true
    set -e

    lunch twrp_miatoll-eng && make clean && mka adbd recoveryimage

    local recovery_img
    recovery_img=$(find out/target/product/miatoll -name "OrangeFox*.img" | head -n1)
    [[ -z "$recovery_img" ]] && recovery_img=$(find out/target/product/miatoll -name "recovery.img" | head -n1)

    if [[ -z "$recovery_img" ]]; then
        log_err "recovery.img not found after build!"
        exit 1
    fi

    mv "$recovery_img" "$WORK_DIR/out/recovery.img"
    cd "$WORK_DIR"
    rm -rf OrangeFox scripts
    log_ok "OrangeFox recovery built successfully."
}

package_zip() {
    log_info "Downloading miatoll-binaries..."
    cd out/

    curl -# -L -o miatoll.zip "https://github.com/dizaumuna/server/releases/download/resources/miatoll.zip"
    unzip miatoll.zip
    rm miatoll.zip

    log_info "Downloading custom kernel for miatoll..."
    curl -# -L -o boot.img "https://github.com/dizaumuna/server/releases/download/resources/boot.img"

    while true; do
        s=$(tr -dc 'a-z0-9' </dev/urandom | head -c 12)
        [[ $(grep -o '[0-9]' <<<"$s" | wc -l) -ge 3 ]] || continue
        file="miatoll_eu_global-ota_full-OS15.0.0.CPH2685-user-15.0-$s.zip"
        zip -r "$file" *
        mv "$file" "$WORK_DIR/"
        echo "$file" > "$WORK_DIR/output.txt"
        break
    done

    log_ok "Done creating OTA ZIP! Cleaning-up temporary files..."
    cd "$WORK_DIR"
    rm -rf out/
}

debloat() {
    rm -rf portrom/system/system/my_product/app/CalendarGoogle
    rm -rf portrom/system/system/my_product/app/Chrome64
    rm -rf portrom/system/system/my_product/app/Facebook-appmanager
    rm -rf portrom/system/system/my_product/app/Gemini
    rm -rf portrom/system/system/my_product/app/Gmail2
    rm -rf portrom/system/system/my_product/app/GoogleContacts
    rm -rf portrom/system/system/my_product/app/GoogleLens
    rm -rf portrom/system/system/my_product/app/GoogleWallet
    rm -rf portrom/system/system/my_product/app/GPay3
    rm -rf portrom/system/system/my_product/app/Maps
    rm -rf portrom/system/system/my_product/app/Meet
    rm -rf portrom/system/system/my_product/app/OplusCamera
    rm -rf portrom/system/system/my_product/app/Photos
    rm -rf portrom/system/system/my_product/app/talkback
    rm -rf portrom/system/system/my_product/app/TrichromeLibrary64
    rm -rf portrom/system/system/my_product/app/WebViewGoogle64
    rm -rf portrom/system/system/my_product/app/YouTube
    rm -rf portrom/system/system/my_product/del-app/ConsumerIRApp
    rm -rf portrom/system/system/my_product/del-app-pre/*
    rm -rf portrom/system/system/my_product/priv-app/Facebook-installer
    rm -rf portrom/system/system/my_product/priv-app/Facebook-services
    rm -rf portrom/system/system/my_product/priv-app/FamilyLinkParentalControls
    rm -rf portrom/system/system/my_product/priv-app/GoogleDialer
    rm -rf portrom/system/system/my_product/priv-app/GoogleFiles
    rm -rf portrom/system/system/my_product/priv-app/GoogleVelvet_CTS
    rm -rf portrom/system/system/my_product/priv-app/Messages
    rm -rf portrom/system/system/my_product/priv-app/GmsCore
    rm -rf portrom/system/system/my_product/priv-app/Phonesky
    rm -rf portrom/system/system/my_product/priv-app/Wellbeing
    rm -rf portrom/system/system/my_product/priv-app/GoogleRestore
    rm -rf portrom/system/system/my_stock/app/Clock
    rm -rf portrom/system/system/my_stock/app/FileManager
    rm -rf portrom/system/system/my_stock/app/Browser
    rm -rf portrom/system/system/my_stock/app/OcrScanner
    rm -rf portrom/system/system/my_stock/app/OppoWeather2
    rm -rf portrom/system/system/my_stock/app/SceneMode
    rm -rf portrom/system/system/my_stock/del-app/EAOnePlusStore
    rm -rf portrom/system/system/my_stock/del-app/OppoNote2
    rm -rf portrom/system/system/my_stock/priv-app/Games
    rm -rf portrom/system/system/my_stock/priv-app/LinktoWindows
    log_ok "Removed useless system apps successfully."
}

main() {
    local device
    device=$(detect_device "$BASEROM")
    load_config "$device"

    log_info "Cleaning up before processing porting..."
    rm -rf baserom portrom repack tmp out *.img *.size

    case "$TARGET_BASEROM_TYPE" in
        dat.br)  extract_baserom_datbr "$BASEROM" ;;
        payload) extract_baserom_payload "$BASEROM" ;;
        img)     extract_baserom_img "$BASEROM" ;;
        *) log_err "Unknown TARGET_BASEROM_TYPE: $TARGET_BASEROM_TYPE"; exit 1 ;;
    esac

    extract_portrom "$PORTROM" "$TARGET_PORTROM_TYPE"

    log_info "Extracting partition images..."
    extract_img baserom/vendor.img baserom

    for part in system system_ext product; do
        local img="portrom/${part}.img"
        [[ -f "$img" ]] && extract_img "$img" portrom || log_warn "$img not found"
    done

    for part in my_manifest my_heytap my_engineering my_bigball my_carrier my_stock my_region my_product; do
        local img="portrom/${part}.img"
        [[ -f "$img" ]] && extract_img "$img" portrom || true
    done

    move_my_partitions_to_system
    patch_port_buildprops
    patch_port_init
    patch_port_vendor
    disable_avb
    disable_encryption
    patch_file_contexts
    patch_semi_vendor
    debloat
    add_apex30

    log_info "Patching APKs and framework JARs..."
    mkdir -p tmp

    patch_services_jar
    patch_heytap_speech_assist
    patch_ota_apk
    patch_aiunit_apk
    patch_oplus_launcher
    patch_systemui_apk
    patch_aod_apk
    patch_gallery_apk
    patch_battery_apk

    rm -rf tmp
    log_ok "APK/smali patching completed."

    log_info "Building images..."

    build_image "system"     "portrom/system/system"         "portrom/system/config"
    build_image "system_ext" "portrom/system_ext/system_ext" "portrom/system_ext/config"
    build_image "product"    "portrom/product/product"        "portrom/product/config"
    build_image "vendor"     "baserom/vendor"                 "baserom/config"

    mkdir -p out
    build_recovery
    build_super
    package_zip

    local elapsed=$(( SECONDS - BUILD_START ))
    log_ok "Done in $(( elapsed / 60 ))m $(( elapsed % 60 ))s"
}

main

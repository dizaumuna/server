#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# ColorOS / OxygenOS / Realme UI
# Author: dizaumuna
#

set -euo pipefail
trap 'echo "[ERROR] Line $LINENO: $BASH_COMMAND" >&2' ERR

WORK_DIR=$(pwd)
BUILD_START=${SECONDS}
PADDING=3

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
    if [[ "$name" =~ ^([a-zA-Z0-9_]+)_ ]]; then
        echo "${BASH_REMATCH[1]}"
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
        log_err "vendor.new.dat.br not found in base ROM"
        exit 1
    fi
}

extract_baserom_payload() {
    local zip="$1"
    log_info "Extracting base ROM [payload format]"
    mkdir -p baserom/raw
    unzip -q "$zip" payload.bin -d baserom/raw
    bin/payload-dumper-go -p vendor -o baserom/ baserom/raw/payload.bin > /dev/null
    log_ok "vendor.img extracted from payload"
}

extract_baserom_img() {
    local zip="$1"
    log_info "Extracting base ROM [img format]"
    mkdir -p baserom/raw
    unzip -q "$zip" "vendor.img" -d baserom/raw 2>/dev/null || \
    unzip -q "$zip" "vendor_a.img" -d baserom/raw 2>/dev/null || true
    find baserom/raw -name "vendor*.img" -exec mv -f {} baserom/vendor.img \;
    log_ok "vendor.img extracted"
}

extract_portrom() {
    local zip="$1"
    local type="$2"
    log_info "Extracting port ROM [$type format]"
    mkdir -p portrom

    if [[ "$type" == "payload" ]]; then
        unzip -q "$zip" payload.bin -d portrom/
        local parts="system,system_ext,vendor,product"
        for part in my_manifest my_heytap my_engineering my_bigball. my_carrier my_stock my_region my_product; do
            parts="${parts},${part}"
        done
        log_info "Dumping partitions: $parts"
        bin/payload-dumper-go -p "$parts" -o portrom/ portrom/payload.bin > /dev/null
        rm -f portrom/payload.bin
        log_ok "Port ROM partitions extracted"
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
        log_ok "Port ROM img files extracted"
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
    python3 tools/extractor.py "$img" "$outdir/$name/"
    log_ok "$name extracted"
}

mount_erofs_img() {
    local img="$1"
    local outdir="$2"
    local name
    name=$(basename "$img" .img)
    mkdir -p "$outdir/$name"
    log_info "Extracting [erofs] $name"
    bin/extract.erofs -i "$img" -o "$outdir/$name" -x > /dev/null 2>&1
    log_ok "$name extracted"
}

extract_img() {
    local img="$1"
    local outdir="$2"
    if [[ ! -f "$img" ]]; then
        log_warn "$img not found, skipping"
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

inject_imports() {
    local partitions="$1"

    local vendor_buildprop="baserom/vendor/build.prop"
    local odm_buildprop="baserom/vendor/odm/etc/build.prop"

    for part in $partitions; do
        local import_line="import /mnt/vendor/${part}/etc/build.prop"

        if [[ -f "$vendor_buildprop" ]]; then
            if ! grep -q "^${import_line}" "$vendor_buildprop"; then
                echo "$import_line" >> "$vendor_buildprop"
                log_ok "Added to vendor/build.prop: $import_line"
            fi
        fi

        if [[ -f "$odm_buildprop" ]]; then
            if ! grep -q "^${import_line}" "$odm_buildprop"; then
                echo "$import_line" >> "$odm_buildprop"
                log_ok "Added to vendor/odm/etc/build.prop: $import_line"
            fi
        fi
    done
}

move_my_partitions_to_system() {
    local partitions="$1"
    local system_dir="portrom/system/system"

    for part in $partitions; do
        local src="portrom/${part}"
        if [[ -d "$src" ]]; then
            log_info "Moving $part → $system_dir/$part"
            mkdir -p "$system_dir/$part"
            cp -rf "$src/." "$system_dir/$part/"
            rm -rf "$src"
            log_ok "$part moved"
        else
            log_warn "$src not found, skipping"
        fi
    done
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
        python3 bin/fspatch.py baserom/config/vendor_file_contexts

    for part in system system_ext product; do
        local ctx="portrom/${part}/config/${part}_file_contexts"
        [[ -f "$ctx" ]] && python3 bin/fspatch.py "$ctx"
    done

    local sys_ctx="portrom/system/config/system_file_contexts"
    if [[ -f "$sys_ctx" ]]; then
        sed -i 's|^\(/system/my_[^ ]*\) u:object_r:system_file:s0|\1(/.*)?    u:object_r:system_file:s0|' "$sys_ctx"
    fi

    log_ok "File contexts patched"
}

build_image() {
    local name="$1"
    local rootfs="$2"
    local config_dir="$3"
    local fs="$4"

    if [[ ! -d "$rootfs" ]]; then
        log_warn "$name has no rootfs ($rootfs), skipping"
        return
    fi

    local size pad_size
    size=$(du -sb "$rootfs" | cut -f1)
    pad_size=$(( size + size * PADDING / 100 ))

    local fs_config="${config_dir}/${name}_fs_config"
    local contexts="${config_dir}/${name}_file_contexts"

    log_info "Building $name.img (fs=$fs, size=$pad_size)"

    if [[ "$fs" == "ext4" ]]; then
        local args="-s -L $name -a $name -J -T 1"
        [[ -f "$fs_config" ]] && args="$args -C $fs_config"
        [[ -f "$contexts" ]] && args="$args -S $contexts"
        eval bin/make_ext4fs $args -l "$pad_size" "${name}.img" "$rootfs"
    elif [[ "$fs" == "erofs" ]]; then
        local args="-b 4096 -T 1"
        [[ -f "$fs_config" ]] && args="$args --fs-config-file $fs_config"
        [[ -f "$contexts" ]] && args="$args --file-contexts $contexts"
        eval bin/e2fsdroid $args -f "$rootfs" -a "/$name" "${name}.img"
    else
        log_err "Unknown filesystem type: $fs"
        exit 1
    fi

    sleep 5
    echo "$pad_size" > "${name}.size"
    log_ok "$name.img built (size=$pad_size)"
}

patch_build_props() {
    local base_device_code port_device_code
    local base_product_model port_product_model
    local base_product_name port_product_name

    local my_manifest_prop="portrom/my_manifest/build.prop"
    local base_manifest_prop=""

    if [[ -f portrom/system/system/my_manifest/build.prop ]]; then
        my_manifest_prop="portrom/system/system/my_manifest/build.prop"
    fi

    base_device_code=$(get_prop baserom/vendor/build.prop "ro.product.device" || true)
    port_device_code=$(get_prop "$my_manifest_prop" "ro.oplus.version.my_manifest" 2>/dev/null | cut -d'_' -f1 || true)
    [[ -z "$port_device_code" ]] && port_device_code=$(get_prop "$my_manifest_prop" "ro.product.model" || true)

    base_product_model=$(get_prop baserom/vendor/build.prop "ro.product.model" || true)
    port_product_model=$(get_prop "$my_manifest_prop" "ro.product.model" || true)
    base_product_name=$(get_prop baserom/vendor/build.prop "ro.product.name" || true)
    port_product_name=$(get_prop "$my_manifest_prop" "ro.product.name" || true)

    log_info "Base device: $base_device_code / $base_product_model"
    log_info "Port device: $port_device_code / $port_product_model"

    local build_date build_utc
    build_date=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
    build_utc=$(date +%s)

    while IFS= read -r prop_file; do
        [[ -n "$port_device_code" && -n "$base_device_code" ]] && \
            sed -i "s|${port_device_code}|${base_device_code}|g" "$prop_file" || true
        [[ -n "$port_product_model" && -n "$base_product_model" ]] && \
            sed -i "s|${port_product_model}|${base_product_model}|g" "$prop_file" || true
        [[ -n "$port_product_name" && -n "$base_product_name" ]] && \
            sed -i "s|${port_product_name}|${base_product_name}|g" "$prop_file" || true
        sed -i "s|ro.build.date=.*|ro.build.date=${build_date}|g" "$prop_file" || true
        sed -i "s|ro.build.date.utc=.*|ro.build.date.utc=${build_utc}|g" "$prop_file" || true
    done < <(find portrom/ -name "build.prop")

    log_ok "Build props patched"
}

disable_avb() {
    log_info "Disabling AVB verification"
    while IFS= read -r fstab; do
        sed -i 's/,avb_keys=[^ ]*//g' "$fstab"
        sed -i 's/,avb=vbmeta_system//g' "$fstab"
        sed -i 's/,avb=vbmeta_vendor//g' "$fstab"
        sed -i 's/,avb=vbmeta//g' "$fstab"
        sed -i 's/,avb//g' "$fstab"
    done < <(find baserom/ portrom/ -name "fstab.*" 2>/dev/null)
    log_ok "AVB disabled"
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
            if [[ -f "$size_file" ]]; then
                local sz
                sz=$(cat "$size_file")
                lpargs="$lpargs --partition ${part}:readonly:${sz}:${group} -i ${part}=${img}"
            else
                local sz
                sz=$(stat -c%s "$img")
                lpargs="$lpargs --partition ${part}:readonly:${sz}:${group} -i ${part}=${img}"
            fi
        fi
    done

    eval bin/lpmake $lpargs -o super.img
    log_ok "super.img built"
}

package_zip() {
    local zipname="${TARGET_OUTPUT_ZIP}.zip"
    log_info "Packaging: $zipname"

    rm -rf repack
    mkdir -p repack out

    cp -f super.img repack/

    cd repack
    zip -r "$zipname" . > /dev/null
    cd "$WORK_DIR"

    mv -f "repack/$zipname" "out/$zipname"
    log_ok "Output: out/$zipname"
}

debloat() {
    # Copyright (C) 2026 diza u muna 
    # my_bigball/app
    rm -rf port/my_bigball/my_bigball/app/Facebook-appmanager
    rm -rf port/my_bigball/my_bigball/app/GoogleContacts
    rm -rf port/my_bigball/my_bigball/app/GPay3
    rm -rf port/my_bigball/my_bigball/app/LatinImeGoogle
    rm -rf port/my_bigball/my_bigball/app/Meet
    rm -rf port/my_bigball/my_bigball/app/Photos
    
    # my_bigball/del-app-pre
    rm -rf port/my_bigball/my_bigball/del-app-pre/Drive_del
    rm -rf port/my_bigball/my_bigball/del-app-pre/Facebook
    rm -rf port/my_bigball/my_bigball/del-app-pre/GoogleFindMyDevice
    rm -rf port/my_bigball/my_bigball/del-app-pre/GoogleHome
    rm -rf port/my_bigball/my_bigball/del-app-pre/GoogleOne
    rm -rf port/my_bigball/my_bigball/del-app-pre/Videos_del
    rm -rf port/my_bigball/my_bigball/del-app-pre/YTMusic_del

    # my_bigball/etc/sysconfig
    rm -rf port/my_bigball/my_bigball/etc/sysconfig/com.google.android.dialer.support.xml
        
    # my_bigball/framework
    rm -rf port/my_bigball/my_bigball/framework/com.google.android.dialer.support.jar

    # my_bigball/overlay
    rm -rf port/my_bigball/my_bigball/overlay/GmsConfigOverlayASI
    rm -rf port/my_bigball/my_bigball/overlay/GmsConfigOverlayCommonCN
    rm -rf port/my_bigball/my_bigball/overlay/GmsConfigOverlayCommonEx
    rm -rf port/my_bigball/my_bigball/overlay/GmsConfigOverlayComms
    rm -rf port/my_bigball/my_bigball/overlay/OplusConfigOverlayComms

    # my_bigball/priv-app
    rm -rf port/my_bigball/my_bigball/priv-app/Facebook-installer
    rm -rf port/my_bigball/my_bigball/priv-app/Facebook-services
    rm -rf port/my_bigball/my_bigball/priv-app/GoogleDialer
    rm -rf port/my_bigball/my_bigball/priv-app/Messages
    rm -rf port/my_bigball/my_bigball/priv-app/PlayAutoInstallConfig_OnePlus
    rm -rf port/my_bigball/my_bigball/priv-app/SearchSelector

    # my_product/app
    rm -rf port/my_product/my_product/app/CalendarGoogle
    rm -rf port/my_product/my_product/app/Chrome64
    rm -rf port/my_product/my_product/app/Gmail2
    rm -rf port/my_product/my_product/app/GoogleLens
    rm -rf port/my_product/my_product/app/GoogleLocationHistory
    rm -rf port/my_product/my_product/app/Maps
    rm -rf port/my_product/my_product/app/OplusCamera
    rm -rf port/my_product/my_product/app/talkback
    rm -rf port/my_product/my_product/app/YouTube
    rm -rf port/my_product/my_product/app/WebViewGoogle64
    rm -rf port/my_product/my_product/app/TrichromeLibrary64

    # my_product/del-app
    rm -rf port/my_product/my_product/del-app/ConsumerIRApp

    # my_product/priv-app
    rm -rf port/my_product/my_product/priv-app/GoogleFiles
    rm -rf port/my_product/my_product/priv-app/GoogleVelvet_CTS
    rm -rf port/my_product/my_product/priv-app/Phonesky
    rm -rf port/my_product/my_product/priv-app/Wellbeing
    rm -rf port/my_product/my_product/priv-app/SOSHelper

    # my_product/overlay
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_COSMOS.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_FIREWORKS.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_FY.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_NONE.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_QY.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_RIPPLE.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_STRIPE.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_SW.apk
    rm -rf port/my_product/my_product/overlay/SystemUIFingerprintRes_Halo.apk

    # my_stock/app
    rm -rf port/my_product/my_stock/app/BeaconLink
    rm -rf port/my_product/my_stock/app/Browser
    rm -rf port/my_product/my_stock/app/ChildrenSpace
    rm -rf port/my_product/my_stock/app/CloudService
    rm -rf port/my_product/my_stock/app/FloatAssistant
    rm -rf port/my_product/my_stock/app/  KeKePay
    rm -rf port/my_product/my_stock/app/OplusOperationManual
    rm -rf port/my_product/my_stock/app/OplusSecurityKeyboard
    rm -rf port/my_product/my_stock/app/PhoneNOAreaInquireProvider
    rm -rf port/my_product/my_stock/app/Portrait
    rm -rf port/my_product/my_stock/app/SceneMode
    rm -rf port/my_product/my_stock/app/SecurePay
    rm -rf port/my_product/my_stock/app/SoftsimRedteaRoaming
    rm -rf port/my_product/my_stock/app/  SmartSideBar
    rm -rf port/my_product/my_stock/app/Calculator2
    rm -rf port/my_product/my_stock/app/FileManager

    # my_stock/del-app
    rm -rf port/my_product/my_stock/del-app/BackupAndRestore
    rm -rf port/my_product/my_stock/del-app/INOnePlusStore
    rm -rf port/my_product/my_stock/del-app/OPBreathMode
    rm -rf port/my_product/my_stock/del-app/OPForum
    rm -rf port/my_product/my_stock/del-app/Pictorial
    rm -rf port/my_product/my_stock/del-app/NewSoundRecorder
    rm -rf port/my_product/my_stock/del-app/OppoNote2
    rm -rf port/my_product/my_stock/del-app/OppoTranslation

    # my_stock/priv-app
    rm -rf port/my_product/my_stock/priv-app/BlackListApp
    rm -rf port/my_product/my_stock/priv-app/dmp
    rm -rf port/my_product/my_stock/priv-app/HeyCast
    rm -rf port/my_product/my_stock/priv-app/KeKeMarket
    rm -rf port/my_product/my_stock/priv-app/LinktoWindows
    rm -rf port/my_product/my_stock/priv-app/NumberRecognition
    log_ok "Debloated system successfully."
}

main() {
    local device
    device=$(detect_device "$BASEROM")
    load_config "$device"

    log_info "Cleaning up"
    rm -rf baserom portrom repack *.img *.size
    log_ok "Clean"

    case "$TARGET_BASEROM_TYPE" in
        dat.br)  extract_baserom_datbr "$BASEROM" ;;
        payload) extract_baserom_payload "$BASEROM" ;;
        img)     extract_baserom_img "$BASEROM" ;;
        *) log_err "Unknown TARGET_BASEROM_TYPE: $TARGET_BASEROM_TYPE"; exit 1 ;;
    esac

    extract_portrom "$PORTROM" "$TARGET_PORTROM_TYPE"

    log_info "Extracting partition images"
    extract_img baserom/vendor.img baserom

    for part in system system_ext product; do
        local img="portrom/${part}.img"
        [[ -f "$img" ]] && extract_img "$img" portrom || log_warn "$img not found"
    done

    for part in my_manifest my_product my_stock my_region my_company my_preload; do
        local img="portrom/${part}.img"
        [[ -f "$img" ]] && extract_img "$img" portrom || true
    done

    if [[ "$TARGET_NEEDS_IMPORT" == "true" ]]; then
        log_info "Injecting import lines"
        move_my_partitions_to_system "$TARGET_IMPORT_PARTITIONS"
        inject_imports "$TARGET_IMPORT_PARTITIONS"
    fi

    patch_build_props
    disable_avb
    patch_file_contexts
    debloat

    log_info "Building images"

    build_image "system"     "portrom/system/system"         "portrom/system/config"     "$TARGET_FS"
    build_image "system_ext" "portrom/system_ext/system_ext" "portrom/system_ext/config" "$TARGET_FS"
    build_image "product"    "portrom/product/product"       "portrom/product/config"     "$TARGET_FS"
    build_image "vendor"     "baserom/vendor"                "baserom/config"             "ext4"

    build_super
    package_zip

    local elapsed=$(( SECONDS - BUILD_START ))
    log_ok "Done in $(( elapsed / 60 ))m $(( elapsed % 60 ))s"
}

main

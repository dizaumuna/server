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
    log_ok "vendor.img extracted."
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
    log_info "Extracting [erofs] $name"
    bin/extract.erofs -i "$img" -o "$outdir/$name" -x > /dev/null 2>&1
    log_ok "$name extracted."

    mkdir -p "$outdir/vendor"
    log_info "Extracting [erofs] vendor"
    bin/extract.erofs -i portrom/vendor.img -o "$outdir/vendor" -x > /dev/null 2>&1
    log_ok "vendor extracted."
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
 
inject_imports() {
    local partitions="$1"
 
    local vendor_buildprop="baserom/vendor/build.prop"
    local odm_buildprop="baserom/vendor/odm/etc/build.prop"
 
    for part in $partitions; do
        local import_line="import /${part}/build.prop"
 
        if [[ -f "$odm_buildprop" ]]; then
            if ! grep -qF "$import_line" "$odm_buildprop"; then
                echo "$import_line" >> "$odm_buildprop"
                log_ok "Added to build.prop: $import_line"
            fi
        fi
    done
}
 
move_my_partitions_to_system() {
    local partitions="$1"
    local system_dir="portrom/system/system/"
 
    for part in $partitions; do
        local src="portrom/${part}"
        if [[ -d "$src" ]]; then
            log_info "Moving $part → $system_dir/$part"
            mkdir -p "$system_dir/$part"
            cp -rf "$src/." "$system_dir/$part/"
            rm -rf "$src"
            log_ok "$part moved."
        else
            log_warn "$src not found, skipping."
        fi
    done
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
 
patch_semi_vendor() {
    log_info "Semi-patching vendor for FP..."
 
    rm -rf baserom/vendor/etc/group
    rm -rf baserom/vendor/etc/passwd
 
    mv portrom/vendor/vendor/etc/group baserom/vendor/etc/group
    mv portrom/vendor/vendor/etc/passwd baserom/vendor/etc/passwd
    log_ok "Patching finished."
}
 
# ─────────────────────────────────────────────────────────────────────────────
# APK / smali patch helpers
# ─────────────────────────────────────────────────────────────────────────────
 
patch_apk() {
    # usage: patch_apk <apk_path> <smali_func> [extra args for patchmethod_v2.py]
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
 
    # Patch 1: assertMinSignatureSchemeIsValid → stub
    local scan_pkg
    scan_pkg=$(find tmp/services -type f -name "ScanPackageUtils.smali")
    if [[ -f "$scan_pkg" ]]; then
        python3 bin/patchmethod_v2.py "$scan_pkg" assertMinSignatureSchemeIsValid && \
            log_ok "ScanPackageUtils patched."
    fi
 
    # Patch 2: getMinimumSignatureSchemeVersionForTargetSdk → return 0
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
 
    # Patch 3: ALLOW_NON_PRELOADS_SYSTEM_SHAREDUIDS → force true
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
 
    # AOD Panoramic
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
 
    # CTS patch
    python3 bin/patchmethod_v2.py -d tmp/SystemUI -n isCtsTest -return false
 
    # My Device (non-CN)
    local feature_smali
    feature_smali=$(find tmp/SystemUI -type f -path "*/systemui/common/feature/FeatureOption.smali")
    [[ -f "$feature_smali" ]] && \
        python3 bin/patchmethod_v2.py "$feature_smali" isSupportMyDevice -return true
 
    # styles.xml null ref fix
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
 
    log_info "Patching Aod.apk (force AOD always-on)..."
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
    log_info "Decompiling Settings.apk with apktool..."

    mkdir -p tmp
    mv portrom/system_ext/system_ext/priv-app/Settings/Settings.apk tmp/
    cd tmp/

    log_info "Downloading apktool..."
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
    log_info "Building APK..."
    java -jar ../apktool.jar b -o Settings_patched.apk
    mv Settings_patched.apk ../
    cd ..
    keytool -genkey -v -keystore signkey.keystore -alias signkey \
    -keyalg RSA -keysize 2048 -validity 10000

    jarsigner -keystore testkey.keystore Settings_patched.apk signkey

    mv Settings_patched.apk portrom/system_ext/system_ext/priv-app/Settings/Settings.apk
    log_ok "Patched Settings.apk successfully."
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
 
# ───────────────────────────── APK/SMALI PATCH END ───────────────────────────────────────────────
 
build_image() {
  NAME=$1
  ROOTFS=$2
  CONFIG_DIR=$3

  echo "  - Processing build of $NAME..."

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

  if [ $? -eq 0 ]; then
    echo "  - Successfully builded $NAME."
  else
    echo "  - Failed while building $NAME."
  fi

  echo
}
 
patch_build_props() {
    local base_device_code port_device_code
    local base_product_model port_product_model
    local base_product_name port_product_name
 
    local my_manifest_prop="portrom/my_manifest/build.prop"
 
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
 
    log_ok "build.prop patched successfully."
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
    log_ok "Android Verified Boot disabled on fstab successfully."
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
}
 
package_zip() {
    local zipname="${TARGET_OUTPUT_ZIP}.zip"
    log_info "Packaging: $zipname"
 
    rm -rf repack
    mkdir -p repack
    mkdir -p out
 
    cp -f super.img repack/
 
    cd repack
    zip -r "$zipname" . > /dev/null
    cd "$WORK_DIR"
 
    mv -f "repack/$zipname" "out/$zipname"
    log_ok "OTA ZIP is in here: out/$zipname"
}
 
debloat() {
    # my_bigball/app
    rm -rf portrom/my_bigball/my_bigball/app/Facebook-appmanager
    rm -rf portrom/my_bigball/my_bigball/app/GoogleContacts
    rm -rf portrom/my_bigball/my_bigball/app/GPay3
    rm -rf portrom/my_bigball/my_bigball/app/LatinImeGoogle
    rm -rf portrom/my_bigball/my_bigball/app/Meet
    rm -rf portrom/my_bigball/my_bigball/app/Photos
 
    # my_bigball/del-app-pre
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/Drive_del
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/Facebook
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/GoogleFindMyDevice
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/GoogleHome
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/GoogleOne
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/Videos_del
    rm -rf portrom/my_bigball/my_bigball/del-app-pre/YTMusic_del
 
    # my_bigball/etc/sysconfig
    rm -rf portrom/my_bigball/my_bigball/etc/sysconfig/com.google.android.dialer.support.xml
 
    # my_bigball/framework
    rm -rf portrom/my_bigball/my_bigball/framework/com.google.android.dialer.support.jar
 
    # my_bigball/overlay
    rm -rf portrom/my_bigball/my_bigball/overlay/GmsConfigOverlayASI
    rm -rf portrom/my_bigball/my_bigball/overlay/GmsConfigOverlayCommonCN
    rm -rf portrom/my_bigball/my_bigball/overlay/GmsConfigOverlayCommonEx
    rm -rf portrom/my_bigball/my_bigball/overlay/GmsConfigOverlayComms
    rm -rf portrom/my_bigball/my_bigball/overlay/OplusConfigOverlayComms
 
    # my_bigball/priv-app
    rm -rf portrom/my_bigball/my_bigball/priv-app/Facebook-installer
    rm -rf portrom/my_bigball/my_bigball/priv-app/Facebook-services
    rm -rf portrom/my_bigball/my_bigball/priv-app/GoogleDialer
    rm -rf portrom/my_bigball/my_bigball/priv-app/Messages
    rm -rf portrom/my_bigball/my_bigball/priv-app/PlayAutoInstallConfig_OnePlus
    rm -rf portrom/my_bigball/my_bigball/priv-app/SearchSelector
 
    # my_product/app
    rm -rf portrom/my_product/my_product/app/CalendarGoogle
    rm -rf portrom/my_product/my_product/app/Chrome64
    rm -rf portrom/my_product/my_product/app/Gmail2
    rm -rf portrom/my_product/my_product/app/GoogleLens
    rm -rf portrom/my_product/my_product/app/GoogleLocationHistory
    rm -rf portrom/my_product/my_product/app/Maps
    rm -rf portrom/my_product/my_product/app/OplusCamera
    rm -rf portrom/my_product/my_product/app/talkback
    rm -rf portrom/my_product/my_product/app/YouTube
    rm -rf portrom/my_product/my_product/app/WebViewGoogle64
    rm -rf portrom/my_product/my_product/app/TrichromeLibrary64
 
    # my_product/del-app
    rm -rf portrom/my_product/my_product/del-app/ConsumerIRApp
 
    # my_product/priv-app
    rm -rf portrom/my_product/my_product/priv-app/GoogleFiles
    rm -rf portrom/my_product/my_product/priv-app/GoogleVelvet_CTS
    rm -rf portrom/my_product/my_product/priv-app/Phonesky
    rm -rf portrom/my_product/my_product/priv-app/Wellbeing
    rm -rf portrom/my_product/my_product/priv-app/SOSHelper
 
    # my_product/overlay
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_COSMOS.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_FIREWORKS.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_FY.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_NONE.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_QY.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_RIPPLE.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_STRIPE.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_13_0_SW.apk
    rm -rf portrom/my_product/my_product/overlay/SystemUIFingerprintRes_Halo.apk
 
    # my_stock/app
    rm -rf portrom/my_stock/my_stock/app/BeaconLink
    rm -rf portrom/my_stock/my_stock/app/Browser
    rm -rf portrom/my_stock/my_stock/app/ChildrenSpace
    rm -rf portrom/my_stock/my_stock/app/CloudService
    rm -rf portrom/my_stock/my_stock/app/FloatAssistant
    rm -rf portrom/my_stock/my_stock/app/KeKePay
    rm -rf portrom/my_stock/my_stock/app/OplusOperationManual
    rm -rf portrom/my_stock/my_stock/app/OplusSecurityKeyboard
    rm -rf portrom/my_stock/my_stock/app/PhoneNOAreaInquireProvider
    rm -rf portrom/my_stock/my_stock/app/Portrait
    rm -rf portrom/my_stock/my_stock/app/SceneMode
    rm -rf portrom/my_stock/my_stock/app/SecurePay
    rm -rf portrom/my_stock/my_stock/app/SoftsimRedteaRoaming
    rm -rf portrom/my_stock/my_stock/app/SmartSideBar
    rm -rf portrom/my_stock/my_stock/app/Calculator2
    rm -rf portrom/my_stock/my_stock/app/FileManager
 
    # my_stock/del-app
    rm -rf portrom/my_stock/my_stock/del-app/BackupAndRestore
    rm -rf portrom/my_stock/my_stock/del-app/INOnePlusStore
    rm -rf portrom/my_stock/my_stock/del-app/OPBreathMode
    rm -rf portrom/my_stock/my_stock/del-app/OPForum
    rm -rf portrom/my_stock/my_stock/del-app/Pictorial
    rm -rf portrom/my_stock/my_stock/del-app/NewSoundRecorder
    rm -rf portrom/my_stock/my_stock/del-app/OppoNote2
    rm -rf portrom/my_stock/my_stock/del-app/OppoTranslation
 
    # my_stock/priv-app
    rm -rf portrom/my_stock/my_stock/priv-app/BlackListApp
    rm -rf portrom/my_stock/my_stock/priv-app/dmp
    rm -rf portrom/my_stock/my_stock/priv-app/HeyCast
    rm -rf portrom/my_stock/my_stock/priv-app/KeKeMarket
    rm -rf portrom/my_stock/my_stock/priv-app/LinktoWindows
    rm -rf portrom/my_stock/my_stock/priv-app/NumberRecognition
 
    log_ok "Debloated successfully."
}
 
main() {
    local device
    device=$(detect_device "$BASEROM")
    load_config "$device"
 
    log_info "Cleaning up before processing porting..."
    rm -rf baserom portrom repack tmp *.img *.size
 
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
 
    if [[ "$TARGET_NEEDS_IMPORT" == "true" ]]; then
        log_info "Adding import lines..."
        move_my_partitions_to_system "$TARGET_IMPORT_PARTITIONS"
        inject_imports "$TARGET_IMPORT_PARTITIONS"
    fi
 
    patch_build_props
    disable_avb
    patch_file_contexts
    patch_semi_vendor
    debloat
 
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
    log_ok "APK/smali patching complete."
 
    log_info "Building images..."
 
    build_image \
      "system" \
      "portrom/system/system" \
      "portrom/system/config"
    
    build_image \
      "system_ext" \
      "portrom/system_ext/system_ext" \
      "portrom/system_ext/config"
    
    build_image \
      "product" \
      "portrom/product/product" \
      "portrom/product/config"
    
    build_image \
      "vendor" \
      "baserom/vendor" \
      "baserom/config"
 
    build_super
    package_zip
 
    local elapsed=$(( SECONDS - BUILD_START ))
    log_ok "Done in $(( elapsed / 60 ))m $(( elapsed % 60 ))s"
}
 
main

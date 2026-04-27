#!/bin/bash

set -euo pipefail

VENDOR="workdir/vendor"
BUILTS="builts"

die() { echo "Fail: $1"; exit 1; }

[ -d "$VENDOR" ] || die "workdir/vendor not found"
[ -d "$BUILTS" ] || die "builts/ not found"

# trash porting, with fixed camera.

patch_build_prop() {
    local FILE="$VENDOR/build.prop"

    sed_prop() {
        local KEY="$1" VAL="$2"
        if grep -q "^${KEY}=" "$FILE"; then
            sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$FILE"
        else
            echo "${KEY}=${VAL}" >> "$FILE"
        fi
    }

    sed_prop "ro.vendor.build.date" "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "ro.vendor.build.date.utc" "26061989"
    sed_prop "ro.vendor.build.fingerprint" "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "ro.vendor.build.id" "AQ3A.240812.002"
    sed_prop "ro.vendor.build.security_patch" "2025-06-01"
    sed_prop "ro.vendor.build.version.incremental" "OS2.0.212.0.VOBCNXM"
    sed_prop "ro.vendor.build.version.release" "15"
    sed_prop "ro.vendor.build.version.release_or_codename" "15"
    sed_prop "ro.bootimage.build.date" "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "ro.bootimage.build.date.utc" "26061989"
    sed_prop "ro.bootimage.build.fingerprint" "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "ro.product.vendor.name" "joyeuse"
    sed_prop "ro.product.vendor.model" "M2003J6B2G"
    sed_prop "ro.product.vendor.marketname" "Redmi Note 9 Pro"
    sed_prop "ro.product.vendor.cert" "M2003J6B2G"

    sed_prop "ro.surface_flinger.enable_frame_rate_override" "false"
    sed_prop "ro.surface_flinger.set_display_power_timer_ms" "1000"
    sed_prop "ro.surface_flinger.set_idle_timer_ms" "4000"
    sed_prop "ro.surface_flinger.set_touch_timer_ms" "4000"

    sed_prop "ro.vendor.audio.voice.change.support" "true"
    sed_prop "ro.vendor.audio.voice.change.version" "2"
    sed_prop "ro.vendor.audio.voice.change.youme.support" "true"
    sed_prop "ro.vendor.audio.voice.volume.boost" "manual"
    sed_prop "ro.vendor.audio.sfx.scenario" "true"
    sed_prop "ro.vendor.audio.misound.bluetooth.enable" "true"

    sed_prop "persist.vendor.fingerprint.sensor_type" "side"
    sed_prop "persist.vendor.side.fp.near.feature.support" "true"
    sed_prop "ro.hardware.fp.sideCap" "true"

    sed_prop "ro.vendor.nfc.RF.conf.items" "8"
    sed_prop "ro.vendor.nfc.customRF" "1"
    sed_prop "ro.vendor.nfc.debounce_field_on" "1"
    sed_prop "ro.vendor.nfc.disable.i2c" "false"
    sed_prop "ro.vendor.nfc.dispatch_optim" "2"
    sed_prop "ro.vendor.nfc.field_on_debounce" "800"
    sed_prop "ro.vendor.nfc.mibeam.version" "3"
    sed_prop "ro.vendor.nfc.mibeam" "1"
    sed_prop "ro.vendor.nfc.repair" "1"
    sed_prop "ro.vendor.nfc.secure_display_optim" "1"
    sed_prop "ro.vendor.nfc.selectcard" "1"
    sed_prop "ro.vendor.nfc.wallet_fusion" "1"

    sed_prop "ro.telephony.iwlan_operation_mode" "legacy"

    sed_prop "sys.haptic.flick.light" "7,2"
    sed_prop "sys.haptic.mesh.heavy" "8,2"
    sed_prop "sys.haptic.mesh.normal" "5,2"
    sed_prop "sys.haptic.mesh.light" "5,1"
    sed_prop "sys.haptic.pickup" "2,2"
    sed_prop "sys.haptic.scroll.edge" "7,0"
    sed_prop "sys.haptic.hold" "4,0"

    sed_prop "persist.vendor.touchfeature.gameturbotool.version" "v3"
    sed_prop "ro.vendor.sensor.maxbrightness" "500"
    sed_prop "persist.vendor.qcom.bluetooth.soc" "cherokee"

    sed_prop "vendor.display.disable_hw_recovery_dump" "1"
    sed_prop "vendor.display.disable_ui_3d_tonemap" "1"
    sed_prop "vendor.display.dataspace_saturation_matrix" "1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0"
    sed_prop "vendor.display.comp_mask" "0"
    sed_prop "vendor.display.svi.config" "1"
    sed_prop "vendor.display.svi.config_path" "/vendor/etc/SVIConfig.xml"

    sed_prop "vendor.mm.enable.qcom_parser" "63963135"
    sed_prop "vendor.pasr.activemode.enabled" "true"
    sed_prop "vendor.power.pasr.enabled" "true"

    sed_prop "ro.miui.pm.install.buffer.size" "49152"
    sed_prop "ro.miui.pm.install.speedinstall" "/data/apk-tmp"
}

patch_odm_build_prop() {
    local FILE="$VENDOR/odm/etc/build.prop"
    [ -f "$FILE" ] || die "odm/etc/build.prop not found"

    sed_prop() {
        local KEY="$1" VAL="$2"
        if grep -q "^${KEY}=" "$FILE"; then
            sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$FILE"
        else
            echo "${KEY}=${VAL}" >> "$FILE"
        fi
    }

    sed_prop "ro.odm.build.date" "Wed Jul  2 19:05:00 CST 2025"
    sed_prop "ro.odm.build.date.utc" "26061989"
    sed_prop "ro.odm.build.fingerprint" "Redmi/joyeuse/joyeuse:15/AQ3A.240812.002/OS2.0.212.0.VOBCNXM:user/release-keys"
    sed_prop "ro.odm.build.id" "AQ3A.240812.002"
    sed_prop "ro.odm.build.tags" "release-keys"
    sed_prop "ro.odm.build.type" "user"
    sed_prop "ro.odm.build.version.incremental" "OS2.0.212.0.VOBCNXM"
    sed_prop "ro.odm.build.version.release" "15"
    sed_prop "ro.odm.build.version.release_or_codename" "15"
    sed_prop "ro.product.odm.name" "joyeuse"
    sed_prop "ro.product.odm.model" "M2003J6B2G"
    sed_prop "ro.product.odm.marketname" "Redmi Note 9 Pro"
    sed_prop "ro.product.odm.cert" "M2003J6B2G"

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
        if ! grep -q "^${KEY}=" "$FILE"; then
            echo "${KEY}=${VAL}" >> "$FILE"
        fi
    done
}

patch_fstab() {
    for FSTAB in "$VENDOR/etc/fstab.default" "$VENDOR/etc/fstab.emmc"; do
        [ -f "$FSTAB" ] || continue
        sed -i \
            's|wait,logical,first_stage_mount,avb=vbmeta_system,avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey|wait,logical,first_stage_mount|g' \
            "$FSTAB"
        sed -i \
            's|wait,logical,first_stage_mount,avb=vbmeta_system|wait,logical,first_stage_mount|g' \
            "$FSTAB"
        sed -i \
            's|wait,logical,first_stage_mount,avb\b|wait,logical,first_stage_mount|g' \
            "$FSTAB"
        sed -i \
            's|latemount,wait,check,formattable,fileencryption=ice,wrappedkey,|latemount,wait,check,formattable,wrappedkey,|g' \
            "$FSTAB"
    done
}

patch_selinux_file_contexts() {
    local FILE="$VENDOR/etc/selinux/vendor_file_contexts"
    [ -f "$FILE" ] || return
    sed -i 's|(vendor|sustem/vendor)|(vendor|system/vendor)|g' "$FILE"
}

patch_wifi_cfg() {
    local FILE="$VENDOR/etc/wifi/WCNSS_qcom_cfg.ini"
    [ -f "$FILE" ] || return
    sed -i 's/^gChannelBondingMode24GHz=0$/gChannelBondingMode24GHz=1/' "$FILE"
    sed -i 's/^sae_enabled=0$/sae_enabled=1/' "$FILE"
}

patch_camera_settings() {
    local FILE="$VENDOR/etc/camera/camxoverridesettings.txt"
    [ -f "$FILE" ] || return
    sed -i '/^advanceFeatureMask=0x7E7$/d' "$FILE"
}

patch_perf_config() {
    local FILE="$VENDOR/etc/perf/perfconfigstore.xml"
    [ -f "$FILE" ] || return
    sed -i '/<Prop Name="vendor.iop.enable_iop" Value="0" \/>/d' "$FILE"
}

patch_init_target_rc() {
    local FILE="$VENDOR/etc/init/hw/init.target.rc"
    [ -f "$FILE" ] || return
    sed -i 's|cnss_diag -q -f -t HELIUM|cnss_diag -q -t HELIUM|' "$FILE"
}

patch_ueventd() {
    local FILE="$VENDOR/ueventd.rc"
    [ -f "$FILE" ] || return
    sed -i 's|/dev/diag                 0660   system     oem_2901|/dev/diag                 0666   system     oem_2901|' "$FILE"
}

copy_builts() {
    cp_file() {
        local FILENAME="$1" DST_REL="$2"
        local SRC DST="$VENDOR/$DST_REL"

        case "$DST_REL" in
            lib64/*) SRC="$BUILTS/lib64/$FILENAME" ;;
            lib/*)   SRC="$BUILTS/lib/$FILENAME" ;;
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

    for F in \
        libaudiopreprocessing.so \
        libbundlewrapper.so \
        libdownmix.so \
        libdynproc.so \
        libeffectproxy.so \
        libldnhncr.so \
        libqcompostprocbundle.so \
        libqcomvisualizer.so \
        libqcomvoiceprocessing.so \
        libreverbwrapper.so \
        libvisualizer.so \
        libvolumelistener.so \
        libhwdap.so \
        libswdap.so \
        libswgamedap.so \
        libswvqe.so; do
        cp_file "$F" "lib/soundfx/$F"
        cp_file "$F" "lib64/soundfx/$F"
    done

    for F in \
        com.qti.sensormodule.ofilm_gc02m1.bin \
        com.qti.sensormodule.ofilm_gc02m1_filter.bin \
        com.qti.sensormodule.ofilm_ov16a1q.bin \
        com.qti.sensormodule.ofilm_ov2180.bin \
        com.qti.sensormodule.ofilm_ov8856.bin \
        com.qti.sensormodule.ofilm_s5k5e9.bin \
        com.qti.sensormodule.ofilm_s5kgm2.bin \
        com.qti.sensormodule.sunny_gc02m1.bin \
        com.qti.sensormodule.sunny_gc8034.bin \
        com.qti.sensormodule.sunny_hi556.bin \
        com.qti.sensormodule.sunny_imx582.bin \
        com.qti.sensormodule.sunny_ov16a1q.bin \
        com.qti.sensormodule.sunny_ov2180.bin \
        com.qti.sensormodule.sunny_ov8856.bin \
        com.qti.sensormodule.sunny_s5k5e9.bin \
        com.qti.sensormodule.sunny_s5kgm2.bin \
        com.qti.tuned.default.bin \
        com.qti.tuned.ofilm_gc02m1.bin \
        com.qti.tuned.ofilm_gc02m1_filter.bin \
        com.qti.tuned.ofilm_ov16a1q.bin \
        com.qti.tuned.ofilm_ov2180.bin \
        com.qti.tuned.ofilm_ov8856.bin \
        com.qti.tuned.ofilm_s5k5e9.bin \
        com.qti.tuned.ofilm_s5kgm2.bin \
        com.qti.tuned.sunny_gc8034.bin \
        com.qti.tuned.sunny_hi556.bin \
        com.qti.tuned.sunny_imx582.bin \
        com.qti.tuned.sunny_ov16a1q.bin \
        com.qti.tuned.sunny_ov2180.bin \
        com.qti.tuned.sunny_s5k5e9.bin \
        com.qti.tuned.sunny_s5kgm2.bin; do
        cp_file "$F" "lib/camera/$F"
        cp_file "$F" "lib64/camera/$F"
    done

    for F in \
        com.qti.eeprom.sunny_gc8034.so \
        com.qti.sensor.curtana_gc02m1.so \
        com.qti.sensor.curtana_gc8034.so \
        com.qti.sensor.curtana_hi556.so \
        com.qti.sensor.curtana_imx582.so \
        com.qti.sensor.curtana_ov16a1q.so \
        com.qti.sensor.curtana_ov2180.so \
        com.qti.sensor.curtana_ov8856.so \
        com.qti.sensor.curtana_s5k5e9.so \
        com.qti.sensor.curtana_s5kgm2.so \
        com.qti.sensor.excalibur_gc02m1.so \
        com.qti.sensor.excalibur_gc8034.so \
        com.qti.sensor.excalibur_hi556.so \
        com.qti.sensor.excalibur_ov2180.so \
        com.qti.sensor.excalibur_ov32a1q.so \
        com.qti.sensor.excalibur_ov8856.so \
        com.qti.sensor.excalibur_s5k5e9.so \
        com.qti.sensor.excalibur_s5kgw1.so; do
        cp_file "$F" "lib64/camera/$F"
    done

    for F in \
        com.almalence.node.sr.so \
        com.altek.node.depurple.so \
        com.altek.node.distortioncorrection.so \
        com.arcsoft.node.bodyslim.so \
        com.arcsoft.node.hdrchecker.so \
        com.arcsoft.node.hdr.so \
        com.arcsoft.node.realtimebokeh.so \
        com.arcsoft.node.skinbeautifier.so \
        com.miai.node.portraitsupernight.so \
        com.miai.node.supernight.so \
        com.mi.node.aiasd.so \
        com.qti.camx.chiiqutils.so \
        com.qti.node.dewarp.so \
        com.qti.node.eisv2.so \
        com.qti.node.eisv3.so \
        com.qti.node.fcv.so \
        com.qti.node.gpu.so \
        com.qti.node.photosolid.so \
        com.qti.node.swregistration.so \
        com.qti.node.watermark.so \
        com.qti.node.xiaomigenderage.so \
        com.qtistatic.stats.aec.so \
        com.qtistatic.stats.af.so \
        com.qtistatic.stats.awb.so \
        com.qtistatic.stats.pdlib.so \
        com.qti.stats.aecwrapper.so \
        com.qti.stats.afwrapper.so \
        com.qti.stats.awbwrapper.so \
        com.qti.stats.hafoverride.so \
        com.st.node.sr.so \
        com.vidhance.node.eis.so \
        com.vidhance.stats.aec_dmbr.so \
        com.visidon.node.clearshot.so \
        com.visidon.node.sr.so \
        com.xiaomi.node.mibokeh.so \
        com.xiaomi.node.mifilter.so \
        com.xiaomi.node.mifragment.so \
        com.xiaomi.node.mimovie.so \
        com.xiaomi.node.misegment.so; do
        cp_file "$F" "lib64/camera/components/$F"
    done
}

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

echo "Done."

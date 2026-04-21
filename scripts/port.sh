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
echo -e "${GRAY}Applying OS-various patches${RESET}"
LOG_STEP_IN "Commenting ro.product.first_api_level..."
sed -i 's/ro.product.first_api_level=34/#ro.product.first_api_level=34/g' workdir/port/my_manifest/my_manifest/build.prop

LOG_STEP_IN "Patching my_product build.prop..."
sed -i 's/ro.sf.lcd_density=560/ro.sf.lcd_density=440/' workdir/port/my_product/my_product/build.prop
sed -i 's/ro.oplus.display.screenhole.positon=596,40:668,112/# ro.oplus.display.screenhole.positon=596,40:668,112\nro.oplus.display.screenhole.positon=519,36:569,86/' workdir/port/my_product/my_product/build.prop
sed -i 's/ro.vendor.display.sensortype=2/# ro.vendor.display.sensortype=2/' workdir/port/my_product/my_product/build.prop
sed -i 's/^persist.oplus.display.vrr=1$/# persist.oplus.display.vrr=1/' workdir/port/my_product/my_product/build.prop
sed -i 's/^persist.oplus.display.vrr.adfr=2$/# persist.oplus.display.vrr.adfr=2/' workdir/port/my_product/my_product/build.prop
sed -i 's/^persist.oplus.display.vrr.adfr.scale=129$/# persist.oplus.display.vrr.adfr.scale=129/' workdir/port/my_product/my_product/build.prop
sed -i 's/^vendor.display.use_layer_ext=1$/# vendor.display.use_layer_ext=1/' workdir/port/my_product/my_product/build.prop
sed -i 's/ro.oplus.density.fhd_default=480/ro.oplus.density.fhd_default=440/' workdir/port/my_product/my_product/build.prop
sed -i 's/ro.oplus.resolution.low=1080,2376/ro.oplus.resolution.low=1080,2400/' workdir/port/my_product/my_product/build.prop
sed -i '/ro.oplus.gaussianlevel=3/d' workdir/port/my_product/my_product/build.prop
echo "debug.sf.disable_client_composition_cache=0" >> workdir/port/my_product/my_product/build.prop
echo -e "     ${GREEN}File modified: build.prop${RESET}"

LOG_STEP_IN "Patching my_product permissions..."
sed -i 's/<feature name="android.hardware.biometrics.face" \/>$/<!-- <feature name="android.hardware.biometrics.face" \/>  -->/' workdir/port/my_product/my_product/etc/permissions/com.oppo.features_allnet_android.xml
sed -i 's/<feature name="oppo.common.support.curved.display" \/>$/<!-- <feature name="oppo.common.support.curved.display" \/> -->/' workdir/port/my_product/my_product/etc/permissions/com.oppo.features_allnet_android.xml
sed -i 's/<oplus-feature name="oplus.software.fingeprint_optical_enabled"\/>$/<!-- <oplus-feature name="oplus.software.fingeprint_optical_enabled"\/> -->/' workdir/port/my_product/my_product/etc/permissions/oplus.product.display_features.xml
sed -i 's/<feature name="oplus.software.video.sr_support"\/>$/<!-- <feature name="oplus.software.video.sr_support"\/> -->/' workdir/port/my_product/my_product/etc/permissions/oplus.product.feature_video_unique.xml
sed -i 's/<feature name="oplus.software.video.osie_support"\/>$/<!-- <feature name="oplus.software.video.osie_support"\/> -->/' workdir/port/my_product/my_product/etc/permissions/oplus.product.feature_video_unique.xml
LOG_STEP_IN "Patching system build.prop..."
sed -i 's/dalvik.vm.minidebuginfo=true/dalvik.vm.minidebuginfo=false/' workdir/port/system/system/system/build.prop
sed -i 's/dalvik.vm.dex2oat-minidebuginfo=true/dalvik.vm.dex2oat-minidebuginfo=false/' workdir/port/system/system/system/build.prop
LOG_STEP_IN "Patching init.rc..."
sed -i 's/write \/proc\/sys\/kernel\/panic_on_oops 1/write \/proc\/sys\/kernel\/panic_on_oops 0/' workdir/port/system/system/system/etc/init/hw/init.rc
LOG_STEP_IN "Patching init.usb.rc..."
sed -i '/vendor.sys.usb.adb.disabled/d' workdir/port/system/system/system/etc/init/hw/init.usb.rc
sed -i '/persist.vendor.usb.config/d' workdir/port/system/system/system/etc/init/hw/init.usb.rc
sed -i '/persist.sys.usb.config.*persist.vendor/d' workdir/port/system/system/system/etc/init/hw/init.usb.rc
LOG_STEP_IN "Patching init.usb.configfs.rc..."
sed -i '/setusbconfig to/d' workdir/port/system/system/system/etc/init/hw/init.usb.configfs.rc
sed -i '/sys.usb.config=\* && property:sys.usb.configfs=1/d' workdir/port/system/system/system/etc/init/hw/init.usb.configfs.rc
sed -i '/rmdir.*rndis.gs4/d' workdir/port/system/system/system/etc/init/hw/init.usb.configfs.rc

cat >> workdir/port/system/system/system/etc/init/hw/init.usb.configfs.rc << 'EOF'

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

LOG_STEP_IN "Modifying atoll vendor..."
sed -i '/sys.thermal.data.path/d' workdir/basevendor/vendor/build.prop
sed -i 's/ro.control_privapp_permissions=$/ro.control_privapp_permissions=enforce/' workdir/basevendor/vendor/build.prop
sed -i 's/#ro.frp.pst/ro.frp.pst/' workdir/basevendor/vendor/build.prop
sed -i '/persist.vendor.radio.manual_nw_rej_ct/d' workdir/basevendor/vendor/build.prop
echo "persist.vendor.radio.manual_nw_rej_ct=1" >> workdir/basevendor/vendor/build.prop
echo "ro.product.mod_device=joyeuse_global" >> workdir/basevendor/vendor/build.prop
echo "ro.vendor.se.type=HCE,UICC" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.bg_apps_limit=48" >> workdir/basevendor/vendor/build.prop
echo "ro.vendor.qti.sys.fw.bservice_enable=true" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.empty_app_percent=50" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.use_trim_settings=true" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.trim_empty_percent=100" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.trim_enable_memory=2147483648" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.trim_cache_percent=100" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.bservice_age=120000" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.bservice_limit=6" >> workdir/basevendor/vendor/build.prop
echo "persist.sys.fw.bservice_enable=true" >> workdir/basevendor/vendor/build.prop
echo "" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.use_color_management=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.protected_contents=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.use_content_detection_for_refresh_rate=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.set_touch_timer_ms=200" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.force_hwc_copy_for_virtual_displays=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.max_frame_buffer_acquired_buffers=3" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.max_virtual_display_dimension=4096" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.supports_background_blur=1" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.has_wide_color_display=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.has_HDR_display=true" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.wcg_composition_dataspace=143261696" >> workdir/basevendor/vendor/build.prop
echo "# ro.surface_flinger.enable_frame_rate_override=false" >> workdir/basevendor/vendor/build.prop

LOG_STEP_IN "Patching ODM..."
cat >> workdir/basevendor/vendor/odm/etc/build.prop << 'EOF'
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
echo -e "     ${GREEN}File modified: build.prop on vendor${RESET}"

LOG_STEP_IN "Removing File Encryption..."
sed -i 's/,inlinecrypt\b//g; s/,fileencryption=ice,wrappedkey\b//g' workdir/basevendor/vendor/etc/fstab.default
sed -i 's/,inlinecrypt\b//g; s/,fileencryption=ice,wrappedkey\b//g' workdir/basevendor/vendor/etc/fstab.emmc
echo -e "     ${GREEN}File modified: fstab.emmc / fstab.default${RESET}"

LOG_STEP_IN "Porting OnePlus vendor to joyeuse..."
sudo rm -rf workdir/basevendor/vendor/etc/group
sudo rm -rf workdir/basevendor/vendor/etc/passwd
sudo cp -r workdir/port/vendor/vendor/etc/group workdir/basevendor/vendor/etc/
sudo cp -r workdir/port/vendor/vendor/etc/passwd workdir/basevendor/vendor/etc/
echo -e "     ${GREEN}File modified: group${RESET}"
echo -e "     ${GREEN}File modified: passwd${RESET}"

LOG_STEP_IN "Processing Overlays..."
sudo cp -r -f workdir/port/vendor/vendor/overlay/* workdir/basevendor/vendor/overlay/

LOG_STEP_IN "Processing OnePlus fixes..."
mv workdir/port/my_product/my_product workdir/port/system/system/
mv workdir/port/my_manifest/my_manifest workdir/port/system/system/
mv workdir/port/my_bigball/my_bigball workdir/port/system/system/
mv workdir/port/my_carrier/my_carrier workdir/port/system/system/
mv workdir/port/my_heytap/my_heytap workdir/port/system/system/
mv workdir/port/my_stock/my_stock workdir/port/system/system/
mv workdir/port/my_engineering/my_engineering workdir/port/system/system/
mv workdir/port/my_region/my_region workdir/port/system/system/

LOG_STEP_IN "Downloading Android VNDK 30..."
curl -# -L -o com.android.vndk.v30.apex https://github.com/dizaumuna/dizaumuna/releases/download/gn/com.android.vndk.v30.apex
mv com.android.vndk.v30.apex workdir/port/system_ext/system_ext/apex/
echo "#builded by dizaumuna" >> workdir/basevendor/vendor/build.prop

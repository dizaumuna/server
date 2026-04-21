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

LOG_STEP_IN "Debloating in process, please wait. This may take a while..."
sleep 10

# my_bigball/app
rm -rf workdir/port/system/system/my_bigball/app/Facebook-appmanager
rm -rf workdir/port/system/system/my_bigball/app/GoogleContacts
rm -rf workdir/port/system/system/my_bigball/app/GPay3
rm -rf workdir/port/system/system/my_bigball/app/LatinImeGoogle
rm -rf workdir/port/system/system/my_bigball/app/Meet
rm -rf workdir/port/system/system/my_bigball/app/Photos

# my_bigball/del-app-pre
rm -rf workdir/port/system/system/my_bigball/del-app-pre/Drive_del
rm -rf workdir/port/system/system/my_bigball/del-app-pre/Facebook
rm -rf workdir/port/system/system/my_bigball/del-app-pre/GoogleFindMyDevice
rm -rf workdir/port/system/system/my_bigball/del-app-pre/GoogleHome
rm -rf workdir/port/system/system/my_bigball/del-app-pre/GoogleOne
rm -rf workdir/port/system/system/my_bigball/del-app-pre/Videos_del
rm -rf workdir/port/system/system/my_bigball/del-app-pre/YTMusic_del

# my_bigball/etc/sysconfig
rm -rf workdir/port/system/system/my_bigball/etc/sysconfig/com.google.android.dialer.support.xml

# my_bigball/framework
rm -rf workdir/port/system/system/my_bigball/framework/com.google.android.dialer.support.jar

# my_bigball/overlay
rm -rf workdir/port/system/system/my_bigball/overlay/GmsConfigOverlayASI
rm -rf workdir/port/system/system/my_bigball/overlay/GmsConfigOverlayCommonCN
rm -rf workdir/port/system/system/my_bigball/overlay/GmsConfigOverlayCommonEx
rm -rf workdir/port/system/system/my_bigball/overlay/GmsConfigOverlayComms
rm -rf workdir/port/system/system/my_bigball/overlay/OplusConfigOverlayComms

# my_bigball/priv-app
rm -rf workdir/port/system/system/my_bigball/priv-app/Facebook-installer
rm -rf workdir/port/system/system/my_bigball/priv-app/Facebook-services
rm -rf workdir/port/system/system/my_bigball/priv-app/GoogleDialer
rm -rf workdir/port/system/system/my_bigball/priv-app/Messages
rm -rf workdir/port/system/system/my_bigball/priv-app/PlayAutoInstallConfig_OnePlus
rm -rf workdir/port/system/system/my_bigball/priv-app/SearchSelector

# my_product/app
rm -rf workdir/port/system/system/my_product/app/CalendarGoogle
rm -rf workdir/port/system/system/my_product/app/Chrome64
rm -rf workdir/port/system/system/my_product/app/Gmail2
rm -rf workdir/port/system/system/my_product/app/GoogleLens
rm -rf workdir/port/system/system/my_product/app/GoogleLocationHistory
rm -rf workdir/port/system/system/my_product/app/Maps
rm -rf workdir/port/system/system/my_product/app/OplusCamera
rm -rf workdir/port/system/system/my_product/app/talkback
rm -rf workdir/port/system/system/my_product/app/YouTube
rm -rf workdir/port/system/system/my_product/app/WebViewGoogle64
rm -rf workdir/port/system/system/my_product/app/TrichromeLibrary64

# my_product/del-app
rm -rf workdir/port/system/system/my_product/del-app/ConsumerIRApp

# my_product/priv-app
rm -rf workdir/port/system/system/my_product/priv-app/GoogleFiles
rm -rf workdir/port/system/system/my_product/priv-app/GoogleVelvet_CTS
rm -rf workdir/port/system/system/my_product/priv-app/Phonesky
rm -rf workdir/port/system/system/my_product/priv-app/Wellbeing
rm -rf workdir/port/system/system/my_product/priv-app/SOSHelper

# my_product/overlay
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_COSMOS.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_FIREWORKS.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_FY.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_NONE.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_QY.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_RIPPLE.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_STRIPE.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_13_0_SW.apk
rm -rf workdir/port/system/system/my_product/overlay/SystemUIFingerprintRes_Halo.apk

# my_stock/app
rm -rf workdir/port/system/system/my_stock/app/BeaconLink
rm -rf workdir/port/system/system/my_stock/app/Browser
rm -rf workdir/port/system/system/my_stock/app/ChildrenSpace
rm -rf workdir/port/system/system/my_stock/app/CloudService
rm -rf workdir/port/system/system/my_stock/app/FloatAssistant
rm -rf workdir/port/system/system/my_stock/app/KeKePay
rm -rf workdir/port/system/system/my_stock/app/OplusOperationManual
rm -rf workdir/port/system/system/my_stock/app/OplusSecurityKeyboard
rm -rf workdir/port/system/system/my_stock/app/PhoneNOAreaInquireProvider
rm -rf workdir/port/system/system/my_stock/app/Portrait
rm -rf workdir/port/system/system/my_stock/app/SceneMode
rm -rf workdir/port/system/system/my_stock/app/SecurePay
rm -rf workdir/port/system/system/my_stock/app/SoftsimRedteaRoaming
rm -rf workdir/port/system/system/my_stock/app/SmartSideBar
rm -rf workdir/port/system/system/my_stock/app/Calculator2
rm -rf workdir/port/system/system/my_stock/app/FileManager

# my_stock/del-app
rm -rf workdir/port/system/system/my_stock/del-app/BackupAndRestore
rm -rf workdir/port/system/system/my_stock/del-app/INOnePlusStore
rm -rf workdir/port/system/system/my_stock/del-app/OPBreathMode
rm -rf workdir/port/system/system/my_stock/del-app/OPForum
rm -rf workdir/port/system/system/my_stock/del-app/Pictorial
rm -rf workdir/port/system/system/my_stock/del-app/NewSoundRecorder
rm -rf workdir/port/system/system/my_stock/del-app/OppoNote2
rm -rf workdir/port/system/system/my_stock/del-app/OppoTranslation

# my_stock/priv-app
rm -rf workdir/port/system/system/my_stock/priv-app/BlackListApp
rm -rf workdir/port/system/system/my_stock/priv-app/dmp
rm -rf workdir/port/system/system/my_stock/priv-app/HeyCast
rm -rf workdir/port/system/system/my_stock/priv-app/KeKeMarket
rm -rf workdir/port/system/system/my_stock/priv-app/LinktoWindows
rm -rf workdir/port/system/system/my_stock/priv-app/NumberRecognition

# APEX
rm -rf workdir/port/system_ext/system_ext/apex/com.android.vndk.v33.apex

# Fonts
rm -rf workdir/port/system/system/system/fonts/Noto*

<div align="center">

# ColorOS / OxygenOS 移植项目

English&nbsp;&nbsp;|&nbsp;&nbsp;Written by humans btw <3

</div>

# Features
- Automatically move my_xxx partitions to system/
- Decompile Settings.apk, patch, recompile and signing APK.
- Auto ROM extraction.
- Anyone can maintain a device, so multiple devices supported.
- OTA ZIP generate and upload to PixelDrain with your API Key.
- Disable Android Verified Boot in fstab.
- Set device state locked in boot.img with magiskboot.
- .dat.br & payload.bin & .dat extraction support.
- Build images and create super.img (checks target's super byte before building)
- LCD & Density patching in my_product/
- OnePlus ROM Display fixes in my_manifest/
- Patch Gallery for AI features
- Force AOD always-on
- Patch OplusLauncher for RAM showage
- AI Editor Unlocking
- Device spoof to PLG110
- Circle To Search and AOD Panoramic patch
- Battery SOH unlocking

# How to use?
- Prepare your base ROM and port ROM. Make sure base ROM filename includes your device's codename (e.g if codename is joyeuse then baserom filename should include joyeuse or JOYEUSE.)

  
Install dependencies
```shell
chmod +x *
chmod +x bin/*
sudo ./bin/install_dependencies.sh
```

Start script
```shell
sudo ./port.sh <baseROM.zip> <portROM.zip>
```

# Credits & thanks to:
- [「BypassSignCheck」by Weverses](https://github.com/Weverses/BypassSignCheck)
- [「contextpatch」 by ColdWindScholar](https://github.com/ColdWindScholar/TIK)
- [「fspatch」by affggh](https://github.com/affggh/fspatch)
- [「lpunpack」by unix3dgforce](https://github.com/unix3dgforce/lpunpack)
- [「miui_port」by ljc-fight](https://github.com/ljc-fight/miui_port)

- Also many of people that I forgot. Sorry for that.

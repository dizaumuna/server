<div align="center">

# ColorOS / OxygenOS on joyeuse
<img width="279" height="600" alt="image" align="right" src="https://github.com/user-attachments/assets/6ca68203-85f1-4368-b81a-e74f1e77c51d" />

</div>

# Currently supported versions
- OxygenOS 15 (OnePlus 13)
## Planned upcoming versions:
- OxygenOS 14 (OnePlus 8T)
- OxygenOS 16 (OnePlus 11R)

# Features
- Decompile Settings.apk, patch, recompile and signing APK.
- Auto ROM extraction.
- OTA ZIP generate and upload to PixelDrain with your API Key.
- Disable Android Verified Boot in fstab.
- Set device state locked in boot.img with magiskboot. / currently unavailable
- .dat.br & payload.bin & .dat extraction support.
- Build images and create super.img (checks target's super byte before building)
- LCD & Density patching in my_product
- OnePlus ROM Display fixes in my_manifest
- Patch Gallery for AI features with patching Gallery.apk
- Force AOD always-on with patching AOD.apk
- Patch OplusLauncher for RAM showage with patching OplusLauncher.apk
- Device spoof to PLG110 on my_manifest
- Circle To Search and AOD Panoramic patch on SystemUI.apk
- Battery SOH unlocking on Battery.apk
- Auto build OrangeFox Recovery.

# System requirements
- 16 GB of RAM (8GB will work but build will be so slow, not recommended.)
- 150GB+ of Storage (NVMe SSD recommended, mostly it's needed for OrangeFox.)
- Intel Core i5 11th generation or newer.
- A lot of time, and also a brain.

# How to use?
- Prepare your base ROM and port ROM. Make sure base ROM filename includes your device's codename (e.g if codename is joyeuse then baserom or portrom filename should include joyeuse or JOYEUSE.)
  
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
- [magiskboot](https://github.com/svoboda18/magiskboot) by svoboda18
- [payload-dumper-go](https://github.com/ssut/payload-dumper-go) by ssut
- [Google] for lpunpack, lpmake.
- [toraidl](https://github.com/toraidl) for scripts, project idea. This project based on his/her OxygenOS-Port repository.
- [ozyern](https://github.com/ozyern) for patchmethod.py and apkeditor.jar
- [affggh](https://github.com/affggh/fspatch) for fspatch.py
- [ColdWindScholar](https://github.com/ColdWindScholar/TIK) for ContextPatch


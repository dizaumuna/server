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

LOG_STEP_IN() {
    echo "  - $1"
}

LOG_STEP_OUT() {
    echo "  - $1"
}

CREATE_WORKDIR () {
    if [ ! -d "workdir" ]; then
        mkdir workdir
    fi
}

#[ BASE INIT
LOG_STEP_IN "Extracting .dat.br files from downloaded firmware."

if [ ! -d "workdir/basevendor" ]; then
    mkdir -p workdir/basevendor
fi

mkdir -p workdir/basesystem

unzip firmwarebase.zip -d workdir/basevendor vendor.* > /dev/null
unzip firmwarebase.zip -d workdir/basesystem system.* > /dev/null

python tools/sdat2img_brotli.py -d workdir/basevendor/vendor.new.dat.br -t workdir/basevendor/vendor.transfer.list -o workdir/basevendor/vendor.img
python tools/sdat2img_brotli.py -d workdir/basesystem/system.new.dat.br -t workdir/basesystem/system.transfer.list -o workdir/basesystem/system.img

rm -rf workdir/basevendor/vendor.*.dat.br
rm -rf firmwarebase.zip

LOG_STEP_IN "Extracting joyeuse system and vendor..."
mkdir -p workdir/basevendor/vendor
mkdir -p workdir/basevendor/config
python3 tools/extractor.py workdir/basevendor/vendor.img workdir/basevendor/vendor
rm -rf workdir/basevendor/vendor.img

mkdir -p workdir/basesystem/system
mkdir -p workdir/basesystem/config
python3 tools/extractor.py workdir/basesystem/system.img workdir/basesystem/system
rm -rf workdir/basesystem/system.img

# BASE OUT]


#[ PORT INIT
LOG_STEP_IN "Extracting partitions from payload.bin..."

if [ ! -d "workdir/port" ]; then
    mkdir -p workdir/port
fi

unzip firmwareport.zip -d workdir/port/ payload.bin > /dev/null

payload-dumper-go -o workdir/port/ \
-p system,system_ext,product,vendor,my_manifest,my_heytap,my_company,my_engineering,my_bigball,my_carrier,my_stock,my_preload,my_region,my_product workdir/port/payload.bin > /dev/null

mv workdir/port/product.img .

./tools/extract.erofs -i workdir/port/system.img -o workdir/port/system -x 
./tools/extract.erofs -i workdir/port/system_ext.img -o workdir/port/system_ext -x
./tools/extract.erofs -i workdir/port/vendor.img -o workdir/port/vendor -x
rm -rf workdir/port/system.img
rm -rf workdir/port/system_ext.img
rm -rf workdir/port/vendor.img
./tools/extract.erofs -i workdir/port/my_manifest.img -o workdir/port/my_manifest -x
./tools/extract.erofs -i workdir/port/my_preload.img -o workdir/port/my_preload -x
./tools/extract.erofs -i workdir/port/my_region.img -o workdir/port/my_region -x
./tools/extract.erofs -i workdir/port/my_stock.img -o workdir/port/my_stock -x
./tools/extract.erofs -i workdir/port/my_product.img -o workdir/port/my_product -x
./tools/extract.erofs -i workdir/port/my_heytap.img -o workdir/port/my_heytap -x
./tools/extract.erofs -i workdir/port/my_bigball.img -o workdir/port/my_bigball -x
./tools/extract.erofs -i workdir/port/my_carrier.img -o workdir/port/my_carrier -x
./tools/extract.erofs -i workdir/port/my_engineering.img -o workdir/port/my_engineering -x
./tools/extract.erofs -i workdir/port/my_company.img -o workdir/port/my_company -x
rm -rf workdir/port/my_manifest.img
rm -rf workdir/port/my_preload.img
rm -rf workdir/port/my_region.img
rm -rf workdir/port/my_stock.img
rm -rf workdir/port/my_product.img
rm -rf workdir/port/my_heytap.img
rm -rf workdir/port/my_bigball.img
rm -rf workdir/port/my_carrier.img
rm -rf workdir/port/my_engineering.img
rm -rf workdir/port/my_company.img
LOG_STEP_OUT "Done extracting partitions from payload.bin."

rm -rf workdir/port/payload.bin
rm -rf workdir/port/system_ext.img
rm -rf workdir/port/system.img 
rm -rf workdir/port/vendor.img
rm -rf workdir/port/my_manifest.img
rm -rf workdir/port/my_preload.img
rm -rf workdir/port/my_region.img
rm -rf workdir/port/my_stock.img
rm -rf workdir/port/my_product.img
rm -rf workdir/port/my_heytap.img
rm -rf workdir/port/my_bigball.img
rm -rf workdir/port/my_carrier.img
rm -rf workdir/port/my_engineering.img
rm -rf workdir/port/my_company.img
rm -rf firmwareport.zip

# PORT OUT]

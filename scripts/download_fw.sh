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

LOG_STEP_IN "Downloaded base firmware:"
cat .currentbase
LOG_STEP_IN "Downloading latest base Xiaomi Redmi Note 9 Pro firmware based on MIUI"
curl -# -L -o firmwarebase.zip "https://bn.d.miui.com/V14.0.3.0.SJZMIXM/miui_JOYEUSEGlobal_V14.0.3.0.SJZMIXM_df17e3fabf_12.0.zip"
echo "Redmi Note 9 Pro firmware based on MIUI" >> .currentbase

CREATE_WORKDIR

LOG_STEP_IN "Downloaded port firmware:"
cat .currentport
LOG_STEP_IN "Downloading latest port OnePlus 12R firmware based on OxygenOS 15"
curl -# -L -o firmwareport.zip -O "https://gauss-componentotacostmanual-sg.allawnofs.com/remove-3a493f9e2bd2d23ead206e225ebd375d/component-ota/25/01/14/b1af1c4ffeba481a84b04848935a58d5.zip"
echo "OnePlus 12R firmware based on OxygenOS 15" >> .currentport

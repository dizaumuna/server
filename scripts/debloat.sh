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

# my_bigball/del-app-x
rm -rf workdir/port/system/system/my_bigball/del-app-pre/*
rm -rf workdir/port/system/system/my_bigball/del-app/*

# my_bigball/priv-app
rm -rf workdir/port/system/system/my_bigball/priv-app/Google_Files
rm -rf workdir/port/system/system/my_bigball/priv-app/GoogleDialer
rm -rf workdir/port/system/system/my_bigball/priv-app/Messages
rm -rf workdir/port/system/system/my_bigball/priv-app/GlobalSearch

# my_bigball/app
rm -rf workdir/port/system/system/my_bigball/app/Drive
rm -rf workdir/port/system/system/my_bigball/app/CalendarGoogle
rm -rf workdir/port/system/system/my_bigball/app/Google_Lens
rm -rf workdir/port/system/system/my_bigball/app/Google_Wallet
rm -rf workdir/port/system/system/my_bigball/app/GoogleContacts
rm -rf workdir/port/system/system/my_bigball/app/Meet
rm -rf workdir/port/system/system/my_bigball/app/YTMusic
rm -rf workdir/port/system/system/my_bigball/app/Photos
rm -rf workdir/port/system/system/my_bigball/app/Videos

# my_product/priv-app
rm -rf workdir/port/system/system/my_product/priv-app/OnePlusCamera

# my_stock/app
rm -rf workdir/port/system/system/my_stock/app/RomUpdate
rm -rf workdir/port/system/system/my_stock/app/ChildrenSpace
rm -rf workdir/port/system/system/my_stock/app/OppoWeather2
rm -rf workdir/port/system/system/my_stock/app/OplusOperationManual
rm -rf workdir/port/system/system/my_stock/app/Calculator2
rm -rf workdir/port/system/system/my_stock/app/Clock
rm -rf workdir/port/system/system/my_stock/app/FileManager
rm -rf workdir/port/system/system/my_stock/app/SceneMode
rm -rf workdir/port/system/system/my_stock/app/SmartSideBar

# my_stock/del-app
rm -rf workdir/port/system/system/my_stock/del-app/OppoRelax
rm -rf workdir/port/system/system/my_stock/del-app/OPForum

# my_stock/priv-app
rm -rf workdir/port/system/system/my_stock/priv-app/Games
rm -rf workdir/port/system/system/my_stock/priv-app/LinktoWindows



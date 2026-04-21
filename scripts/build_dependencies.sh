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
set -e

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

source /etc/os-release

echo "ID: $ID"

LOG_STEP_IN "Installing required dependencies"

if [[ "$ID" == "arch" ]]; then
    sudo pacman -S --needed \
    base-devel \
    cmake \
    git \
    openssl \
    curl \
    jsoncpp \
    boost \
    sqlite \
    zstd \
    lz4 \
    gtest \
    gmock \
    gflags \
    fmt \
    spdlog \
    libwebsockets \
    python \
    python-pip \
    python-virtualenv \
    aria2 \
    ninja \
    ccache \
    go \
    xz \
    unzip \
    jdk17-openjdk

elif [[ "$ID" == "ubuntu" ]]; then
    sudo apt-get update && sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    libcurl4-openssl-dev \
    libjsoncpp-dev \
    libboost-all-dev \
    libsqlite3-dev \
    libzstd-dev \
    liblz4-dev \
    libgtest-dev \
    libgmock-dev \
    libgflags-dev \
    libfmt-dev \
    libspdlog-dev \
    libcpprest-dev \
    libwebsockets-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    aria2 \
    ninja-build \
    ccache \
    golang \
    liblzma-dev \
    unzip \
    python-is-python3 \
    openjdk-17-jdk

else
    echo "Unsupported distrubition / package manager. Your distro is: $ID"
    echo "We are only supporting: Arch Linux / Debian"
    exit 1
fi
    
pip install brotli --break-system-packages
pip install sdat2img_brotli --break-system-packages


wget https://github.com/ssut/payload-dumper-go/releases/download/1.3.0/payload-dumper-go_1.3.0_linux_amd64.tar.gz -O pdg.tar.gz
tar -xvzf pdg.tar.gz
sudo mv payload-dumper-go /usr/local/bin

rm pdg.tar.gz
rm LICENSE
rm README.md

LOG_STEP_OUT "Done installing dependencies."

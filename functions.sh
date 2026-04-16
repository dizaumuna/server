#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# functions.sh — Helper library for port.sh
# Author: dizaumuna
#

trap 'echo "[functions.sh] Script interrupted." >&2; exit 1' SIGINT

if [[ "$OSTYPE" == "darwin"* ]]; then
    shopt -s expand_aliases
    alias sed=gsed
    alias grep=ggrep
    alias find=gfind
    alias du=gdu
    alias stat=gstat
    alias date=gdate
fi

log_info() { echo -e "\033[1;34m[$(date +%H:%M:%S)] $*\033[0m"; }
log_ok()   { echo -e "\033[1;32m[$(date +%H:%M:%S)] $*\033[0m"; }
log_warn() { echo -e "\033[1;33m[$(date +%H:%M:%S)] $*\033[0m"; }
log_err()  { echo -e "\033[1;31m[$(date +%H:%M:%S)] $*\033[0m"; }

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

detect_img_type() {
    local img="$1"
    local magic
    magic=$(xxd -l 4 "$img" 2>/dev/null | awk '{print $2$3}' | head -1 || true)
    case "$magic" in
        e2fd*)  echo "ext" ;;
        e2f9*)  echo "ext" ;;
        *)
            if strings "$img" 2>/dev/null | grep -q "EROFS"; then
                echo "erofs"
            else
                echo "ext"
            fi
            ;;
    esac
}

extract_partition() {
    local img="$1"
    local outdir="$2"
    local name
    name=$(basename "$img" .img)

    if [[ ! -f "$img" ]]; then
        log_warn "extract_partition: $img not found, skipping."
        return
    fi

    local fstype
    fstype=$(detect_img_type "$img")

    if [[ "$fstype" == "erofs" ]]; then
        log_info "[erofs] Extracting $name"
        mkdir -p "$outdir/$name"
        bin/extract.erofs -i "$img" -o "$outdir/$name" -x > /dev/null 2>&1 \
            || { log_err "extract.erofs failed on $img"; exit 1; }
    else
        log_info "[ext] Extracting $name"
        mkdir -p "$outdir/$name" "$outdir/config"
        python3 bin/extractor.py "$img" "$outdir/$name/" \
            || { log_err "extractor.py failed on $img"; exit 1; }
    fi

    rm -f "$img"
    log_ok "$name extracted"
}

disable_avb_verify() {
    local target="$1"
    local fstabs
    fstabs=$(find "$target" -name "fstab.*" 2>/dev/null || true)

    if [[ -z "$fstabs" ]]; then
        log_warn "disable_avb_verify: no fstab found under $target"
        return
    fi

    while IFS= read -r fstab; do
        sed -i 's/,avb_keys=[^ ]*//g' "$fstab"
        sed -i 's/,avb=vbmeta_system//g' "$fstab"
        sed -i 's/,avb=vbmeta_vendor//g' "$fstab"
        sed -i 's/,avb=vbmeta//g' "$fstab"
        sed -i 's/,avb,/,/g' "$fstab"
        sed -i 's/,avb$//g' "$fstab"
    done <<< "$fstabs"

    log_ok "Android Verified Boot disabled under $target"
}

#spoof_bootimg() {
#    local bootimg="$1"
#    local workdir
#    workdir=$(mktemp -d)
#
#    cp "$bootimg" "$workdir/boot.img"
#    pushd "$workdir" > /dev/null
#
#    set +e
#    bin/magiskboot unpack -h boot.img > /dev/null 2>&1
#    if [[ -f header ]]; then
#        sed -i '/^cmdline=/ s/$/ androidboot.vbmeta.device_state=unlocked/' header
#        bin/magiskboot repack boot.img new-boot.img > /dev/null 2>&1
#        cp new-boot.img "$bootimg"
#        log_ok "boot.img spoofed (unlocked state)"
#    else
#        log_warn "spoof_bootimg: no header found, skipping"
#    fi
#    set -e
#
#    popd > /dev/null
#    rm -rf "$workdir"
#}

check_tools() {
    local missing=()
    for tool in "$@"; do
        command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "Missing tools: ${missing[*]}"
        log_err "Run bin/install_dependencies.sh first."
        exit 1
    fi
}

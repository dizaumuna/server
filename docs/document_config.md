# config.sh Documentation

Each device has its own `config.sh` located at `target/<devicecodename>/config.sh`.
This file is sourced by `port.sh` at startup to configure device-specific behavior.

---

## Variables

### Identity

| Variable | Type | Description |
|---|---|---|
| `TARGET_DEVICE` | string | Device codename (e.g. `joyeuse`) |
| `TARGET_ARCH` | string | CPU architecture (`arm64`, `arm`) |
| `TARGET_SOC` | string | SoC model string (e.g. `SM7125`) |

---

### Filesystem

| Variable | Values | Description |
|---|---|---|
| `TARGET_FS` | `ext4` / `erofs` | Filesystem type used for repacking system/system_ext/product images. Determines whether `make_ext4fs` or `e2fsdroid` is used. |

---

### Hardware Features

| Variable | Values | Description |
|---|---|---|
| `TARGET_HAS_SIDEFP` | `true` / `false` | Device has a side-mounted fingerprint sensor. |
| `TARGET_HAVE_QUADCAM` | `true` / `false` | Device has a quad camera setup. |
| `TARGET_HAS_NFC` | `true` / `false` | Device has NFC hardware. |
| `TARGET_HAS_IR` | `true` / `false` | Device has an IR blaster. |
| `TARGET_HAS_WARP_CHARGE` | `true` / `false` | Device supports OnePlus Warp Charge. |
| `TARGET_HAS_VOOC_CHARGE` | `true` / `false` | Device supports OPPO VOOC fast charging. |

---

### Import Lines

| Variable | Values | Description |
|---|---|---|
| `TARGET_NEEDS_IMPORT` | `true` / `false` | Whether `import /my_xxx/build.prop` lines need to be injected into `vendor/build.prop` and `vendor/odm/etc/build.prop`. When `true`, all partitions listed in `TARGET_IMPORT_PARTITIONS` will have their import lines added. |
| `TARGET_IMPORT_PARTITIONS` | space-separated string | List of `my_*` partition names whose build.prop files need to be imported. Example: `"my_manifest my_product my_stock my_region"` |

---

### Partition Layout

| Variable | Values | Description |
|---|---|---|
| `TARGET_IS_AB` | `true` / `false` | Device uses A/B (seamless) partition scheme. |
| `TARGET_HAS_VIRTUAL_AB` | `true` / `false` | Device uses Virtual A/B (VAB) scheme on top of A/B. |

---

### Super Image

| Variable | Type | Description |
|---|---|---|
| `TARGET_SUPER_SIZE` | integer (bytes) | Total super partition size in bytes. |
| `TARGET_SUPER_GROUP` | string | Dynamic partition group name (e.g. `qti_dynamic_partitions`). |
| `TARGET_SUPER_METADATA_SIZE` | integer (bytes) | Metadata size for lpmake (usually `67108864`). |
| `TARGET_SUPER_METADATA_SLOTS` | integer | Number of metadata slots (`2` for A-only, `3` for A/B). |

---

### ROM Types

| Variable | Values | Description |
|---|---|---|
| `TARGET_BASEROM_TYPE` | `dat.br` / `payload` / `img` | Format of the base ROM archive. Determines extraction method. |
| `TARGET_PORTROM_TYPE` | `payload` / `img` | Format of the port ROM archive. |

---
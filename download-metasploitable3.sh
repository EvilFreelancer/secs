#!/usr/bin/env bash
#
# download-metasploitable3.sh - fetch the Metasploitable 3 target VM and
# convert it into a QEMU-ready qcow2 disk in ./dist.
#
# Metasploitable 3 is NOT shipped as a ready-made disk image. Rapid7 publishes
# it as Vagrant boxes on the HCP Vagrant registry. This script downloads the
# VirtualBox-provider box (a gzip tar that contains an .ovf plus a .vmdk disk),
# extracts the disk and converts it to qcow2 so it can be booted with QEMU.
#
# Companion: run-metasploitable3.sh boots the resulting disk.
#
# Variants:
#   ub1404  Ubuntu 14.04 Linux target   (default, ~1.8 GB download)
#   win2k8  Windows Server 2008 R2 target (large, ~5 GB download)
#
# Usage:
#   ./download-metasploitable3.sh [ub1404|win2k8]
#   FORCE=1 ./download-metasploitable3.sh ub1404      # re-download and re-convert
#   KEEP_BOX=0 ./download-metasploitable3.sh ub1404   # delete the .box after convert
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"

# ------------------------------------------------------------------ output ---
if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_0=; fi
ok()   { printf '%s[ ok ]%s %s\n'   "$C_G" "$C_0" "$*"; }
warn() { printf '%s[warn]%s %s\n'   "$C_Y" "$C_0" "$*"; }
err()  { printf '%s[fail]%s %s\n'   "$C_R" "$C_0" "$*" >&2; }
info() { printf '%s[info]%s %s\n'   "$C_B" "$C_0" "$*"; }

# ------------------------------------------------------------ variant table ---
# Provider is always virtualbox: that box packages a plain .vmdk that qemu-img
# reads directly. Versions are the latest published on the registry.
VARIANT="${1:-ub1404}"
case "$VARIANT" in
  ub1404) BOX="metasploitable3-ub1404"; VERSION="0.1.12-weekly" ;;
  win2k8) BOX="metasploitable3-win2k8"; VERSION="0.1.0-weekly" ;;
  -h|--help)
    grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'; exit 0 ;;
  *) err "unknown variant: '$VARIANT' (use ub1404 or win2k8)"; exit 2 ;;
esac

PROVIDER="virtualbox"
URL="https://vagrantcloud.com/rapid7/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}/unknown/vagrant.box"

BOX_FILE="$DIST_DIR/${BOX}-${VERSION}.box"
QCOW2_FILE="$DIST_DIR/${BOX}.qcow2"
WORK_DIR="$DIST_DIR/.work-${BOX}"

FORCE="${FORCE:-0}"
KEEP_BOX="${KEEP_BOX:-1}"

for bin in wget qemu-img tar; do
  command -v "$bin" >/dev/null 2>&1 || { err "required tool not found: $bin"; exit 1; }
done

mkdir -p "$DIST_DIR"

# ------------------------------------------------------------- already done ---
if [ -f "$QCOW2_FILE" ] && [ "$FORCE" != "1" ]; then
  ok "qcow2 already present: $QCOW2_FILE"
  info "size: $(du -h "$QCOW2_FILE" | cut -f1)"
  info "use FORCE=1 to rebuild it, or run ./run-metasploitable3.sh $VARIANT"
  exit 0
fi

# ---------------------------------------------------------------- download ---
info "variant : $VARIANT ($BOX $VERSION)"
info "source  : $URL"
info "target  : $QCOW2_FILE"

if [ -f "$BOX_FILE" ] && [ "$FORCE" != "1" ]; then
  ok "box already downloaded: $BOX_FILE ($(du -h "$BOX_FILE" | cut -f1))"
else
  [ "$FORCE" = "1" ] && rm -f "$BOX_FILE"
  info "downloading box (resumable) ..."
  # -c resumes a partial .part file; the registry redirects to a signed S3 URL
  # that supports range requests.
  wget --continue --tries=3 --timeout=60 --progress=dot:giga \
       -O "${BOX_FILE}.part" "$URL"
  mv "${BOX_FILE}.part" "$BOX_FILE"
  ok "downloaded: $BOX_FILE ($(du -h "$BOX_FILE" | cut -f1))"
fi

info "sha256: $(sha256sum "$BOX_FILE" | cut -d' ' -f1)"

# --------------------------------------------------------- sanity: is a box ---
if ! tar -tzf "$BOX_FILE" >/dev/null 2>&1; then
  err "downloaded file is not a valid gzip tar (corrupt or truncated)"
  err "re-run with FORCE=1 to download again"
  exit 1
fi

# ------------------------------------------------------ extract the vmdk ---
vmdk_in_box="$(tar -tzf "$BOX_FILE" | grep -iE '\.vmdk$' | head -n1 || true)"
if [ -z "$vmdk_in_box" ]; then
  err "no .vmdk found inside the box; contents:"
  tar -tzf "$BOX_FILE" | sed 's/^/    /' >&2
  exit 1
fi
info "disk inside box: $vmdk_in_box"

rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"
info "extracting disk ..."
tar -xzf "$BOX_FILE" -C "$WORK_DIR" -- "$vmdk_in_box"

# ----------------------------------------------------------- convert qcow2 ---
info "converting vmdk -> qcow2 (this can take a minute) ..."
qemu-img convert -p -f vmdk -O qcow2 "$WORK_DIR/$vmdk_in_box" "${QCOW2_FILE}.part"
mv "${QCOW2_FILE}.part" "$QCOW2_FILE"

rm -rf "$WORK_DIR"
[ "$KEEP_BOX" = "1" ] || { rm -f "$BOX_FILE"; info "removed box (KEEP_BOX=0)"; }

# ------------------------------------------------------------------ verify ---
ok "created: $QCOW2_FILE ($(du -h "$QCOW2_FILE" | cut -f1))"
qemu-img info "$QCOW2_FILE" | sed 's/^/    /'
echo
ok "done. boot it with:  ./run-metasploitable3.sh $VARIANT"
info "default credentials (Metasploitable 3): vagrant / vagrant"

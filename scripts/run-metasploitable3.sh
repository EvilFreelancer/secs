#!/usr/bin/env bash
#
# run-metasploitable3.sh - boot the Metasploitable 3 target VM under QEMU/KVM.
#
# Boots the qcow2 produced by download-metasploitable3.sh. Metasploitable 3 is a
# DELIBERATELY VULNERABLE machine, so the default networking is user-mode NAT:
# nothing on your LAN can reach it, and only the ports listed below are exposed,
# forwarded to 127.0.0.1 on the host. Attack it from this host.
#
# Usage:
#   ./scripts/run-metasploitable3.sh [ub1404|win2k8]
#
# Environment overrides:
#   RAM_MB=2048        guest memory in MiB
#   CPUS=2             vCPU count
#   NET_MODE=user      user | tap | none
#   RESTRICT=off       on = also block the guest from host/internet (only inbound
#                      port-forwards work; breaks reverse shells back to the host)
#   TAP=tap0           tap device to use when NET_MODE=tap (must exist, bridged
#                      to an ISOLATED bridge; needs privileges)
#   DISPLAY_MODE=vnc   vnc | none | sdl | gtk
#   VNC=127.0.0.1:0    VNC listen address (":0" = TCP 5900); keep it on 127.0.0.1
#   SNAPSHOT=0         1 = discard all disk writes on exit (disposable session)
#   DISK=/path.qcow2   override the disk path
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO_DIR/dist}"

# ------------------------------------------------------------------ output ---
if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_0=; fi
ok()   { printf '%s[ ok ]%s %s\n'   "$C_G" "$C_0" "$*"; }
warn() { printf '%s[warn]%s %s\n'   "$C_Y" "$C_0" "$*"; }
err()  { printf '%s[fail]%s %s\n'   "$C_R" "$C_0" "$*" >&2; }
info() { printf '%s[info]%s %s\n'   "$C_B" "$C_0" "$*"; }

VARIANT="${1:-ub1404}"
case "$VARIANT" in
  ub1404) BOX="metasploitable3-ub1404" ;;
  win2k8) BOX="metasploitable3-win2k8" ;;
  -h|--help) grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'; exit 0 ;;
  *) err "unknown variant: '$VARIANT' (use ub1404 or win2k8)"; exit 2 ;;
esac

DISK="${DISK:-$DIST_DIR/${BOX}.qcow2}"
if [ ! -f "$DISK" ]; then
  err "disk not found: $DISK"
  err "run first:  ./scripts/download-metasploitable3.sh $VARIANT"
  exit 1
fi
command -v qemu-system-x86_64 >/dev/null 2>&1 || { err "qemu-system-x86_64 not found"; exit 1; }

# ----------------------------------------------------------------- config ---
RAM_MB="${RAM_MB:-2048}"
CPUS="${CPUS:-2}"
NET_MODE="${NET_MODE:-user}"
RESTRICT="${RESTRICT:-off}"
DISPLAY_MODE="${DISPLAY_MODE:-vnc}"
VNC="${VNC:-127.0.0.1:0}"
SNAPSHOT="${SNAPSHOT:-0}"
TAP="${TAP:-tap0}"

# Per-variant host(127.0.0.1) -> guest port forwards for user-mode networking.
if [ "$VARIANT" = "ub1404" ]; then
  FWD=( 2222:22 2121:21 8000:80 13306:3306 8080:8080 8181:8181 8282:8282 \
        8383:8383 8484:8484 8585:8585 6697:6697 9200:9200 3000:3000 3500:3500 )
else
  FWD=( 2222:22 8022:8022 3389:3389 4445:445 11433:1433 8000:80 8080:8080 \
        8443:8443 8484:8484 8585:8585 9200:9200 4848:4848 8020:8020 7676:7676 )
fi

args=( -name "$BOX" -machine pc -m "$RAM_MB" -smp "$CPUS" -rtc base=utc -boot order=c )

# ----------------------------------------------------------- acceleration ---
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  args+=( -enable-kvm -cpu host )
  ACCEL="KVM (hardware)"
else
  args+=( -cpu qemu64 )
  ACCEL="TCG (software, slow)"
  warn "/dev/kvm not accessible - falling back to slow software emulation"
fi

# ------------------------------------------------------------------- disk ---
# IDE controller: maximum compatibility with these older guest kernels.
args+=( -drive file="$DISK",format=qcow2,if=ide,cache=writeback )
[ "$SNAPSHOT" = "1" ] && { args+=( -snapshot ); warn "SNAPSHOT mode: disk writes are discarded on exit"; }

# --------------------------------------------------------------- network ---
# A single busy host port makes QEMU abort the whole launch, so probe each
# forward and skip the ones already bound on the host.
port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH "sport = :$p" 2>/dev/null | grep -q .
  else
    (exec 3<>/dev/tcp/127.0.0.1/"$p") 2>/dev/null && { exec 3>&- 3<&- 2>/dev/null; return 0; } || return 1
  fi
}

APPLIED=()
case "$NET_MODE" in
  user)
    netopt="user,id=net0"
    [ "$RESTRICT" = "on" ] && netopt="${netopt},restrict=on"
    skipped=()
    for f in "${FWD[@]}"; do
      hp="${f%%:*}"; gp="${f##*:}"
      if port_in_use "$hp"; then skipped+=("${hp}->${gp}"); continue; fi
      netopt="${netopt},hostfwd=tcp:127.0.0.1:${hp}-:${gp}"
      APPLIED+=("${hp}:${gp}")
    done
    args+=( -netdev "$netopt" -device e1000,netdev=net0 )
    [ ${#skipped[@]} -gt 0 ] && warn "host port(s) busy, forward skipped: ${skipped[*]}"
    ;;
  tap)
    warn "tap mode: expecting existing device '$TAP' on an ISOLATED bridge (needs privileges)"
    args+=( -netdev "tap,id=net0,ifname=${TAP},script=no,downscript=no" -device e1000,netdev=net0 )
    ;;
  none)
    args+=( -nic none )
    warn "network disabled (NET_MODE=none)"
    ;;
  *) err "unknown NET_MODE: '$NET_MODE' (user|tap|none)"; exit 2 ;;
esac

# --------------------------------------------------------------- display ---
case "$DISPLAY_MODE" in
  vnc)  args+=( -vga std -vnc "$VNC" ) ;;
  none) args+=( -display none ) ;;
  sdl)  args+=( -vga std -display sdl ) ;;
  gtk)  args+=( -vga std -display gtk ) ;;
  *) err "unknown DISPLAY_MODE: '$DISPLAY_MODE' (vnc|none|sdl|gtk)"; exit 2 ;;
esac

# ------------------------------------------------------------------ start ---
info "disk        : $DISK"
info "accel       : $ACCEL"
info "resources   : ${RAM_MB} MiB RAM, ${CPUS} vCPU"
info "network     : $NET_MODE${RESTRICT:+ (restrict=$RESTRICT)}"
if [ "$NET_MODE" = "user" ]; then
  if [ ${#APPLIED[@]} -gt 0 ]; then
    info "port forwards (host 127.0.0.1 -> guest):"
    ssh_hp=""
    for a in "${APPLIED[@]}"; do
      printf '                127.0.0.1:%-6s -> %s\n' "${a%%:*}" "${a##*:}"
      [ "${a##*:}" = "22" ] && ssh_hp="${a%%:*}"
    done
    [ -n "$ssh_hp" ] && info "e.g. SSH:  ssh vagrant@127.0.0.1 -p $ssh_hp   (password: vagrant)"
  else
    warn "no host port forwards active (all busy) - guest still NAT-reachable inside QEMU"
  fi
fi
if [ "$DISPLAY_MODE" = "vnc" ]; then
  vnc_port=$(( 5900 + ${VNC##*:} ))
  info "console     : VNC on ${VNC%:*}:${vnc_port}  (e.g. vncviewer ${VNC%:*}:${vnc_port})"
fi
warn "authorized testing only - Metasploitable 3 is intentionally vulnerable"
echo
info "launching: qemu-system-x86_64 ${args[*]}"
echo

exec qemu-system-x86_64 "${args[@]}"

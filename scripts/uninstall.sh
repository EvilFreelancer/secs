#!/usr/bin/env bash
#
# uninstall.sh - remove the information security tooling installed by install.sh.
#
# Mirrors install.sh. apt packages are removed (use --purge to also drop config).
# Shared dependencies are left in place; run 'sudo apt-get autoremove' yourself
# if you want to reclaim them. Heavy services (Metasploit/Sliver/Greenbone/Wazuh)
# are only touched when you pass their --with-* flag.
#
# Each item shows [done/total] progress and one of: removed / absent / failed.
#
set -uo pipefail

LOG="${LOG:-/tmp/sectools-uninstall.log}"
: > "$LOG"

if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_D=$'\033[2m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_D= C_0=; fi
ok()   { printf '%s[ ok ]%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_Y" "$C_0" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$C_R" "$C_0" "$*" >&2; }
info() { printf '%s[info]%s %s\n' "$C_B" "$C_0" "$*"; }

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
is_kali() { grep -qiE 'kali' /etc/os-release 2>/dev/null; }

# Keep these lists in sync with install.sh
APT_OFFENSE=(
  nmap masscan arp-scan netdiscover dnsutils dnsrecon whatweb
  amass recon-ng
  nikto sqlmap wpscan ffuf gobuster feroxbuster dirb commix zaproxy
  exploitdb
  john hashcat hydra medusa ncrack crunch cewl hashid wordlists seclists
  bettercap ettercap-graphical responder
  aircrack-ng wifite kismet hcxdumptool hcxtools reaver bully
  radare2 gdb strace ltrace
  impacket-scripts smbclient smbmap enum4linux nbtscan
  burpsuite maltego cutter ghidra beef-xss
)
APT_DEFENSE=(
  wireshark tshark tcpdump
  suricata snort
  fail2ban lynis rkhunter chkrootkit aide aide-common
  clamav clamav-daemon clamav-freshclam
  openscap-scanner openscap-utils
  sleuthkit autopsy binwalk foremost scalpel bulk-extractor yara
)
PIPX_OFFENSE=( theHarvester wapiti3 shodan netexec )
PIPX_DEFENSE=( volatility3 )
GO_BINS=( nuclei naabu )

APT_RM="remove"   # switched to 'purge' with --purge

# ----------------------------------------------------------------- progress ---
TOTAL=0; TOTAL_W=1; STEP=0; PFX=""
N_REMOVED=0; N_ABSENT=0; N_FAIL=0
bump()      { STEP=$((STEP+1)); PFX="$(printf '[%*d/%d]' "$TOTAL_W" "$STEP" "$TOTAL")"; }
p_removed() { printf '%s[ ok ]%s %s %sremoved%s %s\n' "$C_G" "$C_0" "$PFX" "$C_G" "$C_0" "$1"; N_REMOVED=$((N_REMOVED+1)); }
p_absent()  { printf '%s[ -- ]%s %s %sabsent%s  %s\n' "$C_D" "$C_0" "$PFX" "$C_D" "$C_0" "$1"; N_ABSENT=$((N_ABSENT+1)); }
p_failr()   { printf '%s[warn]%s %s %sfailed%s  %s\n' "$C_Y" "$C_0" "$PFX" "$C_Y" "$C_0" "$1"; N_FAIL=$((N_FAIL+1)); }
p_dry()     { printf '%s[dry ]%s %s would remove %s\n' "$C_B" "$C_0" "$PFX" "$1"; }

compute_total() {
  TOTAL=0
  if [ "$MODE_OFF" -eq 1 ]; then
    TOTAL=$(( TOTAL + ${#APT_OFFENSE[@]} + ${#PIPX_OFFENSE[@]} + ${#GO_BINS[@]} ))
    [ "$RM_MSF" -eq 1 ]    && TOTAL=$((TOTAL+1))
    [ "$RM_SLIVER" -eq 1 ] && TOTAL=$((TOTAL+1))
  fi
  if [ "$MODE_DEF" -eq 1 ]; then
    TOTAL=$(( TOTAL + ${#APT_DEFENSE[@]} + ${#PIPX_DEFENSE[@]} ))
    [ "$RM_GVM" -eq 1 ]   && TOTAL=$((TOTAL+1))
    [ "$RM_WAZUH" -eq 1 ] && TOTAL=$((TOTAL+1))
  fi
  [ "$RM_BH" -eq 1 ] && TOTAL=$((TOTAL+1))
  TOTAL_W=${#TOTAL}
}

# ------------------------------------------------------------------ removers ---
apt_remove() {
  local p
  for p in "$@"; do
    bump
    if [ -n "$DRY" ]; then p_dry "apt:$p"; continue; fi
    if ! dpkg -s "$p" >/dev/null 2>&1; then p_absent "apt:$p"; continue; fi
    if $SUDO apt-get "$APT_RM" -y "$p" >>"$LOG" 2>&1; then p_removed "apt:$p"; else p_failr "apt:$p"; fi
  done
}
pipx_remove() {
  local p present have_pipx=1
  command -v pipx >/dev/null 2>&1 || have_pipx=0
  for p in "$@"; do
    bump
    if [ -n "$DRY" ]; then p_dry "pipx:$p"; continue; fi
    if [ $have_pipx -eq 0 ]; then p_absent "pipx:$p"; continue; fi
    present="$(pipx list --short 2>/dev/null | awk '{print $1}' | grep -ix "$p" || true)"
    if [ -z "$present" ]; then p_absent "pipx:$p"; continue; fi
    if pipx uninstall "$p" >>"$LOG" 2>&1; then p_removed "pipx:$p"; else p_failr "pipx:$p"; fi
  done
}
go_remove() {
  local b gobin found; gobin="$(command -v go >/dev/null 2>&1 && go env GOPATH 2>/dev/null)/bin"
  for b in "$@"; do
    bump
    if [ -n "$DRY" ]; then p_dry "go:$b"; continue; fi
    found=0
    [ -e "/usr/local/bin/$b" ] && { $SUDO rm -f "/usr/local/bin/$b" >>"$LOG" 2>&1; found=1; }
    [ -n "$gobin" ] && [ -e "$gobin/$b" ] && { rm -f "$gobin/$b" >>"$LOG" 2>&1; found=1; }
    if [ $found -eq 1 ]; then p_removed "go:$b"; else p_absent "go:$b"; fi
  done
}

remove_metasploit() {
  bump
  if [ -n "$DRY" ]; then p_dry "metasploit"; return; fi
  if ! command -v msfconsole >/dev/null 2>&1 && ! dpkg -s metasploit-framework >/dev/null 2>&1; then p_absent "metasploit"; return; fi
  $SUDO apt-get "$APT_RM" -y metasploit-framework >>"$LOG" 2>&1 && p_removed "metasploit" || p_failr "metasploit"
  [ -f /etc/apt/sources.list.d/metasploit-framework.list ] && $SUDO rm -f /etc/apt/sources.list.d/metasploit-framework.list >>"$LOG" 2>&1 || true
}
remove_sliver() {
  bump
  if [ -n "$DRY" ]; then p_dry "sliver"; return; fi
  if [ ! -e /usr/local/bin/sliver-server ] && ! systemctl list-unit-files 2>/dev/null | grep -q '^sliver'; then p_absent "sliver"; return; fi
  $SUDO systemctl disable --now sliver >>"$LOG" 2>&1 || true
  $SUDO rm -f /usr/local/bin/sliver-server /usr/local/bin/sliver-client /etc/systemd/system/sliver.service >>"$LOG" 2>&1 || true
  $SUDO systemctl daemon-reload >>"$LOG" 2>&1 || true
  p_removed "sliver (state in ~/.sliver kept)"
}
remove_greenbone() {
  bump
  if [ -n "$DRY" ]; then p_dry "greenbone/gvm"; return; fi
  if ! dpkg -s gvm >/dev/null 2>&1 && ! command -v gvm-setup >/dev/null 2>&1; then p_absent "greenbone/gvm"; return; fi
  $SUDO apt-get "$APT_RM" -y gvm gvmd gsad openvas-scanner >>"$LOG" 2>&1 \
    && p_removed "greenbone/gvm (data under /var/lib/gvm kept)" || p_failr "greenbone/gvm"
}
remove_wazuh() {
  bump
  if [ -n "$DRY" ]; then p_dry "wazuh"; return; fi
  if ! dpkg -s wazuh-manager >/dev/null 2>&1 && ! (systemctl list-unit-files 2>/dev/null | grep -q '^wazuh-manager'); then p_absent "wazuh"; return; fi
  $SUDO apt-get "$APT_RM" -y wazuh-manager wazuh-indexer wazuh-dashboard >>"$LOG" 2>&1 \
    && p_removed "wazuh (or use wazuh-install.sh --uninstall)" || p_failr "wazuh"
}
remove_bloodhound() {
  bump
  if [ -n "$DRY" ]; then p_dry "bloodhound-ce"; return; fi
  if [ -f bloodhound-ce/docker-compose.yml ] && command -v docker >/dev/null 2>&1; then
    ( cd bloodhound-ce && docker compose down -v ) >>"$LOG" 2>&1 && p_removed "bloodhound-ce (containers+volumes)" || p_failr "bloodhound-ce"
  else p_absent "bloodhound-ce"; fi
}

usage() {
  cat <<'EOF'
uninstall.sh - remove tooling installed by install.sh

USAGE:
  ./scripts/uninstall.sh [MODE] [OPTIONS]

MODE:
  --all              remove offensive + defensive tools
  --offensive        remove offensive tools
  --defensive        remove defensive tools

OPTIONS:
  --purge            apt purge (also remove package config), not just remove
  --with-metasploit  also remove Metasploit
  --with-sliver      also stop and remove Sliver C2
  --with-greenbone   also remove Greenbone/OpenVAS
  --with-wazuh       also remove the Wazuh stack
  --with-bloodhound  also 'docker compose down -v' ./bloodhound-ce
  --autoremove       run 'apt-get autoremove' at the end
  --dry-run          show what would be removed (with progress), change nothing
  -y, --yes          do not ask for confirmation
  -h, --help         this help

Each item prints [done/total] progress and one of: removed / absent / failed.

Log file: /tmp/sectools-uninstall.log
EOF
}

MODE_OFF=0; MODE_DEF=0; RM_MSF=0; RM_SLIVER=0; RM_GVM=0; RM_WAZUH=0; RM_BH=0
AUTORM=0; ASSUME_YES=0; DRY=""
[ $# -eq 0 ] && { usage; exit 0; }
while [ $# -gt 0 ]; do
  case "$1" in
    --all)             MODE_OFF=1; MODE_DEF=1 ;;
    --offensive|--offense) MODE_OFF=1 ;;
    --defensive|--defense) MODE_DEF=1 ;;
    --purge)           APT_RM="purge" ;;
    --with-metasploit) RM_MSF=1 ;;
    --with-sliver)     RM_SLIVER=1 ;;
    --with-greenbone)  RM_GVM=1 ;;
    --with-wazuh)      RM_WAZUH=1 ;;
    --with-bloodhound) RM_BH=1 ;;
    --autoremove)      AUTORM=1 ;;
    --dry-run)         DRY="1" ;;
    -y|--yes)          ASSUME_YES=1 ;;
    -h|--help)         usage; exit 0 ;;
    *) err "unknown option: $1"; echo; usage; exit 2 ;;
  esac
  shift
done
[ $MODE_OFF -eq 0 ] && [ $MODE_DEF -eq 0 ] && { err "choose --all, --offensive, or --defensive"; usage; exit 2; }

compute_total

info "OS: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")  $(is_kali && echo '(Kali)')"
info "Plan: $TOTAL item(s) to process"
[ -n "$DRY" ] && info "DRY RUN - nothing will be removed"
if [ $ASSUME_YES -eq 0 ] && [ -z "$DRY" ]; then
  warn "This will REMOVE up to $TOTAL security tool(s) from your system."
  printf 'Continue? [y/N] '; read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "aborted"; exit 1 ;; esac
fi

if [ $MODE_OFF -eq 1 ]; then
  info "=== removing OFFENSIVE tools ==="
  apt_remove "${APT_OFFENSE[@]}"
  pipx_remove "${PIPX_OFFENSE[@]}"
  go_remove "${GO_BINS[@]}"
  [ $RM_MSF -eq 1 ] && remove_metasploit
  [ $RM_SLIVER -eq 1 ] && remove_sliver
fi
if [ $MODE_DEF -eq 1 ]; then
  info "=== removing DEFENSIVE tools ==="
  apt_remove "${APT_DEFENSE[@]}"
  pipx_remove "${PIPX_DEFENSE[@]}"
  [ $RM_GVM -eq 1 ] && remove_greenbone
  [ $RM_WAZUH -eq 1 ] && remove_wazuh
fi
[ $RM_BH -eq 1 ] && remove_bloodhound

if [ $AUTORM -eq 1 ] && [ -z "$DRY" ]; then info "apt-get autoremove"; $SUDO apt-get autoremove -y >>"$LOG" 2>&1 && ok "autoremoved orphaned dependencies"; fi

echo
info "==================== SUMMARY ===================="
if [ -n "$DRY" ]; then
  info "would process $TOTAL item(s) (dry run)"
else
  ok   "removed: $N_REMOVED"
  info "already absent: $N_ABSENT"
  [ $N_FAIL -gt 0 ] && warn "failed: $N_FAIL"
  info "progress: $STEP/$TOTAL processed  (removed $N_REMOVED + absent $N_ABSENT + failed $N_FAIL)"
fi
info "full log: $LOG"
[ -n "$DRY" ] && info "this was a DRY RUN; re-run without --dry-run to apply."

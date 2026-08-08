#!/usr/bin/env bash
#
# install.sh - install information security tooling on Debian / Ubuntu / Kali.
#
# Companion to ../docs/security-tools.md. Use scripts/uninstall.sh to remove.
#
# Design notes:
#   * Run as a normal user; the script calls sudo only for system packages.
#   * apt packages are installed one by one so a package missing from your
#     distro's repos (many are Kali-only) does not abort the whole run.
#   * pipx / go tools are installed for the current user.
#   * Every tool is counted: each line shows [done/total] progress and whether
#     the tool was already present, newly installed, or skipped.
#   * Heavy services (Metasploit, Sliver, Greenbone, Wazuh, BloodHound) are
#     opt-in behind explicit flags.
#
set -uo pipefail   # intentionally NOT -e: continue past individual failures

LOG="${LOG:-/tmp/sectools-install.log}"
: > "$LOG"

# ------------------------------------------------------------------ output ---
if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_D=$'\033[2m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_D= C_0=; fi
ok()   { printf '%s[ ok ]%s %s\n'   "$C_G" "$C_0" "$*"; }
warn() { printf '%s[warn]%s %s\n'   "$C_Y" "$C_0" "$*"; }
err()  { printf '%s[fail]%s %s\n'   "$C_R" "$C_0" "$*" >&2; }
info() { printf '%s[info]%s %s\n'   "$C_B" "$C_0" "$*"; }

# --------------------------------------------------------------- privileges ---
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

is_kali() { grep -qiE 'kali' /etc/os-release 2>/dev/null; }
os_pretty() { . /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}"; }

# --------------------------------------------------------------- tool lists ---
# apt packages available on Kali; many also on Debian/Ubuntu. Missing ones are
# skipped rather than aborting.
APT_OFFENSE=(
  # recon & scanning
  nmap masscan arp-scan netdiscover dnsutils dnsrecon whatweb
  # osint
  amass recon-ng
  # web application testing
  nikto sqlmap wpscan ffuf gobuster feroxbuster dirb commix zaproxy
  # exploitation & exploit archive
  exploitdb
  # password & hash cracking
  john hashcat hydra medusa ncrack crunch cewl hashid wordlists seclists
  # traffic interception / mitm
  bettercap ettercap-graphical responder
  # wireless
  aircrack-ng wifite kismet hcxdumptool hcxtools reaver bully
  # reverse engineering
  radare2 gdb strace ltrace
  # active directory / post-exploitation
  impacket-scripts smbclient smbmap enum4linux nbtscan
  # GUI / Kali-only (tolerated if absent)
  burpsuite maltego cutter ghidra beef-xss
)
APT_DEFENSE=(
  # traffic analysis
  wireshark tshark tcpdump
  # ids/ips
  suricata snort
  # host protection & auditing
  fail2ban lynis rkhunter chkrootkit aide aide-common
  clamav clamav-daemon clamav-freshclam
  openscap-scanner openscap-utils
  # forensics
  sleuthkit autopsy binwalk foremost scalpel bulk-extractor yara
)
PIPX_OFFENSE=( theHarvester wapiti3 shodan )
PIPX_DEFENSE=( volatility3 )
GO_OFFENSE=(
  github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
)

# ----------------------------------------------------------------- progress ---
TOTAL=0; TOTAL_W=1; STEP=0; PFX=""
N_PRESENT=0; N_NEW=0; N_FAIL=0
FAILED_ALL=()

bump() { STEP=$((STEP+1)); PFX="$(printf '[%*d/%d]' "$TOTAL_W" "$STEP" "$TOTAL")"; }
p_present() { printf '%s[ ok ]%s %s %spresent%s    %s\n'   "$C_G" "$C_0" "$PFX" "$C_D" "$C_0" "$1"; N_PRESENT=$((N_PRESENT+1)); }
p_new()     { printf '%s[ ok ]%s %s %sinstalled%s  %s\n'   "$C_G" "$C_0" "$PFX" "$C_G" "$C_0" "$1"; N_NEW=$((N_NEW+1)); }
p_fail()    { printf '%s[skip]%s %s %sskipped%s    %s\n'   "$C_Y" "$C_0" "$PFX" "$C_Y" "$C_0" "$1"; N_FAIL=$((N_FAIL+1)); FAILED_ALL+=("$1"); }
p_dry()     { printf '%s[dry ]%s %s would install %s\n'    "$C_B" "$C_0" "$PFX" "$1"; }

# how many items a run will process, so [done/total] is known up front
compute_total() {
  TOTAL=0
  if [ "$MODE_OFF" -eq 1 ]; then
    TOTAL=$(( TOTAL + ${#APT_OFFENSE[@]} + ${#PIPX_OFFENSE[@]} + ${#GO_OFFENSE[@]} + 1 ))   # +1 = netexec
    [ "$WANT_MSF" -eq 1 ]    && TOTAL=$((TOTAL+1))
    [ "$WANT_SLIVER" -eq 1 ] && TOTAL=$((TOTAL+1))
  fi
  if [ "$MODE_DEF" -eq 1 ]; then
    TOTAL=$(( TOTAL + ${#APT_DEFENSE[@]} + ${#PIPX_DEFENSE[@]} ))
    [ "$WANT_GVM" -eq 1 ]   && TOTAL=$((TOTAL+1))
    [ "$WANT_WAZUH" -eq 1 ] && TOTAL=$((TOTAL+1))
  fi
  [ "$WANT_BH" -eq 1 ] && TOTAL=$((TOTAL+1))
  TOTAL_W=${#TOTAL}
}

# ---------------------------------------------------------------- installers ---
apt_update_done=0
apt_update() {
  [ "$apt_update_done" = 1 ] && return; apt_update_done=1
  [ -n "$DRY" ] && return
  info "apt-get update"; $SUDO apt-get update -y >>"$LOG" 2>&1
}
# install a build/runtime dependency WITHOUT counting it as a tool
apt_ensure() { apt_update; [ -n "$DRY" ] && return 0; $SUDO apt-get install -y --no-install-recommends "$@" >>"$LOG" 2>&1; }

apt_install() {
  apt_update
  local p
  for p in "$@"; do
    bump
    if [ -n "$DRY" ]; then p_dry "apt:$p"; continue; fi
    if dpkg -s "$p" >/dev/null 2>&1; then p_present "apt:$p"; continue; fi
    if $SUDO apt-get install -y --no-install-recommends "$p" >>"$LOG" 2>&1; then p_new "apt:$p"
    else p_fail "apt:$p (not in this distro's repos)"; fi
  done
}

ensure_pipx() {
  command -v pipx >/dev/null 2>&1 && return
  info "installing pipx (dependency)"; apt_ensure pipx || true
  [ -n "$DRY" ] || pipx ensurepath >>"$LOG" 2>&1 || true
}
pipx_install() {
  ensure_pipx
  local p present
  for p in "$@"; do
    bump
    if [ -n "$DRY" ]; then p_dry "pipx:$p"; continue; fi
    present="$(pipx list --short 2>/dev/null | awk '{print $1}' | grep -ix "$p" || true)"
    if [ -n "$present" ]; then p_present "pipx:$p"; continue; fi
    if pipx install "$p" >>"$LOG" 2>&1; then p_new "pipx:$p"; else p_fail "pipx:$p"; fi
  done
}

ensure_go() {
  command -v go >/dev/null 2>&1 && return 0
  info "installing golang-go (dependency)"; apt_ensure golang-go || true
  command -v go >/dev/null 2>&1
}
go_install() {
  local m bin gobin
  if ! ensure_go; then
    for m in "$@"; do bump; if [ -n "$DRY" ]; then p_dry "go:$(basename "${m%@*}")"; else p_fail "go:$(basename "${m%@*}") (no Go toolchain)"; fi; done
    return
  fi
  gobin="$(go env GOPATH 2>/dev/null)/bin"
  for m in "$@"; do
    bump; bin="$(basename "${m%@*}")"
    if [ -n "$DRY" ]; then p_dry "go:$bin"; continue; fi
    if command -v "$bin" >/dev/null 2>&1; then p_present "go:$bin"; continue; fi
    if go install "$m" >>"$LOG" 2>&1; then $SUDO cp -f "$gobin/$bin" /usr/local/bin/ >>"$LOG" 2>&1 || true; p_new "go:$bin"; else p_fail "go:$bin"; fi
  done
}

install_netexec() {
  bump
  if [ -n "$DRY" ]; then p_dry "netexec"; return; fi
  if command -v netexec >/dev/null 2>&1 || command -v nxc >/dev/null 2>&1; then p_present "netexec"; return; fi
  if is_kali && $SUDO apt-get install -y netexec >>"$LOG" 2>&1; then p_new "netexec"; return; fi
  ensure_pipx
  if pipx install git+https://github.com/Pennyw0rth/NetExec >>"$LOG" 2>&1; then p_new "netexec"; else p_fail "netexec"; fi
}

install_metasploit() {
  bump
  if [ -n "$DRY" ]; then p_dry "metasploit"; return; fi
  if command -v msfconsole >/dev/null 2>&1; then p_present "metasploit"; return; fi
  if is_kali; then $SUDO apt-get install -y metasploit-framework >>"$LOG" 2>&1 && p_new "metasploit" || p_fail "metasploit"; return; fi
  info "installing Metasploit via official nightly installer"
  local tmp; tmp="$(mktemp)"
  if curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o "$tmp" >>"$LOG" 2>&1; then
    chmod 755 "$tmp"; $SUDO "$tmp" >>"$LOG" 2>&1 && p_new "metasploit" || p_fail "metasploit"
  else p_fail "metasploit (download failed)"; fi
  rm -f "$tmp"
}

install_sliver() {
  bump
  if [ -n "$DRY" ]; then p_dry "sliver"; return; fi
  if command -v sliver-server >/dev/null 2>&1; then p_present "sliver"; return; fi
  info "installing Sliver C2 (adds a systemd service)"
  curl -fsSL https://sliver.sh/install | $SUDO bash >>"$LOG" 2>&1 && p_new "sliver" || p_fail "sliver"
}

install_greenbone() {
  bump
  if [ -n "$DRY" ]; then p_dry "greenbone/gvm"; return; fi
  if command -v gvm-setup >/dev/null 2>&1 && command -v gsad >/dev/null 2>&1; then p_present "greenbone/gvm"; return; fi
  info "installing Greenbone / OpenVAS (gvm) - large and slow"
  $SUDO apt-get install -y gvm >>"$LOG" 2>&1 || { p_fail "greenbone/gvm"; return; }
  info "running gvm-setup (downloads feeds; note the admin password it prints)"
  $SUDO gvm-setup >>"$LOG" 2>&1 && p_new "greenbone/gvm (UI: https://127.0.0.1:9392)" || p_fail "greenbone/gvm (gvm-setup failed)"
}

install_wazuh() {
  bump
  if [ -n "$DRY" ]; then p_dry "wazuh"; return; fi
  if systemctl list-unit-files 2>/dev/null | grep -q '^wazuh-manager'; then p_present "wazuh"; return; fi
  warn "Wazuh all-in-one installs indexer + server + dashboard and needs >=4 GB RAM"
  local tmp; tmp="$(mktemp -d)"
  ( cd "$tmp" && curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && $SUDO bash ./wazuh-install.sh -a ) >>"$LOG" 2>&1 \
    && p_new "wazuh (credentials in $LOG)" || p_fail "wazuh"
  rm -rf "$tmp"
}

install_bloodhound() {
  bump
  if [ -n "$DRY" ]; then p_dry "bloodhound-ce"; return; fi
  if ! command -v docker >/dev/null 2>&1; then p_fail "bloodhound-ce (Docker not installed)"; return; fi
  mkdir -p bloodhound-ce && curl -fsSL https://ghst.ly/getbhce -o bloodhound-ce/docker-compose.yml >>"$LOG" 2>&1 \
    && p_new "bloodhound-ce (run: cd bloodhound-ce && docker compose up)" || p_fail "bloodhound-ce"
}

# --------------------------------------------------------------------- usage ---
usage() {
  cat <<'EOF'
install.sh - install information security tooling (Debian/Ubuntu/Kali)

USAGE:
  ./scripts/install.sh [MODE] [OPTIONS]

MODE (choose at least one; --all is the common case):
  --all              offensive + defensive tools (recommended)
  --offensive        recon, scanning, web, exploitation, passwords, wireless, AD
  --defensive        traffic analysis, IDS/IPS, auditing, forensics, anti-rootkit

OPTIONS:
  --no-metasploit    do not install Metasploit (offensive installs it by default)
  --with-sliver      install Sliver C2 (adds a systemd service)
  --with-greenbone   install Greenbone/OpenVAS vulnerability scanner (large)
  --with-wazuh       install Wazuh all-in-one SIEM/XDR (heavy, >=4 GB RAM)
  --with-bloodhound  fetch BloodHound CE docker-compose (needs Docker)
  --list             print what each mode installs and exit
  --dry-run          show actions (with progress) without changing anything
  -y, --yes          do not ask for confirmation
  -h, --help         this help

Each tool prints [done/total] progress and one of: present / installed / skipped.

EXAMPLES:
  ./scripts/install.sh --all
  ./scripts/install.sh --offensive --no-metasploit
  ./scripts/install.sh --defensive --with-wazuh -y
  ./scripts/install.sh --all --dry-run

Log file: /tmp/sectools-install.log  (override with LOG=/path ...)
EOF
}

print_list() {
  echo "OFFENSIVE apt: ${APT_OFFENSE[*]}"; echo
  echo "OFFENSIVE pipx: ${PIPX_OFFENSE[*]} netexec"; echo
  echo "OFFENSIVE go: ${GO_OFFENSE[*]}"; echo
  echo "OFFENSIVE special: metasploit (default), sliver (--with-sliver)"; echo
  echo "DEFENSIVE apt: ${APT_DEFENSE[*]}"; echo
  echo "DEFENSIVE pipx: ${PIPX_DEFENSE[*]}"; echo
  echo "DEFENSIVE special: greenbone (--with-greenbone), wazuh (--with-wazuh)"
}

# ----------------------------------------------------------------- arg parse ---
MODE_OFF=0; MODE_DEF=0; WANT_MSF=1; WANT_SLIVER=0; WANT_GVM=0; WANT_WAZUH=0; WANT_BH=0
ASSUME_YES=0; DRY=""
[ $# -eq 0 ] && { usage; exit 0; }
while [ $# -gt 0 ]; do
  case "$1" in
    --all)            MODE_OFF=1; MODE_DEF=1 ;;
    --offensive|--offense) MODE_OFF=1 ;;
    --defensive|--defense) MODE_DEF=1 ;;
    --no-metasploit)  WANT_MSF=0 ;;
    --with-sliver)    WANT_SLIVER=1 ;;
    --with-greenbone) WANT_GVM=1 ;;
    --with-wazuh)     WANT_WAZUH=1 ;;
    --with-bloodhound) WANT_BH=1 ;;
    --list)           print_list; exit 0 ;;
    --dry-run)        DRY="1" ;;
    -y|--yes)         ASSUME_YES=1 ;;
    -h|--help)        usage; exit 0 ;;
    *) err "unknown option: $1"; echo; usage; exit 2 ;;
  esac
  shift
done

[ $MODE_OFF -eq 0 ] && [ $MODE_DEF -eq 0 ] && { err "choose --all, --offensive, or --defensive"; usage; exit 2; }

compute_total

# ---------------------------------------------------------------------- run ---
info "OS: $(os_pretty)   $(is_kali && echo '(Kali detected)')"
info "Plan: $TOTAL tool(s) to process$([ $MODE_OFF -eq 1 ] && printf ' [offensive]')$([ $MODE_DEF -eq 1 ] && printf ' [defensive]')"
[ -n "$DRY" ] && info "DRY RUN - no changes will be made"

if [ $ASSUME_YES -eq 0 ] && [ -z "$DRY" ]; then
  printf 'Proceed with installation of %d tool(s)? [y/N] ' "$TOTAL"; read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "aborted"; exit 1 ;; esac
fi

if [ $MODE_OFF -eq 1 ]; then
  info "=== OFFENSIVE tools ==="
  apt_install "${APT_OFFENSE[@]}"
  pipx_install "${PIPX_OFFENSE[@]}"
  go_install "${GO_OFFENSE[@]}"
  install_netexec
  [ $WANT_MSF -eq 1 ] && install_metasploit
  [ $WANT_SLIVER -eq 1 ] && install_sliver
fi

if [ $MODE_DEF -eq 1 ]; then
  info "=== DEFENSIVE tools ==="
  apt_install "${APT_DEFENSE[@]}"
  pipx_install "${PIPX_DEFENSE[@]}"
  [ $WANT_GVM -eq 1 ] && install_greenbone
  [ $WANT_WAZUH -eq 1 ] && install_wazuh
fi

[ $WANT_BH -eq 1 ] && install_bloodhound

# ------------------------------------------------------------------ summary ---
echo
info "==================== SUMMARY ===================="
if [ -n "$DRY" ]; then
  info "would process $TOTAL tool(s) (dry run)"
else
  ok   "already present: $N_PRESENT"
  ok   "newly installed: $N_NEW"
  [ $N_FAIL -gt 0 ] && warn "skipped/failed: $N_FAIL"
  info "progress: $STEP/$TOTAL processed  (present $N_PRESENT + new $N_NEW + skipped $N_FAIL)"
  if [ ${#FAILED_ALL[@]} -gt 0 ]; then
    warn "not installed: ${FAILED_ALL[*]}"
    warn "items 'not in repos' are usually Kali-only; install on Kali or via pipx/go."
  fi
fi
info "full log: $LOG"
[ -n "$DRY" ] && info "this was a DRY RUN; re-run without --dry-run to apply."
echo
info "Reminder: use these tools only against systems you are authorized to test."

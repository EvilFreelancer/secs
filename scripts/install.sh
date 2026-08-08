#!/usr/bin/env bash
#
# install.sh - install information security tooling on Debian / Ubuntu / Kali.
#
# Companion to docs/security-tools.md. Use uninstall.sh to remove what this adds.
#
# Design notes:
#   * Run as a normal user; the script calls sudo only for system packages.
#   * apt packages are installed one by one so a package missing from your
#     distro's repos (many are Kali-only) does not abort the whole run.
#   * pipx / go tools are installed for the current user.
#   * Heavy services (Metasploit, Sliver, Greenbone, Wazuh, BloodHound) are
#     opt-in behind explicit flags.
#
set -uo pipefail   # intentionally NOT -e: continue past individual failures

LOG="${LOG:-/tmp/sectools-install.log}"
: > "$LOG"

# ------------------------------------------------------------------ output ---
if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_0=; fi
ok()   { printf '%s[ ok ]%s %s\n'   "$C_G" "$C_0" "$*"; }
warn() { printf '%s[warn]%s %s\n'   "$C_Y" "$C_0" "$*"; }
err()  { printf '%s[fail]%s %s\n'   "$C_R" "$C_0" "$*" >&2; }
info() { printf '%s[info]%s %s\n'   "$C_B" "$C_0" "$*"; }

FAILED_ALL=()
INSTALLED_COUNT=0

# --------------------------------------------------------------- privileges ---
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

is_kali() { grep -qiE 'kali' /etc/os-release 2>/dev/null; }
os_pretty() { . /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}"; }

# --------------------------------------------------------------- tool lists ---
# apt packages available on Kali; many also on Debian/Ubuntu. Missing ones are
# skipped with a warning rather than aborting.
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

# ---------------------------------------------------------------- installers ---
apt_update_done=0
apt_update() { [ "$apt_update_done" = 1 ] && return; info "apt-get update"; $DRY $SUDO apt-get update -y >>"$LOG" 2>&1; apt_update_done=1; }

apt_install() {
  apt_update
  local p
  for p in "$@"; do
    if [ -n "$DRY" ]; then echo "  would apt install: $p"; continue; fi
    if $SUDO apt-get install -y --no-install-recommends "$p" >>"$LOG" 2>&1; then
      ok "apt: $p"; INSTALLED_COUNT=$((INSTALLED_COUNT+1))
    else
      warn "apt: '$p' not available in this distro's repos (skipped)"; FAILED_ALL+=("apt:$p")
    fi
  done
}

ensure_pipx() {
  command -v pipx >/dev/null 2>&1 && return
  info "installing pipx"; apt_install pipx >/dev/null 2>&1 || true
  [ -n "$DRY" ] || pipx ensurepath >>"$LOG" 2>&1 || true
}
pipx_install() {
  ensure_pipx
  local p
  for p in "$@"; do
    if [ -n "$DRY" ]; then echo "  would pipx install: $p"; continue; fi
    if pipx install "$p" >>"$LOG" 2>&1; then ok "pipx: $p"; INSTALLED_COUNT=$((INSTALLED_COUNT+1))
    else warn "pipx: '$p' failed (see $LOG)"; FAILED_ALL+=("pipx:$p"); fi
  done
}

ensure_go() {
  command -v go >/dev/null 2>&1 && return 0
  info "installing golang-go"; apt_install golang-go >/dev/null 2>&1 || true
  command -v go >/dev/null 2>&1
}
go_install() {
  if ! ensure_go; then warn "Go toolchain unavailable; skipping go tools"; return; fi
  local gobin m bin; gobin="$(go env GOPATH 2>/dev/null)/bin"
  for m in "$@"; do
    if [ -n "$DRY" ]; then echo "  would go install: $m"; continue; fi
    if go install "$m" >>"$LOG" 2>&1; then
      bin="$(basename "${m%@*}")"
      if $SUDO cp -f "$gobin/$bin" /usr/local/bin/ >>"$LOG" 2>&1; then ok "go: $bin -> /usr/local/bin"; else ok "go: $bin (in $gobin)"; fi
      INSTALLED_COUNT=$((INSTALLED_COUNT+1))
    else warn "go: '$m' failed (see $LOG)"; FAILED_ALL+=("go:$m"); fi
  done
}

install_netexec() {   # apt on Kali, else pipx from git
  command -v netexec >/dev/null 2>&1 || command -v nxc >/dev/null 2>&1 && { ok "netexec already present"; return; }
  if is_kali; then apt_install netexec; return; fi
  ensure_pipx
  [ -n "$DRY" ] && { echo "  would pipx install NetExec (git)"; return; }
  if pipx install git+https://github.com/Pennyw0rth/NetExec >>"$LOG" 2>&1; then ok "pipx: NetExec"; else warn "NetExec install failed"; FAILED_ALL+=("netexec"); fi
}

install_metasploit() {
  if command -v msfconsole >/dev/null 2>&1; then ok "metasploit already installed"; return; fi
  if is_kali; then apt_install metasploit-framework; return; fi
  info "installing Metasploit via official nightly installer"
  [ -n "$DRY" ] && { echo "  would run msfinstall (rapid7)"; return; }
  local tmp; tmp="$(mktemp)"
  if curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o "$tmp" >>"$LOG" 2>&1; then
    chmod 755 "$tmp"; $SUDO "$tmp" >>"$LOG" 2>&1 && ok "metasploit installed" || { warn "metasploit install failed"; FAILED_ALL+=("metasploit"); }
  else warn "could not download msfinstall"; FAILED_ALL+=("metasploit"); fi
  rm -f "$tmp"
}

install_sliver() {
  command -v sliver-server >/dev/null 2>&1 && { ok "sliver already installed"; return; }
  info "installing Sliver C2 (adds a systemd service)"
  [ -n "$DRY" ] && { echo "  would run sliver.sh/install"; return; }
  curl -fsSL https://sliver.sh/install | $SUDO bash >>"$LOG" 2>&1 && ok "sliver installed" || { warn "sliver install failed"; FAILED_ALL+=("sliver"); }
}

install_greenbone() {
  info "installing Greenbone / OpenVAS (gvm) - this is large and slow"
  apt_install gvm
  [ -n "$DRY" ] && { echo "  would run gvm-setup"; return; }
  info "running gvm-setup (downloads vuln feeds; note the admin password it prints)"
  $SUDO gvm-setup >>"$LOG" 2>&1 && ok "greenbone set up (UI: https://127.0.0.1:9392)" || { warn "gvm-setup failed (see $LOG)"; FAILED_ALL+=("greenbone"); }
}

install_wazuh() {
  warn "Wazuh all-in-one installs indexer + server + dashboard and needs >=4 GB RAM"
  [ -n "$DRY" ] && { echo "  would run wazuh-install.sh -a"; return; }
  local tmp; tmp="$(mktemp -d)"; ( cd "$tmp" && curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && $SUDO bash ./wazuh-install.sh -a ) >>"$LOG" 2>&1 \
    && ok "wazuh installed (credentials printed in $LOG)" || { warn "wazuh install failed (see $LOG)"; FAILED_ALL+=("wazuh"); }
  rm -rf "$tmp"
}

install_bloodhound() {
  if ! command -v docker >/dev/null 2>&1; then warn "docker not found; install Docker first for BloodHound CE"; FAILED_ALL+=("bloodhound:docker"); return; fi
  info "fetching BloodHound CE docker-compose to ./bloodhound-ce/"
  [ -n "$DRY" ] && { echo "  would fetch getbhce compose + docker compose up"; return; }
  mkdir -p bloodhound-ce && curl -fsSL https://ghst.ly/getbhce -o bloodhound-ce/docker-compose.yml >>"$LOG" 2>&1 \
    && ok "BloodHound CE compose saved to ./bloodhound-ce/ (run: cd bloodhound-ce && docker compose up)" \
    || { warn "could not fetch BloodHound compose"; FAILED_ALL+=("bloodhound"); }
}

# --------------------------------------------------------------------- usage ---
usage() {
  cat <<'EOF'
install.sh - install information security tooling (Debian/Ubuntu/Kali)

USAGE:
  ./install.sh [MODE] [OPTIONS]

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
  --dry-run          show actions without changing anything
  -y, --yes          do not ask for confirmation
  -h, --help         this help

EXAMPLES:
  ./install.sh --all
  ./install.sh --offensive --no-metasploit
  ./install.sh --defensive --with-wazuh -y
  ./install.sh --all --dry-run

Log file: /tmp/sectools-install.log  (override with LOG=/path ./install.sh ...)
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
    --dry-run)        DRY="__DRY__" ;;
    -y|--yes)         ASSUME_YES=1 ;;
    -h|--help)        usage; exit 0 ;;
    *) err "unknown option: $1"; echo; usage; exit 2 ;;
  esac
  shift
done
# normalise DRY into a non-empty marker used by the installer functions
[ "$DRY" = "__DRY__" ] && DRY="1" || DRY=""

[ $MODE_OFF -eq 0 ] && [ $MODE_DEF -eq 0 ] && { err "choose --all, --offensive, or --defensive"; usage; exit 2; }

# ---------------------------------------------------------------------- run ---
info "OS: $(os_pretty)   $(is_kali && echo '(Kali detected)')"
[ -n "$DRY" ] && info "DRY RUN - no changes will be made"

if [ $ASSUME_YES -eq 0 ] && [ -z "$DRY" ]; then
  printf 'Proceed with installation? [y/N] '; read -r ans
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
ok "installed/attempted OK: $INSTALLED_COUNT item(s)"
if [ ${#FAILED_ALL[@]} -gt 0 ]; then
  warn "skipped or failed (${#FAILED_ALL[@]}): ${FAILED_ALL[*]}"
  warn "packages marked 'not available' are usually Kali-only; install them on Kali or via pipx/go."
fi
info "full log: $LOG"
[ -n "$DRY" ] && info "this was a DRY RUN; re-run without --dry-run to apply."
echo
info "Reminder: use these tools only against systems you are authorized to test."

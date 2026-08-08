#!/usr/bin/env bash
#
# uninstall.sh - remove the information security tooling installed by install.sh.
#
# Mirrors install.sh. apt packages are removed (use --purge to also drop config).
# Shared dependencies are left in place; run 'sudo apt-get autoremove' yourself
# if you want to reclaim them. Heavy services (Metasploit/Sliver/Greenbone/Wazuh)
# are only touched when you pass their --with-* flag.
#
set -uo pipefail

LOG="${LOG:-/tmp/sectools-uninstall.log}"
: > "$LOG"

if [ -t 1 ]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[36m'; C_0=$'\033[0m'; else C_G= C_Y= C_R= C_B= C_0=; fi
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

apt_remove() {
  local p
  for p in "$@"; do
    if [ -n "$DRY" ]; then echo "  would apt-get $APT_RM: $p"; continue; fi
    if $SUDO apt-get "$APT_RM" -y "$p" >>"$LOG" 2>&1; then ok "removed apt: $p"
    else warn "apt: '$p' not installed / not removable (skipped)"; fi
  done
}
pipx_remove() {
  command -v pipx >/dev/null 2>&1 || { warn "pipx not present; skipping pipx tools"; return; }
  local p
  for p in "$@"; do
    if [ -n "$DRY" ]; then echo "  would pipx uninstall: $p"; continue; fi
    if pipx uninstall "$p" >>"$LOG" 2>&1; then ok "removed pipx: $p"; else warn "pipx: '$p' not installed (skipped)"; fi
  done
}
go_remove() {
  local b gobin; gobin="$(command -v go >/dev/null 2>&1 && go env GOPATH 2>/dev/null)/bin"
  for b in "$@"; do
    if [ -n "$DRY" ]; then echo "  would remove go binary: $b"; continue; fi
    $SUDO rm -f "/usr/local/bin/$b" >>"$LOG" 2>&1 && ok "removed /usr/local/bin/$b" || true
    [ -n "$gobin" ] && rm -f "$gobin/$b" >>"$LOG" 2>&1 || true
  done
}

remove_metasploit() {
  [ -n "$DRY" ] && { echo "  would remove metasploit-framework"; return; }
  $SUDO apt-get "$APT_RM" -y metasploit-framework >>"$LOG" 2>&1 && ok "removed metasploit-framework" || warn "metasploit not removable via apt (skipped)"
  [ -f /etc/apt/sources.list.d/metasploit-framework.list ] && $SUDO rm -f /etc/apt/sources.list.d/metasploit-framework.list && ok "removed metasploit apt repo"
}
remove_sliver() {
  [ -n "$DRY" ] && { echo "  would stop+remove sliver"; return; }
  $SUDO systemctl disable --now sliver >>"$LOG" 2>&1 || true
  $SUDO rm -f /usr/local/bin/sliver-server /usr/local/bin/sliver-client /etc/systemd/system/sliver.service >>"$LOG" 2>&1 || true
  $SUDO systemctl daemon-reload >>"$LOG" 2>&1 || true
  ok "removed Sliver binaries and service (state in ~/.sliver left intact)"
}
remove_greenbone() {
  [ -n "$DRY" ] && { echo "  would remove gvm"; return; }
  $SUDO apt-get "$APT_RM" -y gvm gvmd gsad openvas-scanner >>"$LOG" 2>&1 && ok "removed Greenbone/GVM packages" || warn "GVM packages not fully removable (skipped)"
  warn "Greenbone data (feeds, DB) may remain under /var/lib/gvm and /var/lib/openvas; remove manually if desired."
}
remove_wazuh() {
  [ -n "$DRY" ] && { echo "  would remove wazuh stack"; return; }
  warn "Wazuh is best removed with its own installer: sudo bash wazuh-install.sh --uninstall"
  $SUDO apt-get "$APT_RM" -y 'wazuh-*' 'wazuh-indexer' 'wazuh-dashboard' 'wazuh-manager' >>"$LOG" 2>&1 && ok "removed wazuh-* packages" || warn "wazuh packages not removable via apt (use the installer's --uninstall)"
}
remove_bloodhound() {
  [ -n "$DRY" ] && { echo "  would docker compose down bloodhound-ce"; return; }
  if [ -f bloodhound-ce/docker-compose.yml ] && command -v docker >/dev/null 2>&1; then
    ( cd bloodhound-ce && docker compose down -v ) >>"$LOG" 2>&1 && ok "BloodHound CE containers/volumes removed" || warn "docker compose down failed"
  else warn "no ./bloodhound-ce/docker-compose.yml found (skipped)"; fi
}

usage() {
  cat <<'EOF'
uninstall.sh - remove tooling installed by install.sh

USAGE:
  ./uninstall.sh [MODE] [OPTIONS]

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
  --dry-run          show what would be removed, change nothing
  -y, --yes          do not ask for confirmation
  -h, --help         this help

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

info "OS: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")  $(is_kali && echo '(Kali)')"
[ -n "$DRY" ] && info "DRY RUN - nothing will be removed"
if [ $ASSUME_YES -eq 0 ] && [ -z "$DRY" ]; then
  warn "This will REMOVE security tooling from your system."
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
info "Done. Full log: $LOG"
[ -n "$DRY" ] && info "this was a DRY RUN; re-run without --dry-run to apply."

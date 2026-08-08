# SECS - Makefile
#
# Single, self-contained front door for the security toolchain and the practice
# VM lab. Everything lives here at the make level - no helper shell scripts.
#
# Cross-platform: detects the package manager and adapts.
#   apt    Debian / Ubuntu / Kali
#   dnf    Fedora / RHEL / Rocky / Alma   (yum as a fallback)
#   pacman Arch / Manjaro
#   brew   macOS
#
# Run `make help` for the target list. Read AGENTS.md before running anything
# active - this only ever targets the local, operator-owned lab.

# ============================================================================
# Knobs (override on the CLI, e.g. `make vm-run RAM_MB=8192 VARIANT=win2k8`)
# ============================================================================
# (keep values free of trailing spaces - make preserves them)
VARIANT      ?= ub1404
# ub1404 | win2k8
RAM_MB       ?= 4096
# guest RAM (MiB) for the VM
CPUS         ?= 2
# guest vCPUs
DISPLAY_MODE ?= vnc
# vnc | none | sdl | gtk
VNC          ?= 127.0.0.1:0
# VNC listen addr (":0" = TCP 5900)
SNAPSHOT     ?= 0
# 1 = discard disk writes on exit
NET_MODE     ?= user
# user | tap | none  (tap needs an existing isolated bridge device)
TAP          ?= tap0
# tap device name when NET_MODE=tap
RESTRICT     ?= off
# on = also block guest->host/internet in user mode (breaks reverse shells)
WITH         ?=
# heavy opt-ins: comma list of metasploit,sliver,greenbone,wazuh,bloodhound
NO_MSF       ?=
# set to 1 to skip Metasploit in the offensive set
PURGE        ?=
# set to 1 to apt-purge (drop config) on uninstall
DRY          ?=
# set to 1 to preview package actions, change nothing

DIST    := dist
LOG     := /tmp/secs-make.log
RUN_LOG := $(DIST)/ms3-$(VARIANT).run.log

empty :=
space := $(empty) $(empty)
comma := ,

# ============================================================================
# Platform + package-manager detection (all at the make level)
# ============================================================================
UNAME_S := $(shell uname -s 2>/dev/null)

ifeq ($(UNAME_S),Darwin)
  OS  := macos
  PKG := brew
else
  OS := linux
  ifneq ($(shell command -v apt-get 2>/dev/null),)
    PKG := apt
  else ifneq ($(shell command -v dnf 2>/dev/null),)
    PKG := dnf
  else ifneq ($(shell command -v yum 2>/dev/null),)
    PKG := yum
  else ifneq ($(shell command -v pacman 2>/dev/null),)
    PKG := pacman
  else
    PKG := none
  endif
endif

IS_KALI := $(shell grep -qiE kali /etc/os-release 2>/dev/null && echo 1 || echo 0)

# sudo for system managers, never for brew, never as root
ifeq ($(PKG),brew)
  SUDO :=
else ifeq ($(shell id -u 2>/dev/null),0)
  SUDO :=
else
  SUDO := sudo
endif

# Per-manager verbs (selected by computed variable name)
REFRESH_apt    := apt-get update -y
REFRESH_dnf    := dnf -y makecache
REFRESH_yum    := yum -y makecache
REFRESH_pacman := pacman -Sy --noconfirm
REFRESH_brew   := true
PKG_REFRESH    := $(or $(REFRESH_$(PKG)),true)

CHECK_apt    := dpkg -s
CHECK_dnf    := rpm -q
CHECK_yum    := rpm -q
CHECK_pacman := pacman -Qi
CHECK_brew   := brew list --formula
PKG_CHECK    := $(or $(CHECK_$(PKG)),false)

INSTALL_apt    := apt-get install -y --no-install-recommends
INSTALL_dnf    := dnf install -y
INSTALL_yum    := yum install -y
INSTALL_pacman := pacman -S --needed --noconfirm
INSTALL_brew   := brew install
PKG_INSTALL    := $(INSTALL_$(PKG))

REMOVE_apt    := apt-get $(if $(PURGE),purge,remove) -y
REMOVE_dnf    := dnf remove -y
REMOVE_yum    := yum remove -y
REMOVE_pacman := pacman -Rns --noconfirm
REMOVE_brew   := brew uninstall
PKG_REMOVE    := $(REMOVE_$(PKG))

PIPXBOOT_apt    := apt-get install -y pipx
PIPXBOOT_dnf    := dnf install -y pipx
PIPXBOOT_yum    := yum install -y pipx
PIPXBOOT_pacman := pacman -S --needed --noconfirm python-pipx
PIPXBOOT_brew   := brew install pipx
PIPX_BOOTSTRAP  := $(or $(PIPXBOOT_$(PKG)),true)

GOBOOT_apt    := apt-get install -y golang-go
GOBOOT_dnf    := dnf install -y golang
GOBOOT_yum    := yum install -y golang
GOBOOT_pacman := pacman -S --needed --noconfirm go
GOBOOT_brew   := brew install go
GO_BOOTSTRAP  := $(or $(GOBOOT_$(PKG)),true)

# ============================================================================
# Tool catalog. Package names differ per distro and many offensive tools are
# Kali-only, so each manager gets its own curated list; anything missing from a
# distro's repos is skipped at install time, not fatal. The portable pipx/go set
# is identical everywhere and fills the gaps on non-Kali systems.
# ============================================================================
OFFENSIVE_apt := nmap masscan arp-scan netdiscover dnsutils dnsrecon whatweb \
  amass recon-ng nikto sqlmap wpscan ffuf gobuster feroxbuster dirb commix \
  zaproxy exploitdb john hashcat hydra medusa ncrack crunch cewl hashid \
  wordlists seclists bettercap ettercap-graphical responder aircrack-ng wifite \
  kismet hcxdumptool hcxtools reaver bully radare2 gdb strace ltrace \
  impacket-scripts smbclient smbmap enum4linux nbtscan burpsuite maltego cutter \
  ghidra beef-xss
OFFENSIVE_dnf := nmap masscan arp-scan bind-utils whatweb nikto sqlmap hydra \
  medusa john hashcat crunch aircrack-ng hcxtools hcxdumptool radare2 gdb \
  strace ltrace samba-client nbtscan
OFFENSIVE_yum := $(OFFENSIVE_dnf)
OFFENSIVE_pacman := nmap masscan arp-scan bind whatweb nikto sqlmap hydra john \
  hashcat aircrack-ng hcxtools hcxdumptool radare2 gdb strace ltrace smbclient
OFFENSIVE_brew := nmap masscan nikto sqlmap wpscan hydra john-jumbo hashcat ffuf \
  gobuster feroxbuster amass medusa ncrack aircrack-ng bettercap radare2
OFFENSIVE := $(OFFENSIVE_$(PKG))

DEFENSIVE_apt := wireshark tshark tcpdump suricata snort fail2ban lynis rkhunter \
  chkrootkit aide aide-common clamav clamav-daemon clamav-freshclam \
  openscap-scanner openscap-utils sleuthkit autopsy binwalk foremost scalpel \
  bulk-extractor yara
DEFENSIVE_dnf := wireshark-cli tcpdump suricata fail2ban lynis rkhunter \
  chkrootkit clamav clamav-update aide openscap-scanner scap-security-guide \
  sleuthkit binwalk foremost yara
DEFENSIVE_yum := $(DEFENSIVE_dnf)
DEFENSIVE_pacman := wireshark-cli tcpdump suricata fail2ban lynis rkhunter clamav \
  aide sleuthkit binwalk foremost yara
DEFENSIVE_brew := wireshark tcpdump suricata clamav yara binwalk sleuthkit
DEFENSIVE := $(DEFENSIVE_$(PKG))

# Portable, distro-independent tools (same everywhere).
PIPX_OFFENSIVE := theHarvester wapiti3 shodan
PIPX_DEFENSIVE := volatility3
GO_OFFENSIVE   := github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest \
                  github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
GO_BINS        := nuclei naabu

# ============================================================================
# Practice VM (Metasploitable 3). Rapid7 ships it as Vagrant boxes, not disk
# images: we download the virtualbox box, extract its VMDK and convert to qcow2.
# ============================================================================
ifeq ($(VARIANT),ub1404)
  BOX    := metasploitable3-ub1404
  BOXVER := 0.1.12-weekly
else ifeq ($(VARIANT),win2k8)
  BOX    := metasploitable3-win2k8
  BOXVER := 0.1.0-weekly
else
  BOX    :=
  BOXVER :=
endif
BOXURL  := https://vagrantcloud.com/rapid7/boxes/$(BOX)/versions/$(BOXVER)/providers/virtualbox/unknown/vagrant.box
BOXFILE := $(DIST)/$(BOX)-$(BOXVER).box
QCOW2   := $(DIST)/$(BOX).qcow2

# Per-variant host(127.0.0.1) -> guest port forwards for user-mode networking.
FWD_ub1404 := 2222:22 2121:21 8000:80 13306:3306 8080:8080 8181:8181 8282:8282 \
  8383:8383 8484:8484 8585:8585 6697:6697 9200:9200 3000:3000 3500:3500
FWD_win2k8 := 2222:22 8022:8022 3389:3389 4445:445 11433:1433 8000:80 8080:8080 \
  8443:8443 8484:8484 8585:8585 9200:9200 4848:4848 8020:8020 7676:7676
FWD := $(FWD_$(VARIANT))

# ============================================================================
# Canned recipes (the package loops, shared by install/uninstall)
# ============================================================================
# $(call do_install,<pkg list>)
define do_install
@total=$(words $(1)); n=0; for p in $(1); do n=$$((n+1)); if [ -n "$(DRY)" ]; then printf '  [%s/%s] would-install %s:%s\n' $$n $$total $(PKG) $$p; elif $(PKG_CHECK) $$p >/dev/null 2>&1; then printf '  [%s/%s] present   %s:%s\n' $$n $$total $(PKG) $$p; elif $(SUDO) $(PKG_INSTALL) $$p >>$(LOG) 2>&1; then printf '  [%s/%s] installed %s:%s\n' $$n $$total $(PKG) $$p; else printf '  [%s/%s] skipped   %s:%s\n' $$n $$total $(PKG) $$p; fi; done
endef

# $(call do_remove,<pkg list>)
define do_remove
@total=$(words $(1)); n=0; for p in $(1); do n=$$((n+1)); if [ -n "$(DRY)" ]; then printf '  [%s/%s] would-remove %s:%s\n' $$n $$total $(PKG) $$p; elif ! $(PKG_CHECK) $$p >/dev/null 2>&1; then printf '  [%s/%s] absent    %s:%s\n' $$n $$total $(PKG) $$p; elif $(SUDO) $(PKG_REMOVE) $$p >>$(LOG) 2>&1; then printf '  [%s/%s] removed   %s:%s\n' $$n $$total $(PKG) $$p; else printf '  [%s/%s] failed    %s:%s\n' $$n $$total $(PKG) $$p; fi; done
endef

# $(call do_pipx,<pipx pkg list>)
define do_pipx
@command -v pipx >/dev/null 2>&1 || { [ -n "$(DRY)" ] || { $(SUDO) $(PIPX_BOOTSTRAP) >>$(LOG) 2>&1 || python3 -m pip install --user pipx >>$(LOG) 2>&1 || true; }; }; total=$(words $(1)); n=0; for p in $(1); do n=$$((n+1)); if [ -n "$(DRY)" ]; then printf '  [%s/%s] would-install pipx:%s\n' $$n $$total $$p; elif ! command -v pipx >/dev/null 2>&1; then printf '  [%s/%s] skipped   pipx:%s (no pipx)\n' $$n $$total $$p; elif pipx list --short 2>/dev/null | awk '{print $$1}' | grep -ix "$$p" >/dev/null 2>&1; then printf '  [%s/%s] present   pipx:%s\n' $$n $$total $$p; elif pipx install "$$p" >>$(LOG) 2>&1; then printf '  [%s/%s] installed pipx:%s\n' $$n $$total $$p; else printf '  [%s/%s] skipped   pipx:%s\n' $$n $$total $$p; fi; done
endef

# $(call do_pipx_remove,<pipx pkg list>)
define do_pipx_remove
@total=$(words $(1)); n=0; for p in $(1); do n=$$((n+1)); if [ -n "$(DRY)" ]; then printf '  [%s/%s] would-remove pipx:%s\n' $$n $$total $$p; elif ! command -v pipx >/dev/null 2>&1; then printf '  [%s/%s] absent    pipx:%s\n' $$n $$total $$p; elif ! pipx list --short 2>/dev/null | awk '{print $$1}' | grep -ix "$$p" >/dev/null 2>&1; then printf '  [%s/%s] absent    pipx:%s\n' $$n $$total $$p; elif pipx uninstall "$$p" >>$(LOG) 2>&1; then printf '  [%s/%s] removed   pipx:%s\n' $$n $$total $$p; else printf '  [%s/%s] failed    pipx:%s\n' $$n $$total $$p; fi; done
endef

# ============================================================================
# Help (default target)
# ============================================================================
.DEFAULT_GOAL := help
.NOTPARALLEL:
.PHONY: help doctor \
        install install-all install-offensive install-defensive install-dry \
        install-metasploit install-sliver install-greenbone install-wazuh \
        install-bloodhound _refresh _go-tools _netexec _with-extras \
        uninstall uninstall-all uninstall-offensive uninstall-defensive \
        uninstall-metasploit uninstall-sliver uninstall-greenbone \
        uninstall-wazuh uninstall-bloodhound _go-remove \
        vm-download vm-run vm-run-fg vm-status vm-ssh vm-stop vm-remove _vm-boot

help:
	@echo "SECS - security assistant toolchain & practice lab"
	@echo "=================================================="
	@echo "detected: $(OS) / $(PKG)$(if $(filter 1,$(IS_KALI)), (Kali),)"
	@echo ""
	@echo "Packages:"
	@echo "  make install            Install offensive + defensive tools"
	@echo "  make install-offensive  Offensive tools only (installs Metasploit unless NO_MSF=1)"
	@echo "  make install-defensive  Defensive tools only"
	@echo "  make install-dry        Preview what would be installed (no changes)"
	@echo "  make uninstall          Remove what install added"
	@echo ""
	@echo "  Heavy opt-ins:  make install WITH=sliver,greenbone,wazuh,bloodhound"
	@echo "  Skip Metasploit: make install-offensive NO_MSF=1"
	@echo "  apt purge:       make uninstall PURGE=1"
	@echo ""
	@echo "Practice VM (Metasploitable 3, loopback-only):"
	@echo "  make vm-download        Fetch the box and build $(DIST)/*.qcow2"
	@echo "  make vm-run             Boot it in the background (RAM_MB=$(RAM_MB) CPUS=$(CPUS))"
	@echo "  make vm-run-fg          Boot it in the foreground"
	@echo "  make vm-status          Whether it is running + tail the log"
	@echo "  make vm-ssh             SSH into the guest (vagrant/vagrant)"
	@echo "  make vm-stop            Power it off gracefully"
	@echo "  make vm-remove          Delete the downloaded box and disk image"
	@echo ""
	@echo "  VM knobs: VARIANT=$(VARIANT) (ub1404|win2k8) RAM_MB CPUS SNAPSHOT DISPLAY_MODE VNC"
	@echo ""
	@echo "Diagnostics:"
	@echo "  make doctor             Show detected OS, package manager, key tools"
	@echo ""
	@echo "Authorized testing only. Read AGENTS.md before anything active."

doctor:
	@echo "OS          : $(OS)   package manager: $(PKG)$(if $(filter 1,$(IS_KALI)),   (Kali),)"
	@echo "privilege   : $(if $(SUDO),sudo for system packages,root / brew (no sudo))"
	@echo "offensive   : $(words $(OFFENSIVE)) $(PKG) pkgs + $(words $(PIPX_OFFENSIVE)) pipx + $(words $(GO_BINS)) go + netexec"
	@echo "defensive   : $(words $(DEFENSIVE)) $(PKG) pkgs + $(words $(PIPX_DEFENSIVE)) pipx"
	@printf 'key tools   : '
	@for t in nmap sqlmap hydra hashcat radare2 tshark yara pipx go docker qemu-system-x86_64 msfconsole; do \
	  if command -v $$t >/dev/null 2>&1; then printf '%s ' $$t; else printf '(%s) ' $$t; fi; done; echo
	@[ "$(PKG)" = none ] && echo "warning: no supported package manager; only pipx/go tools can be installed" || true

# ============================================================================
# Install
# ============================================================================
_refresh:
	@: > $(LOG); mkdir -p $(DIST)
	@[ -n "$(DRY)" ] || [ "$(PKG)" = none ] || { echo "refreshing package index ($(PKG)) ..."; $(SUDO) $(PKG_REFRESH) >>$(LOG) 2>&1 || true; }
	@[ "$(PKG)" != none ] || echo "note: no supported package manager on $(OS); installing only the portable pipx/go tools"

install install-all: _refresh
	@echo "=== OFFENSIVE ==="
	$(call do_install,$(OFFENSIVE))
	$(call do_pipx,$(PIPX_OFFENSIVE))
	@$(MAKE) --no-print-directory _go-tools _netexec
	@[ -n "$(NO_MSF)" ] || $(MAKE) --no-print-directory install-metasploit
	@echo "=== DEFENSIVE ==="
	$(call do_install,$(DEFENSIVE))
	$(call do_pipx,$(PIPX_DEFENSIVE))
	@$(MAKE) --no-print-directory _with-extras
	@echo "done. full log: $(LOG)"
	@echo "reminder: use these tools only against systems you are authorized to test."

install-offensive: _refresh
	@echo "=== OFFENSIVE ==="
	$(call do_install,$(OFFENSIVE))
	$(call do_pipx,$(PIPX_OFFENSIVE))
	@$(MAKE) --no-print-directory _go-tools _netexec
	@[ -n "$(NO_MSF)" ] || $(MAKE) --no-print-directory install-metasploit
	@$(MAKE) --no-print-directory _with-extras
	@echo "done. full log: $(LOG)"

install-defensive: _refresh
	@echo "=== DEFENSIVE ==="
	$(call do_install,$(DEFENSIVE))
	$(call do_pipx,$(PIPX_DEFENSIVE))
	@$(MAKE) --no-print-directory _with-extras
	@echo "done. full log: $(LOG)"

install-dry:
	@$(MAKE) --no-print-directory install DRY=1

# go tools (nuclei, naabu) - portable, need a Go toolchain
_go-tools:
	@command -v go >/dev/null 2>&1 || { [ -n "$(DRY)" ] || { echo "  installing go toolchain ..."; $(SUDO) $(GO_BOOTSTRAP) >>$(LOG) 2>&1 || true; }; }
	@if [ -n "$(DRY)" ]; then for m in $(GO_OFFENSIVE); do echo "  would-install go:$$(basename $${m%@*})"; done; \
	elif ! command -v go >/dev/null 2>&1; then echo "  skipped go tools (no Go toolchain)"; else \
	  total=$(words $(GO_OFFENSIVE)); n=0; gobin="$$(go env GOPATH)/bin"; \
	  for m in $(GO_OFFENSIVE); do n=$$((n+1)); bin=$$(basename $${m%@*}); \
	    if command -v $$bin >/dev/null 2>&1; then printf '  [%s/%s] present   go:%s\n' $$n $$total $$bin; \
	    elif go install $$m >>$(LOG) 2>&1; then \
	      { [ -w /usr/local/bin ] && cp -f "$$gobin/$$bin" /usr/local/bin/ 2>>$(LOG); } || { [ -n "$(SUDO)" ] && $(SUDO) cp -f "$$gobin/$$bin" /usr/local/bin/ 2>>$(LOG); } || true; \
	      printf '  [%s/%s] installed go:%s\n' $$n $$total $$bin; \
	    else printf '  [%s/%s] skipped   go:%s\n' $$n $$total $$bin; fi; \
	  done; fi

# netexec - apt on Kali, otherwise pipx from git
_netexec:
	@if [ -n "$(DRY)" ]; then echo "  would-install netexec"; \
	elif command -v netexec >/dev/null 2>&1 || command -v nxc >/dev/null 2>&1; then echo "  present   netexec"; \
	elif [ "$(IS_KALI)" = 1 ] && $(SUDO) apt-get install -y netexec >>$(LOG) 2>&1; then echo "  installed netexec"; \
	elif command -v pipx >/dev/null 2>&1 && pipx install git+https://github.com/Pennyw0rth/NetExec >>$(LOG) 2>&1; then echo "  installed netexec"; \
	else echo "  skipped   netexec"; fi

# Dispatch WITH=a,b,c to the matching install-* targets.
_with-extras:
	@for w in $(subst $(comma),$(space),$(WITH)); do case "$$w" in \
	  metasploit|sliver|greenbone|wazuh|bloodhound) $(MAKE) --no-print-directory install-$$w;; \
	  "") : ;; \
	  *) echo "  unknown WITH item: $$w";; \
	esac; done

install-metasploit:
	@if [ -n "$(DRY)" ]; then echo "  would-install metasploit"; \
	elif command -v msfconsole >/dev/null 2>&1; then echo "  present   metasploit"; \
	elif [ "$(IS_KALI)" = 1 ]; then $(SUDO) apt-get install -y metasploit-framework >>$(LOG) 2>&1 && echo "  installed metasploit" || echo "  skipped   metasploit"; \
	elif [ "$(OS)" != linux ]; then echo "  skipped   metasploit (install from https://docs.metasploit.com/ on $(OS))"; \
	else echo "  installing metasploit via nightly installer ..."; \
	  tmp=$$(mktemp); \
	  if curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o $$tmp >>$(LOG) 2>&1; then chmod 755 $$tmp; $(SUDO) $$tmp >>$(LOG) 2>&1 && echo "  installed metasploit" || echo "  skipped   metasploit"; else echo "  skipped   metasploit (download failed)"; fi; \
	  rm -f $$tmp; fi

install-sliver:
	@if [ -n "$(DRY)" ]; then echo "  would-install sliver"; \
	elif command -v sliver-server >/dev/null 2>&1; then echo "  present   sliver"; \
	elif [ "$(OS)" != linux ]; then echo "  skipped   sliver (Linux-only installer; see https://sliver.sh)"; \
	else echo "  installing Sliver C2 (adds a systemd service) ..."; curl -fsSL https://sliver.sh/install | $(SUDO) bash >>$(LOG) 2>&1 && echo "  installed sliver" || echo "  skipped   sliver"; fi

install-greenbone:
	@if [ -n "$(DRY)" ]; then echo "  would-install greenbone/gvm"; \
	elif command -v gvm-setup >/dev/null 2>&1; then echo "  present   greenbone/gvm"; \
	elif [ "$(PKG)" != apt ]; then echo "  skipped   greenbone/gvm (packaged for Kali/Debian only)"; \
	else echo "  installing Greenbone/OpenVAS (large, slow) ..."; $(SUDO) apt-get install -y gvm >>$(LOG) 2>&1 && $(SUDO) gvm-setup >>$(LOG) 2>&1 && echo "  installed greenbone/gvm (UI https://127.0.0.1:9392)" || echo "  skipped   greenbone/gvm"; fi

install-wazuh:
	@if [ -n "$(DRY)" ]; then echo "  would-install wazuh"; \
	elif [ "$(OS)" != linux ]; then echo "  skipped   wazuh (Linux-only all-in-one installer)"; \
	else echo "  installing Wazuh all-in-one (needs >=4 GB RAM) ..."; tmp=$$(mktemp -d); ( cd $$tmp && curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && $(SUDO) bash ./wazuh-install.sh -a ) >>$(LOG) 2>&1 && echo "  installed wazuh (credentials in $(LOG))" || echo "  skipped   wazuh"; rm -rf $$tmp; fi

install-bloodhound:
	@if [ -n "$(DRY)" ]; then echo "  would-install bloodhound-ce"; \
	elif ! command -v docker >/dev/null 2>&1; then echo "  skipped   bloodhound-ce (Docker not installed)"; \
	else mkdir -p bloodhound-ce && curl -fsSL https://ghst.ly/getbhce -o bloodhound-ce/docker-compose.yml >>$(LOG) 2>&1 && echo "  installed bloodhound-ce (run: cd bloodhound-ce && docker compose up)" || echo "  skipped   bloodhound-ce"; fi

# ============================================================================
# Uninstall
# ============================================================================
uninstall uninstall-all: uninstall-offensive uninstall-defensive
	@echo "done. full log: $(LOG)"

uninstall-offensive:
	@: > $(LOG)
	@echo "=== removing OFFENSIVE ==="
	$(call do_remove,$(OFFENSIVE))
	$(call do_pipx_remove,$(PIPX_OFFENSIVE) netexec)
	@$(MAKE) --no-print-directory _go-remove
	@for w in $(subst $(comma),$(space),$(WITH)); do case "$$w" in metasploit|sliver|greenbone|wazuh|bloodhound) $(MAKE) --no-print-directory uninstall-$$w;; esac; done

uninstall-defensive:
	@echo "=== removing DEFENSIVE ==="
	$(call do_remove,$(DEFENSIVE))
	$(call do_pipx_remove,$(PIPX_DEFENSIVE))

_go-remove:
	@if [ -n "$(DRY)" ]; then for b in $(GO_BINS); do echo "  would-remove go:$$b"; done; exit 0; fi; \
	gobin="$$(command -v go >/dev/null 2>&1 && go env GOPATH 2>/dev/null)/bin"; \
	for b in $(GO_BINS); do found=0; \
	  if [ -e "/usr/local/bin/$$b" ]; then { [ -w "/usr/local/bin/$$b" ] && rm -f "/usr/local/bin/$$b"; } || $(SUDO) rm -f "/usr/local/bin/$$b" 2>>$(LOG) || true; found=1; fi; \
	  [ -n "$$gobin" ] && [ -e "$$gobin/$$b" ] && { rm -f "$$gobin/$$b"; found=1; }; \
	  [ $$found = 1 ] && echo "  removed   go:$$b" || echo "  absent    go:$$b"; \
	done

uninstall-metasploit:
	@if command -v msfconsole >/dev/null 2>&1 && [ "$(PKG)" = apt ]; then $(SUDO) apt-get $(if $(PURGE),purge,remove) -y metasploit-framework >>$(LOG) 2>&1 && echo "  removed   metasploit" || echo "  failed    metasploit"; else echo "  absent    metasploit (or installed outside the package manager)"; fi

uninstall-sliver:
	@if [ -e /usr/local/bin/sliver-server ]; then command -v systemctl >/dev/null 2>&1 && $(SUDO) systemctl disable --now sliver >>$(LOG) 2>&1 || true; $(SUDO) rm -f /usr/local/bin/sliver-server /usr/local/bin/sliver-client /etc/systemd/system/sliver.service >>$(LOG) 2>&1 || true; echo "  removed   sliver (state in ~/.sliver kept)"; else echo "  absent    sliver"; fi

uninstall-greenbone:
	@if command -v gvm-setup >/dev/null 2>&1; then $(SUDO) apt-get $(if $(PURGE),purge,remove) -y gvm gvmd gsad openvas-scanner >>$(LOG) 2>&1 && echo "  removed   greenbone/gvm" || echo "  failed    greenbone/gvm"; else echo "  absent    greenbone/gvm"; fi

uninstall-wazuh:
	@if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^wazuh-manager'; then $(SUDO) apt-get $(if $(PURGE),purge,remove) -y wazuh-manager wazuh-indexer wazuh-dashboard >>$(LOG) 2>&1 && echo "  removed   wazuh" || echo "  failed    wazuh"; else echo "  absent    wazuh"; fi

uninstall-bloodhound:
	@if [ -f bloodhound-ce/docker-compose.yml ] && command -v docker >/dev/null 2>&1; then ( cd bloodhound-ce && docker compose down -v ) >>$(LOG) 2>&1 && echo "  removed   bloodhound-ce" || echo "  failed    bloodhound-ce"; else echo "  absent    bloodhound-ce"; fi

# ============================================================================
# Practice VM lab
# ============================================================================
vm-download:
	@test -n "$(BOX)" || { echo "unknown VARIANT '$(VARIANT)' (use ub1404 or win2k8)"; exit 2; }
	@command -v qemu-img >/dev/null 2>&1 || { echo "qemu-img not found - install QEMU first"; exit 1; }
	@command -v tar >/dev/null 2>&1 || { echo "tar not found"; exit 1; }
	@command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { echo "need curl or wget"; exit 1; }
	@mkdir -p $(DIST); \
	if [ -f $(QCOW2) ]; then echo "qcow2 already present: $(QCOW2) ($$(du -h $(QCOW2) | cut -f1)); 'make vm-run' to boot"; exit 0; fi; \
	echo "variant : $(VARIANT) ($(BOX) $(BOXVER))"; \
	echo "source  : $(BOXURL)"; \
	if [ -f $(BOXFILE) ]; then echo "box already downloaded: $(BOXFILE)"; else \
	  echo "downloading box (resumable) ..."; \
	  if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 --connect-timeout 60 -C - -o $(BOXFILE).part "$(BOXURL)"; \
	  else wget --continue --tries=3 --timeout=60 --progress=dot:giga -O $(BOXFILE).part "$(BOXURL)"; fi; \
	  mv $(BOXFILE).part $(BOXFILE); fi; \
	tar -tzf $(BOXFILE) >/dev/null 2>&1 || { echo "downloaded file is not a valid box (corrupt/truncated); remove $(BOXFILE) and retry"; exit 1; }; \
	vmdk=$$(tar -tzf $(BOXFILE) | grep -iE '\.vmdk$$' | head -n1); \
	[ -n "$$vmdk" ] || { echo "no .vmdk inside the box"; exit 1; }; \
	echo "disk inside box: $$vmdk"; \
	rm -rf $(DIST)/.work-$(BOX); mkdir -p $(DIST)/.work-$(BOX); \
	echo "extracting disk ..."; tar -xzf $(BOXFILE) -C $(DIST)/.work-$(BOX) -- "$$vmdk"; \
	echo "converting vmdk -> qcow2 (this can take a minute) ..."; \
	qemu-img convert -p -f vmdk -O qcow2 "$(DIST)/.work-$(BOX)/$$vmdk" $(QCOW2).part; \
	mv $(QCOW2).part $(QCOW2); rm -rf $(DIST)/.work-$(BOX); \
	qemu-img info $(QCOW2) | sed 's/^/    /'; \
	echo "done -> $(QCOW2). Boot it with 'make vm-run VARIANT=$(VARIANT)' (creds: vagrant/vagrant)"

# Foreground boot (execs qemu). vm-run wraps this in nohup for the background case.
_vm-boot:
	@test -n "$(BOX)" || { echo "unknown VARIANT '$(VARIANT)'"; exit 2; }
	@test -f $(QCOW2) || { echo "disk not found: $(QCOW2) - run 'make vm-download VARIANT=$(VARIANT)'"; exit 1; }
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "qemu-system-x86_64 not found"; exit 1; }
	@args="-name $(BOX) -machine pc -m $(RAM_MB) -smp $(CPUS) -rtc base=utc -boot order=c"; \
	if [ "$(OS)" = macos ]; then \
	  if [ "$$(uname -m)" = x86_64 ]; then args="$$args -accel hvf -cpu host"; accel="HVF (hardware)"; \
	  else args="$$args -accel tcg -cpu qemu64"; accel="TCG (software, slow; x86 guest on Apple Silicon)"; fi; \
	elif [ -r /dev/kvm ] && [ -w /dev/kvm ]; then args="$$args -enable-kvm -cpu host"; accel="KVM (hardware)"; \
	else args="$$args -cpu qemu64"; accel="TCG (software, slow)"; fi; \
	args="$$args -drive file=$(QCOW2),format=qcow2,if=ide,cache=writeback"; \
	[ "$(SNAPSHOT)" = 1 ] && args="$$args -snapshot" || true; \
	case "$(NET_MODE)" in \
	  user) netopt="user,id=net0"; [ "$(RESTRICT)" = on ] && netopt="$$netopt,restrict=on" || true; \
	    for f in $(FWD); do hp=$${f%%:*}; gp=$${f##*:}; \
	      if command -v ss >/dev/null 2>&1 && ss -ltnH "sport = :$$hp" 2>/dev/null | grep -q .; then echo "host port $$hp busy - forward skipped"; continue; fi; \
	      netopt="$$netopt,hostfwd=tcp:127.0.0.1:$$hp-:$$gp"; done; \
	    args="$$args -netdev $$netopt -device e1000,netdev=net0";; \
	  tap) echo "tap mode: expecting existing device '$(TAP)' on an ISOLATED bridge (needs privileges)"; \
	    args="$$args -netdev tap,id=net0,ifname=$(TAP),script=no,downscript=no -device e1000,netdev=net0";; \
	  none) args="$$args -nic none"; echo "network disabled (NET_MODE=none)";; \
	  *) echo "unknown NET_MODE '$(NET_MODE)' (user|tap|none)"; exit 2;; \
	esac; \
	case "$(DISPLAY_MODE)" in \
	  vnc) args="$$args -vga std -vnc $(VNC)";; \
	  none) args="$$args -display none";; \
	  sdl) args="$$args -vga std -display sdl";; \
	  gtk) args="$$args -vga std -display gtk";; \
	esac; \
	echo "disk    : $(QCOW2)"; \
	echo "accel   : $$accel   resources: $(RAM_MB) MiB / $(CPUS) vCPU"; \
	[ "$(DISPLAY_MODE)" = vnc ] && echo "console : VNC on $(VNC) (TCP $$((5900 + $${VNC##*:})))" || true; \
	echo "authorized testing only - Metasploitable 3 is intentionally vulnerable"; \
	echo "launching: qemu-system-x86_64 $$args"; \
	exec qemu-system-x86_64 $$args

vm-run:
	@test -n "$(BOX)" || { echo "unknown VARIANT '$(VARIANT)'"; exit 2; }
	@mkdir -p $(DIST); \
	if pgrep -f 'qemu-system-x86_64 .*$(BOX)' >/dev/null 2>&1; then echo "already running: $(BOX) ('make vm-stop' to stop)"; exit 0; fi; \
	echo "booting $(VARIANT) in the background, log -> $(RUN_LOG)"; \
	nohup $(MAKE) --no-print-directory _vm-boot VARIANT='$(VARIANT)' RAM_MB='$(RAM_MB)' CPUS='$(CPUS)' SNAPSHOT='$(SNAPSHOT)' DISPLAY_MODE='$(DISPLAY_MODE)' VNC='$(VNC)' NET_MODE='$(NET_MODE)' TAP='$(TAP)' RESTRICT='$(RESTRICT)' </dev/null >$(RUN_LOG) 2>&1 & \
	sleep 1; echo "started - 'make vm-status' for forwards, 'make vm-ssh' to log in (vagrant/vagrant)"

vm-run-fg: _vm-boot

vm-status:
	@if pgrep -f 'qemu-system-x86_64 .*$(BOX)' >/dev/null 2>&1; then \
	  echo "RUNNING: $(BOX) (pid $$(pgrep -f 'qemu-system-x86_64 .*$(BOX)' | tr '\n' ' '))"; \
	else echo "not running: $(BOX)"; fi
	@[ -f $(RUN_LOG) ] && { echo "--- tail $(RUN_LOG) ---"; tail -n 20 $(RUN_LOG); } || true

vm-ssh:
	ssh -p 2222 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group1-sha1 vagrant@127.0.0.1

vm-stop:
	@pkill -TERM -f 'qemu-system-x86_64 .*$(BOX)' 2>/dev/null && echo "sent SIGTERM to $(BOX)" || echo "not running: $(BOX)"

vm-remove:
	@test -n "$(BOX)" || { echo "unknown VARIANT '$(VARIANT)'"; exit 2; }
	@if pgrep -f 'qemu-system-x86_64 .*$(BOX)' >/dev/null 2>&1; then \
	  echo "stop it first: make vm-stop VARIANT=$(VARIANT)"; \
	else \
	  rm -f $(QCOW2) $(DIST)/$(BOX)-*.box $(RUN_LOG); \
	  echo "removed disk image and box for $(VARIANT)"; \
	fi

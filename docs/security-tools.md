# Information Security Tools for Linux

A curated reference of the most popular and well-known information security tools that run on Linux, grouped by task. It covers both offensive (red team) and defensive (blue team) tooling, with a short description and installation instructions for each tool.

Installation commands target Debian, Ubuntu and Kali Linux. On Kali and Parrot OS most of these tools are already preinstalled or available through `apt`. Some tools are distributed through `pipx`, `go install`, official installer scripts, Docker or vendor downloads, which is noted per tool.

> Legal note: use these tools only against systems you own or are explicitly authorized to test. Unauthorized access, scanning or exploitation is illegal in most jurisdictions.

## Table of Contents

- [Network Reconnaissance and Scanning](#network-reconnaissance-and-scanning)
- [Information Gathering and OSINT](#information-gathering-and-osint)
- [Vulnerability Scanners](#vulnerability-scanners)
- [Web Application Testing](#web-application-testing)
- [Exploitation Frameworks](#exploitation-frameworks)
- [Password and Hash Cracking](#password-and-hash-cracking)
- [Traffic Interception and Analysis](#traffic-interception-and-analysis)
- [Wireless Attacks](#wireless-attacks)
- [Reverse Engineering and Binary Analysis](#reverse-engineering-and-binary-analysis)
- [Digital Forensics](#digital-forensics)
- [Post-Exploitation and Privilege Escalation](#post-exploitation-and-privilege-escalation)
- [Defensive Tools (Blue Team)](#defensive-tools-blue-team)
- [Security Distributions](#security-distributions)
- [Bulk Installation on Kali and Parrot](#bulk-installation-on-kali-and-parrot)
- [Sources](#sources)

## Network Reconnaissance and Scanning

### Nmap
The de facto standard port, service and OS scanner, with the Nmap Scripting Engine (NSE) for extended checks. Ships with `ncat`, `nping` and the Zenmap GUI.
```bash
sudo apt install nmap
```
Website: https://nmap.org

### Masscan
An asynchronous, extremely fast port scanner able to sweep the entire IPv4 space; useful for very large ranges.
```bash
sudo apt install masscan
# From source:
git clone https://github.com/robertdavidgraham/masscan && cd masscan && make && sudo make install
```
Website: https://github.com/robertdavidgraham/masscan

### arp-scan and netdiscover
Layer 2 host discovery on the local network via ARP; fast for mapping live hosts.
```bash
sudo apt install arp-scan netdiscover
```

### naabu
A fast, reliable port scanner from ProjectDiscovery, designed to feed results into other tools such as nuclei.
```bash
sudo apt install -y libpcap-dev
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
```
Website: https://github.com/projectdiscovery/naabu

## Information Gathering and OSINT

### theHarvester
Gathers emails, subdomains, hosts and names from public sources (search engines, PGP key servers, certificates).
```bash
sudo apt install theharvester
# or
pipx install theHarvester
```
Website: https://github.com/laramies/theHarvester

### Amass
In-depth attack surface mapping and subdomain enumeration, maintained under the OWASP umbrella.
```bash
sudo apt install amass
# or latest:
go install -v github.com/owasp-amass/amass/v4/...@master
```
Website: https://github.com/owasp-amass/amass

### recon-ng
A modular web reconnaissance framework with a Metasploit-like console and a marketplace of modules.
```bash
sudo apt install recon-ng
# or
pipx install recon-ng
```
Website: https://github.com/lanmaster53/recon-ng

### SpiderFoot
OSINT automation with a web UI and hundreds of modules for correlating people, domains, IPs and leaks.
```bash
pipx install spiderfoot
# or
git clone https://github.com/smicallef/spiderfoot && cd spiderfoot && pip install -r requirements.txt
```
Website: https://github.com/smicallef/spiderfoot

### Maltego
Visual link analysis of relationships between entities (domains, people, infrastructure). Community Edition is free.
```bash
sudo apt install maltego   # Kali
```
Website: https://www.maltego.com

### Shodan CLI
Command-line client for the Shodan search engine of internet-exposed devices and services. Requires a free API key.
```bash
pipx install shodan
shodan init <YOUR_API_KEY>
```
Website: https://cli.shodan.io

## Vulnerability Scanners

### Greenbone Vulnerability Management (OpenVAS)
Full-featured open-source network vulnerability scanner; OpenVAS is the scanning engine inside GVM.
```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install gvm
sudo gvm-setup           # note the generated admin password
sudo gvm-check-setup     # verify the installation
# Web UI: https://127.0.0.1:9392
```
Website: https://greenbone.github.io/docs

### Nessus
Industry-standard commercial vulnerability scanner; the free Nessus Essentials edition scans up to 16 IPs.
```bash
# Download the .deb for your distro from tenable.com, then:
sudo dpkg -i Nessus-<version>-debian10_amd64.deb
sudo systemctl start nessusd
# Web UI: https://localhost:8834
```
Website: https://www.tenable.com/products/nessus

### Nuclei
Template-based vulnerability scanner from ProjectDiscovery with a large community template library; fast and CI-friendly.
```bash
sudo apt install nuclei          # Kali
# or latest via Go (Go 1.21+ required):
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
nuclei -update-templates
```
Website: https://github.com/projectdiscovery/nuclei

### Nikto
Fast scanner for common web server misconfigurations, outdated software and default files.
```bash
sudo apt install nikto
```
Website: https://github.com/sullo/nikto

### Wapiti
Black-box web application vulnerability scanner (SQLi, XSS, file disclosure, command injection).
```bash
sudo apt install wapiti
# or
pipx install wapiti3
```
Website: https://wapiti-scanner.github.io

## Web Application Testing

### Burp Suite
The primary intercepting proxy and all-in-one web pentest platform. Community Edition is free; Professional is paid.
```bash
sudo apt install burpsuite       # Kali
# or download the installer from portswigger.net
```
Website: https://portswigger.net/burp

### OWASP ZAP
A fully open-source alternative to Burp with active and passive scanning and an automation framework.
```bash
sudo apt install zaproxy
# or
sudo snap install zaproxy --classic
```
Website: https://www.zaproxy.org

### sqlmap
Automatic detection and exploitation of SQL injection, with database takeover features.
```bash
sudo apt install sqlmap
# or
pipx install sqlmap
```
Website: https://sqlmap.org

### WPScan
Black-box WordPress security scanner for core, plugin and theme vulnerabilities and user enumeration.
```bash
sudo apt install wpscan
# or
gem install wpscan
```
Website: https://wpscan.com

### ffuf, gobuster, feroxbuster
Fast fuzzers and brute-forcers for directories, files, virtual hosts and subdomains.
```bash
sudo apt install ffuf gobuster feroxbuster
# or latest builds:
go install github.com/ffuf/ffuf/v2@latest
go install github.com/OJ/gobuster/v3@latest
```
Websites: https://github.com/ffuf/ffuf , https://github.com/OJ/gobuster , https://github.com/epi052/feroxbuster

### commix
Automated detection and exploitation of OS command injection flaws.
```bash
sudo apt install commix
# or
git clone https://github.com/commixproject/commix && cd commix && python3 commix.py
```
Website: https://github.com/commixproject/commix

## Exploitation Frameworks

### Metasploit Framework
The best-known exploitation and post-exploitation framework, with thousands of exploits, payloads and auxiliary modules.
```bash
# Official nightly installer (imports Rapid7 signing key, sets up deps):
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod 755 msfinstall
./msfinstall
msfconsole
```
Website: https://www.metasploit.com

### searchsploit (Exploit-DB)
Local command-line search over the Exploit-DB archive of public exploits and shellcode.
```bash
sudo apt install exploitdb
searchsploit apache 2.4
```
Website: https://www.exploit-db.com

### Sliver
A modern open-source Command and Control (C2) framework, a common open alternative to Cobalt Strike.
```bash
curl https://sliver.sh/install | sudo bash
# optional, for Windows DLL/shellcode payloads:
sudo apt install mingw-w64
```
Website: https://github.com/BishopFox/sliver

### Empire and Starkiller
Post-exploitation and C2 framework focused on Windows and PowerShell/Python agents; Starkiller is its web GUI.
```bash
sudo apt install powershell-empire starkiller   # Kali
```
Website: https://github.com/BC-SECURITY/Empire

### BeEF
The Browser Exploitation Framework; hooks browsers via XSS and drives client-side attacks.
```bash
sudo apt install beef-xss
```
Website: https://github.com/beefproject/beef

## Password and Hash Cracking

### John the Ripper
A versatile password and hash cracker; the community "jumbo" build supports hundreds of hash formats.
```bash
sudo apt install john
# Jumbo build from source:
git clone https://github.com/openwall/john && cd john/src && ./configure && make -s clean && make -sj4
```
Website: https://www.openwall.com/john

### Hashcat
The fastest GPU-accelerated hash cracker, supporting hundreds of algorithms and attack modes.
```bash
sudo apt install hashcat
```
Website: https://hashcat.net/hashcat

### Hydra
Fast online brute-forcer for many network services (SSH, RDP, HTTP, FTP, SMB and more).
```bash
sudo apt install hydra
```
Website: https://github.com/vanhauser-thc/thc-hydra

### Medusa and Ncrack
Alternative parallel online login brute-forcers; Ncrack integrates well with Nmap output.
```bash
sudo apt install medusa ncrack
```

### crunch and CeWL
Wordlist generators: crunch builds lists from character sets and patterns; CeWL crawls a website to harvest custom words.
```bash
sudo apt install crunch cewl
```

### hashid
Identifies the likely type of a given hash before you attack it.
```bash
sudo apt install hashid
# or
pipx install hashid
```
Website: https://github.com/psypanda/hashID

## Traffic Interception and Analysis

### Wireshark and tshark
The reference network protocol analyzer, with a GUI (Wireshark) and a CLI (tshark) for deep packet inspection.
```bash
sudo apt install wireshark tshark
# Allow non-root capture (log out/in afterwards):
sudo usermod -aG wireshark "$USER"
```
Website: https://www.wireshark.org

### tcpdump
The ubiquitous console packet capture tool, available on almost every Unix system.
```bash
sudo apt install tcpdump
```
Website: https://www.tcpdump.org

### Bettercap
A Swiss-army knife for network attacks and monitoring: MITM, sniffing, spoofing and BLE/Wi-Fi modules.
```bash
sudo apt install bettercap
```
Website: https://www.bettercap.org

### Ettercap
A classic tool for man-in-the-middle attacks and ARP spoofing on a LAN.
```bash
sudo apt install ettercap-graphical
```
Website: https://www.ettercap-project.org

### mitmproxy
Interactive intercepting proxy for HTTP/HTTPS with a TUI, web UI and Python scripting.
```bash
sudo apt install mitmproxy
# or
pipx install mitmproxy
```
Website: https://mitmproxy.org

### Responder
Captures credentials by poisoning LLMNR, NBT-NS and MDNS on a local network.
```bash
sudo apt install responder
# or
git clone https://github.com/lgandx/Responder
```
Website: https://github.com/lgandx/Responder

## Wireless Attacks

### Aircrack-ng
The classic Wi-Fi auditing suite: capture, packet injection and WPA/WEP key cracking.
```bash
sudo apt install aircrack-ng
```
Website: https://www.aircrack-ng.org

### Wifite
Automates Wi-Fi attacks on top of aircrack-ng, hashcat and reaver for hands-off auditing.
```bash
sudo apt install wifite
```
Website: https://github.com/derv82/wifite2

### Kismet
Wireless network detector, sniffer and monitoring platform for Wi-Fi, Bluetooth and SDR.
```bash
sudo apt install kismet
```
Website: https://www.kismetwireless.net

### hcxdumptool and hcxtools
Capture PMKID and handshakes and convert them into hash formats for hashcat.
```bash
sudo apt install hcxdumptool hcxtools
```
Website: https://github.com/ZerBea/hcxdumptool

### Reaver and Bully
Brute-force attacks against the Wi-Fi Protected Setup (WPS) PIN.
```bash
sudo apt install reaver bully
```

## Reverse Engineering and Binary Analysis

### Ghidra
The NSA's open-source software reverse engineering suite with a strong decompiler. Requires a JDK (17+/21).
```bash
sudo apt install ghidra          # Kali
# or download the release ZIP and run ghidraRun:
sudo apt install openjdk-21-jdk
# unzip ghidra_<version>_PUBLIC.zip && ./ghidraRun
```
Website: https://github.com/NationalSecurityAgency/ghidra

### radare2 and Cutter
An open reverse-engineering framework (radare2) with a Qt GUI (Cutter) for disassembly and analysis.
```bash
sudo apt install radare2 cutter
```
Websites: https://rada.re , https://cutter.re

### GDB with pwndbg or GEF
The GNU debugger enhanced with exploitation-friendly plugins.
```bash
sudo apt install gdb
# pwndbg:
git clone https://github.com/pwndbg/pwndbg && cd pwndbg && ./setup.sh
# or GEF:
bash -c "$(curl -fsSL https://gef.blah.cat/sh)"
```
Websites: https://github.com/pwndbg/pwndbg , https://github.com/hugsy/gef

### strace and ltrace
Trace system calls (strace) and library calls (ltrace) of a running process for dynamic analysis.
```bash
sudo apt install strace ltrace
```

## Digital Forensics

### Autopsy and The Sleuth Kit
Disk and file-system forensic analysis; The Sleuth Kit is the CLI engine, Autopsy the graphical front end.
```bash
sudo apt install sleuthkit autopsy
```
Website: https://www.sleuthkit.org

### Volatility 3
The standard framework for memory (RAM) forensics and malware analysis.
```bash
pipx install volatility3
# or from source in a venv:
git clone https://github.com/volatilityfoundation/volatility3 && cd volatility3
python3 -m venv venv && . venv/bin/activate && pip install -e ".[full]"
vol -h
```
Website: https://github.com/volatilityfoundation/volatility3

### binwalk
Analyze and extract the contents of firmware images and arbitrary binary blobs.
```bash
sudo apt install binwalk
```
Website: https://github.com/ReFirmLabs/binwalk

### foremost and scalpel
File carving and recovery based on headers, footers and internal data structures.
```bash
sudo apt install foremost scalpel
```

### bulk_extractor
Rapidly scans disk images and extracts artifacts (emails, URLs, credit-card numbers) without parsing the file system.
```bash
sudo apt install bulk-extractor
```
Website: https://github.com/simsong/bulk_extractor

## Post-Exploitation and Privilege Escalation

### PEASS-ng (LinPEAS / WinPEAS)
Scripts that enumerate local privilege-escalation paths on Linux (LinPEAS) and Windows (WinPEAS).
```bash
sudo apt install peass          # Kali packages the scripts
# or download directly:
curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -o linpeas.sh
```
Website: https://github.com/carlospolop/PEASS-ng

### Impacket
A collection of Python classes and ready-to-use scripts for network protocols (psexec, secretsdump, ntlmrelayx and more).
```bash
sudo apt install impacket-scripts   # Kali
# or
pipx install impacket
```
Website: https://github.com/fortra/impacket

### NetExec (formerly CrackMapExec)
Swiss-army knife for pentesting networks and Active Directory at scale (SMB, WinRM, LDAP, MSSQL).
```bash
sudo apt install netexec          # Kali
# or recommended pipx install:
sudo apt install pipx git
pipx ensurepath
pipx install git+https://github.com/Pennyw0rth/NetExec
```
Website: https://github.com/Pennyw0rth/NetExec

### BloodHound Community Edition
Graph-based analysis of Active Directory and Entra ID attack paths. CE runs via Docker Compose.
```bash
curl -L https://ghst.ly/getbhce -o docker-compose.yml
docker compose pull && docker compose up
# then open http://localhost:8080
```
Website: https://github.com/SpecterOps/BloodHound

### Mimikatz
Extracts plaintext passwords, hashes and Kerberos tickets from Windows memory. Windows tool; Kali ships the binaries for transfer.
```bash
sudo apt install mimikatz         # provides the Windows binaries under /usr/share
```
Website: https://github.com/gentilkiwi/mimikatz

## Defensive Tools (Blue Team)

### Suricata (IDS/IPS)
High-performance network intrusion detection and prevention with multi-threading and protocol analysis.
```bash
# Ubuntu (stable PPA):
sudo apt install software-properties-common
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt update && sudo apt install suricata
# Debian:
sudo apt install suricata
```
Website: https://suricata.io

### Snort (IDS/IPS)
The classic signature-based intrusion detection and prevention system.
```bash
sudo apt install snort            # Snort 2.x from distro repos
# Snort 3 is typically built from source: https://github.com/snort3/snort3
```
Website: https://www.snort.org

### Zeek (network security monitoring)
Formerly Bro; turns raw traffic into rich, structured logs of network activity for detection and hunting.
```bash
# Debian 12 example (Zeek OBS repo):
echo 'deb http://download.opensuse.org/repositories/security:/zeek/Debian_12/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list
curl -fsSL https://download.opensuse.org/repositories/security:zeek/Debian_12/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
sudo apt update && sudo apt install zeek
```
Website: https://zeek.org

### Wazuh (HIDS / XDR / SIEM)
Open-source security platform combining host intrusion detection, log analysis, FIM and SIEM/XDR dashboards.
```bash
# All-in-one central components on a single host:
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```
Website: https://wazuh.com

### OSSEC
A lightweight host-based intrusion detection system with log analysis, file integrity and rootkit checks.
```bash
# Add the Atomicorp OSSEC repo, then:
sudo apt install ossec-hids-server
# or build from source: https://github.com/ossec/ossec-hids
```
Website: https://www.ossec.net

### CrowdSec
A modern collaborative IPS that parses logs to detect attacks and shares crowd-sourced IP reputation.
```bash
curl -s https://install.crowdsec.net | sudo sh
sudo apt install crowdsec
# firewall bouncer (nftables default on Debian 12 / Ubuntu 24.04):
sudo apt install crowdsec-firewall-bouncer-nftables
```
Website: https://www.crowdsec.net

### fail2ban
Scans service logs and bans IPs showing malicious signs (repeated failed logins) via firewall rules.
```bash
sudo apt install fail2ban
```
Website: https://github.com/fail2ban/fail2ban

### Lynis
Security auditing and hardening tool for Linux/Unix that produces prioritized recommendations.
```bash
sudo apt install lynis
sudo lynis audit system
```
Website: https://cisofy.com/lynis

### OpenSCAP
Compliance and vulnerability assessment against SCAP content such as CIS and DISA STIG baselines.
```bash
sudo apt install openscap-scanner openscap-utils ssg-debderived
```
Website: https://www.open-scap.org

### AIDE
Advanced Intrusion Detection Environment; builds a baseline database of file attributes to detect tampering.
```bash
sudo apt install aide
sudo aideinit
```
Website: https://aide.github.io

### rkhunter and chkrootkit
Scanners that look for rootkits, backdoors and suspicious local modifications.
```bash
sudo apt install rkhunter chkrootkit
```

### ClamAV
Open-source antivirus engine for scanning files, mail gateways and endpoints.
```bash
sudo apt install clamav clamav-daemon
sudo freshclam        # update signatures
```
Website: https://www.clamav.net

### Elastic Stack (Elasticsearch, Logstash, Kibana)
The most widely used open logging and SIEM foundation; Elastic Security adds detection rules and dashboards.
```bash
# Add the Elastic APT repo:
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install elasticsearch kibana logstash
```
Website: https://www.elastic.co/security

### Graylog
Centralized log management and analysis with alerting and dashboards, built on OpenSearch and MongoDB.
```bash
# See the official install guide; example package step:
wget https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.deb
sudo dpkg -i graylog-6.1-repository_latest.deb
sudo apt update && sudo apt install graylog-server
```
Website: https://graylog.org

## Security Distributions

Instead of installing tools one by one, you can use a purpose-built distribution that ships them preconfigured.

- Kali Linux - the most popular penetration testing distribution, thousands of preinstalled tools; https://www.kali.org ;
- Parrot Security OS - a lighter alternative to Kali with a strong privacy focus; https://www.parrotsec.org ;
- BlackArch - a huge tool collection layered on top of Arch Linux; https://blackarch.org ;
- Security Onion - a ready-made blue-team distribution for monitoring and detection (Suricata, Zeek, Elastic, Wazuh); https://securityonionsolutions.com ;
- REMnux - a specialized toolkit for malware analysis and reverse engineering; https://remnux.org .

## Bulk Installation on Kali and Parrot

On Kali you can install grouped tool sets with metapackages instead of individual packages.
```bash
sudo apt update
sudo apt install kali-linux-large      # a broad set of common tools
# other useful metapackages:
sudo apt install kali-tools-web kali-tools-wireless kali-tools-passwords kali-tools-forensics
```

On a plain Debian or Ubuntu system, many core tools are one command away.
```bash
sudo apt update
sudo apt install nmap john hydra hashcat wireshark tcpdump aircrack-ng \
  sqlmap nikto lynis clamav suricata fail2ban rkhunter chkrootkit aide
```

Tools not packaged in the distro are typically installed through `pipx` (Python), `go install` (Go), Cargo (Rust), Docker, or a vendor installer, as noted in each section above.

## Sources

- [Metasploit Nightly Installers](https://docs.metasploit.com/docs/using-metasploit/getting-started/nightly-installers.html)
- [Nuclei installation docs](https://docs.projectdiscovery.io/opensource/nuclei/install)
- [Sliver C2 (BishopFox)](https://github.com/BishopFox/sliver)
- [BloodHound CE with Docker Compose](https://support.bloodhoundenterprise.io/hc/en-us/articles/17468450058267-Install-BloodHound-Community-Edition-with-Docker-Compose)
- [NetExec installation (Unix)](https://www.netexec.wiki/getting-started/installation/installation-on-unix)
- [Wazuh Quickstart](https://documentation.wazuh.com/current/quickstart.html)
- [Greenbone / GVM on Kali](https://greenbone.github.io/docs/latest/22.4/kali/index.html)
- [Volatility 3 (GitHub)](https://github.com/volatilityfoundation/volatility3)
- [Suricata Ubuntu install](https://docs.suricata.io/en/latest/install/ubuntu.html)
- [CrowdSec Linux install](https://docs.crowdsec.net/u/getting_started/installation/linux/)
- [Kali Linux Tools index](https://www.kali.org/tools/)

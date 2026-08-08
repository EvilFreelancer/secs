# Metasploitable 3 - target VM basics

Metasploitable 3 is a deliberately vulnerable virtual machine published by
Rapid7 for practising exploitation and validating tooling. Unlike
Metasploitable 2 it is not shipped as a ready-made disk image: Rapid7 publishes
it as Vagrant boxes and expects you to build/run it with Vagrant. In this repo
we bypass Vagrant - the box is downloaded, its VMDK is converted to qcow2 and
booted directly with QEMU/KVM.

Two variants exist:

- `ub1404` - Ubuntu 14.04 Linux target (the one we ship by default);
- `win2k8` - Windows Server 2008 R2 target (larger, optional).

Use these targets only on an isolated host you are authorized to test. The box
is intentionally insecure; do not expose it to a real network.

## Getting it running (this repo)

Everything is driven by `make` from the repo root; the disk lands under `dist/`.

```bash
# 1. download the box and convert it to dist/metasploitable3-ub1404.qcow2
make vm-download

# 2. boot it under QEMU (isolated user-mode networking + VNC console)
make vm-run
```

`make vm-run` boots in the background and writes `dist/ms3-<variant>.run.log`;
`make vm-run-fg` runs it in the foreground instead. Useful knobs (override on the
command line, e.g. `make vm-run RAM_MB=8192`):

- `VARIANT=ub1404|win2k8` picks the target (default `ub1404`);
- `RAM_MB` and `CPUS` size the guest (defaults 4096 MiB / 2 vCPU; the Java
  services like ElasticSearch are happier with more);
- `DISPLAY_MODE=vnc|none|sdl|gtk` picks the console; VNC listens on
  `127.0.0.1:5900` (`VNC=127.0.0.1:1` moves it to 5901);
- `SNAPSHOT=1` throws away all disk writes on exit (disposable session);
- `NET_MODE=user|tap|none` selects networking (see below).

`make vm-status` shows whether it is running and tails the launch log,
`make vm-ssh` opens a shell in the guest (vagrant/vagrant), `make vm-stop` powers
it off, and `make vm-remove` deletes the box and disk image.

The console is reached over VNC, for example `vncviewer 127.0.0.1:5900`. Log in
there with the credentials below, or reach the services over the host port
forwards.

## Credentials

The primary account is the same on both variants:

- `vagrant` / `vagrant` - and it has passwordless `sudo`, so `sudo -i` gives an
  instant root shell. This is the intended "you already own the box" login used
  for inspection and for resetting services.

The Linux target also seeds a set of Star Wars themed accounts with weak
passwords. They exist so you can practise password cracking (hydra against SSH,
or john/hashcat against a dumped `/etc/shadow`). Known pairs include:

| User | Password |
| --- | --- |
| `vagrant` | `vagrant` |
| `boba_fett` | `mandalorian1` |
| `chewbacca` | `rwaaaaawr5` |
| `greedo` | `hanShotFirst!` |
| `kylo_ren` | `daddy_issues1` |

There are roughly fifteen such accounts in total; the remaining passwords are
meant to be recovered by cracking rather than looked up.

Service-level credentials worth knowing:

- MySQL: `root` with an empty password;
- SNMP: community string `public`;
- On the `win2k8` variant several app consoles use fixed logins, e.g. GlassFish
  `admin`/`sploit`, Tomcat/Struts `sploit`/`sploit`, ManageEngine `admin`/`admin`.

## Services and ports (ub1404)

The documented Linux services and the host port our run script forwards them to.
QEMU user-mode forwarding always listens on the host side, so a bare TCP connect
succeeds even when the guest service is not up yet; test at layer 7 (read the
banner, send an HTTP request) to know a service is really ready.

| Guest port | Service | Note / known weakness | Host forward |
| --- | --- | --- | --- |
| 21 | ProFTPD 1.3.5 | mod_copy RCE (CVE-2015-3306) | 127.0.0.1:2121 |
| 22 | OpenSSH 6.6.1p1 | weak user passwords (crack them) | 127.0.0.1:2222 |
| 80 | Apache | Drupal, phpMyAdmin, `payroll_app` (SQLi), chat | 127.0.0.1:8000 |
| 161/udp | SNMP | community `public` | not forwarded (UDP) |
| 631 | CUPS 1.7.2 | CUPS web admin / XSS | not forwarded by default |
| 1617 | JMX | Java JMX RCE (CVE-2015-2342) | not in default set |
| 3000 | Ruby on Rails | app endpoints | 127.0.0.1:3000 |
| 3306 | MySQL | `root` / empty password | 127.0.0.1:13306 |
| 3500 | WEBrick (Ruby) | app endpoints | 127.0.0.1:3500 |
| 6697 | UnrealIRCd 3.2.8.1 | backdoor (CVE-2010-2075) | 127.0.0.1:6697 |
| 8080 | Jetty 8.1.7 | app server | 127.0.0.1:8080 |
| 8989 | custom_http | `five_of_diamonds` flag, behind knockd | not forwarded |
| 9200 | ElasticSearch | script RCE (CVE-2014-3120) | 127.0.0.1:9200 |

The run script forwards a few extra host ports (`8181`, `8282`, `8383`, `8484`,
`8585`) that belong to the `win2k8` variant, so the same script works for both
targets; on `ub1404` those simply stay closed. If a host port is already in use
(commonly `8000`) the script skips just that one forward and prints a warning
instead of refusing to start.

## Reaching the box from the host

With the default `NET_MODE=user`, attack the guest through the forwarded
`127.0.0.1:<host-port>` above. Examples:

```bash
# HTTP app on guest :8080
curl -i http://127.0.0.1:8080/

# MySQL (root, no password) via the guest
mysql -h 127.0.0.1 -P 13306 -u root

# SSH - the guest runs OpenSSH 6.6, so a modern client needs legacy algorithms
ssh -p 2222 \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o PubkeyAcceptedKeyTypes=+ssh-rsa \
    -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    vagrant@127.0.0.1
```

Two limitations of user-mode networking to keep in mind:

- exploits that make the target connect back (reverse shells) reach the host at
  `10.0.2.2`; set your Metasploit `LHOST` to that from the guest's point of view;
- port knocking and any multi-port trick do not survive NAT unless the knock
  ports are forwarded too. For a full pentest lab, run with `NET_MODE=tap`
  against an isolated bridge so the target keeps its own IP and every port.

## Confirming that an exploit actually worked

Getting a service to error is not proof. Establish one of these, strongest last:

1. Command execution / shell. Run a few identifying commands and keep the
   output as evidence:

   ```bash
   id                 # uid=0(root) after a successful privesc
   hostname           # metasploitable3-ub1404
   uname -a
   cat /etc/passwd    # shows the Star Wars accounts
   ```

2. Recovered credentials. Cracking a weak SSH account and logging in as that
   user is a concrete win; dumping and cracking `/etc/shadow` proves root-level
   file access.

3. A captured flag. The box hides a themed deck of playing-card "flags" that
   double as proof markers - reaching one means you got to that location with
   the privilege it required. On `win2k8` there are 15 flags scattered across
   the filesystem, databases and services, retrieved with a mix of techniques:
   plain files, NTFS alternate data streams, steganography in media files,
   base64 in MySQL tables, strings pulled from PE binaries, and PNGs whose magic
   bytes were corrupted (`MSF` written over the header - fix it back to a valid
   PNG signature to view the card). The Linux box uses the same theme; for
   example the `five_of_diamonds` flag sits behind a `custom_http` service on
   port 8989 that is firewalled by knockd until you send the right knock.

4. A Metasploit session. An open `meterpreter`/`shell` session in
   `sessions -l`, ideally elevated, is the cleanest end-to-end confirmation.

### A couple of concrete first exploits

```bash
# Map the target first
nmap -sV -p- 127.0.0.1            # against the forwards, or the guest IP in tap mode

# ProFTPD 1.3.5 mod_copy (CVE-2015-3306) and UnrealIRCd 3.2.8.1 backdoor
# both have ready Metasploit modules:
#   use exploit/unix/ftp/proftpd_modcopy_exec
#   use exploit/unix/irc/unreal_ircd_3281_backdoor
# ElasticSearch CVE-2014-3120:
#   use exploit/multi/elasticsearch/script_mvel_rce
```

After a session opens, prove it with `getuid` / `sysinfo` (Meterpreter) or the
`id`/`hostname` block above.

## Port knocking (knockd)

The Linux target ships `knockd` as a training element. It drops traffic to the
`custom_http` flag port (8989) until the correct knock sequence hits the guest,
then temporarily opens it. The exact sequence lives in `/etc/knockd.conf` on the
box - read it once you have any shell (`vagrant` login works), or discover it by
observing/brute-forcing. Because the knock ports are not forwarded by our
user-mode setup, practise knocking in `NET_MODE=tap` mode where the guest is
directly reachable.

## Resetting the target

- `make vm-run SNAPSHOT=1` boots a throwaway session and discards every change on
  exit - good for a clean slate each run.
- For a persistent-but-revertable disk, take a qcow2 snapshot before testing:

  ```bash
  qemu-img snapshot -c clean dist/metasploitable3-ub1404.qcow2   # create
  qemu-img snapshot -a clean dist/metasploitable3-ub1404.qcow2   # revert
  ```

## Sources

- [rapid7/metasploitable3 README](https://github.com/rapid7/metasploitable3/blob/master/README.md)
- [rapid7/metasploitable3 Wiki - Vulnerabilities](https://github.com/rapid7/metasploitable3/wiki/Vulnerabilities)
- [DeepWiki - Ubuntu VM](https://deepwiki.com/rapid7/metasploitable3/3.2-ubuntu-vm)
- [syselement - Metasploitable3 notes](https://blog.syselement.com/home/home-lab/redteam/metasploitable3)
- [wjmccann - Metasploitable3 and Flags](https://wjmccann.github.io/blog/2018/04/07/Metasploitable3)

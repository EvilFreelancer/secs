---
name: hunting-web-backdoors
description: Hunt for planted webshells and server-side backdoors on web infrastructure — recently-changed files in web roots, dangerous-callable content signatures (eval/system/base64), YARA scans, web-server log anomalies (POST to static-looking paths, rare user agents), and web-server processes spawning shells. Use when a web server is suspect or a post-exploitation foothold is likely, not when testing for the vulnerability that would allow one. A webshell hides in plain sight as a valid file; find it by change, content, and behavior.
verified: 2026-08-08
---

# Hunting Web Backdoors

A webshell is a legitimate-looking file in a place that serves code, dropped
after an attacker got write access, that turns an HTTP request into command
execution. It is among the most durable footholds on internet-facing systems and
among the easiest to overlook, because it *is* a valid `.php`/`.aspx`/`.jsp` file
sitting in a directory full of valid files. You cannot find it by asking "is this
malware" one file at a time; you find it by three orthogonal lenses — what
*changed*, what the content can *do*, and how the file *behaves* when requested —
and by trusting the overlap.

Confirm the host is in scope per [AGENTS.md](../../AGENTS.md). Preserve before you
poke: on a live suspect server, capture the web root and logs (and memory, if
warranted) before touching files, so timestamps and the shell itself are not
contaminated by your own activity.

## When to Use

- A web server is suspected of harboring a planted shell or backdoor
- Sweeping web roots after a confirmed or suspected exploitation
- Confirming or refuting a hunt lead or alert pointing at web infrastructure
- Establishing whether a known web vulnerability was actually used to plant a shell

## When NOT to Use

- **Testing for the upload/RCE flaw itself** — use `testing-web-applications`; this skill hunts the *result*, that one finds the *hole*
- **Deep analysis of a shell you already found** — hand the sample to `analyzing-malware`
- **Generic hypothesis-driven hunting across all telemetry** — use `hunting-threats`; this is the web-root-specific procedure
- **On-host artifacts beyond the web root** (registry, services) — use `investigating-windows-endpoints`, or `responding-to-incidents` for a Linux host
- **Confirmed active intrusion** — switch to `responding-to-incidents`

## Three Lenses (trust the overlap)

**1. Change — what appeared or was modified in the web root.** New or recently
modified files in served directories, especially `upload/`, `images/`, `tmp/`,
and cache paths that should never contain executable content:

```bash
# Recently modified server-executable files under the web root
find /var/www -type f \( -name '*.php' -o -name '*.aspx' -o -name '*.jsp' \
  -o -name '*.ashx' \) -mtime -30 -printf '%TY-%Tm-%Td %p\n' | sort
# Executable content where only static assets belong
find /var/www/uploads -type f -name '*.php'
```

Corroborate timestamps against `$MFT`/`$UsnJrnl` (Windows) or inode change time
(`stat`), because `mtime` is trivially forged.

**2. Content — what the file can do.** Webshells cluster around a small set of
dangerous callables and obfuscation. Grep first, then YARA for known families:

```bash
grep -rInE 'eval\(|assert\(|system\(|exec\(|passthru\(|shell_exec\(|popen\(|base64_decode\(|gzinflate\(|str_rot13\(|\$_(GET|POST|REQUEST|COOKIE)\[' /var/www
yara -r webshells.yar /var/www        # e.g. the neo23x0/signature-base rules
```

High-signal patterns: input superglobal passed straight into a callable
(`system($_GET[...])`), long base64/gzinflate blobs, and one-liner "god shells".
Watch for benign look-alikes (templating, sanitizers) — content is a lead, not a
verdict.

**3. Behavior — how it is reached and what it spawns.** Web-server access logs and
process lineage betray shells that survive a content grep:

- POST requests to files that should only be GET static assets; requests to a
  file no page links to; a single client IP hitting one odd path repeatedly.
- Rare or scripted user agents, and 200s on paths that 404 for everyone else.
- The web-server user (`www-data`, `IIS APPPOOL`) spawning `cmd`, `powershell`,
  `/bin/sh`, `whoami`, or `nc` — a near-certain execution tell in EDR/Sysmon.

```bash
awk '$6 ~ /POST/ {print $7}' /var/log/apache2/access.log | sort | uniq -c | sort -n | tail
```

## Rationalizations to Reject

- *"No AV hit, so the server's clean."* Bespoke and heavily-obfuscated shells evade signatures. Hunt by change and behavior, not just content.
- *"It's a valid PHP file, so it's fine."* Every webshell is a valid file. Validity is the disguise, not the exoneration.
- *"The timestamp is old, ignore it."* `mtime` is attacker-controllable. Corroborate with `$MFT`/USN/ctime and log evidence.
- *"One grep pass covered it."* A grep misses novel obfuscation; pair it with behavior (logs, process lineage) and change detection.
- *"Found one, done."* Attackers plant several and re-drop after cleanup. Sweep the whole root and check for re-appearance.

## Deliverable

```markdown
# Web Backdoor Hunt <WSH-###>   Date: <UTC>   Analyst: <name>
Host / web root / scope: <server, path, in-scope confirmation>
Lenses run:       change / content / behavior — what each surfaced
Findings:         <file path, family/signature, first-seen, how reached>
Evidence:         <log lines, YARA hit, process-spawn event — timestamped>
Entry vector:     <upload/RCE flaw if identifiable — hand to testing-web-applications>
Scope of access:  <what the shell could/did do; other artifacts found>
Conclusion:       backdoored / not / could-not-determine  Confidence: <>
Handoffs:         <sample to analyzing-malware; incident to responding-to-incidents>
```

Save the web root snapshot, logs, and YARA output as
`{tool}_{host}_{YYYYMMDD_HHMMSS}.{ext}` and log findings via
`maintaining-engagement-state`. ATT&CK: T1505.003 (Server Software Component:
Web Shell), with T1190 as the usual entry — re-verify before citing.

## References

- `testing-web-applications` — the upload/RCE flaw that let a shell be planted
- `analyzing-malware` — deep analysis of a recovered shell
- `hunting-threats` — the broader hypothesis-driven hunt this specializes
- `responding-to-incidents`, `investigating-windows-endpoints` — the escalation once a shell is confirmed
- `writing-yara-rules`, `engineering-detections` — turning a found family into detection

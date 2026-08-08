---
name: testing-ics-ot-protocols
description: Safely assess industrial control system and OT networks and their protocols (Modbus, DNP3, S7comm, EtherNet/IP-CIP, OPC UA, IEC 60870-5-104, BACnet) using a passive-first, safety-gated methodology aligned to the Purdue model and IEC 62443. Use when mapping an OT network, evaluating IT/OT segmentation and zone/conduit rules, or inventorying industrial assets — where a probe that is routine on IT can crash a PLC or trip a safety system. Availability and physical safety outrank data completeness, always.
verified: 2026-08-08
---

# Testing ICS / OT Protocols

In OT, a scan is not free. The same TCP connect or version probe that IT devices
shrug off can hang a legacy PLC, disrupt a safety instrumented system (SIS), or
cause physical process upset — and the cost is measured in downtime, damaged
equipment, or human safety, not a reset service. So the default is to *listen*,
not to *ask*, and to *ask* only after a change-management approval, a maintenance
window, and lab validation against the exact device model. Completeness of
vulnerability data is subordinate to keeping the process running and people safe.

This skill is passive-first and defensive by default. Active interaction with
Level 0-1 field devices and any SIS is out of bounds without a documented safety
review and the customer's safety officer in the loop — this is a hard rule under
[AGENTS.md](../../AGENTS.md), not a preference. Confirm the exact in-scope
subnets, asset list, and blackout windows before any capture begins.

## When to Use

- Mapping an OT/ICS network and inventorying industrial assets non-disruptively
- Evaluating IT/OT convergence: segmentation, zone/conduit rules, DMZ, data diodes
- Reviewing industrial-protocol exposure (unauthenticated Modbus writes, cleartext OPC UA)
- Baselining OT traffic so anomalies become detectable later
- Reviewing firewall rules between Purdue levels against an IEC 62443 model

## When NOT to Use

- **IT service enumeration** (SMB/SSH/RDP/HTTP on Level 3.5+ business hosts) — use `enumerating-network-services`; those are IT assets even when they sit near OT
- **Working through a captured OT pcap in depth** — use `analyzing-network-traffic`; this skill decides *what to capture and how safely*, that one dissects it
- **Building detections for OT traffic** — use `engineering-detections` and `writing-sigma-rules`
- **A suspected compromise or safety event in the plant** — stop and use `responding-to-incidents`; escalate to the safety officer immediately
- **Any active probing of PLCs, RTUs, or SIS** without a signed safety review — refuse and escalate; there is no non-destructive default that makes this safe on live field devices

## Safety Tiers (choose the lowest that answers the question)

| Tier | Action | Risk | Gate | Noise |
| --- | --- | --- | --- | --- |
| 1 | Passive capture on SPAN/TAP; protocol DPI; fingerprinting | None | In-scope confirmation | QUIET |
| 2 | Native protocol read (Modbus FC43 device ID, S7 SZL read, CIP Identity) | Minimal | Change approval + maintenance window + lab-validated | MODERATE |
| 3 | OT-safe active scan, Level 2+ only, SIS excluded | Low–moderate | Written approval + rollback + safety officer | LOUD |

Never run Tier 2/3 against Levels 0-1. Never use default Nessus/Nmap aggressive
profiles on OT. Never fuzz an industrial protocol on a live system. Never write
PLC logic or firmware. If a device stops responding, stop and invoke the
rollback procedure — do not "try one more thing."

## Passive First (Tier 1 — QUIET)

Get a mirror port from the plant network team; do not insert an inline tap on a
live process link yourself. Then observe:

```bash
# Baseline capture on the SPAN interface — bounded, no injection
tcpdump -i span0 -w ot_baseline_$(date -u +%Y%m%d_%H%M%S).pcap -G 3600 -W 24

# Industrial-protocol breakdown, read-only
tshark -r ot_baseline_*.pcap -q -z io,phs          # protocol hierarchy
tshark -r ot_baseline_*.pcap -Y 'modbus'  -T fields -e ip.src -e ip.dst -e modbus.func_code
tshark -r ot_baseline_*.pcap -Y 's7comm'  -T fields -e ip.src -e ip.dst -e s7comm.param.func
```

Passive OT platforms (Nozomi Guardian, Dragos Platform, Claroty xDome) and
Grassmarlin do asset discovery and vulnerability inference from mirrored traffic
alone — prefer them over any active probe. From the baseline you can already find
unauthenticated protocols, flat topology, cross-zone flows, and cleartext OPC UA
without sending a single packet to a controller.

## Industrial Protocols and Ports

| Protocol | Port | Watch for |
| --- | --- | --- |
| Modbus/TCP | 502 | Unauthenticated reads/writes (FC 5/6/15/16), writes from non-engineering hosts |
| S7comm / S7comm+ | 102 | Stop/start CPU, program upload/download from unexpected sources |
| EtherNet/IP + CIP | 44818, 2222 | ForwardOpen to controllers, identity enumeration |
| OPC UA | 4840 | `SecurityMode=None`, anonymous sessions, cleartext |
| DNP3 | 20000 | Unsolicited responses, function-code anomalies, no secure authentication |
| IEC 60870-5-104 | 2404 | Command frames (C_SC/C_DC) from outside the control zone |
| BACnet | 47808/udp | Who-Is/I-Am sweeps, writable objects |
| HART-IP | 5094 | Field-device access over IP |

## Purdue Model and Zone/Conduit Review (Tier 1 analysis)

Place every observed asset in a Purdue level and test the flows against an
IEC 62443 zone/conduit model. Active permission rises with the level:

- **Level 0-1** (sensors, actuators, PLCs, RTUs, SIS) — passive only, no exceptions
- **Level 2** (HMIs, engineering workstations) — limited Tier 2 with approval
- **Level 3** (historians, OPC/app servers) — Tier 3 permitted with approval
- **Level 3.5** (OT DMZ, data diodes, jump hosts) / **Level 4** (enterprise IT) — standard IT testing applies

High-severity flows to hunt for in the baseline: any Level 4 to Level 0-3 path
that bypasses the DMZ, any internet-to-OT reachability, Level 3 to Level 0-1
direct control traffic, and unauthenticated write function codes crossing a zone
boundary. Cross-reference findings to IEC 62443 and NIST SP 800-82r3, and cite
real control IDs only.

## Rationalizations to Reject

- *"A quick Nmap won't hurt one PLC."* Legacy controllers have crashed on a single unexpected packet. "Quick" is how outages start in OT.
- *"The vendor says it's robust."* Get that in writing tied to the exact firmware, and still prefer passive. Warranty and safety are the operator's to certify, not yours to assume.
- *"Passive missed some assets, so I'll actively sweep."* Name the gap and request a Tier 2 window for those specific devices — do not broaden to an active sweep.
- *"The SIS is in scope per the ROE."* Safety systems still require a documented safety review and the safety officer present. Scope on paper does not override the safety gate.
- *"It stopped responding but came back."* That is a reportable near-miss. Stop, document, and escalate before continuing.

## Deliverable

```markdown
# Finding <OT-###>           Date: <UTC>   Assessor: <name>
Title:            <e.g. Unauthenticated Modbus writes cross L3->L1 boundary>
Asset / zone:     <device, IP, Purdue level, protocol>
Method / tier:    <Tier 1 passive / Tier 2 read — window + approver>
Standard:         <IEC 62443 SR / NIST SP 800-82r3 control>   ATT&CK (ICS): <T####>
Severity:         <CVSS + process-safety impact>
Evidence:         <pcap slice, asset-list export — timestamped, read-only>
Impact:           <process/safety consequence, not just data>
Remediation:      <segmentation, auth, monitoring — named owner + window>
Detection:        <OT-monitoring signal that would flag it>
```

Save captures as `{tool}_{target}_{YYYYMMDD_HHMMSS}.pcap` and log assets and
findings via `maintaining-engagement-state`. ATT&CK for ICS IDs relevant here
(T0842 Network Sniffing, T0846 Remote System Discovery, T0855 Unauthorized
Command Message, T0836 Modify Parameter, T0816 Device Restart/Shutdown) —
re-verify against the current ATT&CK for ICS release before citing.

## Reading External Sources

Fetch vendor advisories, CISA ICS advisories, and standards summaries as
Markdown:

```bash
curl -sL "https://defuddle.md/<url>"      # scheme in the path is optional
```

Never route **plant/engagement hosts** or OT device addresses through it — the
request leaves your machine to a third party, and OT infrastructure must not be
exposed to external services. Fetch JSON/API responses raw.

## References

- `enumerating-network-services` — IT hosts at Level 3.5/4 around the OT network
- `analyzing-network-traffic` — deep dissection of the captures this skill collects
- `responding-to-incidents` — the handoff when a compromise or safety event is suspected
- IEC 62443 (zones/conduits), NIST SP 800-82r3 (OT security), MITRE ATT&CK for ICS
- Nozomi Guardian, Dragos, Claroty xDome, Grassmarlin, Wireshark/tshark, tcpdump

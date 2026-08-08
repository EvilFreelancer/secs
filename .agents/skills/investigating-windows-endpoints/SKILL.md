---
name: investigating-windows-endpoints
description: Investigate a live or triaged Windows host for intrusion evidence using disk and registry artifacts — MFT/$UsnJrnl, registry hives, AmCache/ShimCache, Prefetch, LNK/JumpLists, ShellBags, and event logs — parsed with the Eric Zimmerman suite and consolidated into a timeline. Use when a Windows endpoint is suspect and you need execution, persistence, and access evidence from on-disk artifacts. Preserve order of volatility first; a running command is a write to the evidence.
verified: 2026-08-08
---

# Investigating Windows Endpoints

A Windows host records far more about what ran on it than most operators expect —
in the MFT, the registry, execution caches, and shell history — and most of it
survives a reboot and a deleted file. The investigator's job is to read those
artifacts in the right order, correlate them into one timeline, and separate the
adversary's activity from the machine's normal churn. The trap is contamination:
every interactive command you run on a live host writes new artifacts and can
overwrite the very evidence you came for. Preserve before you poke.

Order of volatility governs the first move: if the host is live and the memory is
worth having, capture RAM before disk (hand it to `analyzing-memory-images`).
Record what you touch and when, so your own footprint is separable from the
adversary's in the timeline. Confirm the host is in scope per
[AGENTS.md](../../AGENTS.md) before acquisition.

## When to Use

- A Windows endpoint is suspected of compromise and needs disk/registry triage
- Reconstructing what executed, when, and by whom from on-disk artifacts
- Finding persistence, lateral-movement, and data-staging evidence on a host
- Confirming or refuting a hunt lead or an alert on a specific machine
- Producing a host timeline for an incident

## When NOT to Use

- **A memory image / RAM capture** — use `analyzing-memory-images`; injected code and live process state live there, not on disk
- **A specific suspicious binary** — hand it to `analyzing-malware`
- **Network evidence** — use `analyzing-network-traffic`
- **The compromise is in the cloud control plane** — use `investigating-aws-incidents`, `investigating-azure-incidents`, or `investigating-gcp-incidents`
- **Proactive search with no specific host in hand** — use `hunting-threats`
- **Running the whole incident** (scoping, containment, comms) — use `responding-to-incidents`; this skill is the host-artifact deep dive within it

## Preserve First (order of volatility)

1. If live and warranted: memory, then active processes/connections/services — before disk changes them.
2. Triage-image the artifacts rather than working the live filesystem. KAPE collects the standard set fast:

```powershell
kape.exe --tsource C: --tdest E:\Case\Collection `
  --target KapeTriage --mdest E:\Case\Processed --module !EZParser
```

Hash the collection, work on the copy, and keep the original read-only.

## Read the Artifacts (execution, then access, then persistence)

Parse with the Eric Zimmerman (EZ) suite; every tool emits CSV for Timeline
Explorer.

| Question | Artifact | Tool |
| --- | --- | --- |
| What ran, how often, when | Prefetch (`.pf`), AmCache, ShimCache | PECmd, AmcacheParser, AppCompatCacheParser |
| File-system truth + deletions | `$MFT`, `$UsnJrnl:$J` | MFTECmd |
| User/system config, USB, services | Registry (NTUSER, SYSTEM, SOFTWARE, SAM) | RECmd, Registry Explorer |
| What files/dirs a user touched | LNK, JumpLists, ShellBags | LECmd, JLECmd, SBECmd |
| Logons, service installs, task creation | Event logs (`.evtx`) | EvtxECmd |

High-value event IDs: 4624/4625 (logon success/failure) and logon **type** (10 =
RDP, 3 = network), 4672 (admin logon), 4688 (process creation, if audited),
7045 (service install), 4697 (service install, Security), 4698 (scheduled task),
1102 (Security log cleared — an eviction/defense-evasion tell).

Persistence lives where execution meets autostart — cross-reference these against
the offensive playbook in `establishing-persistence`:

- Run/RunOnce keys (NTUSER, SOFTWARE), Startup folder
- Services (`SYSTEM\CurrentControlSet\Services`) and scheduled tasks (`\Windows\System32\Tasks`)
- WMI event subscriptions, COM hijacks (`HKCR\CLSID\...\InprocServer32`), IFEO, AppInit_DLLs, Winlogon

## Build the Timeline

The single most valuable output is a consolidated, cross-artifact timeline.
Correlate: a Prefetch execution of a suspicious binary, its AmCache SHA-1, the
LNK/JumpList that opened its dropper, the 4688/7045 that spawned it, and the
`$MFT`/`$J` record of its creation and deletion. Watch for **timestomping** —
compare `$SI` and `$FN` timestamps in MFTECmd output; a mismatch is manipulation.
Anchor everything in UTC.

## Rationalizations to Reject

- *"I'll just poke around the live box."* Every command writes Prefetch, registry, and MFT entries — you are corrupting evidence and possibly alerting the operator. Image, then analyze.
- *"The file is deleted, so it's gone."* The `$MFT` and `$UsnJrnl` remember creation, rename, and deletion long after. Deleted is not absent.
- *"The timestamps clear it."* Timestamps are attacker-controllable. Check `$SI` vs `$FN`; trust corroboration across artifacts, not a single time.
- *"No malware on disk, so it's clean."* Fileless and LOLBin activity leaves execution and registry traces, not binaries. Read Prefetch, ShimCache, and the logs.
- *"AV/EDR would have caught it."* You are investigating precisely because it did not. Assume nothing from the absence of an alert.

## Deliverable

```markdown
# Host Investigation <WIN-###>   Date: <UTC>   Analyst: <name>
Host / scope:     <hostname, role, in-scope confirmation>
Acquisition:      <live/triage/full image — what was captured, hashes>
Findings:         <execution / persistence / lateral / staging — each with artifact + timestamp>
Timeline:         <UTC, cross-artifact, first-to-last observed adversary action>
Attribution note: <your own actions on the host, so they are separable>
Conclusion:       compromised / not / could-not-determine  Confidence: <>
Handoffs:         <memory image, sample, network, cloud control plane>
```

Save parsed CSVs and the collection as `{tool}_{host}_{YYYYMMDD_HHMMSS}.{ext}`
and log findings via `maintaining-engagement-state`. ATT&CK IDs commonly evidenced
(T1059 Command/Scripting, T1070 Indicator Removal, T1074 Data Staged, T1547
Boot/Logon Autostart, T1053.005 Scheduled Task) — re-verify before citing.

## References

- `responding-to-incidents` — the incident this host analysis feeds
- `analyzing-memory-images` — RAM capture that must precede disk on a live host
- `analyzing-malware` — a suspicious binary recovered from the host
- `establishing-persistence` — the offensive counterpart; know what you are hunting for
- `hunting-threats` — the proactive search that may point you at a host
- Eric Zimmerman EZ Tools, KAPE, Sysmon, Timeline Explorer as core tooling

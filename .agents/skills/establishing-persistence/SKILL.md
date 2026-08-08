---
name: establishing-persistence
description: Maintain authorized access across reboots and credential changes during red-team post-exploitation — Windows autostart (Run keys, services, scheduled tasks, WMI subscriptions), Linux (cron, systemd, shell profiles, SSH keys), Active Directory (accounts, DCSync rights, tickets), and cloud identity — chosen least-aggressive first, logged for cleanup, and paired with the detection each leaves. Use post-compromise to keep an authorized foothold. Every mechanism is inventoried and removed at engagement end; nothing survives closure without written agreement.
verified: 2026-08-08
---

# Establishing Persistence

Persistence is how a red team demonstrates the durability an intrusion would
have — access that survives a reboot, a password reset, or the loss of the
initial foothold — without which a report understates the real risk. It is also
the phase most able to cause lasting harm if done carelessly, so it runs under
tight rules: every mechanism is authorized, inventoried the moment it is placed,
and removed at engagement end. A persistence mechanism you cannot account for is
an incident you caused.

Hard limits from [AGENTS.md](../../AGENTS.md), no exceptions: no backdoor that
survives engagement closure without explicit written agreement to retain it; no
self-propagating code, worms, or implants that spread beyond hosts you manually
target; nothing destructive. Confirm the host and identity are in scope before
placing anything, prefer the least-aggressive mechanism that proves the point,
and treat all of this as **LOUD** — persistence is exactly what mature defenders
hunt for. Record every artifact in `maintaining-engagement-state` as you create
it, tagged for cleanup.

## When to Use

- Post-exploitation on an authorized engagement, to demonstrate durable access
- Surviving reboots or credential rotation to show real intrusion impact
- Establishing a fallback foothold before higher-risk actions
- Modeling a specific actor's persistence TTPs for a purple-team exercise

## When NOT to Use

- **Hunting or detecting persistence defensively** — use `hunting-threats`
- **Finding persistence on a suspect host** — use `investigating-windows-endpoints`
- **Gaining the privilege in the first place** — use `escalating-windows-privileges` or `escalating-linux-privileges`
- **Domain-wide persistence primitives** (DCSync, ticket forging) at depth — coordinate with `attacking-active-directory`
- **Cloud identity persistence at depth** — coordinate with `exploiting-cloud-platforms`
- **Moving loot or tools onto the host** — use `transferring-files`
- **Any request to leave a lasting backdoor for "after the test"** — refuse and escalate unless there is written agreement to retain it

## Choose the Least-Aggressive Mechanism

Match the mechanism to the access you have and the point you need to prove.
Prefer user-level and easily-removed over kernel-level and invasive. For every
technique, know the artifact it leaves — that is both the cleanup handle and the
detection the blue team should have (pair offense with detection, per AGENTS.md).

**Windows**

| Technique | ATT&CK | Detection it generates |
| --- | --- | --- |
| Run/RunOnce keys, Startup folder | T1547.001 | Sysmon 12/13, Autoruns |
| Scheduled task | T1053.005 | Security 4698, Task Scheduler log |
| New/modified service | T1543.003 | Security 4697/7045, Sysmon |
| WMI event subscription | T1546.003 | Sysmon 19/20/21 (rare, high-fidelity) |
| COM hijack / IFEO / AppInit / Winlogon | T1546.015/.012/.010, T1547.004 | Sysmon registry events, Autoruns |

**Linux**

- Cron / user crontab (T1053.003), systemd service or timer (T1543.002), shell rc profiles (T1546.004), `~/.ssh/authorized_keys` (T1098.004), SUID drop (coordinate with `escalating-linux-privileges`). Detection: file-integrity monitoring, auditd `execve`, new unit files, `authorized_keys` changes.

**Identity (AD / cloud)** — highest blast radius, tightest control

- AD: new/enabled account (T1136), group or ACL rights incl. DCSync (T1098), ticket abuse (coordinate with `attacking-active-directory`). Detection: 4720/4728/4738, ACL change auditing, 4769 anomalies.
- Cloud: extra access key, added credential on a principal/service account, trust-policy edit (T1098). Detection: CloudTrail `CreateAccessKey`, Entra audit, GCP IAM changes — the same events `investigating-*-incidents` hunt.

## Inventory and Cleanup (mandatory)

Before you place a mechanism, decide how you will remove it. As you place each
one, record in `maintaining-engagement-state`: host/identity, technique, exact
location (key path, task name, file, account SID/ARN), timestamp, and the removal
step. At engagement end, walk the inventory and remove every item, then confirm
removal. Anything you cannot remove yourself is escalated to the operator
immediately — an orphaned implant is a finding against *you*.

## Rationalizations to Reject

- *"Leave a small backdoor so re-testing is easier."* No mechanism survives engagement closure without written agreement. This is a hard rule.
- *"I'll remember what I dropped."* You will not, and cleanup will miss it. Log it at creation, not from memory later.
- *"Make it spread to the other hosts to prove lateral risk."* Self-propagation is prohibited. Target hosts manually; demonstrate reachability without a worm.
- *"Kernel driver / bootkit is more impressive."* More impressive is more dangerous and harder to remove. Use the least-aggressive mechanism that proves durability.
- *"Persistence is quiet if I'm careful."* Persistence is the most-hunted phase. Assume it is logged; note the detection so the finding helps the defender.

## Deliverable

```markdown
# Persistence Artifact <PERS-###>   Date: <UTC>   Operator: <name>
Host / identity:  <hostname / account / ARN — in-scope confirmed>
Technique:        <name + ATT&CK ID>   Aggressiveness: <user / admin / identity>
Location:         <exact key/path/task/account — the cleanup handle>
Purpose:          <what durability this demonstrates>
Detection:        <log source + event the blue team should alert on>
Cleanup:          <removal step>   Status: <active / REMOVED + verified>
```

Log every artifact in `maintaining-engagement-state` at creation. ATT&CK
techniques above — re-verify IDs against the current release before citing in a
report, and confirm demonstrated durability rather than asserting it.

## References

- `escalating-windows-privileges`, `escalating-linux-privileges` — the privilege this phase relies on
- `attacking-active-directory` — domain persistence primitives (DCSync, tickets)
- `exploiting-cloud-platforms` — cloud identity persistence at depth
- `transferring-files` — staging any payload the mechanism launches
- `hunting-threats`, `investigating-windows-endpoints` — the defensive counterparts that find this
- `maintaining-engagement-state` — the cleanup inventory this skill depends on

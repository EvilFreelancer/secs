---
name: investigating-aws-incidents
description: Investigate a suspected AWS compromise from the control plane — CloudTrail management and data events (queried with Athena or CloudTrail Lake), GuardDuty findings, VPC Flow Logs, and CloudWatch — to reconstruct IAM/STS abuse, persistence, data access, and log tampering into a timeline. Use when the evidence is AWS API calls and cloud logs rather than a host. Preserve the logs before the attacker's retention or a StopLogging call erases them.
verified: 2026-08-08
---

# Investigating AWS Incidents

In AWS the crime scene is the API log, not the disk. Almost every action —
assuming a role, minting an access key, reading a bucket, turning off the trail —
is a CloudTrail event with an identity, a source IP, a user agent, and a
timestamp. The investigator reconstructs the intrusion from that record. The
urgency is that the record is itself a target: an attacker who reaches the
logging configuration can stop the trail or shorten retention, so preservation
comes before analysis.

Confirm the account is in scope per [AGENTS.md](../../AGENTS.md), and treat
findings as sensitive cloud data kept in the engagement store. This skill is
read-only investigation; containment actions (revoking keys, isolating a role)
are the operator's call and belong to the wider incident.

## When to Use

- A suspected AWS compromise where the evidence is control-plane logs
- Tracing IAM/STS abuse: AssumeRole chains, new users/keys, console logins
- Confirming data access or exfiltration from S3 and other services
- Finding cloud persistence (new principals, trust-policy edits) and log tampering
- Building an AWS attack timeline for an incident

## When NOT to Use

- **On-host artifacts of an EC2 instance** — use `investigating-windows-endpoints` (or acquire the disk/memory); this skill is the control plane
- **Azure or GCP** — use `investigating-azure-incidents` or `investigating-gcp-incidents`
- **Proactive search with no incident yet** — use `hunting-threats`
- **Offensive cloud testing** — use `exploiting-cloud-platforms`
- **Proactive hardening** — use `hardening-cloud-posture`
- **Running the whole incident** — use `responding-to-incidents`
- **Packaging IOCs into a product** — use `producing-threat-intelligence`

## Preserve First

Copy the relevant CloudTrail logs out of the account (or into a
forensics/logging account) and snapshot affected EBS volumes before anything can
be altered. Confirm whether CloudTrail log-file validation is on. If a
`StopLogging` or `DeleteTrail` appears in the timeline, note the gap it created —
absence of events after that point is evidence, not all-clear.

## Reconstruct from the Control Plane

Scope the window and the suspect identity, then query CloudTrail — Athena over
the S3-delivered logs, or CloudTrail Lake:

```sql
-- Athena: activity for a suspect access key in the incident window
SELECT eventtime, eventname, sourceipaddress, useragent, awsregion
FROM cloudtrail_logs
WHERE useridentity.accesskeyid = 'AKIA...'
  AND eventtime BETWEEN '2026-08-01T00:00Z' AND '2026-08-08T00:00Z'
ORDER BY eventtime;
```

High-signal `eventName`s to hunt:

| Category | Events |
| --- | --- |
| Access / recon | `ConsoleLogin` (esp. `MFAUsed=No`), `GetCallerIdentity`, `AssumeRole`, `GetAccountAuthorizationDetails` |
| Persistence / privesc | `CreateUser`, `CreateAccessKey`, `CreateLoginProfile`, `AttachUserPolicy`, `PutUserPolicy`, `UpdateAssumeRolePolicy` |
| Data access / exfil | `GetObject`/`ListBucket` (data events), `CreateDBSnapshot` + `ShareDBSnapshot`, `ModifyImageAttribute` (public AMI/snapshot) |
| Defense evasion | `StopLogging`, `DeleteTrail`, `PutEventSelectors`, `DeleteFlowLogs`, `Disassociatefrom...`, GuardDuty `DeleteDetector` |

Correlate with **GuardDuty** findings (managed detections for credential
exfil, recon, and crypto-mining), **VPC Flow Logs** (egress volume and
destinations for exfil), and **CloudWatch**. Pivot on `sourceIPAddress`,
`userAgent` (tooling fingerprint — CLI vs SDK vs console), and `accessKeyId` to
follow the identity through role-assumption chains.

## Rationalizations to Reject

- *"No GuardDuty finding, so nothing happened."* GuardDuty covers known patterns; absence is not innocence. Read CloudTrail directly.
- *"The trail is off — dead end."* The `StopLogging` event, its actor, and the timing are themselves findings. Look for other regions and data-event trails.
- *"Data events are noisy, skip them."* S3/Lambda data events are where exfil is proven. Scope them to the window instead of skipping.
- *"One region is enough."* Attackers operate in unused regions precisely because no one looks. Check global and per-region trails.
- *"The key was rotated, case closed."* Rotation is containment, not investigation. Establish what the key did before it was rotated.

## Deliverable

```markdown
# AWS Investigation <AWS-###>   Date: <UTC>   Analyst: <name>
Account / scope:  <account id, in-scope confirmation>
Window:           <UTC start–end>
Entry:            <compromised identity — user/role/key, first observed use>
Actions:          <API calls by category, with source IP + user agent>
Data touched:     <buckets/DBs/snapshots — read/shared/made public>
Persistence:      <new principals, keys, trust-policy edits>
Log tampering:    <StopLogging/DeleteTrail + resulting gaps>
Timeline:         <UTC, chronological>
Conclusion:       compromised / not / could-not-determine  Confidence: <>
```

Save log exports and query results as `{tool}_{account}_{YYYYMMDD_HHMMSS}.{ext}`
and log IOCs and identities via `maintaining-engagement-state`. ATT&CK IDs
common here (T1078.004 Valid Cloud Accounts, T1098 Account Manipulation, T1530
Data from Cloud Storage, T1070 Indicator Removal, T1537 Transfer to Cloud
Account) — re-verify before citing.

## References

- `investigating-azure-incidents`, `investigating-gcp-incidents` — the sibling cloud investigations
- `investigating-windows-endpoints` — when an EC2 host itself must be examined
- `responding-to-incidents` — the incident this feeds
- `hardening-cloud-posture` — what the audit logging you rely on here should have been
- `exploiting-cloud-platforms` — the offensive counterpart TTPs
- CloudTrail (management + data events), CloudTrail Lake, Athena, GuardDuty, VPC Flow Logs

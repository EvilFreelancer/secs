---
name: investigating-gcp-incidents
description: Investigate a suspected Google Cloud compromise from the control plane — Cloud Audit Logs (Admin Activity, Data Access, System Event, Policy Denied), Cloud Logging, and VPC Flow Logs — to reconstruct IAM and service-account abuse, key creation, data access, and log tampering into a timeline. Use when the evidence is GCP audit logs rather than a host. Service-account keys and IAM bindings are the usual attack path; preserve the audit logs before retention lapses.
verified: 2026-08-08
---

# Investigating GCP Incidents

Google Cloud writes the intrusion into its audit logs. Cloud Audit Logs record
who called which API on what resource, split into streams — Admin Activity
(always on), Data Access (often off by default, and where read/exfil is proven),
System Event, and Policy Denied. The attacker's path is usually identity:
abusing a service account, minting a service-account key, or widening an IAM
binding. The investigator reconstructs it from the logs, and the first job is to
preserve them, because Data Access logs may not have been enabled and their
retention is finite.

Confirm the project/organization is in scope per [AGENTS.md](../../AGENTS.md).
Note up front whether Data Access logging was enabled for the affected services —
if it was not, read/exfil evidence may simply not exist, and that gap is itself a
finding. This is read-only investigation; disabling keys or bindings is the
operator's containment call.

## When to Use

- A suspected GCP compromise where the evidence is Cloud Audit Logs
- Tracing IAM and service-account abuse, key creation, and impersonation
- Confirming data access or exfiltration from GCS and other services
- Finding cloud persistence (new bindings, keys) and log/sink tampering
- Building a GCP attack timeline for an incident

## When NOT to Use

- **On-host artifacts of a GCE instance** — use `investigating-windows-endpoints` (or acquire the disk/memory)
- **AWS or Azure** — use `investigating-aws-incidents` or `investigating-azure-incidents`
- **Proactive search with no incident yet** — use `hunting-threats`
- **Offensive cloud testing** — use `exploiting-cloud-platforms`
- **Proactive hardening** — use `hardening-cloud-posture`
- **Running the whole incident** — use `responding-to-incidents`
- **Packaging IOCs into a product** — use `producing-threat-intelligence`

## Preserve First

Export the relevant audit logs to a separate project or bucket before anything
can be altered, and snapshot affected disks:

```bash
gcloud logging read \
  'logName:"cloudaudit.googleapis.com" AND timestamp>="2026-08-01T00:00:00Z"' \
  --project TARGET --format json > gcp_audit_$(date -u +%Y%m%d_%H%M%S).json
gcloud compute disks snapshot DISK --project TARGET --snapshot-names ir-DISK
```

Check for a `google.logging.v2.ConfigServiceV2.DeleteSink` or disabled Data
Access logging in the window — a gap after that point is evidence, not all-clear.

## Reconstruct from the Control Plane

Scope the window and the suspect principal, then read the audit streams. Query
by `protoPayload.methodName` and `authenticationInfo.principalEmail`:

| Category | methodName signals |
| --- | --- |
| Access / recon | `...IAMPolicy.GetIamPolicy`, `...testIamPermissions`, unusual `principalEmail` |
| Persistence / privesc | `SetIamPolicy` (new bindings), `CreateServiceAccountKey`, `generateAccessToken`/`generateIdToken` (impersonation), `CreateServiceAccount` |
| Data access / exfil | `storage.objects.get`/`list` (Data Access logs), `bigquery ... jobservice`, disk image/snapshot export |
| Defense evasion | `DeleteSink`, `UpdateSink`, disabling Data Access logging, firewall/VPC changes |

```bash
# Service-account key creations in the window
gcloud logging read \
 'protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"' \
 --project TARGET --format 'table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.resourceName)'
```

Correlate with **VPC Flow Logs** for egress volume and destinations. Pivot on
`principalEmail`, `callerIp`, and `callerSuppliedUserAgent` to follow an identity
through impersonation chains (`generateAccessToken` is the GCP equivalent of an
AssumeRole hop and a favorite privilege path).

## Rationalizations to Reject

- *"No Data Access logs, so no exfil happened."* Data Access logging is off by default for many services. Absent logs mean unknown, not clean — record the gap.
- *"Admin Activity looks quiet."* Read/exfil and impersonation may only appear in Data Access and token-generation events. Check those streams explicitly.
- *"One project is enough."* Check the organization and folder levels and other projects the compromised principal could reach.
- *"The key was deleted, case closed."* Establish what the service-account key did before deletion; deletion may itself be the attacker covering tracks.
- *"IAM binding change is routine."* A new `SetIamPolicy` granting a service account broad roles is a classic GCP persistence/privesc step. Verify it was authorized.

## Deliverable

```markdown
# GCP Investigation <GCP-###>   Date: <UTC>   Analyst: <name>
Project / org / scope: <ids, in-scope confirmation>
Window:           <UTC start–end>
Logging state:    <which audit streams were enabled — name the gaps>
Entry:            <compromised principal / service account / key>
Actions:          <methodNames by category, with caller IP + user agent>
Data touched:     <GCS/BigQuery/snapshots — read/exported>
Persistence:      <new bindings, SA keys, impersonation>
Log tampering:    <sink deletes / disabled logging + resulting gaps>
Timeline:         <UTC, chronological>
Conclusion:       compromised / not / could-not-determine  Confidence: <>
```

Save log exports and query output as `{tool}_{project}_{YYYYMMDD_HHMMSS}.{ext}`
and log identities/IOCs via `maintaining-engagement-state`. ATT&CK IDs common
here (T1078.004 Valid Cloud Accounts, T1098 Account Manipulation, T1528 Steal
Application Access Token, T1530 Data from Cloud Storage, T1070 Indicator
Removal) — re-verify before citing.

## References

- `investigating-aws-incidents`, `investigating-azure-incidents` — the sibling cloud investigations
- `investigating-windows-endpoints` — when a GCE host must be examined
- `responding-to-incidents` — the incident this feeds
- `hardening-cloud-posture` — the audit logging and IAM controls this tests in hindsight
- `exploiting-cloud-platforms` — the offensive counterpart TTPs
- Cloud Audit Logs (Admin Activity / Data Access / System Event / Policy Denied), Cloud Logging, VPC Flow Logs

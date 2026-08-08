---
name: investigating-azure-incidents
description: Investigate a suspected Azure and Entra ID compromise from the control plane — Azure Activity Log, Entra sign-in and audit logs, and the Microsoft 365 unified audit log, queried with KQL in Log Analytics/Sentinel — to reconstruct identity abuse, MFA and conditional-access bypass, service-principal and app-consent abuse, role changes, and Key Vault access. Use when the evidence is Azure/Entra logs rather than a host. Identity is the perimeter here; the sign-in and audit logs are the crime scene.
verified: 2026-08-08
---

# Investigating Azure Incidents

Azure intrusions are usually identity intrusions. The attacker signs in as a
user, consents an app, adds a credential to a service principal, or elevates a
role — and each leaves a record in the Entra sign-in logs, the Entra audit log,
the Azure Activity Log, or the Microsoft 365 unified audit log. The
investigator's task is to correlate across those planes, because a single one
rarely tells the whole story: the sign-in log shows the authentication, the
audit log shows what identity changed, and the activity log shows what resources
moved. Query them with KQL and build one timeline.

Confirm the tenant/subscription is in scope per [AGENTS.md](../../AGENTS.md).
Mind log retention: Entra sign-in/audit logs have short default retention unless
exported to Log Analytics, so preserve early. This is read-only investigation;
disabling accounts or revoking sessions is the operator's containment call.

## When to Use

- A suspected Azure/Entra compromise where the evidence is cloud logs
- Tracing identity abuse: risky sign-ins, impossible travel, token/session theft
- Confirming MFA or conditional-access bypass
- Investigating service-principal credential additions and OAuth app-consent abuse
- Reconstructing role assignments (incl. PIM), resource tampering, and Key Vault access

## When NOT to Use

- **On-host artifacts of an Azure VM** — use `investigating-windows-endpoints` (or acquire the disk/memory)
- **AWS or GCP** — use `investigating-aws-incidents` or `investigating-gcp-incidents`
- **Proactive search with no incident yet** — use `hunting-threats`
- **Offensive cloud testing** — use `exploiting-cloud-platforms`
- **Proactive hardening** — use `hardening-cloud-posture`
- **Running the whole incident** — use `responding-to-incidents`
- **Packaging IOCs into a product** — use `producing-threat-intelligence`

## Reconstruct Across the Log Planes

Three Entra/Azure sources plus the M365 unified audit log, correlated:

- **Entra sign-in logs** — authentications: user, app, IP, device, MFA result, conditional-access result, and the risk state. Impossible travel, legacy-auth protocols, and token-replay show here.
- **Entra audit logs** — directory changes: `Add service principal credentials`, `Consent to application`, `Add member to role`, `Update conditional access policy`, user/credential changes.
- **Azure Activity Log** — resource control plane: role assignments (`Microsoft.Authorization/roleAssignments/write`), resource and network-security-group changes, Key Vault operations.
- **M365 unified audit log** — mailbox rules, sharing, and Exchange/SharePoint actions when the compromise touches M365.

Query with KQL in Log Analytics/Sentinel:

```kusto
// New privileged role assignments in the window
AuditLogs
| where TimeGenerated between (datetime(2026-08-01) .. datetime(2026-08-08))
| where OperationName has "Add member to role"
| extend role = tostring(TargetResources[0].displayName)
| project TimeGenerated, InitiatedBy, role, Result

// Sign-ins that bypassed or failed MFA / conditional access
SigninLogs
| where ResultType == 0 and AuthenticationRequirement == "singleFactorAuthentication"
| project TimeGenerated, UserPrincipalName, IPAddress, AppDisplayName, ConditionalAccessStatus
```

High-signal operations: service-principal credential additions and app consents
(a common persistence and data-access path), conditional-access policy edits,
new Global Admin / Privileged Role Admin grants, Key Vault secret reads from
unusual IPs, and mailbox forwarding rules. Pivot on IP, user agent, app id, and
service-principal object id.

## Rationalizations to Reject

- *"Sign-in succeeded with no risk flag, so it's fine."* Risk scoring misses token theft and consented-app access. Corroborate with the audit and activity logs.
- *"MFA is on, so the account is safe."* Check whether MFA was actually satisfied or bypassed via legacy auth, a trusted location, or a stolen session — the sign-in log says which.
- *"It's just an app consent."* Malicious OAuth consent is a durable, MFA-surviving foothold. Treat consented apps as identity persistence.
- *"Only one log source needed."* Azure splits authentication, directory change, and resource change across three logs. One alone under-tells the story.
- *"Retention looks fine."* Entra default retention is short without export. Preserve now, not after the write window closes.

## Deliverable

```markdown
# Azure Investigation <AZ-###>   Date: <UTC>   Analyst: <name>
Tenant / sub / scope: <ids, in-scope confirmation>
Window:           <UTC start–end>
Entry:            <compromised identity / app / service principal>
Auth path:        <sign-in evidence: IP, device, MFA/CA result>
Directory changes: <role adds, SP credentials, app consents>
Resource / data:  <Activity Log + Key Vault + M365 actions>
Persistence:      <app consents, SP creds, CA policy edits>
Timeline:         <UTC, chronological across planes>
Conclusion:       compromised / not / could-not-determine  Confidence: <>
```

Save log exports and KQL results as `{tool}_{tenant}_{YYYYMMDD_HHMMSS}.{ext}`
and log identities/IOCs via `maintaining-engagement-state`. ATT&CK IDs common
here (T1078.004 Valid Cloud Accounts, T1098.003 Additional Cloud Roles,
T1556.009 Modify Authentication Process, T1538 Cloud Service Dashboard, T1528
Steal Application Access Token) — re-verify before citing.

## References

- `investigating-aws-incidents`, `investigating-gcp-incidents` — the sibling cloud investigations
- `investigating-windows-endpoints` — when an Azure VM host must be examined
- `responding-to-incidents` — the incident this feeds
- `hardening-cloud-posture` — the identity controls this investigation tests in hindsight
- `exploiting-cloud-platforms` — the offensive counterpart TTPs
- Entra sign-in/audit logs, Azure Activity Log, M365 unified audit log, Log Analytics/Sentinel (KQL)

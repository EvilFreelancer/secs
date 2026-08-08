---
name: investigating-m365-entra
description: Investigate a Microsoft 365 and Entra ID compromise where the only evidence is cloud logs — the Unified Audit Log, Entra sign-in and audit logs, OAuth app-consent grants, and mailbox inbox/forwarding rules — to reconstruct business email compromise, token and session theft, and consent abuse. Use for a suspected M365/Entra account takeover with no host or memory to image. Preserve the Unified Audit Log first; its retention is finite and the attacker's rules keep working while you look.
verified: 2026-08-08
---

# Investigating M365 / Entra Incidents

A Microsoft 365 compromise usually leaves no host to image — the crime scene is
entirely in the cloud logs. An attacker who phishes a session token or tricks a
user into consenting a malicious OAuth app does not need malware: they read mail,
set a hidden forwarding rule, and pivot to invoice fraud, and every step is a
record in the Unified Audit Log (UAL), the Entra sign-in logs, or the mailbox
configuration. The investigator reconstructs the takeover from those records. The
urgency is twofold: UAL retention is finite, and any forwarding or inbox rule the
attacker set is still exfiltrating mail while you investigate.

Confirm the tenant is in scope per [AGENTS.md](../../AGENTS.md). Enable/confirm
UAL access early and export the relevant window before retention lapses. This is
read-only investigation; disabling the account, revoking sessions, or removing a
malicious app is the operator's containment call.

## When to Use

- A suspected M365/Entra account takeover or business email compromise (BEC)
- No disk or memory to image — only cloud logs (UAL, sign-ins, OAuth grants)
- Hunting hidden inbox/forwarding rules and delegate/permission changes
- Investigating malicious OAuth app consent as a persistence and exfil path
- Reconstructing token/session theft that bypassed MFA

## When NOT to Use

- **Azure resource control plane** (subscriptions, RBAC, Key Vault, VMs) — use `investigating-azure-incidents`; this skill is the M365 workload and identity layer
- **AWS or GCP** — use `investigating-aws-incidents` or `investigating-gcp-incidents`
- **On-host artifacts** — use `investigating-windows-endpoints`
- **Triaging the phishing email that started it** — use `analyzing-phishing-emails`
- **Proactive search with no incident yet** — use `hunting-threats`
- **Running the whole incident** — use `responding-to-incidents`
- **Packaging IOCs into a product** — use `producing-threat-intelligence`

## Reconstruct from the Cloud Logs

**Unified Audit Log** is the backbone. Search it for the suspect user and window:

```powershell
Search-UnifiedAuditLog -StartDate 2026-08-01 -EndDate 2026-08-08 `
  -UserIds victim@corp.com -ResultSize 5000 |
  Where-Object Operations -in `
    'New-InboxRule','Set-InboxRule','Set-Mailbox','Add-MailboxPermission',
    'Consent to application','Add service principal','UserLoggedIn' |
  Export-Csv ual_victim.csv -NoTypeInformation
```

Then correlate across the layers:

- **Mailbox rules (the BEC signature).** Hidden inbox/forwarding rules that move
  or delete mail to a folder like RSS or Archive: `Get-InboxRule -Mailbox
  victim@corp.com` and UAL `New-InboxRule`/`Set-InboxRule`; external forwarding
  via `Set-Mailbox -ForwardingSmtpAddress` (T1114.003). These are how invoices
  get intercepted — find and time them precisely.
- **Delegation / permissions.** `Add-MailboxPermission`, `Add-RecipientPermission`
  granting the attacker standing access without the victim's password.
- **OAuth app consent (persistence that survives a password reset and MFA).**
  UAL `Consent to application` / `Add app role assignment` and Entra
  enterprise-app consent grants — a malicious app with `Mail.Read`/`Mail.Send`
  is durable access; treat consented apps as identity persistence (T1528).
- **Sign-ins.** Entra sign-in logs for the session behind the changes: source IP,
  ASN, device, MFA state, and legacy-auth or token-replay indicators (impossible
  travel, a new device satisfying no MFA). A "successful, low-risk" sign-in can
  still be stolen-token access.

## Rationalizations to Reject

- *"MFA was on, so it wasn't takeover."* Token/session theft and consent phishing bypass MFA entirely. Check the sign-in method and consented apps, not just the MFA flag.
- *"No malware, so no incident."* BEC is malware-free by design. The evidence is rules, consents, and sign-ins, not a binary.
- *"Removed the forwarding rule, done."* Removal is containment. Establish what was exfiltrated, which sessions/apps still have access, and the full timeline first.
- *"One suspicious login, case closed."* Follow the app consents and delegated permissions — the durable foothold often outlives the login.
- *"UAL will still be there next week."* Retention is finite and auditing may have been off. Preserve the window now.

## Deliverable

```markdown
# M365/Entra Investigation <M365-###>   Date: <UTC>   Analyst: <name>
Tenant / scope:   <tenant, victim identities, in-scope confirmation>
Window:           <UTC start–end>   UAL/audit state: <enabled? gaps?>
Entry:            <phish/consent/token — first observed compromised sign-in>
Sign-in evidence: <IP, ASN, device, MFA/legacy-auth, impossible travel>
Mailbox changes:  <inbox/forwarding rules, delegation — with timestamps>
OAuth consents:   <apps + scopes granted — the persistence path>
Data exposed:     <mail read/forwarded, files accessed>
Timeline:         <UTC, chronological>
Conclusion:       compromised / not / could-not-determine  Confidence: <>
```

Save UAL/sign-in exports as `{tool}_{tenant}_{YYYYMMDD_HHMMSS}.csv` and log
identities/IOCs via `maintaining-engagement-state`. ATT&CK IDs common here
(T1078.004 Valid Cloud Accounts, T1114.003 Email Forwarding Rule, T1528 Steal
Application Access Token, T1556 Modify Authentication Process, T1098.003
Additional Cloud Roles) — re-verify before citing.

## References

- `investigating-azure-incidents` — the Azure resource control plane beside this identity/workload layer
- `analyzing-phishing-emails` — the lure that usually starts a BEC
- `responding-to-incidents` — the incident this feeds
- `producing-threat-intelligence` — packaging the actor infrastructure and IOCs
- Unified Audit Log (`Search-UnifiedAuditLog`), Exchange Online PowerShell (`Get-InboxRule`), Entra sign-in/audit logs, Microsoft Sentinel (KQL)

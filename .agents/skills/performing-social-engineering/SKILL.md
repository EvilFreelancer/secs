---
name: performing-social-engineering
description: Run authorized social-engineering assessments — pretext development from OSINT, phishing and spearphishing campaigns (Gophish), vishing and smishing, and physical pretexting — to measure the human attack surface and produce awareness-driving metrics. Use when the engagement scope explicitly authorizes testing people, with organizational sign-off and HR/legal coordination. You are testing a consenting organization's controls, never tricking a private individual; harm, real fraud, and non-consenting targets are out of scope.
verified: 2026-08-08
---

# Performing Social Engineering

Social engineering tests the one control you cannot patch: people. Done right,
it measures how a real lure would fare against the organization's training,
email controls, and reporting culture, and it produces the metrics and teachable
moments that actually move that culture. Done wrong, it humiliates employees,
leaks real personal data, or crosses into fraud. The line between the two is
authorization and restraint, so this skill is gated harder than most.

Authorization here is organizational and specific: written executive sign-off,
legal clearance, a defined scope (which groups, which vectors, which exclusions),
and HR/legal coordination for how results are handled and disclosed. Per
[AGENTS.md](../../AGENTS.md) you target a consenting organization's controls, not
non-consenting private individuals; you never misattribute the campaign to a real
named third party (no false flag); and you demonstrate susceptibility without
causing real loss. Assume every phish is **LOUD** and will be reported — that is
the point.

## When to Use

- The engagement explicitly authorizes testing people, with executive sign-off
- Developing a pretext and phishing/spearphishing campaign against in-scope groups
- Vishing or smishing scenarios to test help-desk and verification procedures
- Physical pretexting (tailgating, USB drops) where the ROE permits it
- Producing susceptibility metrics and awareness recommendations

## When NOT to Use

- **Analyzing an inbound phishing email defensively** — use `analyzing-phishing-emails`
- **OSINT and target-surface mapping only** — use `performing-reconnaissance`; come here to weaponize it into a pretext
- **Building the credential-harvesting landing page's web flaws** — use `testing-web-applications`
- **Any test of non-consenting individuals or without org sign-off** — refuse and escalate; scope on paper for an individual is not consent
- **Writing up results** — use `reporting-security-findings`

## Method (authorization-gated at every phase)

**1. Confirm the gate.** Executive approval, legal review, scope (target groups,
vectors, exclusions, blackout windows), and the agreed handling of any data you
capture. No gate, no send.

**2. Pretext from OSINT.** Build believable context, not a generic lure — email
patterns, org structure, current events, and vendor relationships. Use
`performing-reconnaissance` for harvesting (theHarvester, LinkedIn, breach data
via authorized tooling) and note SPF/DKIM/DMARC posture that a real actor would
exploit.

**3. Stand up controlled infrastructure.** Gophish for campaign management and
metrics; an attacker-owned look-alike domain; a cloned login or awareness landing
page. Capture only what the metric needs (that a credential *would* have been
submitted), and prefer a training redirect over storing real passwords. If the
scope authorizes MFA-phishing (e.g., evilginx2 reverse-proxy), treat captured
sessions as sensitive and short-lived. Callbacks and capture endpoints must be
operator-controlled and in scope.

**4. Vishing / smishing / physical (if in scope).** Scripted pretexts (help-desk,
vendor), tracked for what information was disclosed; USB drops and tailgating only
where the ROE and local law permit, with evidence handling agreed in advance.

**5. Measure, do not maximize harm.** Track answer/click/submit/report rates and
time-to-report. The reporting rate is as important as the click rate — it shows
the human detection control working.

## Data Handling (non-negotiable)

Any credential or session captured is invalidated immediately after the metric is
recorded and stored only in the encrypted engagement store. Report identifiable
results to CISO/legal, not to line managers as a naming exercise. No persistence
on any target, no exfiltration of real business data, and no re-use of harvested
personal data for anything outside the stated metric. Follow the data-handling
rules in [AGENTS.md](../../AGENTS.md).

## Rationalizations to Reject

- *"The domain is in scope, so the CEO's personal accounts are fair game."* Scope is the organization's assets and consenting staff, not anyone's personal life. Stay on org-authorized targets.
- *"Capturing real passwords makes the metric stronger."* The metric is that a credential *would* have been given. Redirect to training; do not hoard live passwords.
- *"Impersonate a named real bank to be realistic."* False-flagging a real third party is prohibited. Use a generic or attacker-owned brand.
- *"Name the employees who clicked."* SE tests controls and culture, not individuals to shame. Report aggregate to CISO/legal.
- *"It's just a USB drop, no approval needed."* Physical and MFA-bypass vectors need explicit ROE clauses and often legal review. No clause, no action.

## Deliverable

```markdown
# SE Assessment <SE-###>     Date: <UTC>   Operator: <name>
Authorization:    <exec sign-off ref, legal review, HR coordination>
Scope:            <groups, vectors, exclusions, window>
Pretext:          <theme + why believable — no real third-party impersonation>
Campaign:         <vector, volume, infrastructure (attacker-owned, in scope)>
Results:          click / submit / disclose rates; time-to-report; reporting rate
Data captured:    <what, and confirmation it was invalidated + secured>
Findings:         <control gaps: email auth, training, help-desk verification>
Recommendation:   <awareness, technical control, process — named owner>
Detection:        <the signal that caught it, or should have>
```

Log campaign artifacts and metrics via `maintaining-engagement-state`. ATT&CK IDs
here (T1566 Phishing, T1598 Phishing for Information, T1589/T1591 Gather Victim
Info, T1204.001 User Execution: Malicious Link, T1608 Stage Capabilities) —
re-verify before citing.

## References

- `performing-reconnaissance` — OSINT and target-surface mapping feeding the pretext
- `analyzing-phishing-emails` — the defensive counterpart that triages what you send
- `testing-web-applications` — flaws in a landing/credential-capture page
- `reporting-security-findings` — turning metrics into awareness recommendations
- Gophish, theHarvester, evilginx2 (authorized MFA-phishing) as core tooling; OWASP/PTES SE guidance

---
name: analyzing-phishing-emails
description: Analyze a reported or suspected phishing email safely — parse the Received chain and Return-Path, validate SPF/DKIM/DMARC alignment, extract and defang URLs and attachments, detonate payloads in a sandbox, and pivot on sender infrastructure to produce IOCs and a disposition. Use when a user-reported email, a mailbox artifact, or a `.eml`/`.msg` needs a verdict. Every link is live until proven otherwise; defang first, click never.
verified: 2026-08-08
---

# Analyzing Phishing Emails

A phishing email is an attack you were handed intact — which is a gift and a
hazard. The gift is a full specimen: headers that trace the real origin, URLs
and attachments that lead to the actor's infrastructure, and a lure that reveals
intent. The hazard is that all of it is live. A URL fetched from your own IP
tips the operator and can burn the investigation; an attachment opened on your
box is the compromise. So the discipline is fixed: preserve the original, defang
everything, and detonate only in isolation. The output is a verdict
(malicious / suspicious / benign) plus IOCs the rest of the program can action.

Handle every specimen as sensitive: the email may contain a real user's PII.
Keep it in the engagement store, never paste it into third-party services beyond
the vetted reputation lookups below, and follow the data-handling rules in
[AGENTS.md](../../AGENTS.md).

## When to Use

- A user-reported email or a `.eml`/`.msg`/mailbox artifact needs a disposition
- Tracing the true sender through a forged `From` and a relay chain
- Extracting URLs, attachments, and sender infrastructure into IOCs
- Confirming spoofing via SPF/DKIM/DMARC alignment
- Feeding a phishing verdict into detection or an incident

## When NOT to Use

- **The email led to a confirmed compromise** — use `responding-to-incidents`; this skill triages the lure, that one runs the intrusion
- **Deep analysis of the attachment's behavior** — hand the sample to `analyzing-malware`; detonate there, do not "just open it"
- **A packet capture of the callback traffic** — use `analyzing-network-traffic`
- **Building a mail-gateway or SIEM rule from what you found** — use `engineering-detections`, `writing-sigma-rules`
- **Packaging the IOCs into an actor/campaign product** — use `producing-threat-intelligence`
- **Sending phishing as the attacker** (red-team simulation) — out of scope here; that is offensive social engineering, not lure triage

## Preserve, Then Defang (do this before anything else)

Work on a copy. Export the **original** with full headers (Outlook: File →
Properties → Internet Headers; Gmail: Show original) and keep the raw `.eml` in
the evidence store with a hash. From this point every indicator is written
**defanged** — `hxxps://`, `192[.]0[.]2[.]5`, `evil[.]example[.]com`,
`user[at]domain` — so nothing is clickable in a report or a chat window.

```bash
# Parse a raw .eml without a mail client (isolated host)
python3 -c "import email,sys;m=email.message_from_file(open(sys.argv[1]));\
print(m.as_string())" phish.eml | less        # read-only, no rendering
```

## Trace the Sender (headers, bottom-to-top)

Read `Received:` from the bottom up — the earliest hop is closest to the real
origin; the top hops are your own infrastructure. Cross-check against the
envelope and the authentication result:

- `Return-Path` / envelope-from vs the displayed `From` — misalignment is a spoofing tell
- `Authentication-Results` — the receiver's own SPF/DKIM/DMARC verdict
- `DKIM-Signature` selector and the `d=` domain — does it align with `From`?
- `Message-ID` domain and `X-Originating-IP` — sanity against the claimed sender

Then validate independently, because the header can lie:

```bash
dig +short TXT example.com | grep -i spf     # is the sending IP authorized?
dig +short TXT _dmarc.example.com            # p=reject / quarantine / none?
```

SPF/DKIM absent or misaligned plus a `p=none` domain is high spoofing risk.
A perfect pass does **not** clear it — actors send from compromised or
look-alike domains that pass their own auth.

## Pivot on Infrastructure and Payloads

- **Sender domain age** — a domain registered in the last few days is a strong signal (WHOIS creation date).
- **Look-alikes** — compare the display domain to your brands for homoglyphs and typosquats.
- **URLs** — flag display-text vs `href` mismatches; submit the URL (never your creds) to URLScan/URLhaus/PhishTank and VirusTotal by **URL**, not by browsing it.
- **Attachments** — hash them and look up the hash first; only detonate in an isolated sandbox (hand off to `analyzing-malware`). Never re-upload a sensitive attachment to a public service without deciding it is safe to make public — the upload is publication.

QUIET vs LOUD: passive reputation lookups by hash/URL are QUIET. Actively
resolving, fetching, or interacting with the actor's live infrastructure from
attributable infrastructure is LOUD and can tip the operator — do not do it from
your own IP.

## Rationalizations to Reject

- *"SPF/DKIM passed, so it's legitimate."* Auth passes for compromised and look-alike domains. Alignment and intent decide it, not a green check.
- *"I'll just click to see where it goes."* From your IP that tips the actor and risks the compromise. Use URLScan or a detonation sandbox.
- *"The attachment looks like a normal invoice."* That is the point. Hash it and detonate it in isolation before you believe it.
- *"One indicator is enough."* A single IOC ages out fast. Extract the set (sender infra, URLs, hashes, lure theme) so detection has something durable.
- *"It's obviously phishing — no need to document."* An undocumented verdict cannot be tuned into a detection or defended later.

## Deliverable

```markdown
# Phishing Analysis <PH-###>     Date: <UTC>   Analyst: <name>
Verdict:          malicious / suspicious / benign   Confidence: <low/med/high>
Subject:          <description>
From / Return-Path: <defanged>   SPF: <pass/fail> DKIM: <pass/fail/none> DMARC: <policy> Aligned: <y/n>
Delivery path:    <hop -> hop, earliest origin IP + reputation>
Lure / intent:    <credential harvest / malware / BEC / etc.>
IOCs (defanged):  URLs / domains / sending IP / attachment SHA-256 + VT verdict
Impact if actioned: <what a click/open achieves>
Recommendation:   <block, purge from mailboxes, user notify, detection to build>
```

Save the raw `.eml` and artifacts as `{tool}_{target}_{YYYYMMDD_HHMMSS}.{ext}`
and log IOCs via `maintaining-engagement-state`. ATT&CK IDs relevant here
(T1566.001 Spearphishing Attachment, T1566.002 Spearphishing Link, T1598.003
Spearphishing for Information) — re-verify against the current ATT&CK release
before citing.

## Reading External Sources

Fetch vendor write-ups and advisories as Markdown:

```bash
curl -sL "https://defuddle.md/<url>"      # scheme in the path is optional
```

Never route the **phishing URLs themselves** or any actor infrastructure through
it — the request leaves your machine to a third party and can tip the operator.
Fetch JSON/API responses raw.

## References

- `analyzing-malware` — detonating the attachment or second-stage payload
- `analyzing-network-traffic` — the callback/exfil traffic if a host was hit
- `responding-to-incidents` — when the lure succeeded and this is now an intrusion
- `engineering-detections`, `writing-sigma-rules` — turning the verdict into a rule
- `producing-threat-intelligence` — packaging IOCs into an actor/campaign product
- SPF/DKIM/DMARC (RFC 7208/6376/7489); URLScan, URLhaus, PhishTank, VirusTotal as reputation sources

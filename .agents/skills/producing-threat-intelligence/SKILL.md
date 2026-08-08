---
name: producing-threat-intelligence
description: Turn raw observations, extracted IOCs, and open sources into finished threat intelligence — running the intelligence cycle (direction, collection, processing, analysis, dissemination, feedback), enriching and grading indicators, pivoting on TTPs over atomic IOCs, structuring attribution with calibrated confidence, and packaging tactical/operational/strategic products with TLP and sourcing. Use when packaging IOCs from an investigation into a product, tracking an actor, or standing up a CTI capability. Intelligence answers a decision-maker's question; a pile of indicators is not intelligence.
verified: 2026-08-08
---

# Producing Threat Intelligence

Intelligence is not a feed of indicators — it is an answer to a question someone
is going to make a decision on. A list of 400 IPs with no confidence, no
sourcing, and no "so what" is data; it becomes intelligence only when it is
tied to a requirement, graded for reliability, and written so the reader knows
what to do and how much to trust it. The two failure modes are equal and
opposite: shipping raw IOCs as if they were analysis, and shipping confident
attribution the evidence does not support. This skill exists to avoid both.

This is an Advisory skill — it produces products, it does not touch targets. But
collection has OPSEC: interacting with adversary infrastructure, or uploading a
sample or URL to a public enrichment service, can tip off the actor and can
expose engagement data. Treat every collection action as potentially observable.

## When to Use

- Packaging IOCs and TTPs from an investigation into a finished intel product
- Enriching and grading indicators (IP, domain, URL, hash) before they are actioned
- Tracking a threat actor or campaign and building an actor profile from OSINT
- Defining Priority Intelligence Requirements (PIRs) and a collection plan
- Standing up or maturing a CTI program and its dissemination workflow

## When NOT to Use

- **Searching your own telemetry for compromise** — use `hunting-threats`; a hunt *consumes* intelligence, this skill *produces* it
- **Working an alert to a disposition** — use `triaging-security-alerts`
- **Writing a detection from the TTPs** — use `engineering-detections`, `writing-sigma-rules`, `writing-yara-rules`
- **Running or documenting a live incident** — use `responding-to-incidents`
- **Navigating work by ATT&CK technique** — use `mapping-attack-techniques`
- **Writing up a pentest/audit finding** — use `reporting-security-findings`; an intel product is a different genre from a vulnerability report

## The Intelligence Cycle

Run the loop; do not skip to collection because it feels productive.

1. **Direction** — write PIRs. A PIR is a decision-linked question with a
   stakeholder, priority, and intelligence level (strategic / operational /
   tactical). "Which actors target our sector and how?" is a PIR; "collect
   IOCs" is not. Requirements drive collection, not the other way round.
2. **Collection** — plan sources against each PIR: OSINT (CISA KEV, Abuse.ch
   MalwareBazaar, AlienVault OTX, certificate transparency), commercial and
   ISAC feeds, internal telemetry, trusted-community sharing. Record provenance
   for everything.
3. **Processing** — normalize formats, deduplicate (hash the indicator),
   defang, and tag each item with source, type, first-seen, TLP, and a
   confidence value.
4. **Analysis** — this is the job. Pivot, correlate, apply structured analytic
   techniques, and answer the PIR with calibrated confidence.
5. **Dissemination** — deliver the right product to the right audience in the
   right format, marked with TLP.
6. **Feedback** — ask whether it answered the question and drove a decision;
   feed that back into direction. Products no one uses are a collection problem.

## Enrichment and Grading

Enrich every actionable indicator across independent sources before it is
trusted or actioned:

| Indicator | Sources |
| --- | --- |
| IP | AbuseIPDB, GreyNoise (is it just internet background noise?), Shodan, passive DNS, WHOIS/ASN |
| Domain / URL | VirusTotal, passive DNS, WHOIS + registration age, certificate transparency, URLScan |
| File hash | VirusTotal, MalwareBazaar, MISP, internal sandbox — never re-upload a sensitive sample (see OPSEC) |

Grade **source reliability** and **information credibility** separately (the
Admiralty/NATO A-F / 1-6 scheme is the common shorthand) and combine independent
sources into a composite confidence. GreyNoise "benign/known-scanner" is the
cheapest false-positive killer for IPs — check it first. Enrichment *informs*
blocking; it does not authorize automated blocking of shared or CDN
infrastructure without human review.

## Analysis Over Indicators

- **Pivot on TTPs, not just atomic IOCs.** Hashes and IPs are perishable;
  behaviour persists. Extract the *how* (a scheduled task launching `rundll32`
  against a staged DLL) and hand that to detection, not just the sample hash.
- **Use analytic models to structure, not decorate.** The Diamond Model
  (adversary / capability / infrastructure / victim) organizes a campaign; the
  Cyber Kill Chain sequences it; ATT&CK gives the shared technique vocabulary.
- **Fight your own bias.** Analysis of Competing Hypotheses (ACH) forces you to
  test evidence against *alternative* explanations, not just the first story
  that fits. Attribution is where confirmation bias does the most damage.
- **Attribution is probabilistic and hard.** State it in calibrated language —
  words of estimative probability ("likely", "highly likely") with an explicit
  confidence level — and name the evidence. Infrastructure and tooling are
  shared, rented, and deliberately spoofed. Never assert attribution you cannot
  evidence, and never produce a false-flag product that misattributes activity
  to a real named third party (a hard rule under [AGENTS.md](../../AGENTS.md)).

## Collection OPSEC (do no harm while gathering)

- **Public enrichment is publication.** Uploading a file or submitting a URL to
  VirusTotal (or similar) makes it visible to other subscribers — including,
  potentially, the adversary, who may watch for their own samples. For sensitive
  or engagement-specific artifacts, query by **hash** rather than uploading, or
  use an isolated/private sandbox.
- **Do not interact with live adversary infrastructure** (resolving, browsing,
  or probing C2/phishing hosts) from attributable infrastructure — it tips the
  actor and can taint your analysis.
- **Honor TLP on inbound intel.** Do not re-share TLP:AMBER/RED beyond its
  permitted audience when you disseminate.

## Products and Dissemination

Match the product to the audience:

- **Tactical** — enriched, graded IOC package (STIX 2.1 bundle or MISP event) for tooling and SOC action.
- **Operational** — a campaign/actor report: TTPs mapped to ATT&CK, Diamond Model, targeting, and recommended detections.
- **Strategic** — a brief for leadership: sector threat landscape, trends, and risk-based recommendations, minimal jargon.

Share machine-readable intel over **STIX/TAXII** (MISP, OpenCTI as the platform
backbone). Mark every product with **TLP** (CLEAR/GREEN/AMBER/AMBER+STRICT/RED)
and record the distribution.

## Rationalizations to Reject

- *"Here are the IOCs — that's the intel."* Indicators without a requirement, sourcing, and confidence are data. Say what they mean and what to do.
- *"The infrastructure overlaps, so it's APT-X."* Overlap is a lead, not a verdict. Rent, reuse, and false flags exist. Grade the confidence and offer the alternative hypothesis.
- *"Higher confidence sounds more useful."* Overstated confidence gets people to act on air. Calibrate; unsupported certainty is a defect, not a feature.
- *"Just upload the sample to VT to check it."* That can publish an engagement artifact to the world. Query by hash first; upload only when you have decided it is safe to make public.
- *"The feed is huge, so coverage is great."* Volume is not value. An unrequirement-linked feed is noise you pay to store.

## Deliverable

```markdown
# Intel Product <TI-###>     Date: <UTC>   Analyst: <name>   TLP: <CLEAR/GREEN/AMBER/RED>
PIR addressed:    <the requirement this answers>
Type:             <tactical / operational / strategic>
BLUF:             <bottom line up front — the answer and the "so what">
Key judgments:    <each with confidence + estimative language>
Actor / campaign: <Diamond Model summary if applicable>
TTPs:             <ATT&CK techniques — behaviour, not just IOCs>
Indicators:       <enriched + graded; source + first-seen + confidence each>
Sourcing:         <reliability/credibility grades; collection provenance>
Alternatives:     <competing hypotheses considered and why rejected>
Recommendations:  <detections, mitigations, decisions enabled>
```

Log indicators, actor notes, and product provenance via
`maintaining-engagement-state`. ATT&CK reconnaissance/resource-development IDs
common to CTI collection (T1591 Gather Victim Org Info, T1589 Gather Victim
Identity Info, T1592 Gather Victim Host Info, T1593 Search Open Sources) —
re-verify against the current ATT&CK release before citing.

## Reading External Sources

Fetch advisories, actor reporting, and vendor blogs as Markdown for analysis:

```bash
curl -sL "https://defuddle.md/<url>"      # scheme in the path is optional
```

It returns full text (not a summary) so you can grep it and trust a negative.
Never route **live adversary infrastructure** (C2, phishing, malware hosting) or
**engagement/client hosts** through it — the request leaves your machine to a
third party and, for live actor infrastructure, can tip off the operator. Fetch
JSON/API responses raw.

## References

- `hunting-threats` — the consumer: hunts driven by the intel this skill produces
- `analyzing-malware`, `analyzing-network-traffic` — where tactical IOCs and TTPs are extracted
- `engineering-detections`, `writing-yara-rules`, `writing-sigma-rules` — turning TTPs into detections
- `mapping-attack-techniques` — the ATT&CK vocabulary for operational products
- MISP, OpenCTI, STIX 2.1 / TAXII; Diamond Model, Cyber Kill Chain, ACH; TLP 2.0; Admiralty grading
- CISA KEV, Abuse.ch (MalwareBazaar), AlienVault OTX, GreyNoise, VirusTotal, Shodan, passive DNS

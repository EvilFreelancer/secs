# Installed security skills

49 curated, non-overlapping Agent Skills that give the assistant expert
methodology for the full information-security lifecycle. They are loaded
automatically by any AGENTS.md/CLAUDE.md-aware agent working in this repo and are
governed by the guardrails in [../../AGENTS.md](../../AGENTS.md).

## Layout

The skill folders physically live here in `.agents/skills/`. Each is exposed to
Claude Code through a relative symlink at `.claude/skills/<name>` pointing back to
`../../.agents/skills/<name>`, matching the repo-wide convention. Edit skills
here; the symlinks pick up changes automatically.

## Sources and attribution

These skills were selected (one per capability, no duplicates) from three
open-source collections. Licenses and full skill sets belong to the upstream
projects - consult their repositories:

- **secskills** - https://github.com/trilwu/secskills (32 of the skills below);
- **ai-security-arsenal** - https://github.com/hardw00t/ai-security-arsenal (`threat-modeling`, `iac-security`, `container-security`);
- **Anthropic Cybersecurity Skills** - https://github.com/mukul975/Anthropic-Cybersecurity-Skills (14 skills, adapted into this project's house style and guardrails, not copied verbatim: `testing-mobile-applications`, `testing-ics-ot-protocols`, `producing-threat-intelligence`, `analyzing-phishing-emails`, `recognizing-deception`, `establishing-persistence`, `performing-social-engineering`, `hunting-web-backdoors`, `auditing-mcp-servers`, and the incident set `investigating-aws-incidents`, `investigating-azure-incidents`, `investigating-gcp-incidents`, `investigating-m365-entra`, `investigating-windows-endpoints`). These names were chosen to resolve cross-references the other skills already made; the remaining narrow upstream cross-references were repointed to the umbrella skill that covers them.

Before relying on any skill for a real engagement, re-read its `SKILL.md`: skills
are instructions the agent will follow, and upstream content changes over time.
Vetting on install found no injection or exfiltration content, but treat this as
a point-in-time check.

## What is installed

Planning and coordination: `maintaining-engagement-state`, `threat-modeling`,
`mapping-attack-techniques`, `orchestrating-vulnerability-research`.

Offense (recon to post-ex): `performing-reconnaissance`,
`enumerating-network-services`, `testing-web-applications`, `testing-apis`,
`testing-mobile-applications`, `testing-ics-ot-protocols`,
`attacking-active-directory`, `cracking-passwords`,
`escalating-linux-privileges`, `escalating-windows-privileges`,
`exploiting-cloud-platforms`, `attacking-wireless-networks`, `transferring-files`,
`establishing-persistence`, `recognizing-deception`, `performing-social-engineering`.

Code, binary, supply chain, AI, cloud posture: `auditing-code-for-vulnerabilities`,
`analyzing-binaries`, `reviewing-cryptography`, `auditing-supply-chain`,
`securing-ai-systems`, `iac-security`, `container-security`,
`vetting-agent-extensions`, `auditing-mcp-servers`.

Defense and DFIR: `hunting-threats`, `producing-threat-intelligence`,
`triaging-security-alerts`, `responding-to-incidents`, `analyzing-phishing-emails`,
`analyzing-malware`, `hunting-web-backdoors`, `analyzing-network-traffic`,
`analyzing-memory-images`, `investigating-windows-endpoints`,
`investigating-aws-incidents`, `investigating-azure-incidents`,
`investigating-gcp-incidents`, `investigating-m365-entra`,
`managing-vulnerabilities`, `hardening-cloud-posture`.

Detection engineering: `engineering-detections`, `writing-yara-rules`,
`writing-sigma-rules`.

Reporting: `reporting-security-findings`.

## Using these globally

These skills are scoped to this project. To make them available in every
session, symlink the real folders from `.agents/skills/` into `~/.claude/skills/`
(run from the repo root):

```bash
for d in .agents/skills/*/; do ln -s "$(pwd)/$d" "$HOME/.claude/skills/$(basename "$d")"; done
```

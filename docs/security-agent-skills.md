# Agent Skills for Information Security Work

A catalog of Agent Skills and skill collections that help AI coding agents (Claude Code, Cursor, Codex, OpenCode and others) drive the information security tools listed in [security-tools.md](security-tools.md). Skills are `SKILL.md` files that prime the agent with expert methodology, ready-to-run commands and output templates for a specific task.

> Supply-chain warning: skills are third-party instructions the agent will follow. Snyk's "ToxicSkills" research reported prompt injection in about 36% of tested skills and thousands of malicious payloads across the ecosystem. Review every `SKILL.md` before installing, prefer reputable authors, and run untrusted tooling in an isolated lab. Use these skills only for authorized testing.

## Multi-skill collections and plugins

- **SecSkills** (trilwu/secskills) - a pentesting plugin with 16 core skills and 6 subagents covering the full offensive lifecycle (recon, web/API testing, malware analysis, detection engineering, incident response); https://github.com/trilwu/secskills ;
- **AI Security Arsenal** (hardw00t) - skills, agents and workflows for mobile, web, cloud, network, code and AI/ML security, compatible with several agents; https://github.com/hardw00t/ai-security-arsenal ;
- **Transilience Community Tools** - a consolidated suite of 26 skills plus tool integrations spanning recon to reporting; https://github.com/transilienceai/communitytools ;
- **Claude Code CyberSecurity Skill** (Masriyan) - 19 skills across offensive, defensive, reverse engineering, threat hunting, OT/ICS and GRC; https://github.com/Masriyan/Claude-Code-CyberSecurity-Skill ;
- **claude-cybersecurity-skill** (pitimon) - a plugin covering 18 cybersecurity domains (IR, DFIR, DevSecOps, SOC, cloud/CSPM, OT/ICS and more); https://github.com/pitimon/claude-cybersecurity-skill ;
- **cybersecurity-skills** (briiirussell) - red, blue and purple team skills meant to be run end to end by the agent; https://github.com/briiirussell/cybersecurity-skills ;
- **claude-cybersecurity** (AgriciDaniel) - an AI security code-review skill with 8 specialist agents mapped to OWASP 2025, CWE Top 25 and MITRE ATT&CK; https://github.com/AgriciDaniel/claude-cybersecurity ;
- **Claude-Red** (SnailSploit) - a curated library of offensive skills from SQLi to shellcode, EDR evasion and exploit development; https://github.com/SnailSploit/Claude-Red ;
- **awesome-skills-security** (Eyadkelleh) - SecLists wordlists, injection payloads and expert agents for pentesting, CTFs and bug bounty; https://github.com/Eyadkelleh/awesome-skills-security ;
- **pentest-ai-agents** (0xSteph) - offensive security subagents for planning engagements, analyzing recon, researching exploits and writing reports; https://github.com/0xSteph/pentest-ai-agents ;
- **red-run** (blacklanternsecurity) - an offensive security toolkit for Claude Code from an established security firm; https://github.com/blacklanternsecurity/red-run ;
- **claude-pentest-skills** (frendysanusi) - focused web application penetration testing skills; https://github.com/frendysanusi/claude-pentest-skills ;
- **claude-pentest** (Stickman230) - an open plugin that adds offensive pentesting capability, with Kali MCP integration; https://github.com/Stickman230/claude-pentest ;
- **awesome-claude-code-subagents** (VoltAgent) - includes a dedicated penetration-tester subagent within a broad subagent library; https://github.com/VoltAgent/awesome-claude-code-subagents .

## Individual skills for specific tools

- **Nmap Network Reconnaissance** - a two-phase workflow of fast SYN discovery followed by targeted service detection and NSE scripting; https://mcpmarket.com/tools/skills/nmap-network-reconnaissance ;
- **Sliver C2** (redhound-arsenal) - build, extend and operate the Sliver C2 framework for red team operations and post-exploitation; https://lobehub.com/skills/redhoundinfosec-redhound-arsenal-sliver-c2 ;
- **network-pentest** (AI Security Arsenal) - internal network and Active Directory testing with Nmap, BloodHound, Impacket, NetExec/CrackMapExec, Responder, Mimikatz and Rubeus; https://github.com/hardw00t/ai-security-arsenal ;
- **api-security** (AI Security Arsenal) - REST and GraphQL testing with Burp Suite, Postman, graphql-cop, jwt_tool and Nuclei; https://github.com/hardw00t/ai-security-arsenal ;
- **dast-automation** (AI Security Arsenal) - automated dynamic testing with Playwright, Nuclei, ZAP, Burp and SQLMap; https://github.com/hardw00t/ai-security-arsenal ;
- **android-pentest / ios-pentest** (AI Security Arsenal) - mobile app testing with Frida, objection, apktool, jadx and class-dump; https://github.com/hardw00t/ai-security-arsenal ;
- **testing-web-applications** (SecSkills) - black-box web testing for injection, auth and SSRF with sqlmap, ffuf, gobuster, nikto and nuclei; https://github.com/trilwu/secskills ;
- **Open Redirect Vulnerabilities** (LobeHub) - a tactical checklist for finding and exploiting open redirects in web assessments; https://lobehub.com/skills/comeonoliver-skillshub-offensive-open-redirect ;
- **RCE hunting** (LobeHub) - methodology for discovering remote code execution during web app testing; https://lobehub.com/it/skills/comeonoliver-skillshub-offensive-rce .

## Defensive and DFIR skills (blue team)

- **engineering-detections** (SecSkills) - author Sigma, YARA and Suricata rules with false-positive analysis; https://github.com/trilwu/secskills ;
- **analyzing-malware** (SecSkills) - containment-first sample analysis with config and C2 extraction; https://github.com/trilwu/secskills ;
- **responding-to-incidents** (SecSkills) - DFIR methodology emphasizing evidence preservation and timelining; https://github.com/trilwu/secskills ;
- **Threat Hunting** (Masriyan) - IOC extraction, MITRE ATT&CK mapping and SIEM query libraries; https://github.com/Masriyan/Claude-Code-CyberSecurity-Skill ;
- **Log Analysis and SIEM** (Masriyan) - multi-platform query libraries, Sigma rules and anomaly detection; https://github.com/Masriyan/Claude-Code-CyberSecurity-Skill ;
- **security-scanner** (LobeHub) - scans installed plugins and skills for malicious code and injected instructions before you trust them; https://lobehub.com/skills/hiroro-work-claude-plugins-security-scanner .

## Vendor and code-review skills

- **Trail of Bits Code Audit** - static analysis with CodeQL and variant analysis for vulnerability detection; https://github.com/trailofbits/claude-skills ;
- **Trail of Bits YARA Rule Authoring** - comprehensive malware signature creation; https://github.com/trailofbits/claude-skills ;
- **Snyk Fix** - automated remediation and validation for code and dependency vulnerabilities; https://snyk.io/articles/top-claude-skills-cybersecurity-hacking-vulnerability-scanning/ ;
- **Claude Code OWASP** - a living reference for the OWASP Top 10:2025 and secure coding patterns; https://snyk.io/articles/top-claude-skills-cybersecurity-hacking-vulnerability-scanning/ ;
- **threat-modeling** (AI Security Arsenal) - STRIDE, PASTA and attack-tree modeling with OWASP Threat Dragon; https://github.com/hardw00t/ai-security-arsenal .

## Where to find and how to install

- **LobeHub Skills Marketplace** - browsable catalog with basic safety vetting; https://lobehub.com/skills ;
- **Snyk overview of top security skills** - a curated shortlist with context; https://snyk.io/articles/top-claude-skills-cybersecurity-hacking-vulnerability-scanning/ .

For Claude Code, install a skill by placing its folder under `~/.claude/skills/` (global) or `.claude/skills/` (per project), then restart the session. Most collections above can be added as a plugin or cloned directly. Always read the `SKILL.md` first.

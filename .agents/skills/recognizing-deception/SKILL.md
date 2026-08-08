---
name: recognizing-deception
description: Spot defensive deception during an authorized engagement before you trigger it — canarytokens (HTTP/DNS/AWS-key/document/Slack/kubeconfig), Active Directory honey accounts and Kerberoast bait, decoy files, and honeypots — using provenance discipline and telltale patterns so a planted tripwire does not burn the operation. Use before acting on found credentials, roasting an SPN, or opening a too-convenient file. Unattributable access is a trap until proven otherwise; if you cannot say where it came from, do not use it.
verified: 2026-08-08
---

# Recognizing Deception

Modern defenders plant tripwires whose only purpose is to fire when an intruder
touches them: a credential that has no legitimate use, an account that never logs
on, a document that phones home when opened. Because they have zero legitimate
use, any interaction is a definitive, high-fidelity compromise alert — which
makes them the cheapest way for a blue team to catch a red team. Recognizing them
is an OPSEC skill: the goal is not to disarm the defense but to avoid stepping on
it and burning the engagement. The core instinct is provenance. Access you cannot
attribute to a specific step you took is a trap until proven otherwise.

This skill is advisory judgement layered over other work — it does not add target
interaction beyond what you are already authorized to do. It pairs tightly with
credential provenance in `maintaining-engagement-state`: log where every
credential and access came from, so "I don't know where this came from" becomes a
visible stop signal rather than a shrug.

## When to Use

- Before acting on found credentials, keys, or tokens of uncertain origin
- Before Kerberoasting or AS-REP roasting an account that looks conveniently exposed
- Before opening an enticingly-named file or browsing a suspiciously discoverable share
- Before using an AWS/Slack/kube credential discovered in a repo or on a host
- Any time access appears without a step you can point to that produced it

## When NOT to Use

- **Deploying deception as the defender** — that is the inverse discipline and is out of scope here
- **Recording where a credential came from** — use `maintaining-engagement-state`; this skill decides whether to trust it, that one stores the provenance
- **The active AD attack itself** — use `attacking-active-directory`; consult this skill before you pull the trigger
- **Password attacks on a hash you already hold** — use `cracking-passwords`; check the account is not bait first
- **Cloud credential abuse** — use `exploiting-cloud-platforms`; validate the key is not a canary first

## Telltale Patterns

Defenders bait with things that look valuable and discoverable. Treat these as
deception until disproven:

| Bait | Recognition signal |
| --- | --- |
| AD honey account | `lastLogon`/`lastLogonTimestamp` null or ancient; enabled but never used; a fake SPN making it look Kerberoastable; minimal group membership; description like "do not use"; a SACL audit rule on the object |
| Canary credential (AWS/Slack/kube/Azure cert) | Valid **format** but tied to no real identity; sitting in `~/.aws/credentials`, a repo `.env`, `/root/.kube/config`; never appears in prior legitimate API/auth logs |
| Decoy document | Juicy name (`Salary-2026`, `Layoffs-DRAFT`, `passwords`) in a share where it is unused; opens fine but is oddly isolated; unusual ACLs making it conveniently readable |
| HTTP/DNS token | A URL or hostname referenced in comments, bookmarks, `/etc/hosts` with no operational use; an unusual subdomain in an otherwise consistent namespace |
| Honeypot host | Services too open, too clean, or inconsistent with the environment; a machine that answers everything and contains nothing real |

Heuristics that cut across all of them: access is **too easy** for its apparent
value; the credential/account/file has **no legitimate usage history**; naming or
placement is a shade off the environment's real conventions; and you cannot name
the step that produced the access.

## What To Do When You Suspect Bait

- **Stop before the trigger.** For canary keys, `sts:GetCallerIdentity`,
  `auth.test`, or a `kubectl get pods` is the fire event — do not run it to
  "just check." For a honey account, the Kerberos request is the alert.
- **Verify passively where possible.** Check logon history and account age in
  data you already hold, compare naming against known-good objects, and confirm
  provenance in `maintaining-engagement-state` before acting.
- **If you tripped one, say so immediately.** Tell the operator at once — a fired
  canary means the blue team likely knows you are there, which changes the
  engagement and any stealth objective. Concealing it corrupts the results.

## Rationalizations to Reject

- *"Free domain admin creds — jackpot."* Unearned, unattributable high-value access is the single most common bait. Verify provenance before you touch it.
- *"I'll just validate the key quickly."* The validation call is the trigger. There is no free check on a canary.
- *"An SPN means Kerberoast it."* A never-logged-on account with a lone SPN and a SACL is honeyuser bait; roasting it is a high-fidelity alert.
- *"The file opened fine, so it's real."* Document tokens open fine — that is the design; the callback already fired.
- *"I probably didn't trigger anything."* If you cannot say you didn't, assume you did and tell the operator.

## Deliverable

```markdown
# Deception Check <DEC-###>     Date: <UTC>   Operator: <name>
Item:             <credential / account / file / host>
Provenance:       <exact step that produced it — or "unknown">
Signals:          <which telltale patterns matched>
Assessment:       likely-bait / likely-real / undetermined   Confidence: <>
Action:           <avoided / verified-then-used / TRIGGERED — escalated at UTC>
```

Log the item and its provenance in `maintaining-engagement-state`; a triggered
tripwire is escalated to the operator immediately, not buried in the report.

## References

- `maintaining-engagement-state` — credential provenance; the backbone of this discipline
- `attacking-active-directory` — consult this before roasting or using AD objects
- `cracking-passwords` — confirm the account is not a honeyuser first
- `exploiting-cloud-platforms` — validate a cloud key is not a canary before use
- `performing-reconnaissance` — where conveniently-discoverable bait is first met
- Thinkst Canary / Canarytokens and AD honey-object practice as the deception this recognizes

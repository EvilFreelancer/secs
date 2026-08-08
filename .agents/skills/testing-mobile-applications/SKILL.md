---
name: testing-mobile-applications
description: Test Android and iOS applications for security flaws following OWASP MASVS/MASTG — insecure data storage, weak transport security and certificate pinning, broken authentication and session handling, cryptography misuse, exported-component and deep-link abuse, and client-side resilience. Use when assessing an APK/IPA, bypassing pinning to inspect API traffic, auditing on-device storage, or testing platform-specific controls. The mobile client is untrusted; the finding usually lives in what it stores, trusts, or fails to verify.
verified: 2026-08-08
---

# Testing Mobile Applications

A mobile app ships to the attacker's device. Anything it stores, hardcodes, or
trusts client-side is readable by a motivated user with a rooted phone and
Frida. So the assessment is not "can the UI be fooled" but "what does the client
hold that the server should have owned" — session tokens in plaintext
preferences, API keys in the binary, authorization decided on the handset,
pinning that a one-line hook removes. Test the client to find the server's
mistakes.

Scope and authorization gate first: confirm the package IDs (and backend API
hosts, if in scope) are on the allow-list before touching anything, per
[AGENTS.md](../../AGENTS.md). The app's backend is a separate asset — testing it
needs its own authorization, and third-party SDKs and analytics endpoints the
app talks to are out of scope unless explicitly named.

## When to Use

- Black-box or gray-box assessment of an Android or iOS application
- Auditing on-device storage (SharedPreferences, Keychain, SQLite, files) for secrets or PII
- Bypassing TLS certificate pinning to inspect the app's API traffic
- Testing authentication, session handling, and biometric/local-auth gates
- Reviewing exported components, deep links, and custom URL schemes for abuse
- Assessing root/jailbreak detection, tamper resistance, and other resilience controls

## When NOT to Use

- **The backend API itself** — use `testing-apis`; the mobile client is the lens, but auth/IDOR/mass-assignment flaws in the API are that skill's job
- **A WebView-heavy or hybrid app's web layer** — use `testing-web-applications` for the DOM/JS/XSS surface
- **Reverse-engineering a native library or recovering an algorithm** — use `analyzing-binaries` for the `.so`/Mach-O internals
- **A suspected-malicious APK/IPA** — use `analyzing-malware`; detonate for behavior, do not "pentest" it
- **Imaging a seized handset for evidence** — that is device forensics under `responding-to-incidents`, not app testing
- **Writing up what you found** — use `reporting-security-findings`

## Environment

| Component | Android | iOS |
| --- | --- | --- |
| Instrumented device | Rooted device or AVD; Magisk for hiding | Jailbroken device or Corellium |
| Runtime hooking | Frida, objection | Frida, objection, SSL Kill Switch 3 |
| Static analysis | jadx, apktool, MobSF | Ghidra/Hopper, MobSF, `otool`, `class-dump` |
| Traffic interception | Burp/mitmproxy + user CA | Burp/mitmproxy + trusted profile |

Prefer an emulator/simulator or a dedicated test device over the operator's
personal phone. Snapshot before invasive changes so the device is restorable.

## Static Analysis (QUIET — local, no target interaction)

Static review runs entirely on your workstation against the binary; it touches
no server, so it is the safe first pass.

**Android** — decompile and read the manifest before anything else:

```bash
apktool d target.apk -o apk_src/                 # resources + AndroidManifest.xml
jadx -d jadx_out/ target.apk                      # Java/Kotlin source
grep -rniE 'api[_-]?key|secret|password|token|bearer|-----BEGIN' jadx_out/
```

In `AndroidManifest.xml`: `android:exported="true"` components (activities,
services, receivers, providers) reachable by other apps, `android:debuggable`,
`android:allowBackup="true"`, and `usesCleartextTraffic`. Review the
`network_security_config.xml` for `cleartextTrafficPermitted` and trust anchors.

**iOS** — extract the IPA, then inspect the Mach-O and plists:

```bash
otool -L TargetApp                                # linked frameworks
otool -arch all -Vt TargetApp | grep -i 'PIE\|stack'   # hardening flags
plutil -p Info.plist | grep -iA3 'ATS\|NSAppTransport'  # ATS exceptions
```

MobSF automates both platforms for a first sweep — treat its output as leads to
confirm by hand, not as findings.

## Dynamic Analysis (MODERATE — device + backend interaction)

**Intercept traffic.** Route the app through Burp/mitmproxy and install the CA.
If traffic does not appear, the app pins. Remove pinning to observe the API:

```bash
# Android — Frida universal pinning bypass
frida -U -f com.target.app -l frida-multiple-unpinning.js --no-pause
# iOS — objection at launch
objection -g "Target App" explore --startup-command "ios sslpinning disable"
```

Pinning bypass proves the pin is client-side only (expected); the real finding
is whatever the now-visible traffic reveals (tokens in URLs, missing server-side
authz, weak TLS). Fuzzing or heavy replay against the backend is **LOUD** and
needs backend authorization — treat it under `testing-apis`.

**Inspect storage after exercising the app.** Log in, use features, then look:

```bash
# Android
adb shell run-as com.target.app cat shared_prefs/*.xml
adb shell run-as com.target.app sqlite3 databases/app.db '.dump'
adb logcat -d | grep -iE 'token|password|key|session'
# iOS (objection)
ios keychain dump
env NSFileProtection   # verify data-protection class on sensitive files
```

**Authentication and resilience.** Hook local-auth callbacks with Frida to force
a success return and confirm the gate is client-side only; test session timeout
and server-side token revocation; bypass root/jailbreak detection with Frida or
Magisk and confirm whether it is the app's only defense.

**Platform IPC and deep links.** Invoke exported components and URL schemes with
attacker-controlled extras:

```bash
adb shell am start -n com.target.app/.InternalActivity --es user_id admin
adb shell am start -a android.intent.action.VIEW -d "targetapp://reset?token=x"
```

## What Actually Matters (map to OWASP MASVS)

| MASVS area | High-yield checks |
| --- | --- |
| STORAGE | Secrets/PII/tokens in prefs, SQLite, plists, Keychain, logs, backups, clipboard, screenshots |
| CRYPTO | Hardcoded keys, ECB, static IVs, home-grown crypto, keys not in Keystore/Keychain |
| AUTH | Client-side authorization, biometric gate with no server check, token not invalidated server-side |
| NETWORK | Missing/broken TLS validation, cleartext endpoints, pinning as the only transport control |
| PLATFORM | Exported components, deep-link/URL-scheme abuse, WebView `addJavascriptInterface`, pasteboard leakage |
| RESILIENCE | Root/JB and tamper detection trivially bypassed, no obfuscation on a client that needs it |

Note the tester's own actions for the blue team: pinning bypass leaves Frida
artifacts (`frida-server`, gadget in memory); repeated failed logins and
anomalous device fingerprints are detectable server-side. Pair each finding with
the telemetry that would have caught it.

## Rationalizations to Reject

- *"Pinning is bypassed, so pinning is the finding."* Pinning is client-side by nature; bypassing it is the method. The finding is what the traffic then shows.
- *"It's obfuscated, so the secret is safe."* Obfuscation delays static review; Frida reads the value at runtime regardless. If the client can decrypt it, so can you.
- *"Root detection blocks me, so it's secure."* Root/JB detection is a speed bump. Report it as resilience, never as an access control.
- *"The API key is only in the app."* Every user has the app. A key in the binary is a public key.
- *"Emulator only — good enough."* Some controls (hardware-backed Keystore/Secure Enclave, attestation) behave differently on real hardware; state which you used.

## Deliverable

```markdown
# Finding <MOB-###>          Date: <UTC>   Tester: <name>
Title:            <e.g. Session token stored in cleartext SharedPreferences>
Asset:            <package id / bundle id>   Platform: Android <ver> / iOS <ver>
MASVS / MASTG:    <MASVS-STORAGE-1 / MASTG-TEST-xxxx>
CWE / OWASP:      <CWE-###>   ATT&CK (Mobile): <T####>
Severity:         <CVSS + contextual>   Device: <real / emulator, rooted/JB>
Steps:            <exact commands / hooks — reproducible>
Evidence:         <path to dump, capture, screenshot — timestamped>
Impact:           <what an attacker with the app + this flaw achieves>
Remediation:      <fix, named owner>
Detection:        <server/EDR/MDM signal the blue team could alert on>
```

Save raw artifacts as `{tool}_{package}_{YYYYMMDD_HHMMSS}.{ext}` and log the
finding via `maintaining-engagement-state`. ATT&CK Mobile IDs seen here
(T1409 stored app data, T1417 input capture, T1422 network-config discovery,
T1521.003 encrypted channel, T1633 virtualization/sandbox evasion) — re-verify
against the current ATT&CK release before citing in a report.

## Reading External Sources

Fetch MASTG pages, vendor docs, and advisories as Markdown:

```bash
curl -sL "https://defuddle.md/<url>"      # scheme in the path is optional
```

This strips boilerplate and returns full text rather than a summary. Do not
route the **target's backend URLs**, engagement hosts, or any adversary
infrastructure through it — the request leaves your machine to a third party.
Fetch JSON/API responses raw; readability extraction mangles structured data.

## References

- `testing-apis` — the backend the mobile client talks to
- `analyzing-binaries` — native `.so`/Mach-O internals and packed code
- `reporting-security-findings` — severity, PoC, and write-up
- OWASP MASVS and MASTG (Mobile Application Security Verification Standard / Testing Guide)
- Frida, objection, MobSF, jadx, apktool, Ghidra, Burp Suite as core tooling

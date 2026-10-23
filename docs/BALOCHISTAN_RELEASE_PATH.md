# LifeLink: Balochistan release path

**Working status, 15 October 2026:** suitable for a synthetic-data exhibition; **not approved for real clinical records or blood-bank operation**. This checklist distinguishes facility approval, possible software regulation, and an Android/store release. A technical build or an app-store approval does not license a blood bank.

## 1. Name the operator and intended use

- Identify the legal entity and actual clinic/blood establishment that will operate LifeLink in Balochistan. Record its address, responsible medical director, service scope, and staff roles.
- Write a short intended-use statement: what the software records, what decisions it may influence, who may use it, and which clinical decisions remain with licensed professionals. Decide whether the AI meal draft is excluded from the clinical product; do not market it as treatment advice.
- Obtain written clinical review of patient identity, donor eligibility, sample-to-patient matching, results, blood-unit traceability, release/issue, corrections, consent, downtime and adverse-event procedures. Do not use the existing volume-only inventory as a live unit ledger.

## 2. Ask the relevant authorities before processing real records

1. Contact the [Balochistan Safe Blood Transfusion Authority](https://bbta.gob.pk/) about the intended facility's registration/licence, permitted activities, inspection and record requirements. Its [2005 Rules](https://balochistan.gov.pk/wp-content/uploads/2024/11/Balochistan-Safe-Blood-Transfusion-Rules-2005-2005.pdf) include the blood-bank application form and responsible in-charge information. Ask whether a software change to record keeping must be documented in its SOPs and inspected. The facility operator, not the student app developer, must own this application.
2. Ask the [Balochistan Healthcare Commission](https://health.balochistan.gov.pk/wp-content/uploads/2025/07/Registration-form-Balochistan-Healthcare-Commission.pdf) whether the planned clinic/facility must register separately and which service category applies.
3. Send LifeLink's intended-use statement to [DRAP's medical-devices office](https://www.dra.gov.pk/medical-devices-establishments-and-products/) and seek a written classification/registration answer **before** claiming the software is or is not a regulated medical device. A record-viewing app and software that recommends treatment can be classified differently. DRAP lists a Quetta field office on its [e-services portal](https://e.dra.gov.pk/).
4. Retain correspondence, licence/certificate numbers, inspection findings and approvals in the operator's release file. The developer should not guess a licence category or represent app-store acceptance as regulatory authorization.

## 3. Complete the release gates in the repository

- Meet every clinical/security item in [PUBLIC_RELEASE_GATE.md](PUBLIC_RELEASE_GATE.md): separate child clinical identity from login, verify parent/legal-guardian authority, implement a traceable blood-unit ledger, encrypt persisted records, prove access control and audit, restore encrypted backups, and rehearse downtime/recovery with the clinic.
- Have a Pakistan-qualified lawyer/privacy lead review the actual operator, patient/child consent and authority, hosted Mumbai Supabase region and other processors, retention, correction, incident response, privacy notice and Terms. Enter the real monitored contacts through Admin Settings; demonstration placeholders are not release terms.
- Replace the FYP Gmail SMTP sender with an operator-controlled transactional email service and verify signup, staff setup and password recovery on the supported devices. Rotate credentials previously disclosed outside the server secret store. Enable Supabase leaked-password protection if the production plan supports it; review the current Security Advisor again before launch.
- Use separate synthetic staging and production projects. Review all RLS policies, Edge Functions, direct database access, auth rate limits and app roles with an independent security tester. Exercise lost-device, revoked-staff, wrong-patient, duplicate-result, retry and concurrent-stock scenarios.
- Use a clean, reviewed Git commit/tag, locked dependencies, automated tests and documented deployment/rollback. Current uncommitted work and a passing debug build are not a reproducible production release.

## 4. Build and distribute Android/iOS apps

1. Register the operator's own developer accounts and choose a unique application ID/bundle ID that the operator controls. The Android release build intentionally rejects the example ID and a missing private signing key. Keep the signing key backed up securely; do not send it in chat or commit it.
2. Finalize app name, logo rights, screenshots, support URL, published privacy policy, data deletion/contact process, age category and store listing. Build a signed Android App Bundle for Google Play; use an APK only for a controlled direct-install/test distribution. Test the release build, not just debug, on real devices.
3. Complete Google Play's [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291) and other data-safety disclosures truthfully. Google notes that blood donation and disease management are health features. If the app claims diagnosis/treatment or qualifies as a medical device, supply the applicable regulatory evidence or narrow the claim.
4. For iOS, configure the operator's Apple developer account, bundle ID, signing/provisioning, privacy disclosures, TestFlight review accounts and real-device tests. [Apple's review guidance](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review) calls for regulatory clearance or supporting evidence for medical apps making diagnostic/treatment claims.
5. Release first to a limited, supervised clinical pilot only after the facility and software clearances above. Keep incident contact, monitoring, security updates and a rollback plan active after launch. Any later rollout outside Pakistan requires a country-by-country regulatory and privacy assessment.

This document is an engineering handoff, not a legal opinion or regulatory approval. Requirements and forms change; confirm the current process with the named authorities and the facility's counsel before submission.

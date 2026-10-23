# LifeLink password recovery — operator setup

Status, 1 October 2026: application recovery UI is implemented; live Supabase recovery verification and password change passed with a disposable synthetic account. Gmail SMTP credentials are saved in the Supabase dashboard, and delivery to the operator's ordinary Gmail inbox is confirmed. The hosted Reset password template is saved and its dashboard preview contains `{{ .Token }}` with no confirmation link or localhost URL. Supabase accepted a fresh recovery-email request after that change (HTTP 200); receipt of the new code and the final on-device password change still need the inbox acceptance test below.

## Gmail setup for this FYP

Use an account owned by the project operator. Enable Google 2-Step Verification and create an App Password named LifeLink. Enter this private credential directly into Supabase, never in chat, source files, the APK, or AI secrets.

In [Authentication → Emails → SMTP Settings](https://supabase.com/dashboard/project/osqirvdgczhvnacwxfgg/auth/smtp), enable custom SMTP:

| Setting | Value |
| --- | --- |
| Sender name | LifeLink |
| Sender email | Your full FYP Gmail address |
| Host | smtp.gmail.com |
| Port | 465 |
| Username | The same full Gmail address |
| Password | Google App Password, not your normal account password |

Some Google accounts do not support App Passwords. Do not disable two-factor authentication to work around this. Gmail has sending limits and is a demonstration option; review a dedicated transactional sender before a public release.

The hosted [Reset password email template](https://supabase.com/dashboard/project/osqirvdgczhvnacwxfgg/auth/templates/reset-password) is set to subject `Your LifeLink password reset code` and the complete contents of `supabase/templates/recovery.html`. Keep `{{ .Token }}` exactly as written. This is a transactional security email; do not add marketing.

The code flow does not use a redirect URL or browser callback. Existing emails still contain their old links: request a fresh code after saving the template. Other authentication email flows, such as signup confirmation, still need their own valid deployed URL configuration; do not invent a public website or use localhost for a released app.

## Inbox acceptance test (operator)

1. Install the new app build and select **Forgot password?**.
2. Request a code for an existing account whose inbox you own.
3. Confirm the email arrives and contains a numeric code, not a localhost link.
4. Enter that code in LifeLink. Set and confirm a new password of 12–128 characters.
5. Confirm the old password fails and the new password succeeds. Do not share either password or the code.
6. Verify that reusing the code fails. Test a second mailbox outside the Supabase team to validate delivery to normal users.

The app uses a separate, non-persisted recovery client, so verifying the code does not open the normal clinical portal. Following a password change it requests global session revocation. Already-issued access tokens can remain valid until expiry; this is not a claim of instantaneous invalidation of every token. If revocation fails, the app reports it instead of claiming all devices were signed out.

The operator privacy notice now identifies Google/Gmail as the transactional email processor (recipient email, security email content, delivery metadata). Clinical records and AI drafts must never be placed into these emails.

## Evidence already obtained

A temporary, nonce-protected integration function created a marked synthetic account, called the deployed meal-plan endpoint, generated a recovery OTP without sending email, verified it, changed only that account's password, rejected the old password and reused OTP, and accepted the new password. The synthetic account was deleted. The diagnostic function was subsequently replaced with an inert HTTP 404 handler and its local private fixture file was removed.

This proves backend behavior, **not delivery of an email**. Never replace the inbox acceptance test with an admin-generated-link test.

References: [Supabase SMTP restrictions](https://supabase.com/docs/guides/auth/auth-smtp), [Google App Passwords](https://support.google.com/mail/answer/185833), [Google SMTP settings](https://support.google.com/a/answer/9003945), [Supabase email template variables](https://supabase.com/docs/guides/auth/auth-email-templates).

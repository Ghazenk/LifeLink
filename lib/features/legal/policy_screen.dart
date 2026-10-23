import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';

Map<String, String> termsSections(PolicySettings settings) => {
  'Project and eligibility':
      '${settings.operatorName} is a final-year demonstration project. This deployment is intended for Pakistan. Register only if you are 13 or older; this is a project safety rule, not a statement of Pakistan’s legal age of consent. If you are below the age of legal majority where you live, involve a parent or legal guardian before use. Do not submit information about children under 13. Age eligibility is not eligibility to donate blood.',
  'Clinical limits': 'Use synthetic data until the operator approves a real deployment. LifeLink does not provide emergency care, diagnose conditions or prescribe treatment. Clinicians must verify records, measurements and scheduling. Optional AI meal drafts are for adults only, can be wrong, and require doctor or registered-dietitian review.',
  'Accounts and permitted use': 'Provide accurate information, keep credentials private and access only records you are authorized to use. Do not impersonate others, bypass access controls, upload unlawful material or disclose other people’s information without authority. Staff must verify age and authority before importing account details.',
  'Your content and intellectual property': 'Submit only material you own or have permission to use. You retain your rights and authorize the operator to process material solely to provide the service and handle legal requests. AI output may be inaccurate, nonexclusive or infringing; no ownership or clearance is promised. See the Copyright policy to report infringement.',
  'Privacy and service providers': 'The Privacy and Cookies & storage notices describe Supabase cloud services, local storage and optional Groq/xAI processing. AI sharing is optional and requires confirmation for each request. There is no marketing or session replay SDK, paid subscription, free trial or automatic renewal in this version.',
  'Suspension, corrections and changes': 'The operator may restrict accounts for misuse, safety issues or repeated infringement, subject to review. Contact the administrator for correction, access or deletion requests. Any future charges, tracking or materially changed terms must be disclosed before use; this notice does not authorize them.',
  'Pakistan deployment': 'The operator must comply with applicable Pakistani law and the rules of the province or territory where the healthcare service operates. Software access does not license a blood bank or authorize a donation or transfusion. Qualified staff and an appropriately authorized facility must make clinical decisions. Nothing here excludes rights or remedies that cannot lawfully be excluded. Contact the operator first about complaints; applicable authorities and courts remain available.',
  'Operator contact':
      'Operator: ${settings.operatorName}\nCountry: ${settings.country.isEmpty ? 'Not configured — operator must complete before release.' : settings.country}\nContact: ${settings.email.isEmpty ? 'Not configured — contact the project administrator.' : settings.email}\nThese demonstration terms require operator/legal review for the actual jurisdiction and service.',
};

Map<String, String> copyrightSections(PolicySettings settings) => {
  'Scope': 'LifeLink accepts staff-imported account fields and displays optional AI-generated meal text. It has no public file-sharing feed or avatar uploads. Upload only material you are authorized to provide. Pakistan’s copyright law and applicable orders govern the local complaints process. This page does not claim US DMCA safe-harbor status.',
  'Send a copyright notice':
      settings.copyrightEmail.isEmpty ||
          settings.agentName.isEmpty ||
          settings.agentAddress.isEmpty ||
          settings.agentPhone.isEmpty
      ? 'The copyright contact details are incomplete. Contact the project administrator directly; do not send personal or medical records to a placeholder address. The operator must configure and monitor real notice details in Admin → Privacy & project settings before public release.'
      : 'Copyright contact: ${settings.agentName}\nEmail: ${settings.copyrightEmail}\nMailing address: ${settings.agentAddress}\nPhone: ${settings.agentPhone}\nSend notices to this agent, with “Copyright notice — LifeLink” as the subject. Do not include unrelated patient information.',
  'Required notice information': 'Include your physical or electronic signature; identify the copyrighted work (or a representative list); identify the material to remove and its precise location (screen, record reference or URL); provide your name, address, phone and email; state your good-faith belief that use is not authorized by the owner, agent or law; and confirm that the notice is accurate and that you are authorized to act for the owner. Do not send passwords or unrelated health information.',
  'Review and removal': 'The operator reviews notices promptly, removes or disables access to identified infringing material where appropriate, and notifies the submitting user when possible. Clinical records may require restricted retention and legal review rather than indiscriminate deletion. Use minimal record references when reporting private material. Notices and contact details may be shared with the affected party as needed to process the claim.',
  'Disputing removal': 'If material was removed by mistake, send the copyright contact the material reference, your contact details and evidence of authorization or misidentification. The operator reviews the dispute, applicable Pakistani law and any court orders before deciding whether to restore access. There is no automatic US counter-notice timetable for this Pakistan deployment. Do not include unrelated clinical records.',
  'Repeat infringement': 'The operator documents substantiated incidents, considers disputes and counter-notices, and terminates accounts of repeat infringers in appropriate circumstances. Administrators can restrict accounts through account management; access restrictions must preserve legally required clinical records. A report alone is not proof of infringement.',
};

class CopyrightReportLink extends StatelessWidget {
  const CopyrightReportLink({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PolicyScreen(page: 'copyright')),
    ),
    child: const Text('Report copyright infringement'),
  );
}

class PolicySettings {
  const PolicySettings({
    this.operatorName = 'LifeLink',
    this.email = '',
    this.country = 'Pakistan',
    this.agentName = '',
    this.copyrightEmail = '',
    this.agentAddress = '',
    this.agentPhone = '',
    this.retention = 'Contact the project administrator about retention and deletion. This FYP deployment has no automatic clinical-record deletion schedule.',
  });
  final String operatorName, email, country, retention;
  final String agentName, copyrightEmail, agentAddress, agentPhone;
  factory PolicySettings.fromMap(Map<String, dynamic> row) => PolicySettings(
    operatorName: row['operator_name'] as String? ?? 'LifeLink',
    email: row['privacy_email'] as String? ?? '',
    country: (row['country'] as String?)?.trim().isNotEmpty == true
        ? row['country'] as String
        : 'Pakistan',
    agentName: row['copyright_agent_name'] as String? ?? '',
    copyrightEmail: row['copyright_email'] as String? ?? '',
    agentAddress: row['copyright_address'] as String? ?? '',
    agentPhone: row['copyright_phone'] as String? ?? '',
    retention:
        row['retention_notice'] as String? ?? 'Contact the administrator.',
  );
}

final policySettingsProvider = FutureProvider<PolicySettings>((ref) async {
  final row = await SupabaseClientManager.client
      .from('app_settings')
      .select()
      .eq('id', true)
      .single();
  return PolicySettings.fromMap(row);
});

class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({super.key, this.cookies = false, this.page = 'privacy'});
  final bool cookies;
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(policySettingsProvider);
    final settings = loaded.valueOrNull ?? const PolicySettings();
    final title = cookies
        ? 'Cookies & local storage'
        : page == 'terms'
        ? 'Terms of use'
        : page == 'copyright'
        ? 'Copyright & takedowns'
        : 'Privacy notice';
    final sections = page == 'terms'
        ? termsSections(settings)
        : page == 'copyright'
        ? copyrightSections(settings)
        : cookies
        ? <String, String>{
            'Essential storage': 'LifeLink is primarily a mobile and desktop app. It uses local storage to keep you signed in, cache records you are allowed to access, and queue changes while offline. These functions are necessary for the app to work.',
            'Cookies and browser versions': 'The native app does not use advertising cookies. A browser deployment may use essential browser storage for authentication; its host may also set operational cookies. Browser deployments must be reviewed separately before release.',
            'No optional tracking enabled': 'This version does not include advertising, marketing analytics, or optional tracking SDKs. There is no optional cookie category to accept. If that changes, this notice and consent controls must be updated before those trackers run.',
            'Managing stored data': 'Signing out removes synced cached records. Unsynced changes stay on this device, isolated to the originating account, so that account can sign back in and sync them. You can remove the app’s local storage through your device settings, but doing so may permanently lose unsynced work. Use a screen lock and protect shared devices.',
          }
        : <String, String>{
            'About this project':
                '${settings.operatorName} is a final-year project for blood-bank and thalassemia care workflows. This notice describes the current implementation; it is not a certification of regulatory compliance. Use synthetic data until the operator has completed its legal, clinical, and security review.',
            'Age eligibility': 'Registration is limited to people 13 or older. We ask for an age declaration before account details and refuse new accounts without it. Staff must verify age before creating or importing an account. We store an affirmative declaration, not a date of birth. This is not independent age verification or parental consent. Do not submit information about a child under 13 through this FYP.',
            'QR and connection codes': 'Camera access is optional and requested only when you open the scanner. QR images are decoded on this device, not sent to a barcode service; temporary camera captures are deleted after decoding. Sharing codes expire after 15 minutes and identify no patient in the QR itself. Connection requests require separate approval; approval shares visits and laboratory records and can be revoked. A caregiver account or record-sharing link does not establish legal guardianship.',
            'Information used': 'The app processes account identifiers, name, email, phone number, account role, blood group, screening answers, visits, lab readings, donation and transfusion records, and guardianship requests. Passwords are handled by Supabase Auth; the app does not store plaintext passwords in the clinical database.',
            'Why information is used': 'Information supports account access, registration approval, clinic queues, clinical records, inventory accounting, approved guardianship access, and offline synchronization. Authorized staff access depends on their role. Public community impact entries do not disclose other donors’ names.',
            'Storage and service providers': 'Supabase provides cloud authentication, database, Edge Functions, and operational request logging (including IP address and request metadata). Google Gmail is configured as the SMTP provider for transactional account emails and processes the recipient email address, security-email content, and delivery metadata. Gmail is a demonstration sender for this FYP and should be replaced or formally reviewed before a public clinic deployment. The current Supabase project is hosted in ap-south-1 (Mumbai, India), outside Pakistan. Do not use real patient information until the operator has reviewed cross-border processing, provider contracts and applicable local healthcare requirements. Isar stores a device-local cache and pending changes. Session credentials use operating-system secure storage on supported native platforms. The Isar clinical cache is not encrypted by this app; device encryption and restricted device access remain necessary.',
            'Optional AI meal drafts': 'AI is optional and requires consent for each request. Only the selected cuisine and dietary preference are sent to the configured AI provider (Groq or xAI); the app does not send names, account IDs, diagnoses, blood groups, or lab records to that provider. The provider processes requests under its own terms. The AI provider receives the request text, selected model and server connection metadata, including the server IP; Supabase receives the authenticated request and quota records. Provider logging and retention may apply. Review the configured provider before enabling AI.',
            'AI limitations': 'Please confirm every draft with your doctor or registered dietitian. AI can be wrong. Drafts are general meal inspiration, not medical diets, prescriptions, or treatment. Do not use them to change medicines, supplements, iron intake, or transfusion schedules. Drafts are displayed in memory and are not saved as clinical records.',
            'Retention and deletion': settings.retention,
            'Your choices': 'You may decline AI, request correction of inaccurate details, or ask the administrator about access and deletion. Clinical records and audit history may require retention; deleting an account is not automatically the same as deleting every clinical record. Requests are handled by the operator, not an automated deletion button.',
            'Contact and deployment details':
                'Operator: ${settings.operatorName}\nCountry: ${settings.country.isEmpty ? 'Not configured' : settings.country}\nPrivacy contact: ${settings.email.isEmpty ? 'Contact the LifeLink project administrator. A privacy email has not yet been configured.' : settings.email}',
          };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (loaded.hasError)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Current operator settings could not be loaded. Default project details are shown.',
                    ),
                  ),
                Text(
                  cookies
                      ? 'Your storage, explained.'
                      : page == 'privacy'
                      ? 'Your information matters.'
                      : title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('FYP notice · version 28 September 2026'),
                const SizedBox(height: 24),
                for (final section in sections.entries) ...[
                  Text(
                    section.key,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(section.value),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PolicyLinks extends StatelessWidget {
  const PolicyLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    children: [
      for (final entry in {'terms': 'Terms', 'copyright': 'Copyright'}.entries)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PolicyScreen(page: entry.key)),
          ),
          child: Text(entry.value),
        ),
      TextButton(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PolicyScreen())),
        child: const Text('Privacy'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PolicyScreen(cookies: true)),
        ),
        child: const Text('Cookies & storage'),
      ),
    ],
  );
}

class PolicyAdminScreen extends ConsumerStatefulWidget {
  const PolicyAdminScreen({super.key});
  @override
  ConsumerState<PolicyAdminScreen> createState() => _PolicyAdminScreenState();
}

class _PolicyAdminScreenState extends ConsumerState<PolicyAdminScreen> {
  final _form = GlobalKey<FormState>();
  final _operator = TextEditingController(),
      _email = TextEditingController(),
      _country = TextEditingController(),
      _retention = TextEditingController();
  final _agentName = TextEditingController(),
      _agentEmail = TextEditingController(),
      _agentAddress = TextEditingController(),
      _agentPhone = TextEditingController();
  bool _loaded = false, _saving = false;
  @override
  void dispose() {
    _operator.dispose();
    _email.dispose();
    _country.dispose();
    _retention.dispose();
    for (final controller in [
      _agentName,
      _agentEmail,
      _agentAddress,
      _agentPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(policySettingsProvider);
    return settings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, stack) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(policySettingsProvider),
          child: const Text('Could not load settings. Retry'),
        ),
      ),
      data: (value) {
        if (!_loaded) {
          _operator.text = value.operatorName;
          _email.text = value.email;
          _country.text = value.country;
          _retention.text = value.retention;
          _agentName.text = value.agentName;
          _agentEmail.text = value.copyrightEmail;
          _agentAddress.text = value.agentAddress;
          _agentPhone.text = value.agentPhone;
          _loaded = true;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Privacy & project settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These details appear publicly on the privacy and storage pages. Do not enter credentials or patient information.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _operator,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Operator / project name',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      maxLength: 254,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Privacy contact email (optional for FYP)',
                      ),
                      validator: (v) =>
                          v != null &&
                              v.isNotEmpty &&
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _country,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _retention,
                      maxLength: 1500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Retention and deletion notice',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pakistan copyright contact — publish actual monitored details, not placeholders. US agent registration is relevant only if US DMCA protection is sought after legal review.',
                    ),
                    for (final entry in <TextEditingController, String>{
                      _agentName: 'Copyright contact name (150 characters max)',
                      _agentEmail: 'Copyright notice email',
                      _agentAddress: 'Copyright contact mailing address',
                      _agentPhone: 'Copyright contact phone',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextFormField(
                          controller: entry.key,
                          decoration: InputDecoration(labelText: entry.value),
                          maxLength: entry.key == _agentAddress
                              ? 500
                              : entry.key == _agentEmail
                              ? 254
                              : entry.key == _agentPhone
                              ? 80
                              : 150,
                          validator: (v) =>
                              entry.key == _agentEmail &&
                                  v != null &&
                                  v.isNotEmpty &&
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v.trim())
                              ? 'Enter a valid email'
                              : null,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save public details'),
                    ),
                    const SizedBox(height: 16),
                    const PolicyLinks(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseClientManager.client
          .from('app_settings')
          .update({
            'copyright_agent_name': _agentName.text.trim(),
            'copyright_email': _agentEmail.text.trim(),
            'copyright_address': _agentAddress.text.trim(),
            'copyright_phone': _agentPhone.text.trim(),
            'operator_name': _operator.text.trim(),
            'privacy_email': _email.text.trim(),
            'country': _country.text.trim(),
            'retention_notice': _retention.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', true)
          .select('id')
          .single();
      ref.invalidate(policySettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public policy details updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Settings were not saved. Check your connection and admin access.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

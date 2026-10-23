import 'package:lifelink/features/legal/age_gate.dart';
import 'package:lifelink/features/legal/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/features/auth/data/auth_repository.dart';

import 'password_recovery_screen.dart';
import 'email_verification_screen.dart';

import 'package:lifelink/core/security/password_policy.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _ageEligible = false;
  bool _termsAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'patient';
  String? _selectedBloodGroup;

  // Questionnaire state
  bool _q1DonatedRecently = false;
  bool _q2FeverInfection = false;
  bool _q3Antibiotics = false;
  bool _q4Disease = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isLogin && (!_ageEligible || !_termsAccepted)) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      if (_isLogin) {
        await repo.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        Map<String, dynamic>? medicalHistory;
        if (_selectedRole == 'donor') {
          medicalHistory = {
            'donated_recently': _q1DonatedRecently,
            'fever_infection': _q2FeverInfection,
            'taking_antibiotics': _q3Antibiotics,
            'infectious_disease': _q4Disease,
          };
        }

        final response = await repo.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          bloodGroup: _selectedRole == 'caregiver' ? null : _selectedBloodGroup,
          medicalHistory: medicalHistory,
          age13OrOlder: _ageEligible,
          termsAccepted: _termsAccepted,
        );
        if (response.session == null && mounted) {
          final verified = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: _emailController.text.trim().toLowerCase(),
              ),
            ),
          );
          if (verified != true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created, but the email is not verified. Use Verify email on the sign-in screen.',
                ),
              ),
            );
            setState(() {
              _isLogin = true;
              _passwordController.clear();
            });
            return;
          }
        }
      }
      if (!_isLogin && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified. Reception must approve your account before access is enabled.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isLogin = true;
          _passwordController.clear();
        });
      }

      // If it's a login, the Router will automatically redirect upon state change
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeading(
                              _isLogin ? 'Welcome back.' : 'Join LifeLink.',
                              _isLogin ? 'Sign in to your LifeLink account.' : 'Connect with your blood bank and care team.',
                            ),
                            if (!_isLogin && !_ageEligible)
                              AgeGate(
                                onEligible: () =>
                                    setState(() => _ageEligible = true),
                              ),
                            if (_isLogin || _ageEligible) ...[
                              if (!_isLogin) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _roleCard(
                                        'donor',
                                        'Donor',
                                        Icons.bloodtype_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _roleCard(
                                        'patient',
                                        'Patient',
                                        Icons.medical_services_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _roleCard(
                                  'caregiver',
                                  'Caregiver',
                                  Icons.family_restroom,
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (!_isLogin) ...[
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _phoneController,
                                  maxLength: 11,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number (11 digits)',
                                    prefixIcon: Icon(Icons.phone),

                                    counterText:
                                        "", // Hide the character counter
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Required';
                                    }
                                    if (v.length != 11 ||
                                        int.tryParse(v) == null) {
                                      return 'Must be exactly 11 digits';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_selectedRole != 'caregiver')
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedBloodGroup,
                                    decoration: const InputDecoration(
                                      labelText: 'Blood Group',
                                      prefixIcon: Icon(Icons.water_drop),
                                    ),
                                    items: _bloodGroups.map((bg) {
                                      return DropdownMenuItem(
                                        value: bg,
                                        child: Text(bg),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(
                                      () => _selectedBloodGroup = val,
                                    ),
                                    validator: (v) =>
                                        v == null ? 'Required' : null,
                                  ),
                                const SizedBox(height: 16),
                                if (_selectedRole == 'donor') ...[
                                  const Text(
                                    'Pre-Donation Medical Questionnaire',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    title: const Text(
                                      'Have you donated blood in the past 3 months?',
                                    ),
                                    value: _q1DonatedRecently,
                                    onChanged: (val) => setState(
                                      () => _q1DonatedRecently = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    title: const Text(
                                      'Have you had a fever or infection in the last 7 days?',
                                    ),
                                    value: _q2FeverInfection,
                                    onChanged: (val) => setState(
                                      () => _q2FeverInfection = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    title: const Text(
                                      'Are you currently taking antibiotics?',
                                    ),
                                    value: _q3Antibiotics,
                                    onChanged: (val) => setState(
                                      () => _q3Antibiotics = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    title: const Text(
                                      'Do you have a history of infectious diseases (e.g. HIV, Hepatitis)?',
                                    ),
                                    value: _q4Disease,
                                    onChanged: (val) => setState(
                                      () => _q4Disease = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],

                              TextFormField(
                                controller: _emailController,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onChanged: _isLogin
                                    ? (_) => setState(() {})
                                    : null,
                                validator: (v) => v == null || !v.contains('@')
                                    ? 'Enter a valid email address'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                autofillHints: [
                                  _isLogin
                                      ? AutofillHints.password
                                      : AutofillHints.newPassword,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) _submit();
                                },
                                validator: (v) => _isLogin
                                    ? (v == null || v.isEmpty
                                          ? 'Enter your password'
                                          : null)
                                    : PasswordPolicy.validate(v),
                              ),
                              const SizedBox(height: 24),
                              if (!_isLogin)
                                CheckboxListTile(
                                  value: _termsAccepted,
                                  onChanged: (v) => setState(
                                    () => _termsAccepted = v == true,
                                  ),
                                  title: const Text(
                                    'I agree to the Terms and acknowledge the Privacy notice linked below.',
                                  ),
                                ),
                              if (_isLogin)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    PasswordRecoveryScreen(
                                                      initialEmail:
                                                          _emailController.text
                                                              .trim(),
                                                    ),
                                              ),
                                            ),
                                      child: const Text('Forgot password?'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          _isLoading ||
                                              !_emailController.text.contains(
                                                '@',
                                              )
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    EmailVerificationScreen(
                                                      email: _emailController
                                                          .text
                                                          .trim()
                                                          .toLowerCase(),
                                                    ),
                                              ),
                                            ),
                                      child: const Text('Verify email'),
                                    ),
                                  ],
                                ),
                              FilledButton(
                                onPressed:
                                    _isLoading || (!_isLogin && !_termsAccepted)
                                    ? null
                                    : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Sign in' : 'Create account',
                                      ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                      _isLogin = !_isLogin;
                                      _ageEligible = false;
                                      _termsAccepted = false;
                                      _emailController.clear();
                                      _passwordController.clear();
                                      _fullNameController.clear();
                                      _phoneController.clear();
                                      _formKey.currentState?.reset();
                                    }),
                              child: Text(
                                _isLogin
                                    ? 'New to LifeLink? Create an account'
                                    : 'Already registered? Sign in',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            const PolicyLinks(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(String role, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedRole == role;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isLoading ? null : () => setState(() => _selectedRole = role),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

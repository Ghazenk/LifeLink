import 'package:flutter/material.dart';

/// No identity fields, network calls, or persisted answers before this gate.
class AgeGate extends StatefulWidget {
  const AgeGate({super.key, required this.onEligible, this.staff = false});
  final VoidCallback onEligible;
  final bool staff;
  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  bool _declined = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.staff
            ? 'Confirm age before entering account details'
            : 'Before you register',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Text(
        widget.staff
            ? 'Verify that this person is at least 13 before collecting their details. Do not create an account for a child under 13.'
            : 'Are you 13 or older? Please answer before entering any personal information.',
      ),
      if (_declined)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Registration is unavailable. No account details have been collected or saved. Please close this registration screen.',
          ),
        )
      else ...[
        const SizedBox(height: 24),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => setState(() => _declined = true),
          child: Text(
            widget.staff ? 'Under 13 or age not verified' : 'I am under 13',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: widget.onEligible,
          child: Text(
            widget.staff
                ? 'I verified this person is 13 or older'
                : 'I am 13 or older',
          ),
        ),
      ],
    ],
  );
}

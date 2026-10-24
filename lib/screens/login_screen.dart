import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, otp, signup }

class _LoginScreenState extends State<LoginScreen> {
  _Step step = _Step.phone;
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final referralCtrl = TextEditingController();
  String city = AppStore.cities.first;
  bool acceptedTerms = false;
  String? error;

  @override
  void dispose() {
    for (final c in [phoneCtrl, otpCtrl, nameCtrl, emailCtrl, referralCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _phone => '+92${phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';

  void _next() {
    setState(() => error = null);
    final store = StoreScope.of(context);
    switch (step) {
      case _Step.phone:
        final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
        if (digits.length != 10 || !digits.startsWith('3')) {
          setState(() => error = 'Enter a valid mobile number (3XX XXXXXXX)');
          return;
        }
        otpCtrl.clear();
        setState(() => step = _Step.otp);
      case _Step.otp:
        if (otpCtrl.text.trim() != AppStore.demoOtp) {
          setState(() => error = 'Incorrect code');
          return;
        }
        switch (store.login(_phone)) {
          case LoginResult.ok:
            break;
          case LoginResult.newUser:
            setState(() => step = _Step.signup);
          case LoginResult.blocked:
            setState(() => error = 'This account has been blocked. Please contact MIK DRIVE support.');
        }
      case _Step.signup:
        final email = emailCtrl.text.trim();
        if (nameCtrl.text.trim().length < 2) {
          setState(() => error = 'Please enter your full name');
          return;
        }
        if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          setState(() => error = 'Enter a valid email or leave it empty');
          return;
        }
        if (!acceptedTerms) {
          setState(() => error = 'Please accept the terms to continue');
          return;
        }
        final err = store.signup(
            phone: _phone, name: nameCtrl.text.trim(), email: email, city: city, referral: referralCtrl.text);
        if (err != null) setState(() => error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: step == _Step.phone
          ? null
          : AppBar(
              leading: BackButton(
                onPressed: () => setState(() {
                  error = null;
                  step = _Step.phone;
                }),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step == _Step.phone) ...[
                      const SizedBox(height: 40),
                      const MikLogo(size: 56),
                      const SizedBox(height: 32),
                    ],
                    Text(_title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_subtitle, style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 24),
                    ..._fields(),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    const Spacer(),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _next,
                      child: Text(step == _Step.signup ? 'Create account' : 'Next'),
                    ),
                    if (step == _Step.phone) ...[
                      const SizedBox(height: 16),
                      const Text('Open without login (demo)', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: _demoButton(Icons.person_outline, 'Passenger',
                              () => StoreScope.of(context).demoLogin(AppMode.passenger)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _demoButton(Icons.directions_car_outlined, 'Driver',
                              () => StoreScope.of(context).demoLogin(AppMode.driver)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _demoButton(Icons.admin_panel_settings_outlined, 'Control office',
                              () => StoreScope.of(context)
                                  .adminLogin(AppStore.adminUsername, AppStore.adminPassword)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoButton(IconData icon, String label, VoidCallback onTap) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        onPressed: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      );

  String get _title => switch (step) {
        _Step.phone => 'Enter your phone number',
        _Step.otp => 'Enter the code',
        _Step.signup => 'Create your account',
      };

  String get _subtitle => switch (step) {
        _Step.phone => 'We will send you a code by SMS',
        _Step.otp => 'Sent to $_phone · Demo code: ${AppStore.demoOtp}',
        _Step.signup => 'Drivers will see your name and rating',
      };

  List<Widget> _fields() => switch (step) {
        _Step.phone => [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(prefixText: '+92  ', hintText: '300 1234567'),
              onSubmitted: (_) => _next(),
            ),
          ],
        _Step.otp => [
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              decoration: const InputDecoration(hintText: '----', counterText: ''),
              onSubmitted: (_) => _next(),
            ),
          ],
        _Step.signup => [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: city,
              decoration: const InputDecoration(labelText: 'City'),
              items: [
                for (final c in AppStore.cities) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => city = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referralCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Referral code (optional)',
                helperText: 'Got a code from a friend? You both get Rs ${AppStore.referralBonus}',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: acceptedTerms,
              onChanged: (v) => setState(() => acceptedTerms = v ?? false),
              title: const Text('I accept the Terms of Service and Privacy Policy'),
            ),
          ],
      };
}

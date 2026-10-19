import 'package:flutter/material.dart';

import '../main.dart';
import '../store.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, otp, name }

class _LoginScreenState extends State<LoginScreen> {
  _Step step = _Step.phone;
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => error = null);
    switch (step) {
      case _Step.phone:
        final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
        if (digits.length != 10 || !digits.startsWith('3')) {
          setState(() => error = 'Enter a valid mobile number (3XX XXXXXXX)');
          return;
        }
        setState(() => step = _Step.otp);
      case _Step.otp:
        if (otpCtrl.text.trim() != AppStore.demoOtp) {
          setState(() => error = 'Incorrect code');
          return;
        }
        setState(() => step = _Step.name);
      case _Step.name:
        if (nameCtrl.text.trim().length < 2) {
          setState(() => error = 'Please enter your name');
          return;
        }
        StoreScope.of(context)
            .login('+92${phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}', nameCtrl.text.trim());
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
                  step = _Step.values[step.index - 1];
                }),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step == _Step.phone) ...[
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Go Ride',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 32),
              ],
              Text(_title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_subtitle, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              _field(),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const Spacer(),
              FilledButton(onPressed: _next, child: const Text('Next')),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => switch (step) {
        _Step.phone => 'Enter your phone number',
        _Step.otp => 'Enter the code',
        _Step.name => 'What is your name?',
      };

  String get _subtitle => switch (step) {
        _Step.phone => 'We will send you a code by SMS',
        _Step.otp => 'Demo code: ${AppStore.demoOtp}',
        _Step.name => 'Drivers will see you by this name',
      };

  Widget _field() => switch (step) {
        _Step.phone => TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(prefixText: '+92  ', hintText: '300 1234567'),
          ),
        _Step.otp => TextField(
            controller: otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            decoration: const InputDecoration(hintText: '----', counterText: ''),
          ),
        _Step.name => TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
      };
}

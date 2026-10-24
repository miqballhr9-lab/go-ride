import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final user = TextEditingController(text: AppStore.adminUsername);
  final pass = TextEditingController(text: AppStore.adminPassword);
  String? error;

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  void _login() {
    if (StoreScope.of(context).adminLogin(user.text, pass.text)) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      setState(() => error = 'Wrong username or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: Alignment.centerLeft, child: MikLogo(size: 44)),
                  const Text('Control office', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 24),
                  TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _login(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _login, child: const Text('Sign in')),
                  const SizedBox(height: 16),
                  const Text('Demo: sign in as', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                    for (final a in StoreScope.of(context).staff)
                      ActionChip(
                        label: Text(a.role.label),
                        onPressed: () {
                          user.text = a.username;
                          pass.text = a.password;
                          _login();
                        },
                      ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

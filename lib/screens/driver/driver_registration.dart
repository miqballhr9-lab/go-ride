import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Driver mode pehli dafa kholne pe registration.
class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key});

  @override
  State<DriverRegistration> createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  final _form = GlobalKey<FormState>();
  final cnic = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();

  @override
  void dispose() {
    for (final c in [cnic, model, color, plate]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Zaroori hai' : null;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    StoreScope.of(context).registerDriver(
      cnic: cnic.text.trim(),
      vehicle: Vehicle(
        model: model.text.trim(),
        color: color.text.trim(),
        plate: plate.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Driver registration')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Driver banne ke liye apni maloomat dein. Control office verify karke account approve karega.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextFormField(
              controller: cnic,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CNIC number', hintText: '35202-1234567-1'),
              validator: (v) {
                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return d.length == 13 ? null : '13 hindson ka CNIC likhein';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Gari ka model', hintText: 'Suzuki Alto'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: color,
              decoration: const InputDecoration(labelText: 'Rang', hintText: 'White'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Number plate', hintText: 'LEA-1234'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            for (final doc in ['Driving license ki photo', 'CNIC ki photo', 'Gari ki photo'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file),
                title: Text(doc),
                subtitle: const Text('Upload: Firebase lagne ke baad'),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Registration mukammal')),
          ],
        ),
      ),
    );
  }
}

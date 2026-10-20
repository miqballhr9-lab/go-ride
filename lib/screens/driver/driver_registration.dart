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
  final license = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();
  final year = TextEditingController();
  VehicleType type = VehicleType.mini;
  final Set<String> docs = {};
  String? error;

  @override
  void dispose() {
    for (final c in [cnic, license, model, color, plate, year]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _submit() {
    setState(() => error = null);
    if (!_form.currentState!.validate()) return;
    final missing = driverDocuments.where((d) => !docs.contains(d)).toList();
    if (missing.isNotEmpty) {
      setState(() => error = 'Please add: ${missing.join(', ')}');
      return;
    }
    StoreScope.of(context).registerDriver(
      cnic: cnic.text.trim(),
      licenseNo: license.text.trim().toUpperCase(),
      documents: docs,
      vehicle: Vehicle(
        type: type,
        model: model.text.trim(),
        color: color.text.trim(),
        plate: plate.text.trim().toUpperCase(),
        year: int.parse(year.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Become a driver')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Earn with Go Ride on your own schedule. Fill in your details and our team will '
                'verify your documents within 24 hours.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            const _Section('Personal details'),
            TextFormField(
              controller: cnic,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CNIC number', hintText: '35202-1234567-1'),
              validator: (v) {
                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return d.length == 13 ? null : 'Enter a 13-digit CNIC';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: license,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Driving license number'),
              validator: _required,
            ),
            const SizedBox(height: 20),
            const _Section('Vehicle'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in VehicleType.values)
                ChoiceChip(
                  avatar: Icon(vehicleIcon(t), size: 18),
                  label: Text(t.label),
                  selected: type == t,
                  onSelected: (_) => setState(() => type = t),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              type.isFreight
                  ? 'You will receive freight requests (${type.description}).'
                  : type == VehicleType.ac
                      ? 'You will receive ride requests.'
                      : 'You will receive ride and courier requests.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: model,
              decoration: InputDecoration(
                  labelText: 'Make and model',
                  hintText: switch (type) {
                    VehicleType.moto => 'Honda CD 70',
                    VehicleType.pickup => 'Suzuki Ravi',
                    VehicleType.shehzore => 'Hyundai Shehzore',
                    VehicleType.truck => 'Mazda T3500',
                    _ => 'Suzuki Alto',
                  }),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: color,
                  decoration: const InputDecoration(labelText: 'Color', hintText: 'White'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year', hintText: '2018'),
                  validator: (v) {
                    final y = int.tryParse(v ?? '');
                    final minYear = type == VehicleType.ac ? 2012 : 2005;
                    if (y == null || y > DateTime.now().year) return 'Enter a valid year';
                    if (y < minYear) return '$minYear or newer';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Number plate', hintText: 'LEA-1234'),
              validator: _required,
            ),
            const SizedBox(height: 20),
            const _Section('Documents'),
            for (final doc in driverDocuments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(docs.contains(doc) ? Icons.check_circle : Icons.add_a_photo_outlined,
                    color: docs.contains(doc) ? Colors.green : AppColors.dark),
                title: Text(doc),
                subtitle: Text(docs.contains(doc) ? 'Added' : 'Tap to add a photo'),
                trailing: docs.contains(doc)
                    ? TextButton(onPressed: () => setState(() => docs.remove(doc)), child: const Text('Remove'))
                    : null,
                // Asli app mein yahan camera/gallery khulegi aur photo Firebase Storage pe jayegi.
                onTap: () => setState(() => docs.add(doc)),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Submit application')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => store.switchMode(AppMode.passenger),
              child: const Text('Back to passenger mode'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

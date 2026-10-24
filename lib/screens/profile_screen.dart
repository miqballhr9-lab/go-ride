import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController name;
  late final TextEditingController email;
  late String city;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    final u = StoreScope.of(context).currentUser!;
    name = TextEditingController(text: u.name);
    email = TextEditingController(text: u.email);
    city = u.city;
    _init = true;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.currentUser!;
    final d = u.driver;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(children: [
              Avatar(u.name, size: 96, photo: u.photo),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Change photo',
                  style: IconButton.styleFrom(backgroundColor: AppColors.dark),
                  onPressed: () => _pickPhoto(context),
                  icon: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
          if (u.photo != null)
            Center(
              child: TextButton(onPressed: () => store.setPhoto(null), child: const Text('Remove photo')),
            ),
          const SizedBox(height: 8),
          Center(child: Text(u.phone, style: const TextStyle(color: AppColors.muted))),
          const SizedBox(height: 8),
          Center(child: RatingStars(rating: u.passengerRating, count: u.passengerRatingCount)),
          if (d != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('As driver  ', style: TextStyle(color: AppColors.muted)),
                RatingStars(rating: u.driverRating, count: u.driverRatingCount),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: AppStore.cities.contains(city) ? city : AppStore.cities.first,
            decoration: const InputDecoration(labelText: 'City'),
            items: [for (final c in AppStore.cities) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => city = v!),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (name.text.trim().length < 2) {
                showSnack(context, 'Please enter your full name');
                return;
              }
              store.updateProfile(name: name.text.trim(), email: email.text.trim(), city: city);
              showSnack(context, 'Profile saved');
            },
            child: const Text('Save'),
          ),
          if (d != null) ...[
            const SizedBox(height: 24),
            const Text('Driver account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            _row('Status', d.status.label),
            _row('Vehicle', '${d.vehicle.type.label} · ${d.vehicle}'),
            _row('Year', '${d.vehicle.year}'),
            _row('CNIC', d.cnic),
            _row('License', d.licenseNo),
          ],
          const SizedBox(height: 24),
          Text('Member since ${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(v)),
        ]),
      );

  Future<void> _pickPhoto(BuildContext context) async {
    final store = StoreScope.of(context);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (file == null) return;
      store.setPhoto(await file.readAsBytes());
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open your photos. Please allow access and try again.');
    }
  }
}

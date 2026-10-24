import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'support/support_home.dart';

// ================================================================ Settings

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: Text('${u.name} · ${u.phone}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: const Text('City'),
            subtitle: Text(u.city),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final c = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final c in AppStore.cities)
                      ListTile(
                        title: Text(c),
                        trailing: c == u.city ? const Icon(Icons.check, color: AppColors.brand) : null,
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                  ]),
                ),
              );
              if (c != null) store.updateProfile(name: u.name, email: u.email, city: c);
            },
          ),
          const _Header('App'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(u.language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final l = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                      title: const Text('English'),
                      trailing: u.language == 'English' ? const Icon(Icons.check, color: AppColors.brand) : null,
                      onTap: () => Navigator.pop(ctx, 'English'),
                    ),
                    const ListTile(
                      enabled: false,
                      title: Text('اردو (Urdu)'),
                      subtitle: Text('Coming soon'),
                    ),
                  ]),
                ),
              );
              if (l != null) store.updatePrefs(language: l);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Ride updates'),
            subtitle: const Text('Driver offers, arrival and trip status'),
            value: u.notifyRides,
            onChanged: (v) => store.updatePrefs(notifyRides: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.local_offer_outlined),
            title: const Text('Promotions'),
            subtitle: const Text('Discounts, promo codes and news'),
            value: u.notifyPromos,
            onChanged: (v) => store.updatePrefs(notifyPromos: v),
          ),
          const _Header('About'),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Terms of service'),
            subtitle: Text('Version 1.0 (demo)'),
          ),
          const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy policy')),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () {
              Navigator.pop(context);
              store.logout();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Delete account', style: TextStyle(color: AppColors.danger)),
            subtitle: const Text('Your profile and history will be removed'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete your account?'),
                  content: const Text('This removes your profile, wallet history and ride history. '
                      'You can create a new account later with the same number.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep account')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                store.deleteAccount();
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.muted)),
      );
}

// ================================================================ Help

const helpFaq = [
  ('How is the fare decided?',
      'You offer your own fare. Drivers nearby can accept it or send a counter-offer, and you choose the driver you like.'),
  ('How do I pay?', 'Pay the driver in cash at the end of the ride, or pay from your MIK DRIVE wallet.'),
  ('How do groceries work?',
      'Choose a store, add your shopping list and an estimated budget. The driver buys the items and you pay the item cost plus the fare on delivery.'),
  ('How do I book a bus?', 'Open Buses from the menu, choose the cities and date, pick a bus and the number of seats.'),
  ('I left something in the car',
      'Open Request history, find the trip, then create a support request with the category "Lost item".'),
  ('How do I become a driver?',
      'Open the menu, tap Driver mode and complete the online registration with your CNIC, license and vehicle documents.'),
  ('How does commission work for drivers?',
      'MIK DRIVE keeps a small percentage of each completed ride. It is taken from your wallet after the ride.'),
  ('How do I cancel a ride?',
      'Tap "Cancel ride" before the trip starts and choose a reason. Frequent cancellations may lower your rating.'),
  ('How do I delete my account?', 'Open Settings and tap Delete account.'),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Frequently asked questions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          for (final (q, a) in helpFaq)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(q),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(a, style: const TextStyle(color: AppColors.muted))],
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Still need help?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Our support team replies in the app, usually within a few hours.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportHome())),
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact support'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ================================================================ Drivers Academy

class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final done = store.currentUser!.driver?.completedLessons ?? <String>{};
    final progress = done.length / academyLessons.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers Academy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Learn to earn more', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${done.length} of ${academyLessons.length} lessons completed',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: progress, minHeight: 8, color: AppColors.brand, backgroundColor: Colors.white24),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final l in academyLessons)
            Card(
              elevation: 0,
              color: AppColors.surface,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: done.contains(l.id) ? AppColors.brand : Colors.white,
                  child: Icon(done.contains(l.id) ? Icons.check : Icons.play_arrow_rounded, color: AppColors.dark),
                ),
                title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${l.minutes} min read'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LessonScreen(lesson: l))),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonScreen extends StatelessWidget {
  final Lesson lesson;
  const _LessonScreen({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final done = store.currentUser!.driver?.completedLessons.contains(lesson.id) ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (i, p) in lesson.points.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.brand,
                    child: Text('${i + 1}', style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: Text(p, style: const TextStyle(fontSize: 16))),
              ]),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: store.currentUser!.driver == null
                ? null
                : () {
                    store.completeLesson(lesson.id);
                    Navigator.pop(context);
                  },
            child: Text(done ? 'Completed' : 'Mark as completed'),
          ),
        ],
      ),
    );
  }
}

// ================================================================ Online registration

/// Driver ki application, documents aur gari ki halat ek jagah.
class OnlineRegistrationScreen extends StatelessWidget {
  const OnlineRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.currentUser!;
    final d = u.driver;
    return Scaffold(
      appBar: AppBar(title: const Text('Online registration')),
      body: d == null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.edit_note, size: 64, color: AppColors.dark),
                const SizedBox(height: 12),
                const Text('You have not registered as a driver yet',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    store.switchMode(AppMode.driver);
                  },
                  child: const Text('Start registration'),
                ),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  StatusChip(
                    d.status.label,
                    switch (d.status) {
                      DriverStatus.pending => AppColors.warning,
                      DriverStatus.approved => AppColors.brand,
                      _ => AppColors.danger,
                    },
                  ),
                ]),
                if (d.rejectionReason != null) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${d.rejectionReason}', style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                _row('Vehicle', '${d.vehicle.type.label} · ${d.vehicle.color} ${d.vehicle.model} (${d.vehicle.year})'),
                _row('Number plate', d.vehicle.plate),
                _row('CNIC', d.cnic),
                _row('License', d.licenseNo),
                _row('License expiry',
                    '${d.licenseExpiry.day}/${d.licenseExpiry.month}/${d.licenseExpiry.year}${d.licenseExpired ? ' (expired)' : ''}'),
                const SizedBox(height: 16),
                const Text('Documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                for (final doc in driverDocuments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(d.documents.contains(doc) ? Icons.check_circle : Icons.error_outline,
                        color: d.documents.contains(doc) ? AppColors.brand : AppColors.danger),
                    title: Text(doc),
                    subtitle: Text(d.documents.contains(doc) ? 'Uploaded' : 'Missing'),
                  ),
                const SizedBox(height: 12),
                if (d.status == DriverStatus.rejected)
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      store.reapplyDriver();
                      store.switchMode(AppMode.driver);
                    },
                    child: const Text('Apply again'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTicketScreen())),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Update a document (send to support)'),
                  ),
              ],
            ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(v)),
        ]),
      );
}

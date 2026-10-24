import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

export '../maps/ride_map.dart';

import '../main.dart';
import '../models.dart';
import '../screens/profile_screen.dart';
import '../screens/support/support_home.dart';
import '../screens/wallet_screen.dart';
import '../screens/menu_screens.dart';
import '../screens/buses_screen.dart';
import '../store.dart';
import '../theme.dart';

/// MIK ka logo (MIK Ledger wala), naam ke saath ya akela.
class MikLogo extends StatelessWidget {
  final double size;
  final bool withName;
  final Color nameColor;
  const MikLogo({super.key, this.size = 48, this.withName = true, this.nameColor = AppColors.dark});

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset('assets/mik_logo.png', width: size, height: size, semanticLabel: 'MIK logo');
    if (!withName) return logo;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      logo,
      SizedBox(width: size * 0.25),
      Text('MIK DRIVE',
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w900, color: nameColor, letterSpacing: 0.5)),
    ]);
  }
}

String pkr(int amount) => amount < 0 ? '-Rs ${-amount}' : 'Rs $amount';

IconData serviceIcon(ServiceType s) => switch (s) {
      ServiceType.ride => Icons.directions_car,
      ServiceType.courier => Icons.inventory_2_outlined,
      ServiceType.freight => Icons.local_shipping_outlined,
      ServiceType.intercity => Icons.route,
      ServiceType.groceries => Icons.local_grocery_store_outlined,
    };

IconData vehicleIcon(VehicleType t) => switch (t) {
      VehicleType.moto => Icons.two_wheeler,
      VehicleType.rickshaw => Icons.electric_rickshaw,
      VehicleType.mini || VehicleType.ac => Icons.directions_car,
      VehicleType.comfort => Icons.directions_car_filled,
      _ => Icons.local_shipping,
    };

/// Courier aur freight ki details (passenger, driver aur admin teeno jagah).
class ServiceInfo extends StatelessWidget {
  final RideRequest ride;
  final bool showReceiverPhone;
  const ServiceInfo({super.key, required this.ride, this.showReceiverPhone = true});

  @override
  Widget build(BuildContext context) {
    final p = ride.parcel, f = ride.freight, g = ride.grocery;
    if (p == null && f == null && g == null) return const SizedBox.shrink();
    final lines = g != null
        ? [
            'Shopping list: ${g.items.join(', ')}',
            'Items budget ${pkr(g.budget)} · paid to the driver on delivery',
            if (g.note.isNotEmpty) 'Note: ${g.note}',
          ]
        : p != null
        ? [
            'Parcel: ${p.description} (${p.size.label}${p.fragile ? ', fragile' : ''})',
            'Receiver: ${p.receiverName}${showReceiverPhone ? ' · ${p.receiverPhone}' : ''}',
          ]
        : [
            'Cargo: ${f!.cargo}',
            '${f.weightKg} kg · ${f.helpers == 0 ? 'no helpers' : '${f.helpers} loading helper${f.helpers > 1 ? 's' : ''}'}',
          ];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(serviceIcon(ride.service), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in lines) Text(l, style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Pickup / drop ki line, jaise inDrive ke card mein hoti hai.
class RouteLines extends StatelessWidget {
  final Place from;
  final Place to;
  const RouteLines({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(AppColors.brand, from.name),
        const SizedBox(height: 6),
        _row(AppColors.dark, to.name),
      ],
    );
  }

  Widget _row(Color c, String text) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis)),
      ]);
}

/// Jagah chunna; `places` na diya ho to user ke sheher ki jaghein.
Future<Place?> pickPlace(BuildContext context, String title, {Place? exclude, List<Place>? places}) {
  final store = StoreScope.of(context);
  final list = places ?? store.currentCity.places;
  final city = store.currentCity.name;
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PlacePicker(title: title, exclude: exclude, places: list, city: city),
  );
}

class _PlacePicker extends StatefulWidget {
  final String title;
  final Place? exclude;
  final List<Place> places;
  final String city;
  const _PlacePicker({required this.title, this.exclude, required this.places, required this.city});

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.places
        .where((p) => p != widget.exclude && p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search for a place'),
            onChanged: (v) => setState(() => query = v),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name),
                    subtitle: Text(p.isAirport ? '${widget.city} · Airport fee applies' : widget.city),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Wajah chunne wali sheet (ride cancel, driver reject, waghera).
Future<String?> pickReason(BuildContext context, String title, List<String> reasons) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final r in reasons)
          ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
        ListTile(
          title: const Text('Go back', style: TextStyle(color: AppColors.muted)),
          onTap: () => Navigator.pop(ctx),
        ),
      ]),
    ),
  );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Uint8List? photo;
  const Avatar(this.name, {super.key, this.size = 44, this.photo});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surface,
        backgroundImage: photo == null ? null : MemoryImage(photo!),
        child: photo != null
            ? null
            : Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.4, color: AppColors.dark)),
      );
}

/// inDrive jaisi rating: sitare, number aur kitni ratings.
class RatingStars extends StatelessWidget {
  final double rating;
  final int count;
  const RatingStars({super.key, required this.rating, required this.count});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i - 0.25
                ? Icons.star_rounded
                : (rating >= i - 0.75 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: 20,
            color: AppColors.warning,
          ),
        const SizedBox(width: 6),
        Text('${rating.toStringAsFixed(2)} ($count)', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
      ]);
}

class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              iconSize: 36,
              onPressed: () => onChanged(i),
              icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.warning),
            ),
        ],
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    // Logo ke rang: hare aur peele pe navy likhai, baqi pe safed.
    final ink = (color == AppColors.brand || color == AppColors.warning) ? AppColors.dark : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Color rideStatusColor(RideStatus s) => switch (s) {
      RideStatus.completed => AppColors.brand,
      RideStatus.cancelled => AppColors.danger,
      RideStatus.searching => AppColors.warning,
      _ => AppColors.dark,
    };

void showSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// AppBar ke shuru mein back aur menu dono buttons. AppBar mein `leadingWidth: 96` ke saath.
class BackMenuLeading extends StatelessWidget {
  final VoidCallback onBack;
  const BackMenuLeading({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        if (Scaffold.maybeOf(context)?.hasDrawer ?? false)
          IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
      ]);
}

/// Social links. Aap ke page ke links yahan daalein.
const facebookUrl = '';
const instagramUrl = '';

/// Side menu, inDrive ki tarteeb mein (passenger aur driver ke alag items).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.currentUser!;
    final isDriver = store.mode == AppMode.driver;
    final rating = isDriver ? user.driverRating : user.passengerRating;
    final count = isDriver ? user.driverRatingCount : user.passengerRatingCount;
    void go(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    void service(ServiceType s) {
      Navigator.pop(context);
      store.openService(s);
    }

    void driverFilter(ServiceType? s) {
      Navigator.pop(context);
      final type = user.driver?.vehicle.type;
      if (s != null && type != null && !s.vehicles.contains(type)) {
        showSnack(context, '${s.label} needs a ${s.vehicles.map((v) => v.label).join(' or ')}. Yours is ${type.label}.');
        return;
      }
      store.setDriverFilter(s);
    }

    Widget item(IconData icon, String label, VoidCallback onTap, {bool selected = false, Widget? trailing, bool isNew = false}) =>
        ListTile(
          selected: selected,
          selectedTileColor: AppColors.surface,
          selectedColor: AppColors.dark,
          leading: isNew
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                )
              : Icon(icon, color: AppColors.muted),
          title: Text(label, style: const TextStyle(fontSize: 17)),
          trailing: trailing,
          onTap: onTap,
        );

    final unread = store.unreadNotifications;
    final bell = item(Icons.notifications_outlined, 'Notifications', () => go(const NotificationsScreen()),
        trailing: unread > 0 ? StatusChip('$unread new', AppColors.danger) : null);
    final common = [
      bell,
      item(Icons.shield_outlined, 'Safety', () => go(const SafetyScreen())),
      item(Icons.settings_outlined, 'Settings', () => go(const SettingsScreen())),
      item(Icons.info_outline, 'Help', () => go(const HelpScreen())),
      item(Icons.support_agent, 'Support', () => go(const SupportHome())),
    ];

    final items = isDriver
        ? [
            item(Icons.directions_car_outlined, 'City', () => driverFilter(null), selected: store.driverFilter == null),
            item(Icons.school_outlined, 'Drivers Academy', () => go(const AcademyScreen())),
            item(Icons.account_balance_wallet_outlined, 'Wallet', () => go(const WalletScreen()),
                trailing: Text(pkr(user.walletBalance),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: user.walletBalance < 0 ? AppColors.danger : AppColors.dark))),
            item(Icons.public, 'City to City', () => driverFilter(ServiceType.intercity),
                selected: store.driverFilter == ServiceType.intercity),
            item(Icons.local_shipping_outlined, 'Freight', () => driverFilter(ServiceType.freight),
                selected: store.driverFilter == ServiceType.freight),
            ...common,
            item(Icons.edit_note, 'Online registration', () => go(const OnlineRegistrationScreen())),
            item(Icons.card_giftcard, 'Invite a friend', () => go(const ReferralScreen())),
          ]
        : [
            item(Icons.directions_car_outlined, 'City', () => service(ServiceType.ride)),
            item(Icons.history, 'Request history', () => go(const HistoryScreen())),
            item(Icons.local_grocery_store_outlined, 'Groceries in 30 min', () => service(ServiceType.groceries),
                isNew: true),
            item(Icons.inventory_2_outlined, 'Couriers', () => service(ServiceType.courier)),
            item(Icons.public, 'City to City', () => service(ServiceType.intercity)),
            item(Icons.local_shipping_outlined, 'Freight', () => service(ServiceType.freight)),
            item(Icons.directions_bus_outlined, 'Buses', () => go(const BusesScreen())),
            item(Icons.account_balance_wallet_outlined, 'Wallet', () => go(const WalletScreen()),
                trailing: Text(pkr(user.walletBalance), style: const TextStyle(fontWeight: FontWeight.w700))),
            ...common,
            item(Icons.card_giftcard, 'Invite a friend', () => go(const ReferralScreen())),
          ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: () => go(const ProfileScreen()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
                child: Row(children: [
                  Avatar(user.name, size: 64, photo: user.photo),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                      const SizedBox(height: 4),
                      RatingStars(rating: rating, count: count),
                    ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                ...items,
                item(Icons.admin_panel_settings_outlined, 'Control office (demo)', () {
                  Navigator.pop(context);
                  // Back dabane pe isi screen pe wapas aayenge.
                  store.adminLogin(AppStore.adminUsername, AppStore.adminPassword);
                }),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: FilledButton(
                style: isDriver
                    ? FilledButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: AppColors.dark)
                    : null,
                onPressed: (store.passengerRide != null || store.driverRide != null)
                    ? null
                    : () {
                        Navigator.pop(context);
                        store.switchMode(isDriver ? AppMode.passenger : AppMode.driver);
                      },
                child: Text(isDriver ? 'Passenger mode' : 'Driver mode'),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _social(context, FontAwesomeIcons.facebookF, 'Facebook', facebookUrl),
              const SizedBox(width: 24),
              _social(context, FontAwesomeIcons.instagram, 'Instagram', instagramUrl),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _social(BuildContext context, FaIconData icon, String name, String url) => IconButton(
        tooltip: name,
        iconSize: 30,
        icon: FaIcon(icon, color: AppColors.ink),
        onPressed: () => showSnack(context, url.isEmpty ? '$name page link will be added soon' : url),
      );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.currentUser!;
    final list = store.historyFor(me.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Request history')),
      body: list.isEmpty
          ? const Center(child: Text('No rides yet', style: TextStyle(color: AppColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (_, i) {
                final r = list[i];
                final asDriver = r.driverId == me.id;
                return Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RouteLines(from: r.from, to: r.to),
                      const SizedBox(height: 6),
                      Text('${r.service.label} · ${r.vehicleType.label} · ${timeAgo(r.createdAt)} · ${asDriver ? 'as driver' : 'as passenger'}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(pkr(r.finalFare), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    StatusChip(r.status.label, rideStatusColor(r.status)),
                  ]),
                ]);
              },
            ),
    );
  }
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SafetyTip(Icons.verified_user_outlined, 'Verified drivers',
              'Every driver is checked by our team: CNIC, driving license and vehicle documents.'),
          _SafetyTip(Icons.directions_car_outlined, 'Check the car',
              'Before you get in, match the car model, color and number plate shown in the app.'),
          _SafetyTip(Icons.share_location_outlined, 'Share your trip',
              'Send your trip details to family or friends during the ride.'),
          _SafetyTip(Icons.sos_outlined, 'SOS button',
              'In an emergency, press SOS during the ride to call 15 (Police) and alert support.'),
          _SafetyTip(Icons.star_outline, 'Rate every ride',
              'Ratings help us remove drivers and passengers who break the rules.'),
        ],
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _SafetyTip(this.icon, this.title, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: AppColors.brand, child: Icon(icon, color: AppColors.dark)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
        ]),
      );
}


/// Ghanti ka button, na-parhi notifications ki ginti ke saath.
class NotificationBell extends StatelessWidget {
  final bool onMap;
  const NotificationBell({super.key, this.onMap = false});

  @override
  Widget build(BuildContext context) {
    final n = StoreScope.of(context).unreadNotifications;
    final icon = Badge(
      isLabelVisible: n > 0,
      label: Text('$n'),
      child: const Icon(Icons.notifications_outlined),
    );
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    return onMap
        ? FloatingActionButton.small(
            heroTag: 'bell', tooltip: 'Notifications', backgroundColor: Colors.white, onPressed: open, child: icon)
        : IconButton(tooltip: 'Notifications', onPressed: open, icon: icon);
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AppStore store;
  late final Set<String> unreadIds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store = StoreScope.of(context);
    final me = store.currentUser!.id;
    unreadIds = {for (final n in store.myNotifications) if (!n.readBy.contains(me)) n.id};
  }

  @override
  void dispose() {
    store.markNotificationsRead();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = StoreScope.of(context).myNotifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: list.isEmpty
          ? const Center(child: Text('No notifications', style: TextStyle(color: AppColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 20),
              itemBuilder: (_, i) {
                final n = list[i];
                final unread = unreadIds.contains(n.id);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 10),
                    child: CircleAvatar(radius: 4, backgroundColor: unread ? AppColors.danger : Colors.transparent),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(n.body),
                      const SizedBox(height: 2),
                      Text(timeAgo(n.time), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                ]);
              },
            ),
    );
  }
}

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.currentUser!;
    final invited = store.users.values.where((x) => x.referredBy == u.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.card_giftcard, size: 64),
          const SizedBox(height: 12),
          Text('Give ${pkr(AppStore.referralBonus)}, get ${pkr(AppStore.referralBonus)}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('When a friend signs up with your code, you both get a wallet bonus.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: SelectableText(u.referralCode,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: u.referralCode));
                  if (context.mounted) showSnack(context, 'Code copied');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Friends who joined (${invited.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final f in invited) ListTile(contentPadding: EdgeInsets.zero, leading: Avatar(f.name), title: Text(f.name)),
          if (invited.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No one yet. Share your code!', style: TextStyle(color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

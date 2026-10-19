import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

String pkr(int amount) => 'Rs $amount';

/// OpenStreetMap wala map (free). Pickup hara, drop kala marker.
class RideMap extends StatelessWidget {
  final Place? from;
  final Place? to;
  const RideMap({super.key, this.from, this.to});

  @override
  Widget build(BuildContext context) {
    final points = [if (from != null) from!.point, if (to != null) to!.point];
    final options = points.length == 2
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(60),
            ),
          )
        : MapOptions(
            initialCenter: points.isEmpty ? AppStore.cityCenter : points.first,
            initialZoom: 13,
          );
    return FlutterMap(
      // Key badalne se camera naye points pe chala jata hai.
      key: ValueKey('${from?.name}-${to?.name}'),
      options: options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.goride.go_ride',
        ),
        if (points.length == 2)
          PolylineLayer(polylines: [
            Polyline(points: points, strokeWidth: 5, color: AppColors.dark),
          ]),
        MarkerLayer(markers: [
          if (from != null) _marker(from!.point, AppColors.brand),
          if (to != null) _marker(to!.point, AppColors.dark),
        ]),
      ],
    );
  }

  Marker _marker(LatLng p, Color c) => Marker(
        point: p,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
          ),
        ),
      );
}

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

Future<Place?> pickPlace(BuildContext context, String title, {Place? exclude}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PlacePicker(title: title, exclude: exclude),
  );
}

class _PlacePicker extends StatefulWidget {
  final String title;
  final Place? exclude;
  const _PlacePicker({required this.title, this.exclude});

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final list = AppStore.places
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
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Jagah dhoondein'),
            onChanged: (v) => setState(() => query = v),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name),
                    subtitle: const Text('Lahore'),
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

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surface,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.4, color: AppColors.dark)),
      );
}

/// Side menu: profile, passenger/driver mode switch, history, logout.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.user!;
    final isDriver = store.mode == AppMode.driver;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Avatar(user.name, size: 52),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              subtitle: Text(user.phone),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ride history'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                store.logout();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: isDriver
                    ? FilledButton.styleFrom(backgroundColor: AppColors.dark, foregroundColor: Colors.white)
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
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ride history')),
      body: store.history.isEmpty
          ? const Center(child: Text('Abhi koi ride nahi', style: TextStyle(color: AppColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: store.history.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (_, i) {
                final r = store.history[i];
                final done = r.status == RideStatus.completed;
                return Row(children: [
                  Expanded(child: RouteLines(from: r.from, to: r.to)),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(pkr(r.finalFare), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(r.isMine ? 'Passenger' : 'Driver',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    Text(done ? 'Mukammal' : 'Cancel',
                        style: TextStyle(color: done ? Colors.green : AppColors.danger, fontSize: 12)),
                  ]),
                ]);
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'maps_config.dart';

/// Ride ka map. Google Maps key ho to Google Maps (inDrive jaisa), warna CARTO (English naam).
/// [centerPin]: inDrive ki tarah beech mein pin; map ghumane pe [onCenterChanged] milta hai.
class RideMap extends StatelessWidget {
  final Place? from;
  final Place? to;
  final List<LatLng> cars;
  final double zoom;
  final LatLng? center;
  final bool centerPin;
  final ValueChanged<LatLng>? onCenterChanged;

  const RideMap({
    super.key,
    this.from,
    this.to,
    this.cars = const [],
    this.zoom = 13,
    this.center,
    this.centerPin = false,
    this.onCenterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final map = ValueListenableBuilder<bool>(
      valueListenable: MapConfig.googleFailed,
      builder: (_, _, _) => MapConfig.useGoogle ? _GoogleMap(map: this) : _CartoMap(map: this),
    );
    if (!centerPin) return map;
    return Stack(children: [
      Positioned.fill(child: map),
      // Pin ki nok map ke beech pe
      IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
                ),
              ),
              Container(width: 3, height: 14, color: AppColors.dark),
            ]),
          ),
        ),
      ),
    ]);
  }

  List<LatLng> get _points => [
        if (from != null && !centerPin) from!.point,
        if (to != null) to!.point,
        if (centerPin && from != null && to != null) from!.point,
      ];

  LatLng get _start => from?.point ?? center ?? AppStore.cityCenter;

  /// Pin mode mein map apni jagah rehta hai (pickup badalne pe dobara center nahi hota).
  Key get _mapKey => centerPin ? ValueKey('pin-$center') : ValueKey('${from?.name}-${to?.name}-$center');
}

class _CartoMap extends StatelessWidget {
  final RideMap map;
  const _CartoMap({required this.map});

  @override
  Widget build(BuildContext context) {
    final points = map._points;
    final options = MapOptions(
      initialCameraFit: points.length == 2
          ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(60))
          : null,
      initialCenter: points.length == 2 ? points.first : map._start,
      initialZoom: map.centerPin ? 15 : map.zoom,
      onMapEvent: map.onCenterChanged == null
          ? null
          : (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd) {
                map.onCenterChanged!(e.camera.center);
              }
            },
    );
    return FlutterMap(
      key: map._mapKey,
      options: options,
      children: [
        // CARTO Voyager: OpenStreetMap ka data, magar jaghon ke naam English mein
        // (standard OSM map Pakistan mein naam Urdu mein dikhata hai). API key nahi chahiye.
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.goride.go_ride',
          maxZoom: 20,
        ),
        if (points.length == 2)
          PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 5, color: AppColors.dark)]),
        MarkerLayer(markers: [
          for (final c in map.cars) Marker(point: c, width: 28, height: 28, child: Image.asset('assets/map/car.png')),
          if (map.from != null && !map.centerPin) _pin(map.from!.point, 'pickup'),
          if (map.to != null) _pin(map.to!.point, 'drop'),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors, CARTO')),
      ],
    );
  }

  Marker _pin(LatLng p, String kind) =>
      Marker(point: p, width: 28, height: 28, child: Image.asset('assets/map/$kind.png'));
}

class _GoogleMap extends StatelessWidget {
  final RideMap map;
  const _GoogleMap({required this.map});

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);
  static final _car = gm.AssetMapBitmap('assets/map/car.png', width: 28, height: 28);
  static final _pickup = gm.AssetMapBitmap('assets/map/pickup.png', width: 28, height: 28);
  static final _drop = gm.AssetMapBitmap('assets/map/drop.png', width: 28, height: 28);

  @override
  Widget build(BuildContext context) {
    final points = map._points;
    var center = map._start;
    return gm.GoogleMap(
      key: map._mapKey,
      initialCameraPosition: gm.CameraPosition(target: _g(map._start), zoom: map.centerPin ? 15 : map.zoom),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: (c) {
        if (points.length == 2) {
          final sw = LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
            points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
          );
          final ne = LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
            points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
          );
          c.moveCamera(gm.CameraUpdate.newLatLngBounds(gm.LatLngBounds(southwest: _g(sw), northeast: _g(ne)), 60));
        }
      },
      onCameraMove: (pos) => center = LatLng(pos.target.latitude, pos.target.longitude),
      onCameraIdle: () => map.onCenterChanged?.call(center),
      markers: {
        for (final (i, c) in map.cars.indexed) gm.Marker(markerId: gm.MarkerId('car$i'), position: _g(c), icon: _car),
        if (map.from != null && !map.centerPin)
          gm.Marker(markerId: const gm.MarkerId('from'), position: _g(map.from!.point), icon: _pickup),
        if (map.to != null) gm.Marker(markerId: const gm.MarkerId('to'), position: _g(map.to!.point), icon: _drop),
      },
      polylines: {
        if (points.length == 2)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: [for (final p in points) _g(p)],
            color: AppColors.dark,
            width: 5,
          ),
      },
    );
  }
}

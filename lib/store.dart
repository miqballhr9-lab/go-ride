import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// App ki saari state. Abhi yeh demo data aur timers se backend ki
/// nakal karta hai; baad mein yahi methods Firebase se jod diye jayenge.
class AppStore extends ChangeNotifier {
  final _rand = Random();
  int _idCounter = 0;
  String _newId() => '${DateTime.now().millisecondsSinceEpoch}-${_idCounter++}';

  // ---------- Auth ----------
  AppUser? user;
  AppMode mode = AppMode.passenger;

  static const demoOtp = '1234';

  void login(String phone, String name) {
    user = AppUser(phone: phone, name: name);
    notifyListeners();
  }

  void logout() {
    _cancelTimers();
    user = null;
    mode = AppMode.passenger;
    passengerRide = null;
    driverRide = null;
    driverOnline = false;
    openRequests.clear();
    history.clear();
    notifyListeners();
  }

  void switchMode(AppMode m) {
    mode = m;
    if (m == AppMode.passenger) setDriverOnline(false);
    notifyListeners();
  }

  void registerDriver({
    required String cnic,
    required Vehicle vehicle,
  }) {
    final u = user!;
    u.cnic = cnic;
    u.vehicle = vehicle;
    // Asal app mein control office approve karega; demo mein foran approve.
    u.driverApproved = true;
    notifyListeners();
  }

  // ---------- Places & fare ----------
  static const places = <Place>[
    Place('Liberty Market', LatLng(31.5104, 74.3416)),
    Place('Mall Road', LatLng(31.5580, 74.3260)),
    Place('Anarkali Bazaar', LatLng(31.5686, 74.3140)),
    Place('Allama Iqbal Airport', LatLng(31.5216, 74.4036)),
    Place('DHA Phase 5', LatLng(31.4637, 74.4096)),
    Place('Johar Town', LatLng(31.4697, 74.2728)),
    Place('Model Town', LatLng(31.4835, 74.3256)),
    Place('Packages Mall', LatLng(31.4710, 74.3555)),
    Place('Badshahi Masjid', LatLng(31.5880, 74.3100)),
    Place('Railway Station', LatLng(31.5770, 74.3376)),
    Place('Emporium Mall', LatLng(31.4673, 74.2660)),
    Place('Gulberg Main Boulevard', LatLng(31.5204, 74.3487)),
  ];

  static const cityCenter = LatLng(31.5204, 74.3587);

  /// Mashwara kiraya (PKR): base + per km.
  static int suggestedFare(Place from, Place to) {
    final km = const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;
    final fare = 150 + km * 45;
    return max(200, (fare / 10).round() * 10);
  }

  // ---------- Passenger side ----------
  RideRequest? passengerRide;
  final List<RideRequest> history = [];
  final List<Timer> _timers = [];

  void _later(int seconds, VoidCallback fn) {
    _timers.add(Timer(Duration(seconds: seconds), fn));
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void createRequest(Place from, Place to, int fare, String comment) {
    final req = RideRequest(
      id: _newId(),
      passengerName: user!.name,
      passengerRating: 5.0,
      from: from,
      to: to,
      fare: fare,
      comment: comment,
      isMine: true,
    );
    passengerRide = req;
    notifyListeners();
    _scheduleDriverOffers(req);
  }

  void _scheduleDriverOffers(RideRequest req) {
    final count = 2 + _rand.nextInt(3);
    for (var i = 0; i < count; i++) {
      _later(2 + i * 3 + _rand.nextInt(2), () {
        if (passengerRide != req || req.status != RideStatus.searching) return;
        final d = _fakeDrivers[_rand.nextInt(_fakeDrivers.length)];
        if (req.offers.any((o) => o.driver.id == d.id)) return;
        // Kuch drivers passenger ka kiraya maan lete hain, kuch zyada maangte hain.
        final bump = [0, 0, 20, 50, 100][_rand.nextInt(5)];
        req.offers.add(Offer(
          id: _newId(),
          driver: d,
          fare: req.fare + bump,
          etaMinutes: 2 + _rand.nextInt(8),
        ));
        notifyListeners();
      });
    }
  }

  /// inDrive ki tarah: offers kam aayen to passenger kiraya barha sakta hai.
  void raiseFare(int newFare) {
    final req = passengerRide;
    if (req == null || req.status != RideStatus.searching) return;
    req.fare = newFare;
    req.offers.clear();
    notifyListeners();
    _scheduleDriverOffers(req);
  }

  void declineOffer(Offer offer) {
    passengerRide?.offers.remove(offer);
    notifyListeners();
  }

  void acceptOffer(Offer offer) {
    final req = passengerRide;
    if (req == null) return;
    req.acceptedOffer = offer;
    req.status = RideStatus.driverComing;
    notifyListeners();
    // Driver ki taraf se ride ka safar (demo).
    _later(offer.etaMinutes.clamp(3, 6), () => _setStatus(req, RideStatus.driverArrived));
    _later(offer.etaMinutes.clamp(3, 6) + 5, () => _setStatus(req, RideStatus.inProgress));
    _later(offer.etaMinutes.clamp(3, 6) + 15, () => _setStatus(req, RideStatus.completed));
  }

  void _setStatus(RideRequest req, RideStatus s) {
    if (req.status == RideStatus.cancelled || req.status == RideStatus.completed) return;
    req.status = s;
    if (s == RideStatus.completed && !history.contains(req)) history.insert(0, req);
    notifyListeners();
  }

  void cancelPassengerRide() {
    final req = passengerRide;
    if (req == null) return;
    req.status = RideStatus.cancelled;
    history.insert(0, req);
    passengerRide = null;
    notifyListeners();
  }

  void ratePassengerRide(int stars) {
    passengerRide?.rating = stars;
    passengerRide = null;
    notifyListeners();
  }

  // ---------- Driver side ----------
  bool driverOnline = false;
  final List<RideRequest> openRequests = [];
  final Set<String> _offeredRequestIds = {};
  RideRequest? driverRide;
  Timer? _requestFeed;
  int get todayEarnings => history
      .where((r) => !r.isMine && r.status == RideStatus.completed)
      .fold(0, (sum, r) => sum + r.finalFare);
  int get todayTrips =>
      history.where((r) => !r.isMine && r.status == RideStatus.completed).length;

  bool hasOffered(RideRequest r) => _offeredRequestIds.contains(r.id);

  void setDriverOnline(bool online) {
    driverOnline = online;
    _requestFeed?.cancel();
    if (online) {
      openRequests.clear();
      for (var i = 0; i < 3; i++) {
        openRequests.add(_fakePassengerRequest());
      }
      _requestFeed = Timer.periodic(const Duration(seconds: 8), (_) {
        if (driverRide != null) return;
        openRequests.insert(0, _fakePassengerRequest());
        // Purani requests khud expire ho jati hain.
        if (openRequests.length > 8) openRequests.removeLast();
        notifyListeners();
      });
    } else {
      openRequests.clear();
    }
    notifyListeners();
  }

  void skipRequest(RideRequest r) {
    openRequests.remove(r);
    notifyListeners();
  }

  /// Driver passenger ka kiraya accept kare ya apna kiraya offer kare.
  void sendDriverOffer(RideRequest req, int fare) {
    final u = user!;
    _offeredRequestIds.add(req.id);
    notifyListeners();
    final me = DriverInfo(
      id: 'me',
      name: u.name,
      rating: 5.0,
      trips: todayTrips,
      vehicle: u.vehicle!,
    );
    _later(3 + _rand.nextInt(3), () {
      if (!openRequests.contains(req) || driverRide != null) return;
      // Passenger zyada kiraye pe kabhi kabhi mana kar deta hai.
      final accepted = fare <= req.fare || _rand.nextDouble() < 0.6;
      if (!accepted) {
        openRequests.remove(req);
        notifyListeners();
        return;
      }
      req.acceptedOffer = Offer(id: _newId(), driver: me, fare: fare, etaMinutes: 5);
      req.status = RideStatus.driverComing;
      driverRide = req;
      openRequests.remove(req);
      notifyListeners();
    });
  }

  void driverArrived() => _driverStep(RideStatus.driverArrived);
  void driverStartRide() => _driverStep(RideStatus.inProgress);
  void driverCompleteRide() => _driverStep(RideStatus.completed);

  void _driverStep(RideStatus s) {
    final r = driverRide;
    if (r == null) return;
    r.status = s;
    if (s == RideStatus.completed) history.insert(0, r);
    notifyListeners();
  }

  void driverCancelRide() {
    final r = driverRide;
    if (r == null) return;
    r.status = RideStatus.cancelled;
    history.insert(0, r);
    driverRide = null;
    notifyListeners();
  }

  void closeDriverRide() {
    driverRide = null;
    notifyListeners();
  }

  // ---------- Demo data ----------
  static const _names = [
    'Ali', 'Ahmed', 'Bilal', 'Usman', 'Hamza', 'Fatima', 'Ayesha', 'Zain',
    'Sana', 'Imran', 'Kamran', 'Hira', 'Faisal', 'Nadia', 'Saad',
  ];

  static final _fakeDrivers = <DriverInfo>[
    const DriverInfo(id: 'd1', name: 'Asif', rating: 4.9, trips: 1240,
        vehicle: Vehicle(model: 'Suzuki Alto', color: 'White', plate: 'LEA-4521')),
    const DriverInfo(id: 'd2', name: 'Tariq', rating: 4.8, trips: 860,
        vehicle: Vehicle(model: 'Toyota Corolla', color: 'Silver', plate: 'LEB-1189')),
    const DriverInfo(id: 'd3', name: 'Naveed', rating: 4.7, trips: 412,
        vehicle: Vehicle(model: 'Honda City', color: 'Black', plate: 'LEC-7730')),
    const DriverInfo(id: 'd4', name: 'Shahid', rating: 4.95, trips: 2301,
        vehicle: Vehicle(model: 'Suzuki Cultus', color: 'Grey', plate: 'LED-3302')),
    const DriverInfo(id: 'd5', name: 'Rizwan', rating: 4.6, trips: 198,
        vehicle: Vehicle(model: 'Suzuki Wagon R', color: 'Blue', plate: 'LEE-9054')),
    const DriverInfo(id: 'd6', name: 'Waqas', rating: 4.85, trips: 1570,
        vehicle: Vehicle(model: 'Toyota Yaris', color: 'White', plate: 'LEF-6618')),
  ];

  RideRequest _fakePassengerRequest() {
    final from = places[_rand.nextInt(places.length)];
    Place to;
    do {
      to = places[_rand.nextInt(places.length)];
    } while (to == from);
    final suggested = suggestedFare(from, to);
    // Passenger aksar mashwara kiraye se thora kam offer karta hai.
    final fare = max(150, suggested - [0, 20, 50, 80][_rand.nextInt(4)]);
    return RideRequest(
      id: _newId(),
      passengerName: _names[_rand.nextInt(_names.length)],
      passengerRating: 4.5 + _rand.nextInt(6) / 10,
      from: from,
      to: to,
      fare: fare,
      comment: _rand.nextBool() ? '' : ['2 passengers', 'I have luggage', 'Please hurry', 'Need AC'][_rand.nextInt(4)],
      isMine: false,
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _requestFeed?.cancel();
    super.dispose();
  }
}

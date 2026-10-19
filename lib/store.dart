import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

enum LoginResult { ok, newUser, blocked }

/// App ki saari state: accounts, rides, support tickets aur control office.
/// Abhi yeh demo data aur timers se backend ki nakal karta hai; baad mein
/// yahi methods Firebase se jod diye jayenge.
class AppStore extends ChangeNotifier {
  AppStore({bool seed = true}) {
    if (seed) _seed();
  }

  final _rand = Random();
  int _idCounter = 0;
  String _newId(String prefix) => '$prefix${1000 + _idCounter++}';

  final Map<String, AppUser> users = {};
  final List<RideRequest> rides = [];
  final List<SupportTicket> tickets = [];
  FareSettings settings = FareSettings.defaults();

  final List<Timer> _timers = [];
  Timer? _requestFeed;

  void _later(int seconds, VoidCallback fn) {
    _timers.add(Timer(Duration(seconds: seconds), () {
      fn();
      notifyListeners();
    }));
  }

  AppUser userById(String id) => users[id]!;
  RideRequest? rideById(String? id) {
    if (id == null) return null;
    for (final r in rides) {
      if (r.id == id) return r;
    }
    return null;
  }

  // =========================================================== Auth
  AppUser? currentUser;
  AppMode mode = AppMode.passenger;
  bool adminLoggedIn = false;

  static const demoOtp = '1234';
  static const adminUsername = 'admin';
  static const adminPassword = 'admin123';
  static const demoPassengerPhone = '+923000000001';
  static const demoDriverPhone = '+923000000002';

  /// Demo accounts mein seedha login (OTP ke baghair).
  void demoLogin(AppMode as) {
    login(as == AppMode.driver ? demoDriverPhone : demoPassengerPhone);
    if (as == AppMode.driver) switchMode(AppMode.driver);
  }

  AppUser? userByPhone(String phone) {
    for (final u in users.values) {
      if (u.phone == phone) return u;
    }
    return null;
  }

  LoginResult login(String phone) {
    final u = userByPhone(phone);
    if (u == null) return LoginResult.newUser;
    if (u.blocked) return LoginResult.blocked;
    currentUser = u;
    mode = AppMode.passenger;
    notifyListeners();
    return LoginResult.ok;
  }

  void signup({
    required String phone,
    required String name,
    required String email,
    required String city,
  }) {
    final u = AppUser(id: _newId('U'), phone: phone, name: name, email: email, city: city);
    users[u.id] = u;
    currentUser = u;
    mode = AppMode.passenger;
    notifyListeners();
  }

  void updateProfile({required String name, required String email, required String city}) {
    final u = currentUser!;
    u.name = name;
    u.email = email;
    u.city = city;
    notifyListeners();
  }

  void logout() {
    final u = currentUser;
    if (u?.driver != null) setDriverOnline(false);
    currentUser = null;
    mode = AppMode.passenger;
    notifyListeners();
  }

  bool adminLogin(String username, String password) {
    if (username.trim() != adminUsername || password != adminPassword) return false;
    adminLoggedIn = true;
    notifyListeners();
    return true;
  }

  void adminLogout() {
    adminLoggedIn = false;
    notifyListeners();
  }

  void switchMode(AppMode m) {
    if (m == AppMode.passenger && currentUser?.driver != null) setDriverOnline(false);
    mode = m;
    notifyListeners();
  }

  // =========================================================== Places & fare
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
  static const cities = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan'];

  /// Mashwara kiraya (PKR): base + per km, kam se kam minimum.
  int suggestedFare(VehicleType type, Place from, Place to) {
    final km = const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;
    final fare = settings.baseFare[type]! + km * settings.perKm[type]!;
    return max(settings.minFare[type]!, (fare / 10).round() * 10);
  }

  /// inDrive ki tarah passenger mashwara kiraye se kam bhi offer kar sakta hai, magar had tak.
  int lowestAllowedFare(VehicleType type, Place from, Place to) =>
      max(settings.minFare[type]!, (suggestedFare(type, from, to) * 0.7 / 10).round() * 10);

  // =========================================================== Passenger
  final Map<String, String> _activePassengerRide = {};

  RideRequest? get passengerRide => rideById(_activePassengerRide[currentUser?.id]);

  void createRequest(VehicleType type, Place from, Place to, int fare, String comment) {
    final req = RideRequest(
      id: _newId('R'),
      passengerId: currentUser!.id,
      vehicleType: type,
      from: from,
      to: to,
      fare: fare,
      comment: comment,
    );
    rides.insert(0, req);
    _activePassengerRide[currentUser!.id] = req.id;
    notifyListeners();
    _scheduleBotOffers(req);
  }

  void _scheduleBotOffers(RideRequest req) {
    final drivers = users.values
        .where((u) => u.isBot && u.isApprovedDriver && u.driver!.vehicle.type == req.vehicleType)
        .toList()
      ..shuffle(_rand);
    final count = min(drivers.length, 2 + _rand.nextInt(3));
    final fareAtRequest = req.fare;
    for (var i = 0; i < count; i++) {
      final d = drivers[i];
      _later(2 + i * 3 + _rand.nextInt(2), () {
        if (req.status != RideStatus.searching || req.fare != fareAtRequest) return;
        if (req.offers.any((o) => o.driverId == d.id) || req.declinedDriverIds.contains(d.id)) return;
        // Kuch drivers passenger ka kiraya maan lete hain, kuch zyada maangte hain.
        final bump = [0, 0, 20, 50, 100][_rand.nextInt(5)];
        req.offers.add(Offer(
          id: _newId('O'),
          driverId: d.id,
          fare: req.fare + bump,
          etaMinutes: 2 + _rand.nextInt(8),
        ));
      });
    }
  }

  void raiseFare(int newFare) {
    final req = passengerRide;
    if (req == null || req.status != RideStatus.searching) return;
    req.fare = newFare;
    // Purani offers purane kiraye pe thin.
    req.offers.clear();
    notifyListeners();
    _scheduleBotOffers(req);
  }

  void declineOffer(Offer offer) {
    final req = passengerRide;
    if (req == null) return;
    req.offers.remove(offer);
    req.declinedDriverIds.add(offer.driverId);
    notifyListeners();
  }

  void acceptOffer(Offer offer) {
    final req = passengerRide;
    if (req == null || req.status != RideStatus.searching) return;
    final driver = userById(offer.driverId);
    req.acceptedOffer = offer;
    req.status = RideStatus.driverComing;
    req.offers.clear();
    notifyListeners();
    if (driver.isBot) {
      _runBotDriver(req, offer);
    } else {
      _activeDriverRide[driver.id] = req.id;
    }
  }

  void _runBotDriver(RideRequest req, Offer offer) {
    final arrive = offer.etaMinutes.clamp(3, 6);
    _later(arrive, () => _botStep(req, RideStatus.driverArrived));
    _later(arrive + 5, () => _botStep(req, RideStatus.inProgress));
    _later(arrive + 15, () => _botStep(req, RideStatus.completed));
  }

  void _botStep(RideRequest req, RideStatus s) {
    if (!req.status.isActive) return;
    req.status = s;
    if (s == RideStatus.completed) _completeRide(req);
  }

  void _completeRide(RideRequest req) {
    req.status = RideStatus.completed;
    req.completedAt = DateTime.now();
    req.commission = (req.finalFare * settings.commissionPercent / 100).round();
  }

  static const passengerCancelReasons = [
    'Driver asked me to cancel',
    'Driver is taking too long',
    'I changed my plans',
    'Wrong pickup location',
    'Other',
  ];

  static const driverCancelReasons = [
    'Passenger did not show up',
    'Passenger asked me to cancel',
    'Pickup is too far',
    'Vehicle problem',
    'Other',
  ];

  void cancelPassengerRide(String reason) {
    final req = passengerRide;
    if (req == null) return;
    req.status = RideStatus.cancelled;
    req.cancelReason = reason;
    req.cancelledBy = 'passenger';
    _activePassengerRide.remove(currentUser!.id);
    notifyListeners();
  }

  /// Ride khatam (ya driver ne cancel ki) to passenger screen band kare.
  void closePassengerRide({int? stars}) {
    final req = passengerRide;
    if (req == null) return;
    if (stars != null && req.status == RideStatus.completed && req.driverId != null) {
      req.driverRatingGiven = stars;
      final d = userById(req.driverId!);
      d.driverRatingSum += stars;
      d.driverRatingCount++;
    }
    _activePassengerRide.remove(currentUser!.id);
    notifyListeners();
  }

  // =========================================================== Chat
  static const _botReplies = ['OK', 'Theek hai', 'On my way', 'Coming in 2 minutes', 'Sure'];

  void sendChat(RideRequest ride, String text) {
    final me = currentUser!.id;
    ride.chat.add(ChatMessage(me, text));
    notifyListeners();
    final other = me == ride.passengerId ? ride.driverId : ride.passengerId;
    if (other != null && userById(other).isBot) {
      _later(2, () {
        if (ride.status.isActive) {
          ride.chat.add(ChatMessage(other, _botReplies[_rand.nextInt(_botReplies.length)]));
        }
      });
    }
  }

  // =========================================================== Driver
  final Map<String, String> _activeDriverRide = {};

  RideRequest? get driverRide => rideById(_activeDriverRide[currentUser?.id]);

  void registerDriver({
    required String cnic,
    required String licenseNo,
    required Vehicle vehicle,
    required Set<String> documents,
  }) {
    currentUser!.driver = DriverProfile(
      cnic: cnic,
      licenseNo: licenseNo,
      vehicle: vehicle,
      documents: documents,
    );
    notifyListeners();
  }

  /// Rejected driver purani application hata kar dobara form bhar sakta hai.
  void reapplyDriver() {
    currentUser!.driver = null;
    notifyListeners();
  }

  bool get driverOnline => currentUser?.driver?.online ?? false;

  void setDriverOnline(bool online) {
    final me = currentUser;
    final profile = me?.driver;
    if (profile == null) return;
    profile.online = online && profile.status == DriverStatus.approved;
    profile.location = profile.online ? _randomPointNear(cityCenter) : null;
    _requestFeed?.cancel();
    if (profile.online) {
      final type = profile.vehicle.type;
      if (openRequests.length < 3) {
        for (var i = 0; i < 3; i++) {
          _botPassengerRequest(type);
        }
      }
      _requestFeed = Timer.periodic(const Duration(seconds: 8), (_) {
        if (driverRide != null) return;
        // Purani demo requests jin pe kisi ne offer nahi di, hata do.
        final cutoff = DateTime.now().subtract(const Duration(seconds: 90));
        rides.removeWhere((r) =>
            r.status == RideStatus.searching &&
            r.createdAt.isBefore(cutoff) &&
            r.offers.isEmpty &&
            userById(r.passengerId).isBot);
        _botPassengerRequest(type);
        notifyListeners();
      });
    }
    notifyListeners();
  }

  List<RideRequest> get openRequests {
    final me = currentUser;
    final type = me?.driver?.vehicle.type;
    if (me == null || type == null) return [];
    return rides
        .where((r) =>
            r.status == RideStatus.searching &&
            r.vehicleType == type &&
            r.passengerId != me.id &&
            !r.declinedDriverIds.contains(me.id))
        .take(8)
        .toList();
  }

  bool hasOffered(RideRequest r) => r.offers.any((o) => o.driverId == currentUser?.id);

  void skipRequest(RideRequest r) {
    r.declinedDriverIds.add(currentUser!.id);
    notifyListeners();
  }

  /// Driver passenger ka kiraya accept kare ya apna kiraya offer kare.
  void sendDriverOffer(RideRequest req, int fare) {
    final me = currentUser!;
    final offer = Offer(id: _newId('O'), driverId: me.id, fare: fare, etaMinutes: 3 + _rand.nextInt(5));
    req.offers.add(offer);
    notifyListeners();
    if (!userById(req.passengerId).isBot) return; // asli passenger khud faisla karega
    _later(3 + _rand.nextInt(3), () {
      if (req.status != RideStatus.searching || _activeDriverRide.containsKey(me.id)) return;
      // Passenger zyada kiraye pe kabhi kabhi mana kar deta hai.
      final accepted = fare <= req.fare || _rand.nextDouble() < 0.6;
      req.offers.remove(offer);
      if (!accepted) {
        req.declinedDriverIds.add(me.id);
        return;
      }
      req.acceptedOffer = offer;
      req.status = RideStatus.driverComing;
      req.offers.clear();
      _activeDriverRide[me.id] = req.id;
    });
  }

  void driverArrived() => _driverStep(RideStatus.driverArrived);
  void driverStartRide() => _driverStep(RideStatus.inProgress);

  void driverCompleteRide() {
    final r = driverRide;
    if (r == null) return;
    _completeRide(r);
    final passenger = userById(r.passengerId);
    if (passenger.isBot) {
      // Demo passenger driver ko khud rating deta hai.
      final stars = 4 + _rand.nextInt(2);
      r.driverRatingGiven = stars;
      currentUser!.driverRatingSum += stars;
      currentUser!.driverRatingCount++;
    }
    notifyListeners();
  }

  void _driverStep(RideStatus s) {
    final r = driverRide;
    if (r == null || !r.status.isActive) return;
    r.status = s;
    notifyListeners();
  }

  void driverCancelRide(String reason) {
    final r = driverRide;
    if (r == null) return;
    r.status = RideStatus.cancelled;
    r.cancelReason = reason;
    r.cancelledBy = 'driver';
    _activeDriverRide.remove(currentUser!.id);
    notifyListeners();
  }

  void closeDriverRide({int? passengerStars}) {
    final r = driverRide;
    if (r == null) return;
    if (passengerStars != null && r.status == RideStatus.completed) {
      r.passengerRatingGiven = passengerStars;
      final p = userById(r.passengerId);
      p.passengerRatingSum += passengerStars;
      p.passengerRatingCount++;
    }
    _activeDriverRide.remove(currentUser!.id);
    notifyListeners();
  }

  // Driver ki kamai: pichle 24 ghante.
  Iterable<RideRequest> _myDriverRidesToday() {
    final me = currentUser?.id;
    final since = DateTime.now().subtract(const Duration(hours: 24));
    return rides.where((r) =>
        r.driverId == me && r.status == RideStatus.completed && r.completedAt!.isAfter(since));
  }

  int get todayTrips => _myDriverRidesToday().length;
  int get todayGross => _myDriverRidesToday().fold(0, (s, r) => s + r.finalFare);
  int get todayCommission => _myDriverRidesToday().fold(0, (s, r) => s + r.commission);

  // =========================================================== History
  List<RideRequest> historyFor(String userId) => rides
      .where((r) =>
          !r.status.isActive && (r.passengerId == userId || r.driverId == userId))
      .toList();

  // =========================================================== Support
  List<SupportTicket> get myTickets =>
      tickets.where((t) => t.userId == currentUser?.id).toList();

  SupportTicket createTicket({
    required String category,
    String? rideId,
    required String message,
  }) {
    final t = SupportTicket(
      id: _newId('T'),
      userId: currentUser!.id,
      role: mode,
      category: category,
      rideId: rideId,
    );
    t.messages.add(TicketMessage(fromSupport: false, text: message));
    tickets.insert(0, t);
    notifyListeners();
    _later(1, () {
      t.messages.add(TicketMessage(
        fromSupport: true,
        text: 'Thank you for contacting Go Ride support. Your ticket number is ${t.id}. '
            'Our team will reply here as soon as possible.',
      ));
    });
    return t;
  }

  void userReplyTicket(SupportTicket t, String text) {
    t.messages.add(TicketMessage(fromSupport: false, text: text));
    t.status = TicketStatus.open;
    notifyListeners();
  }

  // =========================================================== Admin
  void adminReplyTicket(SupportTicket t, String text) {
    t.messages.add(TicketMessage(fromSupport: true, text: text));
    t.status = TicketStatus.answered;
    notifyListeners();
  }

  void closeTicket(SupportTicket t) {
    t.status = TicketStatus.closed;
    notifyListeners();
  }

  void approveDriver(AppUser u) {
    u.driver!.status = DriverStatus.approved;
    u.driver!.rejectionReason = null;
    notifyListeners();
  }

  void rejectDriver(AppUser u, String reason) {
    u.driver!
      ..status = DriverStatus.rejected
      ..rejectionReason = reason
      ..online = false;
    notifyListeners();
  }

  void setDriverBlocked(AppUser u, bool blocked) {
    u.driver!
      ..status = blocked ? DriverStatus.blocked : DriverStatus.approved
      ..online = false;
    notifyListeners();
  }

  void setUserBlocked(AppUser u, bool blocked) {
    u.blocked = blocked;
    if (blocked && u.driver != null) u.driver!.online = false;
    notifyListeners();
  }

  void adminCancelRide(RideRequest r) {
    if (!r.status.isActive) return;
    r.status = RideStatus.cancelled;
    r.cancelledBy = 'admin';
    r.cancelReason = 'Cancelled by Go Ride support';
    notifyListeners();
  }

  void updateSettings(FareSettings s) {
    settings = s;
    notifyListeners();
  }

  List<AppUser> get allDrivers =>
      users.values.where((u) => u.driver != null).toList()
        ..sort((a, b) => b.driver!.submittedAt.compareTo(a.driver!.submittedAt));
  List<AppUser> get allPassengers =>
      users.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<AppUser> get pendingDrivers =>
      allDrivers.where((u) => u.driver!.status == DriverStatus.pending).toList();
  List<AppUser> get onlineDrivers =>
      allDrivers.where((u) => u.driver!.online && u.driver!.location != null).toList();

  Iterable<RideRequest> get ridesToday {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    return rides.where((r) => r.createdAt.isAfter(since));
  }

  int get completedToday => ridesToday.where((r) => r.status == RideStatus.completed).length;
  int get cancelledToday => ridesToday.where((r) => r.status == RideStatus.cancelled).length;
  int get grossToday => ridesToday
      .where((r) => r.status == RideStatus.completed)
      .fold(0, (s, r) => s + r.finalFare);
  int get commissionToday => ridesToday
      .where((r) => r.status == RideStatus.completed)
      .fold(0, (s, r) => s + r.commission);
  int get activeRides => rides.where((r) => r.status.isActive).length;
  int get openTickets => tickets.where((t) => t.status == TicketStatus.open).length;

  // =========================================================== Demo data
  static const _firstNames = [
    'Ali', 'Ahmed', 'Bilal', 'Usman', 'Hamza', 'Fatima', 'Ayesha', 'Zain',
    'Sana', 'Imran', 'Kamran', 'Hira', 'Faisal', 'Nadia', 'Saad', 'Maryam',
  ];
  static const _lastNames = ['Khan', 'Malik', 'Butt', 'Sheikh', 'Raza', 'Iqbal', 'Chaudhry', 'Qureshi'];

  LatLng _randomPointNear(LatLng c) => LatLng(
        c.latitude + (_rand.nextDouble() - 0.5) * 0.12,
        c.longitude + (_rand.nextDouble() - 0.5) * 0.14,
      );

  String _randomPhone() => '+923${_rand.nextInt(5)}${(10000000 + _rand.nextInt(89999999))}';

  AppUser _botUser(String name, {DateTime? createdAt}) {
    final u = AppUser(
      id: _newId('U'),
      phone: _randomPhone(),
      name: name,
      email: '${name.split(' ').first.toLowerCase()}@example.com',
      isBot: true,
      createdAt: createdAt,
    );
    users[u.id] = u;
    return u;
  }

  void _botPassengerRequest(VehicleType type) {
    final passengers = users.values.where((u) => u.isBot && u.driver == null).toList();
    final p = passengers[_rand.nextInt(passengers.length)];
    final from = places[_rand.nextInt(places.length)];
    Place to;
    do {
      to = places[_rand.nextInt(places.length)];
    } while (to == from);
    final suggested = suggestedFare(type, from, to);
    // Passenger aksar mashwara kiraye se thora kam offer karta hai.
    final fare = max(lowestAllowedFare(type, from, to), suggested - [0, 20, 50, 80][_rand.nextInt(4)]);
    rides.insert(
      0,
      RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        vehicleType: type,
        from: from,
        to: to,
        fare: fare,
        comment: _rand.nextBool()
            ? ''
            : ['2 passengers', 'I have luggage', 'Please hurry', 'Need AC'][_rand.nextInt(4)],
      ),
    );
  }

  void _seed() {
    final now = DateTime.now();
    String name() => '${_firstNames[_rand.nextInt(_firstNames.length)]} ${_lastNames[_rand.nextInt(_lastNames.length)]}';

    // Passengers
    for (var i = 0; i < 14; i++) {
      final u = _botUser(name(), createdAt: now.subtract(Duration(days: _rand.nextInt(200))));
      u.passengerRatingSum = (4.3 + _rand.nextDouble() * 0.7) * 10;
      u.passengerRatingCount = 10;
    }

    // Approved drivers
    const cars = {
      VehicleType.moto: ['Honda CD 70', 'Yamaha YBR 125', 'Suzuki GS 150'],
      VehicleType.mini: ['Suzuki Alto', 'Suzuki Wagon R', 'Suzuki Cultus'],
      VehicleType.ac: ['Toyota Corolla', 'Honda City', 'Toyota Yaris'],
    };
    const colors = ['White', 'Silver', 'Black', 'Grey', 'Blue'];
    Vehicle vehicle(VehicleType t) => Vehicle(
          type: t,
          model: cars[t]![_rand.nextInt(3)],
          color: colors[_rand.nextInt(colors.length)],
          plate: 'LE${String.fromCharCode(65 + _rand.nextInt(26))}-${1000 + _rand.nextInt(8999)}',
          year: 2012 + _rand.nextInt(13),
        );
    for (final t in VehicleType.values) {
      for (var i = 0; i < 5; i++) {
        final u = _botUser(name(), createdAt: now.subtract(Duration(days: 30 + _rand.nextInt(400))));
        u.driver = DriverProfile(
          cnic: '35202-${1000000 + _rand.nextInt(8999999)}-${_rand.nextInt(9)}',
          licenseNo: 'LHR-${100000 + _rand.nextInt(899999)}',
          vehicle: vehicle(t),
          documents: driverDocuments.toSet(),
          status: DriverStatus.approved,
          submittedAt: u.createdAt,
        )
          ..online = _rand.nextDouble() < 0.7
          ..location = _randomPointNear(cityCenter);
        u.driverRatingSum = (4.5 + _rand.nextDouble() * 0.5) * 50;
        u.driverRatingCount = 50;
      }
    }

    // Approval ke intezar mein drivers
    for (var i = 0; i < 3; i++) {
      final u = _botUser(name(), createdAt: now.subtract(Duration(hours: 2 + i * 7)));
      u.driver = DriverProfile(
        cnic: '35201-${1000000 + _rand.nextInt(8999999)}-${_rand.nextInt(9)}',
        licenseNo: 'LHR-${100000 + _rand.nextInt(899999)}',
        vehicle: vehicle(VehicleType.values[i]),
        documents: i == 2 ? driverDocuments.take(4).toSet() : driverDocuments.toSet(),
        submittedAt: u.createdAt,
      );
    }

    // Pichle 24 ghante ki rides
    final passengers = users.values.where((u) => u.driver == null).toList();
    final drivers = users.values.where((u) => u.isApprovedDriver).toList();
    for (var i = 0; i < 40; i++) {
      final d = drivers[_rand.nextInt(drivers.length)];
      final p = passengers[_rand.nextInt(passengers.length)];
      final from = places[_rand.nextInt(places.length)];
      var to = places[_rand.nextInt(places.length)];
      if (to == from) to = places[(places.indexOf(from) + 3) % places.length];
      final type = d.driver!.vehicle.type;
      final created = now.subtract(Duration(minutes: 30 + _rand.nextInt(60 * 23)));
      final r = RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        vehicleType: type,
        from: from,
        to: to,
        fare: suggestedFare(type, from, to),
        createdAt: created,
      );
      r.acceptedOffer = Offer(
        id: _newId('O'),
        driverId: d.id,
        fare: r.fare + [0, 0, 20, 50][_rand.nextInt(4)],
        etaMinutes: 4,
      );
      if (_rand.nextDouble() < 0.85) {
        _completeRide(r);
        r.completedAt = created.add(Duration(minutes: 15 + _rand.nextInt(30)));
        r.driverRatingGiven = 4 + _rand.nextInt(2);
      } else {
        r.status = RideStatus.cancelled;
        r.cancelledBy = _rand.nextBool() ? 'passenger' : 'driver';
        r.cancelReason = r.cancelledBy == 'passenger'
            ? passengerCancelReasons[_rand.nextInt(4)]
            : driverCancelReasons[_rand.nextInt(4)];
      }
      rides.add(r);
    }
    rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Pakke demo accounts: test karne ke liye
    final demoPassenger = AppUser(
      id: _newId('U'),
      phone: demoPassengerPhone,
      name: 'Demo Passenger',
      email: 'passenger@goride.demo',
      createdAt: now.subtract(const Duration(days: 30)),
    );
    users[demoPassenger.id] = demoPassenger;
    final demoDriver = AppUser(
      id: _newId('U'),
      phone: demoDriverPhone,
      name: 'Demo Driver',
      email: 'driver@goride.demo',
      createdAt: now.subtract(const Duration(days: 60)),
    )..driver = DriverProfile(
        cnic: '35202-1234567-1',
        licenseNo: 'LHR-123456',
        vehicle: const Vehicle(
            type: VehicleType.mini, model: 'Suzuki Alto', color: 'White', plate: 'LEA-1234', year: 2020),
        documents: driverDocuments.toSet(),
        status: DriverStatus.approved,
        submittedAt: now.subtract(const Duration(days: 60)),
      );
    users[demoDriver.id] = demoDriver;

    // Support tickets
    final samples = [
      (passengers[0], AppMode.passenger, 'Lost item', 'I left my phone charger in the car. Can you help me contact the driver?'),
      (passengers[1], AppMode.passenger, 'Fare or payment', 'The driver asked for Rs 100 more than the agreed fare.'),
      (drivers[0], AppMode.driver, 'Fare or payment', 'How do I pay my weekly commission?'),
    ];
    for (final (u, role, cat, msg) in samples) {
      final t = SupportTicket(
        id: _newId('T'),
        userId: u.id,
        role: role,
        category: cat,
        rideId: rides.firstWhere((r) => r.passengerId == u.id || r.driverId == u.id,
            orElse: () => rides.first).id,
        createdAt: now.subtract(Duration(hours: 1 + _rand.nextInt(10))),
      );
      t.messages.add(TicketMessage(fromSupport: false, text: msg, time: t.createdAt));
      tickets.add(t);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _requestFeed?.cancel();
    super.dispose();
  }
}

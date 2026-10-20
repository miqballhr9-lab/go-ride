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
  /// Parcel ke size aur freight ke mazdooron ka kharcha upar se.
  int suggestedFare(VehicleType type, Place from, Place to, {ParcelDetails? parcel, FreightDetails? freight}) {
    final km = const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;
    final fare = settings.baseFare[type]! + km * settings.perKm[type]!;
    final extras = (parcel?.size.surcharge ?? 0) + (freight?.helpers ?? 0) * helperFee;
    return max(settings.minFare[type]!, (fare / 10).round() * 10) + extras;
  }

  /// inDrive ki tarah passenger mashwara kiraye se kam bhi offer kar sakta hai, magar had tak.
  int lowestAllowedFare(VehicleType type, Place from, Place to, {ParcelDetails? parcel, FreightDetails? freight}) =>
      max(settings.minFare[type]!,
          (suggestedFare(type, from, to, parcel: parcel, freight: freight) * 0.7 / 10).round() * 10);

  // =========================================================== Passenger
  final Map<String, String> _activePassengerRide = {};

  RideRequest? get passengerRide => rideById(_activePassengerRide[currentUser?.id]);

  /// Request bhejta hai; wallet mein paise kam hon to error wapas karta hai.
  String? createRequest(
    VehicleType type,
    Place from,
    Place to,
    int fare,
    String comment, {
    ServiceType service = ServiceType.ride,
    PaymentMethod payment = PaymentMethod.cash,
    ParcelDetails? parcel,
    FreightDetails? freight,
  }) {
    if (payment == PaymentMethod.wallet && currentUser!.walletBalance < fare) {
      return 'Not enough wallet balance (${currentUser!.walletBalance}). Top up or pay cash.';
    }
    final req = RideRequest(
      id: _newId('R'),
      passengerId: currentUser!.id,
      service: service,
      vehicleType: type,
      payment: payment,
      parcel: parcel,
      freight: freight,
      from: from,
      to: to,
      fare: fare,
      comment: comment,
    );
    rides.insert(0, req);
    _activePassengerRide[currentUser!.id] = req.id;
    notifyListeners();
    _scheduleBotOffers(req);
    return null;
  }

  void _scheduleBotOffers(RideRequest req) {
    final drivers = users.values
        .where((u) =>
            u.isBot &&
            u.isApprovedDriver &&
            u.driver!.vehicle.type == req.vehicleType &&
            u.walletBalance >= minDriverBalance)
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

  void _completeRide(RideRequest req, {DateTime? at}) {
    final time = at ?? DateTime.now();
    req.status = RideStatus.completed;
    req.completedAt = time;
    req.commission = (req.finalFare * settings.commissionPercent / 100).round();
    final driverId = req.driverId!;
    if (req.payment == PaymentMethod.wallet) {
      _tx(req.passengerId, TxType.ridePayment, -req.finalFare, rideId: req.id, time: time);
      _tx(driverId, TxType.rideEarning, req.finalFare, rideId: req.id, time: time);
    }
    // inDrive ki tarah commission driver ke wallet se kat-ta hai.
    _tx(driverId, TxType.commission, -req.commission, rideId: req.id, time: time);
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
  void closePassengerRide({int? stars, String review = ''}) {
    final req = passengerRide;
    if (req == null) return;
    if (stars != null && req.status == RideStatus.completed && req.driverId != null) {
      req.driverRatingGiven = stars;
      req.driverReview = review;
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

  /// Call khatam hone pe chat mein uska record.
  void logCall(RideRequest ride, int seconds) {
    final m = seconds ~/ 60, sec = (seconds % 60).toString().padLeft(2, '0');
    ride.chat.add(ChatMessage(currentUser!.id, 'Call · $m:$sec', isCall: true));
    notifyListeners();
  }

  // =========================================================== Wallet
  final List<WalletTransaction> transactions = [];

  /// Driver ka balance minus mein ho to woh online nahi ho sakta.
  static const minDriverBalance = 0;

  WalletTransaction _tx(String userId, TxType type, int amount,
      {String? method, String? rideId, String note = '', TxStatus status = TxStatus.success, DateTime? time}) {
    final t = WalletTransaction(
      id: _newId('W'),
      userId: userId,
      type: type,
      amount: amount,
      method: method,
      rideId: rideId,
      note: note,
      status: status,
      time: time,
    );
    transactions.insert(0, t);
    if (status == TxStatus.success) users[userId]!.walletBalance += amount;
    return t;
  }

  List<WalletTransaction> transactionsFor(String userId) =>
      transactions.where((t) => t.userId == userId).toList()..sort((a, b) => b.time.compareTo(a.time));

  List<WalletTransaction> get pendingTopUps =>
      transactions.where((t) => t.type == TxType.topUp && t.status == TxStatus.pending).toList();

  /// JazzCash / Easypaisa / card foran; bank transfer control office approve karta hai.
  WalletTransaction topUp(int amount, String method, {String account = ''}) {
    final manual = method == 'Bank transfer';
    final t = _tx(currentUser!.id, TxType.topUp, amount,
        method: method, note: account, status: TxStatus.pending);
    notifyListeners();
    if (!manual) {
      // Asli app mein yahan payment gateway ka jawab aayega.
      _later(2, () => _settle(t, TxStatus.success));
    }
    return t;
  }

  void _settle(WalletTransaction t, TxStatus status) {
    if (t.status != TxStatus.pending) return;
    t.status = status;
    if (status == TxStatus.success) users[t.userId]!.walletBalance += t.amount;
  }

  void approveTopUp(WalletTransaction t) {
    _settle(t, TxStatus.success);
    notifyListeners();
  }

  void rejectTopUp(WalletTransaction t) {
    _settle(t, TxStatus.failed);
    notifyListeners();
  }

  void adjustBalance(AppUser u, int amount, String note) {
    _tx(u.id, TxType.adjustment, amount, note: note);
    notifyListeners();
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

  bool get canGoOnline => (currentUser?.walletBalance ?? 0) >= minDriverBalance;

  void setDriverOnline(bool online) {
    final me = currentUser;
    final profile = me?.driver;
    if (profile == null) return;
    profile.online = online && profile.status == DriverStatus.approved && canGoOnline;
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
      r.driverReview = _rand.nextBool() ? driverReviewTags[_rand.nextInt(driverReviewTags.length)] : '';
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

  void closeDriverRide({int? passengerStars, String review = ''}) {
    final r = driverRide;
    if (r == null) return;
    if (passengerStars != null && r.status == RideStatus.completed) {
      r.passengerRatingGiven = passengerStars;
      r.passengerReview = review;
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
    final (service, parcel, freight) = _randomService(type);
    final suggested = suggestedFare(type, from, to, parcel: parcel, freight: freight);
    // Passenger aksar mashwara kiraye se thora kam offer karta hai.
    final fare = max(lowestAllowedFare(type, from, to, parcel: parcel, freight: freight),
        suggested - [0, 20, 50, 80][_rand.nextInt(4)]);
    rides.insert(
      0,
      RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        service: service,
        vehicleType: type,
        parcel: parcel,
        freight: freight,
        payment: _rand.nextDouble() < 0.2 ? PaymentMethod.wallet : PaymentMethod.cash,
        from: from,
        to: to,
        fare: fare,
        comment: service != ServiceType.ride || _rand.nextBool()
            ? ''
            : ['2 passengers', 'I have luggage', 'Please hurry', 'Need AC'][_rand.nextInt(4)],
      ),
    );
  }

  static const _cargo = ['Household furniture', 'Fridge and washing machine', 'Construction material', 'Shop stock (boxes)', 'Office shifting'];
  static const _parcels = ['Documents', 'Lunch box', 'Mobile phone', 'Clothes', 'Medicines', 'Gift box'];

  (ServiceType, ParcelDetails?, FreightDetails?) _randomService(VehicleType type) {
    if (type.isFreight) {
      return (
        ServiceType.freight,
        null,
        FreightDetails(
          cargo: _cargo[_rand.nextInt(_cargo.length)],
          weightKg: (type.maxKg * (0.3 + _rand.nextDouble() * 0.6) / 50).round() * 50,
          helpers: _rand.nextInt(3),
        ),
      );
    }
    if ((type == VehicleType.moto || type == VehicleType.mini) && _rand.nextDouble() < 0.3) {
      return (
        ServiceType.courier,
        ParcelDetails(
          receiverName: '${_firstNames[_rand.nextInt(_firstNames.length)]} ${_lastNames[_rand.nextInt(_lastNames.length)]}',
          receiverPhone: _randomPhone(),
          size: ParcelSize.values[_rand.nextInt(type == VehicleType.moto ? 2 : 3)],
          description: _parcels[_rand.nextInt(_parcels.length)],
          fragile: _rand.nextDouble() < 0.2,
        ),
        null,
      );
    }
    return (ServiceType.ride, null, null);
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
      VehicleType.pickup: ['Suzuki Ravi', 'Suzuki Bolan pickup', 'Changan pickup'],
      VehicleType.shehzore: ['Hyundai Shehzore', 'Kia Bongo', 'JAC X200'],
      VehicleType.truck: ['Mazda T3500', 'Isuzu NKR', 'Hino 300'],
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
      for (var i = 0; i < (t.isFreight ? 3 : 5); i++) {
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
        _tx(u.id, TxType.topUp, [1000, 2000, 3000][_rand.nextInt(3)],
            method: topUpMethods[_rand.nextInt(3)], time: now.subtract(Duration(days: 1 + _rand.nextInt(5))));
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
      final (service, parcel, freight) = _randomService(type);
      final r = RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        service: service,
        vehicleType: type,
        parcel: parcel,
        freight: freight,
        from: from,
        to: to,
        fare: suggestedFare(type, from, to, parcel: parcel, freight: freight),
        createdAt: created,
      );
      r.acceptedOffer = Offer(
        id: _newId('O'),
        driverId: d.id,
        fare: r.fare + [0, 0, 20, 50][_rand.nextInt(4)],
        etaMinutes: 4,
      );
      if (_rand.nextDouble() < 0.85) {
        _completeRide(r, at: created.add(Duration(minutes: 15 + _rand.nextInt(30))));
        r.driverRatingGiven = 4 + _rand.nextInt(2);
        if (_rand.nextBool()) r.driverReview = driverReviewTags[_rand.nextInt(driverReviewTags.length)];
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
    _tx(demoPassenger.id, TxType.topUp, 1000, method: 'JazzCash', time: now.subtract(const Duration(days: 2)));
    _tx(demoDriver.id, TxType.topUp, 500, method: 'Easypaisa', time: now.subtract(const Duration(days: 1)));

    // Bank transfer wale top-up jo control office ke approval ke intezar mein hain
    for (final d in drivers.take(2)) {
      _tx(d.id, TxType.topUp, 2000,
          method: 'Bank transfer',
          note: 'Meezan Bank ref ${100000 + _rand.nextInt(899999)}',
          status: TxStatus.pending,
          time: now.subtract(Duration(hours: 1 + _rand.nextInt(5))));
    }

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

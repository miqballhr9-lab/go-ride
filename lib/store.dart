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
  final List<AuditEntry> auditLog = [];
  final List<SafetyAlert> alerts = [];
  final List<PromoCode> promos = [];
  final List<Incentive> incentives = [];
  final List<AppNotification> notifications = [];
  final List<BusTrip> busTrips = [];
  final List<BusBooking> busBookings = [];
  String bannerText = '';
  bool bannerActive = false;

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
  StaffAccount? currentStaff;
  bool get adminLoggedIn => currentStaff != null;

  static const demoOtp = '1234';
  static const adminUsername = 'admin';
  static const adminPassword = 'admin123';

  final List<StaffAccount> staff = [
    const StaffAccount(adminUsername, adminPassword, 'Ayesha (Super admin)', AdminRole.superAdmin),
    const StaffAccount('support', 'support123', 'Bilal (Support)', AdminRole.support),
    const StaffAccount('verify', 'verify123', 'Sana (Verification)', AdminRole.verification),
    const StaffAccount('finance', 'finance123', 'Usman (Finance)', AdminRole.finance),
  ];

  void addStaff(StaffAccount a) {
    staff.add(a);
    _audit('Added staff account', '${a.name} · ${a.role.label}');
    notifyListeners();
  }

  void _audit(String action, String target) {
    auditLog.insert(0, AuditEntry(currentStaff?.name ?? 'System', action, target));
  }
  static const demoPassengerPhone = '+923000000001';
  static const demoDriverPhone = '+923000000002';

  /// Demo accounts mein seedha login (OTP ke baghair).
  void demoLogin(AppMode as) {
    login(as == AppMode.driver ? demoDriverPhone : demoPassengerPhone);
    if (as == AppMode.driver) switchMode(AppMode.driver);
  }

  AppUser? userByPhone(String phone) {
    for (final u in users.values) {
      if (u.phone == phone && !u.deleted) return u;
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

  /// Naya account. Referral code sahi ho to dono ko bonus milta hai.
  String? signup({
    required String phone,
    required String name,
    required String email,
    required String city,
    String referral = '',
  }) {
    AppUser? referrer;
    if (referral.trim().isNotEmpty) {
      referrer = userByReferral(referral);
      if (referrer == null) return 'Referral code not found';
    }
    final u = AppUser(id: _newId('U'), phone: phone, name: name, email: email, city: city);
    _addUser(u);
    if (referrer != null) {
      u.referredBy = referrer.id;
      _tx(u.id, TxType.referral, referralBonus, note: 'Joined with ${referrer.referralCode}');
      _tx(referrer.id, TxType.referral, referralBonus, note: 'Invited ${u.name}');
      notify(Audience.user, 'Referral bonus', '${u.name} joined with your code. ${_pkr(referralBonus)} added to your wallet.',
          userId: referrer.id);
    }
    currentUser = u;
    mode = AppMode.passenger;
    notifyListeners();
    return null;
  }

  static const referralBonus = 100;

  void _addUser(AppUser u) {
    users[u.id] = u;
    final prefix = u.name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase().padRight(3, 'X').substring(0, 3);
    u.referralCode = '$prefix${100 + users.length}';
  }

  AppUser? userByReferral(String code) {
    final c = code.trim().toUpperCase();
    for (final u in users.values) {
      if (u.referralCode == c) return u;
    }
    return null;
  }

  static String _pkr(int v) => 'Rs $v';

  /// Menu se service kholna (City, Couriers, Groceries...): passenger home pe wahi tab.
  ServiceType? pendingService;

  void openService(ServiceType s) {
    if (mode == AppMode.driver) switchMode(AppMode.passenger);
    pendingService = s;
    notifyListeners();
  }

  ServiceType? takePendingService() {
    final s = pendingService;
    pendingService = null;
    return s;
  }

  void setPhoto(Uint8List? bytes) {
    currentUser!.photo = bytes;
    notifyListeners();
  }

  void updatePrefs({String? language, bool? notifyRides, bool? notifyPromos}) {
    final u = currentUser!;
    if (language != null) u.language = language;
    if (notifyRides != null) u.notifyRides = notifyRides;
    if (notifyPromos != null) u.notifyPromos = notifyPromos;
    notifyListeners();
  }

  /// Account delete: user ka data chhupa diya jata hai aur woh log out ho jata hai.
  /// Usi number se dobara naya account ban sakta hai.
  void deleteAccount() {
    final u = currentUser!;
    if (u.driver != null) setDriverOnline(false);
    u.deleted = true;
    _audit('User deleted their account', u.name);
    currentUser = null;
    mode = AppMode.passenger;
    notifyListeners();
  }

  void completeLesson(String id) {
    currentUser!.driver!.completedLessons.add(id);
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
    for (final a in staff) {
      if (a.username == username.trim() && a.password == password) {
        currentStaff = a;
        _audit('Signed in', a.role.label);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void adminLogout() {
    currentStaff = null;
    notifyListeners();
  }

  /// Back button: driver mode se passenger mode, passenger se shuru ki screen.
  void goBack() {
    if (currentUser == null) return;
    if (mode == AppMode.driver) {
      switchMode(AppMode.passenger);
    } else {
      logout();
    }
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
    Place('Allama Iqbal Airport', LatLng(31.5216, 74.4036), isAirport: true),
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
  static const cities = ['Lahore', 'Karachi', 'Islamabad'];

  late final Map<String, City> cityData = {
    'Lahore': City(
      name: 'Lahore',
      center: cityCenter,
      places: places,
      settings: FareSettings.defaults(),
      stores: const [
        Place('Al-Fatah Gulberg', LatLng(31.5160, 74.3500)),
        Place('Carrefour Emporium Mall', LatLng(31.4673, 74.2660)),
        Place('Imtiaz Super Market Johar Town', LatLng(31.4690, 74.2780)),
        Place('Metro Cash & Carry Thokar', LatLng(31.4730, 74.2420)),
        Place('Hyperstar Fortress', LatLng(31.5300, 74.3640)),
      ],
    ),
    'Karachi': City(
      name: 'Karachi',
      center: const LatLng(24.8607, 67.0011),
      settings: FareSettings.defaults()..commissionPercent = 12,
      stores: const [
        Place('Imtiaz Super Market Bahadurabad', LatLng(24.8790, 67.0700)),
        Place('Naheed Supermarket', LatLng(24.8760, 67.0640)),
        Place('Chase Up Gulshan', LatLng(24.9200, 67.0950)),
        Place('Carrefour Dolmen Clifton', LatLng(24.8022, 67.0300)),
      ],
      places: const [
        Place('Clifton Beach', LatLng(24.7925, 67.0336)),
        Place('Dolmen Mall Clifton', LatLng(24.8022, 67.0300)),
        Place('Saddar', LatLng(24.8556, 67.0225)),
        Place('Jinnah International Airport', LatLng(24.9065, 67.1608), isAirport: true),
        Place('Gulshan-e-Iqbal', LatLng(24.9180, 67.0971)),
        Place('Tariq Road', LatLng(24.8722, 67.0626)),
        Place('DHA Phase 6', LatLng(24.8040, 67.0670)),
        Place('Port Grand', LatLng(24.8478, 66.9893)),
        Place('Lucky One Mall', LatLng(24.9326, 67.0870)),
        Place('Karachi Cantt Station', LatLng(24.8432, 67.0436)),
      ],
    ),
    'Islamabad': City(
      name: 'Islamabad',
      center: const LatLng(33.6844, 73.0479),
      settings: FareSettings.defaults(),
      airportFee: 250,
      stores: const [
        Place('Al-Fatah F-7', LatLng(33.7200, 73.0560)),
        Place('Carrefour Centaurus', LatLng(33.7077, 73.0500)),
        Place('Esajees F-6', LatLng(33.7280, 73.0770)),
        Place('Imtiaz Super Market G-9', LatLng(33.6870, 73.0330)),
      ],
      places: const [
        Place('Faisal Mosque', LatLng(33.7295, 73.0372)),
        Place('Centaurus Mall', LatLng(33.7077, 73.0500)),
        Place('Blue Area', LatLng(33.7104, 73.0590)),
        Place('F-6 Super Market', LatLng(33.7270, 73.0763)),
        Place('F-7 Jinnah Super', LatLng(33.7206, 73.0566)),
        Place('Islamabad International Airport', LatLng(33.5491, 72.8256), isAirport: true),
        Place('Daman-e-Koh', LatLng(33.7401, 73.0569)),
        Place('Pakistan Monument', LatLng(33.6935, 73.0686)),
        Place('G-9 Markaz', LatLng(33.6880, 73.0320)),
        Place('Bahria Town Phase 4', LatLng(33.5309, 73.1203)),
      ],
    ),
  };

  City cityOf(String? name) => cityData[name] ?? cityData['Lahore']!;
  City get currentCity => cityOf(currentUser?.city);
  FareSettings get settings => currentCity.settings;

  /// Intercity ke liye doosre sheher.
  List<Place> intercityDestinations(String fromCity) =>
      [for (final c in cityData.values) if (c.name != fromCity) c.asPlace];

  /// Mashwara kiraya (PKR): base + per km, kam se kam minimum.
  /// Parcel ke size, freight ke mazdooron aur airport ka kharcha upar se.
  int suggestedFare(VehicleType type, Place from, Place to,
      {ParcelDetails? parcel,
      FreightDetails? freight,
      GroceryDetails? grocery,
      String? city,
      ServiceType service = ServiceType.ride}) {
    final c = cityOf(city ?? currentUser?.city);
    final st = c.settings;
    final km = const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;
    // Intercity: lamba safar, per km sasta.
    final perKm = service == ServiceType.intercity ? st.perKm[type]! * 0.6 : st.perKm[type]!;
    final fare = st.baseFare[type]! + km * perKm;
    final airport = (from.isAirport || to.isAirport) ? c.airportFee : 0;
    final extras = (parcel?.size.surcharge ?? 0) +
        (freight?.helpers ?? 0) * helperFee +
        (grocery != null ? groceryShoppingFee : 0) +
        airport;
    return max(st.minFare[type]!, (fare / 10).round() * 10) + extras;
  }

  /// inDrive ki tarah passenger mashwara kiraye se kam bhi offer kar sakta hai, magar had tak.
  int lowestAllowedFare(VehicleType type, Place from, Place to,
          {ParcelDetails? parcel,
          FreightDetails? freight,
          GroceryDetails? grocery,
          String? city,
          ServiceType service = ServiceType.ride}) =>
      max(
          cityOf(city ?? currentUser?.city).settings.minFare[type]!,
          (suggestedFare(type, from, to, parcel: parcel, freight: freight, grocery: grocery, city: city, service: service) *
                      0.7 /
                      10)
                  .round() *
              10);

  // =========================================================== Promo codes
  /// Promo ka discount, ya galti ka paigham.
  (int, String?) checkPromo(String code, int fare) {
    final c = code.trim().toUpperCase();
    for (final p in promos) {
      if (p.code != c) continue;
      if (!p.active || p.expires.isBefore(DateTime.now())) return (0, 'This promo code has expired');
      if (p.used >= p.maxUses) return (0, 'This promo code has been fully used');
      return (p.discountFor(fare), null);
    }
    return (0, 'Promo code not found');
  }

  void createPromo(PromoCode p) {
    promos.insert(0, p);
    _audit('Created promo code', '${p.code} · ${p.summary}');
    notifyListeners();
  }

  void setPromoActive(PromoCode p, bool active) {
    p.active = active;
    _audit(active ? 'Activated promo' : 'Paused promo', p.code);
    notifyListeners();
  }

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
    GroceryDetails? grocery,
    DateTime? scheduledAt,
    int seats = 1,
    String promo = '',
  }) {
    final me = currentUser!;
    if (me.suspended) return 'Your account is suspended until ${_date(me.suspendedUntil!)}. Contact support.';
    if (!currentCity.services.contains(service)) return '${service.label} is not available in ${me.city} yet';
    var discount = 0;
    String? promoCode;
    if (promo.trim().isNotEmpty) {
      final (d, err) = checkPromo(promo, fare);
      if (err != null) return err;
      discount = d;
      promoCode = promo.trim().toUpperCase();
    }
    if (payment == PaymentMethod.wallet && me.walletBalance < fare - discount) {
      return 'Not enough wallet balance (${me.walletBalance}). Top up or pay cash.';
    }
    if (promoCode != null) promos.firstWhere((p) => p.code == promoCode).used++;
    final req = RideRequest(
      city: me.city,
      scheduledAt: scheduledAt,
      seats: seats,
      promoCode: promoCode,
      discount: discount,
      id: _newId('R'),
      passengerId: currentUser!.id,
      service: service,
      vehicleType: type,
      payment: payment,
      parcel: parcel,
      freight: freight,
      grocery: grocery,
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
            u.walletBalance >= minDriverBalance &&
            u.city == req.city)
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
    req.commission = (req.finalFare * cityOf(req.city).settings.commissionPercent / 100).round();
    final driverId = req.driverId!;
    if (req.payment == PaymentMethod.wallet) {
      _tx(req.passengerId, TxType.ridePayment, -req.passengerPays, rideId: req.id, time: time);
      _tx(driverId, TxType.rideEarning, req.passengerPays, rideId: req.id, time: time);
    }
    // Promo ka discount MIK DRIVE driver ko deta hai, taake driver ka nuqsan na ho.
    if (req.discount > 0) _tx(driverId, TxType.promo, req.discount, rideId: req.id, time: time);
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

  // =========================================================== Safety
  /// Passenger ya driver SOS dabaye to control office ko foran alert.
  void raiseSos(RideRequest ride) {
    final me = currentUser!.id;
    if (alerts.any((a) => a.rideId == ride.id && !a.resolved)) return;
    alerts.insert(0, SafetyAlert(id: _newId('A'), rideId: ride.id, userId: me));
    notifyListeners();
  }

  int get openAlerts => alerts.where((a) => !a.resolved).length;

  void resolveAlert(SafetyAlert a, String note) {
    a
      ..resolved = true
      ..note = note;
    _audit('Resolved SOS alert', 'Ride ${a.rideId}: $note');
    notifyListeners();
  }

  /// Shak wale accounts: bohat cancel, kam rating, ya minus balance.
  List<(AppUser, String)> get fraudFlags {
    final out = <(AppUser, String)>[];
    for (final u in users.values) {
      final asDriver = rides.where((r) => r.driverId == u.id).toList();
      final asPassenger = rides.where((r) => r.passengerId == u.id).toList();
      final dCancel = asDriver.where((r) => r.cancelledBy == 'driver').length;
      final pCancel = asPassenger.where((r) => r.cancelledBy == 'passenger').length;
      if (asDriver.length >= 3 && dCancel / asDriver.length > 0.3) {
        out.add((u, 'Driver cancels often ($dCancel of ${asDriver.length} rides)'));
      }
      if (asPassenger.length >= 3 && pCancel / asPassenger.length > 0.3) {
        out.add((u, 'Passenger cancels often ($pCancel of ${asPassenger.length} rides)'));
      }
      if (u.driver != null && u.driverRatingCount >= 5 && u.driverRating < 4.0) {
        out.add((u, 'Low driver rating (${u.driverRating.toStringAsFixed(2)})'));
      }
      if (u.walletBalance < -500) out.add((u, 'Wallet far below zero (${_pkr(u.walletBalance)})'));
    }
    return out;
  }

  void warnUser(AppUser u, String reason) {
    u.warnings++;
    notify(Audience.user, 'Warning from MIK DRIVE', reason, userId: u.id);
    _audit('Warned user', '${u.name}: $reason');
    notifyListeners();
  }

  void suspendUser(AppUser u, int days, String reason) {
    u.suspendedUntil = DateTime.now().add(Duration(days: days));
    if (u.driver != null) u.driver!.online = false;
    notify(Audience.user, 'Account suspended', 'Suspended for $days day(s): $reason', userId: u.id);
    _audit('Suspended user for $days day(s)', '${u.name}: $reason');
    notifyListeners();
  }

  void unsuspendUser(AppUser u) {
    u.suspendedUntil = null;
    _audit('Lifted suspension', u.name);
    notifyListeners();
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // =========================================================== Notifications
  void notify(Audience audience, String title, String body, {String? userId}) {
    notifications.insert(
        0, AppNotification(id: _newId('N'), audience: audience, userId: userId, title: title, body: body));
  }

  void broadcast(Audience audience, String title, String body) {
    notify(audience, title, body);
    _audit('Sent notification to ${audience.label}', title);
    notifyListeners();
  }

  void setBanner(String text, bool active) {
    bannerText = text;
    bannerActive = active && text.trim().isNotEmpty;
    _audit(bannerActive ? 'Updated app banner' : 'Turned off app banner', text);
    notifyListeners();
  }

  List<AppNotification> get myNotifications {
    final u = currentUser;
    if (u == null) return [];
    return notifications.where((n) => switch (n.audience) {
          Audience.everyone => true,
          Audience.passengers => mode == AppMode.passenger,
          Audience.drivers => u.driver != null,
          Audience.user => n.userId == u.id,
        }).toList();
  }

  int get unreadNotifications => myNotifications.where((n) => !n.readBy.contains(currentUser!.id)).length;

  void markNotificationsRead() {
    for (final n in myNotifications) {
      n.readBy.add(currentUser!.id);
    }
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
    notify(Audience.user, 'Top-up approved', '${_pkr(t.amount)} added to your wallet.', userId: t.userId);
    _audit('Approved top-up', '${userById(t.userId).name} · ${_pkr(t.amount)}');
    notifyListeners();
  }

  void rejectTopUp(WalletTransaction t) {
    _settle(t, TxStatus.failed);
    _audit('Rejected top-up', '${userById(t.userId).name} · ${_pkr(t.amount)}');
    notifyListeners();
  }

  void adjustBalance(AppUser u, int amount, String note) {
    _tx(u.id, TxType.adjustment, amount, note: note);
    _audit('Adjusted balance ${amount > 0 ? '+' : ''}$amount', '${u.name}: $note');
    notifyListeners();
  }

  /// Driver apni kamai bank / JazzCash mein nikalta hai. Paise foran rok liye jate hain.
  String? requestWithdrawal(int amount, String method, String account) {
    final me = currentUser!;
    if (amount < 500) return 'Minimum withdrawal is Rs 500';
    if (amount > me.walletBalance) return 'You can withdraw up to ${_pkr(me.walletBalance)}';
    me.walletBalance -= amount;
    transactions.insert(
        0,
        WalletTransaction(
          id: _newId('W'),
          userId: me.id,
          type: TxType.withdrawal,
          amount: -amount,
          method: method,
          note: account,
          status: TxStatus.pending,
        ));
    notifyListeners();
    return null;
  }

  List<WalletTransaction> get pendingWithdrawals =>
      transactions.where((t) => t.type == TxType.withdrawal && t.status == TxStatus.pending).toList();

  void approveWithdrawal(WalletTransaction t) {
    if (t.status != TxStatus.pending) return;
    t.status = TxStatus.success;
    notify(Audience.user, 'Withdrawal sent', '${_pkr(-t.amount)} sent to your ${t.method}.', userId: t.userId);
    _audit('Paid withdrawal', '${userById(t.userId).name} · ${_pkr(-t.amount)}');
    notifyListeners();
  }

  void rejectWithdrawal(WalletTransaction t) {
    if (t.status != TxStatus.pending) return;
    t.status = TxStatus.failed;
    users[t.userId]!.walletBalance -= t.amount; // paise wapas
    _audit('Rejected withdrawal', '${userById(t.userId).name} · ${_pkr(-t.amount)}');
    notifyListeners();
  }

  void refundRide(RideRequest r, int amount, String reason) {
    if (r.refunded) return;
    r.refunded = true;
    _tx(r.passengerId, TxType.refund, amount, rideId: r.id, note: reason);
    notify(Audience.user, 'Refund', '${_pkr(amount)} added to your wallet for ride ${r.id}.', userId: r.passengerId);
    _audit('Refunded ${_pkr(amount)}', 'Ride ${r.id}: $reason');
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
    DateTime? licenseExpiry,
  }) {
    currentUser!.driver = DriverProfile(
      cnic: cnic,
      licenseNo: licenseNo,
      vehicle: vehicle,
      documents: documents,
      licenseExpiry: licenseExpiry,
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

  /// Driver online kyun nahi ho sakta (null = ho sakta hai).
  String? get onlineBlocker {
    final me = currentUser;
    final d = me?.driver;
    if (me == null || d == null) return 'Not a driver';
    if (me.suspended) return 'Your account is suspended until ${_date(me.suspendedUntil!)}';
    if (d.status != DriverStatus.approved) return 'Your driver account is not approved';
    if (d.licenseExpired) return 'Your driving license has expired. Upload a new one in support.';
    if (!canGoOnline) return 'Your wallet balance is below zero. Top up to go online.';
    if (!d.selfieValid) return 'selfie';
    return null;
  }

  /// Roz ek selfie: taake account wahi driver chala raha ho.
  void takeSelfie() {
    currentUser!.driver!.lastSelfieAt = DateTime.now();
    notifyListeners();
  }

  void setDestination(Place? p) {
    currentUser!.driver!.destination = p;
    notifyListeners();
  }

  void setDriverOnline(bool online) {
    final me = currentUser;
    final profile = me?.driver;
    if (profile == null) return;
    profile.online = online && onlineBlocker == null;
    profile.location = profile.online ? _randomPointNear(cityOf(me!.city).center) : null;
    _requestFeed?.cancel();
    if (profile.online) {
      final type = profile.vehicle.type;
      if (openRequests.length < 3) {
        for (var i = 0; i < 3; i++) {
          _botPassengerRequest(type, me!.city);
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
        _botPassengerRequest(type, me!.city);
        notifyListeners();
      });
    }
    notifyListeners();
  }

  List<RideRequest> get openRequests {
    final me = currentUser;
    final type = me?.driver?.vehicle.type;
    if (me == null || type == null) return [];
    final dest = me.driver!.destination;
    return rides
        .where((r) =>
            r.status == RideStatus.searching &&
            r.vehicleType == type &&
            r.city == me.city &&
            (driverFilter == null || r.service == driverFilter) &&
            r.passengerId != me.id &&
            !r.declinedDriverIds.contains(me.id) &&
            // Destination mode: sirf woh rides jo driver ki manzil ke 5 km andar khatam hon.
            (dest == null || const Distance().as(LengthUnit.Kilometer, r.to.point, dest.point) <= 5))
        .take(8)
        .toList();
  }

  /// Driver menu se "City to City" / "Freight": sirf usi service ki requests.
  ServiceType? driverFilter;

  void setDriverFilter(ServiceType? s) {
    driverFilter = s;
    notifyListeners();
  }

  // =========================================================== Buses
  static const _busOperators = ['MIK Express', 'Green Line Coaches', 'Star Travels', 'City Connect'];

  void _seedBuses() {
    final now = DateTime.now();
    const routes = [
      ('Lahore', 'Islamabad', 2600, Duration(hours: 4, minutes: 30)),
      ('Lahore', 'Karachi', 6800, Duration(hours: 18)),
      ('Islamabad', 'Karachi', 7400, Duration(hours: 20)),
    ];
    for (var day = 0; day < 3; day++) {
      for (final (a, b, price, dur) in routes) {
        for (final (from, to) in [(a, b), (b, a)]) {
          for (final hour in [7, 11, 15, 22]) {
            final op = _busOperators[_rand.nextInt(_busOperators.length)];
            final business = _rand.nextBool();
            final t = BusTrip(
              id: _newId('B'),
              operator: op,
              fromCity: from,
              toCity: to,
              departs: DateTime(now.year, now.month, now.day + day, hour, [0, 15, 30, 45][_rand.nextInt(4)]),
              duration: dur,
              pricePerSeat: business ? (price * 1.4 / 50).round() * 50 : price,
              totalSeats: business ? 30 : 45,
              busType: business ? 'Business' : 'Executive',
            )..seatsLeft = 3 + _rand.nextInt(business ? 27 : 42);
            busTrips.add(t);
          }
        }
      }
    }
  }

  List<BusTrip> searchBuses(String from, String to, DateTime day) => busTrips
      .where((t) =>
          t.fromCity == from &&
          t.toCity == to &&
          t.departs.year == day.year &&
          t.departs.month == day.month &&
          t.departs.day == day.day &&
          t.departs.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.departs.compareTo(b.departs));

  BusTrip busTripById(String id) => busTrips.firstWhere((t) => t.id == id);

  /// Bus ki seat book karna. Wallet se ho to paise foran katte hain.
  String? bookBus(BusTrip trip, int seats, PaymentMethod payment) {
    final me = currentUser!;
    if (seats < 1 || seats > 6) return 'You can book 1 to 6 seats';
    if (seats > trip.seatsLeft) return 'Only ${trip.seatsLeft} seats left on this bus';
    final total = trip.pricePerSeat * seats;
    if (payment == PaymentMethod.wallet && me.walletBalance < total) {
      return 'Not enough wallet balance (${me.walletBalance}). Top up or pay at the terminal.';
    }
    trip.seatsLeft -= seats;
    final b = BusBooking(id: _newId('K'), tripId: trip.id, userId: me.id, seats: seats, total: total, payment: payment);
    busBookings.insert(0, b);
    if (payment == PaymentMethod.wallet) {
      _tx(me.id, TxType.ridePayment, -total, note: 'Bus ticket ${b.id} · ${trip.fromCity} → ${trip.toCity}');
    }
    notify(Audience.user, 'Bus ticket booked',
        '${trip.operator} ${trip.fromCity} → ${trip.toCity}, ${_date(trip.departs)}. Ticket ${b.id}.',
        userId: me.id);
    notifyListeners();
    return null;
  }

  /// Rawangi se 2 ghante pehle tak cancel; wallet wale paise wapas.
  String? cancelBusBooking(BusBooking b) {
    final trip = busTripById(b.tripId);
    if (b.cancelled) return 'Already cancelled';
    if (trip.departs.difference(DateTime.now()) < const Duration(hours: 2)) {
      return 'Tickets can be cancelled up to 2 hours before departure';
    }
    b.cancelled = true;
    trip.seatsLeft += b.seats;
    if (b.payment == PaymentMethod.wallet) _tx(b.userId, TxType.refund, b.total, note: 'Bus ticket ${b.id} cancelled');
    notifyListeners();
    return null;
  }

  List<BusBooking> get myBusBookings => busBookings.where((b) => b.userId == currentUser?.id).toList();

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
    _payIncentives(currentUser!);
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

  // =========================================================== Driver bonus
  List<Incentive> incentivesFor(AppUser u) => incentives
      .where((i) =>
          i.validUntil.isAfter(DateTime.now()) &&
          (i.vehicleType == null || i.vehicleType == u.driver?.vehicle.type))
      .toList();

  int incentiveProgress(Incentive i, AppUser u) {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    return rides
        .where((r) =>
            r.driverId == u.id &&
            r.status == RideStatus.completed &&
            r.completedAt!.isAfter(since) &&
            (i.vehicleType == null || r.vehicleType == i.vehicleType))
        .length;
  }

  void _payIncentives(AppUser u) {
    for (final i in incentivesFor(u)) {
      if (!i.paidTo.contains(u.id) && incentiveProgress(i, u) >= i.targetRides) {
        i.paidTo.add(u.id);
        _tx(u.id, TxType.bonus, i.reward, note: i.title);
        notify(Audience.user, 'Bonus earned!', '${i.title}: ${_pkr(i.reward)} added to your wallet.', userId: u.id);
      }
    }
  }

  void createIncentive(Incentive i) {
    incentives.insert(0, i);
    notify(Audience.drivers, 'New bonus', '${i.title}: complete ${i.targetRides} rides, earn ${_pkr(i.reward)}');
    _audit('Created driver bonus', '${i.title} · ${_pkr(i.reward)}');
    notifyListeners();
  }

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
        text: 'Thank you for contacting MIK DRIVE support. Your ticket number is ${t.id}. '
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
    t.assignedTo ??= currentStaff?.name;
    _audit('Replied to ticket', t.id);
    notifyListeners();
  }

  void closeTicket(SupportTicket t) {
    t.status = TicketStatus.closed;
    _audit('Closed ticket', t.id);
    notifyListeners();
  }

  void assignTicket(SupportTicket t, String? staffName) {
    t.assignedTo = staffName;
    _audit('Assigned ticket', '${t.id} → ${staffName ?? 'nobody'}');
    notifyListeners();
  }

  void approveDriver(AppUser u) {
    u.driver!.status = DriverStatus.approved;
    u.driver!.rejectionReason = null;
    notify(Audience.user, 'You are approved!', 'Your driver account is approved. Go online to start earning.',
        userId: u.id);
    _audit('Approved driver', u.name);
    notifyListeners();
  }

  void rejectDriver(AppUser u, String reason) {
    u.driver!
      ..status = DriverStatus.rejected
      ..rejectionReason = reason
      ..online = false;
    notify(Audience.user, 'Application not approved', reason, userId: u.id);
    _audit('Rejected driver', '${u.name}: $reason');
    notifyListeners();
  }

  void setDriverBlocked(AppUser u, bool blocked) {
    u.driver!
      ..status = blocked ? DriverStatus.blocked : DriverStatus.approved
      ..online = false;
    _audit(blocked ? 'Blocked driver' : 'Unblocked driver', u.name);
    notifyListeners();
  }

  void setUserBlocked(AppUser u, bool blocked) {
    u.blocked = blocked;
    if (blocked && u.driver != null) u.driver!.online = false;
    _audit(blocked ? 'Blocked account' : 'Unblocked account', u.name);
    notifyListeners();
  }

  void adminCancelRide(RideRequest r) {
    if (!r.status.isActive) return;
    r.status = RideStatus.cancelled;
    r.cancelledBy = 'admin';
    r.cancelReason = 'Cancelled by MIK DRIVE support';
    _audit('Cancelled ride', r.id);
    notifyListeners();
  }

  void updateSettings(FareSettings s, {String city = 'Lahore', int? airportFee, Set<ServiceType>? services}) {
    final c = cityOf(city);
    c.settings = s;
    if (airportFee != null) c.airportFee = airportFee;
    if (services != null) {
      c.services
        ..clear()
        ..addAll(services);
    }
    _audit('Updated fares and settings', city);
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
    _addUser(u);
    return u;
  }

  void _botPassengerRequest(VehicleType type, [String city = 'Lahore']) {
    final passengers = users.values.where((u) => u.isBot && u.driver == null).toList();
    final p = passengers[_rand.nextInt(passengers.length)];
    final c = cityOf(city);
    var (service, parcel, freight, grocery) = _randomService(type);
    // Groceries ki pickup store hoti hai.
    final pool = grocery != null && c.stores.isNotEmpty ? c.stores : c.places;
    final from = pool[_rand.nextInt(pool.length)];
    // Kabhi kabhi doosre sheher ki (intercity) request, kal ke liye.
    final intercity = (type == VehicleType.mini || type == VehicleType.ac) && _rand.nextDouble() < 0.12;
    Place to;
    if (intercity) {
      service = ServiceType.intercity;
      parcel = null;
      grocery = null;
      final others = intercityDestinations(city);
      to = others[_rand.nextInt(others.length)];
    } else {
      do {
        to = c.places[_rand.nextInt(c.places.length)];
      } while (to == from);
    }
    final suggested = suggestedFare(type, from, to,
        parcel: parcel, freight: freight, grocery: grocery, city: city, service: service);
    // Passenger aksar mashwara kiraye se thora kam offer karta hai.
    final fare = max(
        lowestAllowedFare(type, from, to,
            parcel: parcel, freight: freight, grocery: grocery, city: city, service: service),
        suggested - [0, 20, 50, 80][_rand.nextInt(4)]);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    rides.insert(
      0,
      RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        city: city,
        scheduledAt: intercity ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7 + _rand.nextInt(10)) : null,
        seats: intercity ? 1 + _rand.nextInt(3) : 1,
        service: service,
        vehicleType: type,
        parcel: parcel,
        freight: freight,
        grocery: grocery,
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

  static const _groceryLists = [
    ['Milk 2 L', 'Bread', 'Eggs 1 dozen'],
    ['Atta 10 kg', 'Cooking oil 3 L', 'Sugar 2 kg'],
    ['Tomatoes 1 kg', 'Onions 2 kg', 'Potatoes 2 kg', 'Green chillies'],
    ['Rice 5 kg', 'Daal chana 1 kg', 'Tea 450 g'],
    ['Diapers', 'Baby wipes', 'Formula milk'],
  ];

  (ServiceType, ParcelDetails?, FreightDetails?, GroceryDetails?) _randomService(VehicleType type) {
    if (type.isFreight) {
      return (
        ServiceType.freight,
        null,
        FreightDetails(
          cargo: _cargo[_rand.nextInt(_cargo.length)],
          weightKg: (type.maxKg * (0.3 + _rand.nextDouble() * 0.6) / 50).round() * 50,
          helpers: _rand.nextInt(3),
        ),
        null,
      );
    }
    final roll = _rand.nextDouble();
    if ((type == VehicleType.moto || type == VehicleType.mini) && roll < 0.15) {
      final items = _groceryLists[_rand.nextInt(_groceryLists.length)];
      return (
        ServiceType.groceries,
        null,
        null,
        GroceryDetails(items: items, budget: (items.length * (300 + _rand.nextInt(700)) / 50).round() * 50),
      );
    }
    if ((type == VehicleType.moto || type == VehicleType.mini) && roll < 0.4) {
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
        null,
      );
    }
    return (ServiceType.ride, null, null, null);
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
          // Kuch licenses jald expire hone wale, ek expire ho chuka.
          licenseExpiry: now.add(Duration(days: i == 0 ? 12 : (i == 1 && t == VehicleType.mini ? -3 : 200 + _rand.nextInt(600)))),
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
      final type = d.driver!.vehicle.type;
      final created = now.subtract(Duration(minutes: 30 + _rand.nextInt(60 * 23)));
      final (service, parcel, freight, grocery) = _randomService(type);
      final stores = cityOf('Lahore').stores;
      final from = grocery != null ? stores[_rand.nextInt(stores.length)] : places[_rand.nextInt(places.length)];
      var to = places[_rand.nextInt(places.length)];
      if (to == from) to = places[(places.indexOf(to) + 3) % places.length];
      final r = RideRequest(
        id: _newId('R'),
        passengerId: p.id,
        service: service,
        vehicleType: type,
        parcel: parcel,
        freight: freight,
        grocery: grocery,
        from: from,
        to: to,
        fare: suggestedFare(type, from, to, parcel: parcel, freight: freight, grocery: grocery),
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
      email: 'passenger@mikdrive.demo',
      createdAt: now.subtract(const Duration(days: 30)),
    );
    _addUser(demoPassenger);
    final demoDriver = AppUser(
      id: _newId('U'),
      phone: demoDriverPhone,
      name: 'Demo Driver',
      email: 'driver@mikdrive.demo',
      createdAt: now.subtract(const Duration(days: 60)),
    )..driver = DriverProfile(
        cnic: '35202-1234567-1',
        licenseNo: 'LHR-123456',
        vehicle: const Vehicle(
            type: VehicleType.mini, model: 'Suzuki Alto', color: 'White', plate: 'LEA-1234', year: 2020),
        documents: driverDocuments.toSet(),
        status: DriverStatus.approved,
        submittedAt: now.subtract(const Duration(days: 60)),
        licenseExpiry: now.add(const Duration(days: 400)),
      );
    _addUser(demoDriver);
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
    tickets[1].assignedTo = staff[1].name;
    tickets.add(SupportTicket(
      id: _newId('T'),
      userId: demoPassenger.id,
      role: AppMode.passenger,
      category: 'Lost item',
      rideId: null,
      createdAt: now.subtract(const Duration(hours: 5)),
    )..messages.add(TicketMessage(
        fromSupport: false,
        text: 'I forgot my umbrella in a Suzuki Alto yesterday evening.',
        time: now.subtract(const Duration(hours: 5)))));

    _seedBuses();

    // Promo codes, bonus, notifications, banner
    promos.addAll([
      PromoCode(code: 'WELCOME50', percent: 50, maxDiscount: 150, maxUses: 1000, expires: now.add(const Duration(days: 30)))
        ..used = 214,
      PromoCode(code: 'GORIDE100', fixed: 100, maxUses: 500, expires: now.add(const Duration(days: 7)))..used = 88,
      PromoCode(code: 'EID2026', percent: 20, maxDiscount: 200, maxUses: 300, expires: now.subtract(const Duration(days: 3)))
        ..used = 300,
    ]);
    incentives.addAll([
      Incentive(
          id: _newId('I'),
          title: 'Complete 3 rides today',
          targetRides: 3,
          reward: 300,
          validUntil: now.add(const Duration(hours: 12))),
      Incentive(
          id: _newId('I'),
          title: 'Freight weekend: 2 deliveries',
          vehicleType: VehicleType.pickup,
          targetRides: 2,
          reward: 800,
          validUntil: now.add(const Duration(days: 2))),
    ]);
    bannerText = 'Use code WELCOME50 for 50% off your next ride (up to Rs 150)';
    bannerActive = true;
    notifications.addAll([
      AppNotification(
          id: _newId('N'),
          audience: Audience.everyone,
          title: 'Welcome to MIK DRIVE',
          body: 'Ride, courier, freight and intercity: all in one app. Offer your own fare!',
          time: now.subtract(const Duration(days: 1))),
      AppNotification(
          id: _newId('N'),
          audience: Audience.drivers,
          title: 'New bonus',
          body: 'Complete 3 rides today and earn Rs 300.',
          time: now.subtract(const Duration(hours: 3))),
    ]);

    // Ek khula SOS alert, aur purana hal shuda
    final someRide = rides.firstWhere((r) => r.status == RideStatus.completed);
    alerts.addAll([
      SafetyAlert(id: _newId('A'), rideId: someRide.id, userId: someRide.passengerId, time: now.subtract(const Duration(minutes: 8))),
      SafetyAlert(id: _newId('A'), rideId: rides[5].id, userId: rides[5].passengerId, time: now.subtract(const Duration(days: 1)))
        ..resolved = true
        ..note = 'Called passenger, false alarm',
    ]);

    // Driver withdrawals jo finance ke intezar mein hain
    for (final d in drivers.skip(3).take(2)) {
      d.walletBalance -= 1500;
      transactions.insert(
          0,
          WalletTransaction(
              id: _newId('W'),
              userId: d.id,
              type: TxType.withdrawal,
              amount: -1500,
              method: 'JazzCash',
              note: '••••${1000 + _rand.nextInt(8999)}',
              status: TxStatus.pending,
              time: now.subtract(Duration(hours: 2 + _rand.nextInt(6)))));
    }

    // Ek driver jo bohat cancel karta hai (fraud flag ke liye)
    final flaky = drivers[2];
    for (var i = 0; i < 4; i++) {
      final r = RideRequest(
        id: _newId('R'),
        passengerId: passengers[i].id,
        vehicleType: flaky.driver!.vehicle.type,
        from: places[i],
        to: places[i + 4],
        fare: 300,
        createdAt: now.subtract(Duration(hours: 3 + i)),
      )
        ..acceptedOffer = Offer(id: _newId('O'), driverId: flaky.id, fare: 300, etaMinutes: 5)
        ..status = RideStatus.cancelled
        ..cancelledBy = 'driver'
        ..cancelReason = 'Pickup is too far';
      rides.add(r);
    }
    rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    auditLog.addAll([
      AuditEntry(staff[2].name, 'Approved driver', drivers[0].name, time: now.subtract(const Duration(hours: 6))),
      AuditEntry(staff[3].name, 'Approved top-up', '${drivers[1].name} · Rs 2000', time: now.subtract(const Duration(hours: 9))),
      AuditEntry(staff[0].name, 'Created promo code', 'GORIDE100 · Rs 100 off', time: now.subtract(const Duration(days: 1))),
    ]);
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

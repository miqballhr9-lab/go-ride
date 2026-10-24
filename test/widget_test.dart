import 'package:flutter_test/flutter_test.dart';
import 'package:go_ride/main.dart';
import 'package:go_ride/models.dart';
import 'package:go_ride/store.dart';

void main() {
  testWidgets('Login screen is shown', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(MikDriveApp(store: store));
    expect(find.text('Enter your phone number'), findsOneWidget);
    store.dispose();
  });

  test('New phone needs signup, then can log in again', () {
    final store = AppStore();
    expect(store.login('+923001234567'), LoginResult.newUser);
    store.signup(phone: '+923001234567', name: 'Test', email: '', city: 'Lahore');
    store.logout();
    expect(store.login('+923001234567'), LoginResult.ok);
    store.dispose();
  });

  test('Blocked user cannot log in', () {
    final store = AppStore();
    store.signup(phone: '+923001111111', name: 'B', email: '', city: 'Lahore');
    final u = store.currentUser!;
    store.logout();
    store.setUserBlocked(u, true);
    expect(store.login('+923001111111'), LoginResult.blocked);
    store.dispose();
  });

  test('Passenger request receives offers, ride completes with commission', () async {
    final store = AppStore();
    store.signup(phone: '+923001234567', name: 'Test', email: '', city: 'Lahore');
    final from = AppStore.places[0], to = AppStore.places[3];
    store.createRequest(VehicleType.mini, from, to, store.suggestedFare(VehicleType.mini, from, to), '');
    await Future.delayed(const Duration(seconds: 6));
    final ride = store.passengerRide!;
    expect(ride.offers, isNotEmpty);
    store.acceptOffer(ride.offers.first);
    expect(ride.status, RideStatus.driverComing);
    await Future.delayed(const Duration(seconds: 22));
    expect(ride.status, RideStatus.completed);
    expect(ride.commission, (ride.finalFare * store.settings.commissionPercent / 100).round());
    store.closePassengerRide(stars: 5);
    expect(store.passengerRide, isNull);
    store.dispose();
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('Driver needs admin approval before going online', () {
    final store = AppStore();
    store.signup(phone: '+923009999999', name: 'Driver', email: '', city: 'Lahore');
    store.registerDriver(
      cnic: '3520212345671',
      licenseNo: 'LHR-1',
      documents: driverDocuments.toSet(),
      vehicle: const Vehicle(type: VehicleType.mini, model: 'Alto', color: 'White', plate: 'LEA-1', year: 2018),
    );
    final me = store.currentUser!;
    store.setDriverOnline(true);
    expect(store.driverOnline, isFalse);
    expect(store.pendingDrivers, contains(me));
    store.approveDriver(me);
    store.takeSelfie();
    store.setDriverOnline(true);
    expect(store.driverOnline, isTrue);
    expect(store.openRequests, isNotEmpty);
    store.dispose();
  });

  test('Support ticket gets admin reply', () {
    final store = AppStore();
    store.signup(phone: '+923008888888', name: 'S', email: '', city: 'Lahore');
    final t = store.createTicket(category: 'Lost item', message: 'Left my bag');
    expect(store.myTickets, contains(t));
    store.adminReplyTicket(t, 'We will help');
    expect(t.status, TicketStatus.answered);
    store.dispose();
  });

  test('Recommended fare respects minimum', () {
    final store = AppStore(seed: false);
    final f = store.suggestedFare(VehicleType.mini, AppStore.places[0], AppStore.places[11]);
    expect(f, greaterThanOrEqualTo(store.settings.minFare[VehicleType.mini]!));
  });

  test('Demo accounts log in to passenger and approved driver', () {
    final store = AppStore();
    store.demoLogin(AppMode.passenger);
    expect(store.currentUser!.phone, AppStore.demoPassengerPhone);
    store.logout();
    store.demoLogin(AppMode.driver);
    expect(store.mode, AppMode.driver);
    expect(store.currentUser!.isApprovedDriver, isTrue);
    store.dispose();
  });

  test('Commission is taken from driver wallet; negative balance blocks going online', () {
    final store = AppStore();
    store.demoLogin(AppMode.driver);
    store.takeSelfie();
    final me = store.currentUser!;
    final start = me.walletBalance;
    store.adjustBalance(me, -start - 50, 'test');
    expect(store.canGoOnline, isFalse);
    store.setDriverOnline(true);
    expect(store.driverOnline, isFalse);
    store.adjustBalance(me, 100, 'test');
    store.setDriverOnline(true);
    expect(store.driverOnline, isTrue);
    store.dispose();
  });

  test('Instant top-up adds balance, bank transfer waits for approval', () async {
    final store = AppStore();
    store.demoLogin(AppMode.passenger);
    final me = store.currentUser!;
    final start = me.walletBalance;
    final t = store.topUp(500, 'JazzCash', account: '••••4567');
    expect(t.status, TxStatus.pending);
    await Future.delayed(const Duration(seconds: 3));
    expect(t.status, TxStatus.success);
    expect(me.walletBalance, start + 500);
    final bank = store.topUp(2000, 'Bank transfer', account: 'ref 1');
    await Future.delayed(const Duration(seconds: 3));
    expect(bank.status, TxStatus.pending);
    expect(store.pendingTopUps, contains(bank));
    store.approveTopUp(bank);
    expect(me.walletBalance, start + 2500);
    store.dispose();
  });

  test('Wallet payment needs enough balance', () {
    final store = AppStore();
    store.signup(phone: '+923007777777', name: 'W', email: '', city: 'Lahore');
    final err = store.createRequest(VehicleType.mini, AppStore.places[0], AppStore.places[3], 500, '',
        payment: PaymentMethod.wallet);
    expect(err, isNotNull);
    expect(store.passengerRide, isNull);
    store.dispose();
  });

  test('Courier and freight fares include parcel size and helpers', () {
    final store = AppStore(seed: false);
    final a = AppStore.places[0], b = AppStore.places[3];
    const large = ParcelDetails(receiverName: 'R', receiverPhone: '+923001234567', size: ParcelSize.large, description: 'Box');
    expect(store.suggestedFare(VehicleType.mini, a, b, parcel: large),
        store.suggestedFare(VehicleType.mini, a, b) + ParcelSize.large.surcharge);
    const cargo = FreightDetails(cargo: 'Sofa', weightKg: 300, helpers: 2);
    expect(store.suggestedFare(VehicleType.pickup, a, b, freight: cargo),
        store.suggestedFare(VehicleType.pickup, a, b) + 2 * helperFee);
  });

  test('Freight driver receives freight requests', () {
    final store = AppStore();
    store.signup(phone: '+923006666666', name: 'Truck', email: '', city: 'Lahore');
    store.registerDriver(
      cnic: '3520212345671',
      licenseNo: 'LHR-2',
      documents: driverDocuments.toSet(),
      vehicle: const Vehicle(type: VehicleType.shehzore, model: 'Shehzore', color: 'White', plate: 'LES-1', year: 2019),
    );
    store.approveDriver(store.currentUser!);
    store.takeSelfie();
    store.setDriverOnline(true);
    expect(store.openRequests, isNotEmpty);
    expect(store.openRequests.every((r) => r.service == ServiceType.freight && r.freight != null), isTrue);
    store.dispose();
  });

  test('Back goes from driver to passenger, then to start; admin returns to user screen', () {
    final store = AppStore();
    store.demoLogin(AppMode.driver);
    store.goBack();
    expect(store.mode, AppMode.passenger);
    expect(store.currentUser, isNotNull);
    store.adminLogin(AppStore.adminUsername, AppStore.adminPassword);
    store.adminLogout();
    expect(store.currentUser, isNotNull);
    store.goBack();
    expect(store.currentUser, isNull);
    store.dispose();
  });

  test('Promo code lowers what the passenger pays; MIK DRIVE pays the driver the discount', () async {
    final store = AppStore();
    store.demoLogin(AppMode.passenger);
    final a = AppStore.places[0], b = AppStore.places[3];
    final fare = store.suggestedFare(VehicleType.mini, a, b);
    final (d, err) = store.checkPromo('GORIDE100', fare);
    expect(err, isNull);
    expect(d, 100);
    expect(store.checkPromo('EID2026', fare).$2, isNotNull); // expired
    expect(store.createRequest(VehicleType.mini, a, b, fare, '', promo: 'GORIDE100'), isNull);
    final ride = store.passengerRide!;
    expect(ride.discount, 100);
    await Future.delayed(const Duration(seconds: 6));
    store.acceptOffer(ride.offers.first);
    await Future.delayed(const Duration(seconds: 22));
    expect(ride.status, RideStatus.completed);
    expect(ride.passengerPays, ride.finalFare - 100);
    expect(store.transactions.any((t) => t.rideId == ride.id && t.type == TxType.promo && t.amount == 100), isTrue);
    store.dispose();
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('Referral gives both users a bonus', () {
    final store = AppStore();
    final friend = store.userByPhone(AppStore.demoPassengerPhone)!;
    final before = friend.walletBalance;
    expect(store.signup(phone: '+923005555555', name: 'New', email: '', city: 'Lahore', referral: 'NOPE1'), isNotNull);
    expect(store.signup(phone: '+923005555555', name: 'New', email: '', city: 'Lahore', referral: friend.referralCode), isNull);
    expect(store.currentUser!.walletBalance, AppStore.referralBonus);
    expect(friend.walletBalance, before + AppStore.referralBonus);
    store.dispose();
  });

  test('Driver needs a daily selfie and valid license to go online; suspension blocks too', () {
    final store = AppStore();
    store.demoLogin(AppMode.driver);
    expect(store.onlineBlocker, 'selfie');
    store.takeSelfie();
    expect(store.onlineBlocker, isNull);
    final me = store.currentUser!;
    me.driver!.licenseExpiry = DateTime.now().subtract(const Duration(days: 1));
    expect(store.onlineBlocker, contains('license'));
    me.driver!.licenseExpiry = DateTime.now().add(const Duration(days: 100));
    store.adminLogin(AppStore.adminUsername, AppStore.adminPassword);
    store.suspendUser(me, 3, 'test');
    expect(store.onlineBlocker, contains('suspended'));
    expect(store.auditLog.first.action, contains('Suspended'));
    store.dispose();
  });

  test('Withdrawal holds money until finance approves or rejects', () {
    final store = AppStore();
    store.demoLogin(AppMode.driver);
    final me = store.currentUser!;
    final start = me.walletBalance;
    expect(store.requestWithdrawal(100, 'JazzCash', '••••1'), isNotNull); // kam se kam 500
    expect(store.requestWithdrawal(500, 'JazzCash', '••••1'), isNull);
    expect(me.walletBalance, start - 500);
    final t = store.pendingWithdrawals.firstWhere((t) => t.userId == me.id);
    store.rejectWithdrawal(t);
    expect(me.walletBalance, start);
    store.dispose();
  });

  test('Staff roles: support cannot see payments; SOS alert shows up for the safety team', () {
    final store = AppStore();
    expect(store.adminLogin('support', 'support123'), isTrue);
    expect(store.currentStaff!.role, AdminRole.support);
    store.adminLogout();
    store.demoLogin(AppMode.passenger);
    final a = AppStore.places[0], b = AppStore.places[3];
    store.createRequest(VehicleType.mini, a, b, store.suggestedFare(VehicleType.mini, a, b), '');
    final before = store.openAlerts;
    store.raiseSos(store.passengerRide!);
    expect(store.openAlerts, before + 1);
    store.dispose();
  });

  test('Cities have their own places, fares and airport fee; intercity is cheaper per km', () {
    final store = AppStore();
    store.signup(phone: '+923004444444', name: 'Khi', email: '', city: 'Karachi');
    expect(store.currentCity.name, 'Karachi');
    final places = store.currentCity.places;
    final airport = places.firstWhere((p) => p.isAirport);
    final normal = places.firstWhere((p) => !p.isAirport && p != places.first);
    final withAirport = store.suggestedFare(VehicleType.mini, places.first, airport);
    expect(withAirport, greaterThan(store.settings.minFare[VehicleType.mini]!));
    expect(store.suggestedFare(VehicleType.mini, places.first, normal), greaterThan(0));
    final isb = store.cityOf('Islamabad').asPlace;
    final ride = store.suggestedFare(VehicleType.mini, store.currentCity.asPlace, isb);
    final intercity = store.suggestedFare(VehicleType.mini, store.currentCity.asPlace, isb, service: ServiceType.intercity);
    expect(intercity, lessThan(ride));
    store.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:go_ride/main.dart';
import 'package:go_ride/models.dart';
import 'package:go_ride/store.dart';

void main() {
  testWidgets('Login screen is shown', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(GoRideApp(store: store));
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:go_ride/main.dart';
import 'package:go_ride/models.dart';
import 'package:go_ride/store.dart';

void main() {
  testWidgets('Login screen is shown', (tester) async {
    await tester.pumpWidget(GoRideApp(store: AppStore()));
    expect(find.text('Enter your phone number'), findsOneWidget);
  });

  test('Passenger request receives driver offers that can be accepted', () async {
    final store = AppStore()..login('+923001234567', 'Test');
    store.createRequest(AppStore.places[0], AppStore.places[3], 400, '');
    await Future.delayed(const Duration(seconds: 6));
    final ride = store.passengerRide!;
    expect(ride.offers, isNotEmpty);
    store.acceptOffer(ride.offers.first);
    expect(ride.status, RideStatus.driverComing);
    store.dispose();
  });

  test('Recommended fare is at least Rs 200', () {
    expect(AppStore.suggestedFare(AppStore.places[0], AppStore.places[11]), greaterThanOrEqualTo(200));
  });
}

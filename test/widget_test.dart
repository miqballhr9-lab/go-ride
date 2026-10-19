import 'package:flutter_test/flutter_test.dart';
import 'package:go_ride/main.dart';
import 'package:go_ride/models.dart';
import 'package:go_ride/store.dart';

void main() {
  testWidgets('Login screen dikhti hai', (tester) async {
    await tester.pumpWidget(GoRideApp(store: AppStore()));
    expect(find.text('Apna phone number likhein'), findsOneWidget);
  });

  test('Passenger request pe driver offers aati hain aur accept hoti hai', () async {
    final store = AppStore()..login('+923001234567', 'Test');
    store.createRequest(AppStore.places[0], AppStore.places[3], 400, '');
    await Future.delayed(const Duration(seconds: 6));
    final ride = store.passengerRide!;
    expect(ride.offers, isNotEmpty);
    store.acceptOffer(ride.offers.first);
    expect(ride.status, RideStatus.driverComing);
    store.dispose();
  });

  test('Mashwara kiraya kam se kam Rs 200', () {
    expect(AppStore.suggestedFare(AppStore.places[0], AppStore.places[11]), greaterThanOrEqualTo(200));
  });
}

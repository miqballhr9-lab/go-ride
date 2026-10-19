# Go Ride

An inDrive-style ride-hailing app: the passenger names their own fare, and drivers accept it or send a counter-offer.

## What's built so far (MVP with demo data)

**Passenger mode**
- Phone + OTP login (demo code: `1234`)
- Pick pickup and destination on the map, with a recommended fare
- Offer your own fare, add a comment
- Driver offers: Accept / Decline, raise fare by Rs 20
- Ride status: driver on the way, arrived, in progress, completed, rating

**Driver mode** (switch from the side menu)
- Registration: CNIC, car model, color, number plate
- Online / Offline, nearby ride requests
- Accept the passenger's fare or counter-offer (+20/+50/+100)
- Ride flow: arrived, start, complete; today's earnings

![App flow](docs/app-flow.png)

## Still to do
- [ ] Firebase backend (real login, real drivers/passengers, live location)
- [ ] Control office (admin web panel)
- [ ] GPS location, place search (geocoding)
- [ ] Document upload, notifications, in-app chat/call

> All rides and drivers currently come from demo data in `lib/store.dart`.
> Once Firebase is connected, the same methods will talk to the real backend.

## Running
```bash
flutter pub get
flutter run            # Android/iPhone
flutter run -d chrome  # in the browser
flutter test
```

## Code layout
```
lib/
  main.dart            app + login/mode routing
  models.dart          Ride, Offer, Driver, Place
  store.dart           app state (demo backend for now)
  theme.dart
  widgets/common.dart  map, side menu, history
  screens/login_screen.dart
  screens/passenger/   home, offers, ride
  screens/driver/      home (requests), registration, ride
```

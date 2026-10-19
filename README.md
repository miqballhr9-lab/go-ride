# Go Ride

An inDrive-style ride-hailing app: the passenger names their own fare, and drivers accept it or send a counter-offer.

## What's built so far (MVP with demo data)

For review, the login screen has one-tap buttons that open the **Passenger**, **Driver** (already approved) and **Control office** panels without logging in.

**Accounts**
- Phone + OTP login (demo code: `1234`), new users create an account (name, email, city)
- Profile editing, blocked accounts cannot log in
- Separate passenger and driver ratings

**Passenger mode**
- Choose Moto / Ride Mini / Ride AC, pickup and destination, recommended fare
- Offer your own fare (down to 70% of recommended), comment for the driver
- Driver offers: Accept / Decline, raise fare by Rs 20
- Ride status, chat with driver, share trip, SOS, cancel with a reason, rate the driver
- Ride history, support tickets, FAQ, safety tips

**Driver mode** (switch from the side menu)
- Registration: CNIC, license, vehicle type/model/color/year/plate, 6 documents
- Application reviewed by the control office (pending / approved / rejected / blocked)
- Online / Offline, nearby requests for your vehicle type
- Accept the passenger's fare or counter-offer (+20/+50/+100)
- Ride flow with chat, cancel reasons, passenger rating
- Earnings card: net income, commission, rides, rating

**Control office** (demo: tap "Control office" on the login screen)
- Dashboard: rides, fares, commission, online drivers, pending drivers, open tickets
- Live map of online drivers
- Drivers: review documents, approve / reject with reason, block / unblock
- Users: search, view rides, block / unblock
- Rides: filter by status and type, full ride details, cancel active rides
- Support: reply to tickets with templates, close tickets
- Fares & settings: base fare, per km, minimum fare per vehicle type, commission %

![App flow](docs/app-flow.png)
![Control office](docs/control-office.png)

## Still to do
- [ ] Firebase backend (real login, real drivers/passengers, live location)
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

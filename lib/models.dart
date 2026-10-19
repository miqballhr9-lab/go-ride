import 'package:latlong2/latlong.dart';

enum AppMode { passenger, driver }

enum RideStatus {
  searching, // passenger ne request bheji, offers aa rahi hain
  driverComing, // offer accept ho gayi, driver aa raha hai
  driverArrived,
  inProgress,
  completed,
  cancelled,
}

class Place {
  final String name;
  final LatLng point;
  const Place(this.name, this.point);
}

class Vehicle {
  final String model;
  final String color;
  final String plate;
  const Vehicle({required this.model, required this.color, required this.plate});

  @override
  String toString() => '$color $model · $plate';
}

class AppUser {
  final String phone;
  String name;
  Vehicle? vehicle; // driver registration ke baad set hota hai
  String? cnic;
  bool driverApproved = false;

  AppUser({required this.phone, required this.name});

  bool get isDriverRegistered => vehicle != null;
}

class DriverInfo {
  final String id;
  final String name;
  final double rating;
  final int trips;
  final Vehicle vehicle;
  const DriverInfo({
    required this.id,
    required this.name,
    required this.rating,
    required this.trips,
    required this.vehicle,
  });
}

class Offer {
  final String id;
  final DriverInfo driver;
  final int fare;
  final int etaMinutes;
  const Offer({
    required this.id,
    required this.driver,
    required this.fare,
    required this.etaMinutes,
  });
}

class RideRequest {
  final String id;
  final String passengerName;
  final double passengerRating;
  final Place from;
  final Place to;
  int fare; // passenger ka bataya hua kiraya
  final String comment;
  final DateTime createdAt;
  final bool isMine; // is device ke passenger ki request

  RideStatus status = RideStatus.searching;
  final List<Offer> offers = [];
  Offer? acceptedOffer;
  int? rating;

  RideRequest({
    required this.id,
    required this.passengerName,
    required this.passengerRating,
    required this.from,
    required this.to,
    required this.fare,
    this.comment = '',
    required this.isMine,
  }) : createdAt = DateTime.now();

  double get distanceKm =>
      const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;

  int get finalFare => acceptedOffer?.fare ?? fare;
}

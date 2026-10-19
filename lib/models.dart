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

extension RideStatusLabel on RideStatus {
  String get label => switch (this) {
        RideStatus.searching => 'Searching',
        RideStatus.driverComing => 'Driver on the way',
        RideStatus.driverArrived => 'Driver arrived',
        RideStatus.inProgress => 'In progress',
        RideStatus.completed => 'Completed',
        RideStatus.cancelled => 'Cancelled',
      };

  bool get isActive =>
      this != RideStatus.completed && this != RideStatus.cancelled;
}

enum VehicleType { moto, mini, ac }

extension VehicleTypeInfo on VehicleType {
  String get label => switch (this) {
        VehicleType.moto => 'Moto',
        VehicleType.mini => 'Ride Mini',
        VehicleType.ac => 'Ride AC',
      };

  String get description => switch (this) {
        VehicleType.moto => '1 passenger, fastest',
        VehicleType.mini => 'Small car, budget',
        VehicleType.ac => 'Comfortable car with AC',
      };
}

/// Control office yeh settings badal sakta hai.
class FareSettings {
  final Map<VehicleType, int> baseFare;
  final Map<VehicleType, int> perKm;
  final Map<VehicleType, int> minFare;
  int commissionPercent;

  FareSettings({
    required this.baseFare,
    required this.perKm,
    required this.minFare,
    required this.commissionPercent,
  });

  factory FareSettings.defaults() => FareSettings(
        baseFare: {VehicleType.moto: 60, VehicleType.mini: 120, VehicleType.ac: 170},
        perKm: {VehicleType.moto: 22, VehicleType.mini: 40, VehicleType.ac: 52},
        minFare: {VehicleType.moto: 100, VehicleType.mini: 200, VehicleType.ac: 280},
        commissionPercent: 10,
      );
}

class Place {
  final String name;
  final LatLng point;
  const Place(this.name, this.point);
}

class Vehicle {
  final VehicleType type;
  final String model;
  final String color;
  final String plate;
  final int year;
  const Vehicle({
    required this.type,
    required this.model,
    required this.color,
    required this.plate,
    required this.year,
  });

  @override
  String toString() => '$color $model · $plate';
}

enum DriverStatus { pending, approved, rejected, blocked }

extension DriverStatusLabel on DriverStatus {
  String get label => switch (this) {
        DriverStatus.pending => 'Pending review',
        DriverStatus.approved => 'Approved',
        DriverStatus.rejected => 'Rejected',
        DriverStatus.blocked => 'Blocked',
      };
}

const driverDocuments = [
  'Profile photo',
  'CNIC (front)',
  'CNIC (back)',
  'Driving license',
  'Vehicle registration',
  'Vehicle photo',
];

class DriverProfile {
  final String cnic;
  final String licenseNo;
  final Vehicle vehicle;
  final Set<String> documents;
  final DateTime submittedAt;
  DriverStatus status;
  String? rejectionReason;
  bool online = false;
  LatLng? location;

  DriverProfile({
    required this.cnic,
    required this.licenseNo,
    required this.vehicle,
    required this.documents,
    this.status = DriverStatus.pending,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();
}

class AppUser {
  final String id;
  final String phone;
  String name;
  String email;
  String city;
  final DateTime createdAt;
  bool blocked = false;
  final bool isBot; // demo data: app khud chalata hai

  // Rating: passenger aur driver ki alag alag.
  double passengerRatingSum = 0;
  int passengerRatingCount = 0;
  double driverRatingSum = 0;
  int driverRatingCount = 0;

  DriverProfile? driver;

  AppUser({
    required this.id,
    required this.phone,
    required this.name,
    this.email = '',
    this.city = 'Lahore',
    this.isBot = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get passengerRating =>
      passengerRatingCount == 0 ? 5.0 : passengerRatingSum / passengerRatingCount;
  double get driverRating =>
      driverRatingCount == 0 ? 5.0 : driverRatingSum / driverRatingCount;

  bool get isApprovedDriver => driver?.status == DriverStatus.approved;
}

class Offer {
  final String id;
  final String driverId;
  final int fare;
  final int etaMinutes;
  const Offer({
    required this.id,
    required this.driverId,
    required this.fare,
    required this.etaMinutes,
  });
}

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime time;
  ChatMessage(this.senderId, this.text) : time = DateTime.now();
}

class RideRequest {
  final String id;
  final String passengerId;
  final VehicleType vehicleType;
  final Place from;
  final Place to;
  int fare; // passenger ka bataya hua kiraya
  final String comment;
  final DateTime createdAt;

  RideStatus status = RideStatus.searching;
  final List<Offer> offers = [];
  final Set<String> declinedDriverIds = {};
  Offer? acceptedOffer;
  String? cancelReason;
  String? cancelledBy; // 'passenger', 'driver', 'admin'
  DateTime? completedAt;
  int? driverRatingGiven; // passenger ne driver ko di
  int? passengerRatingGiven; // driver ne passenger ko di
  int commission = 0;
  final List<ChatMessage> chat = [];

  RideRequest({
    required this.id,
    required this.passengerId,
    required this.vehicleType,
    required this.from,
    required this.to,
    required this.fare,
    this.comment = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String? get driverId => acceptedOffer?.driverId;

  double get distanceKm =>
      const Distance().as(LengthUnit.Meter, from.point, to.point) / 1000;

  int get finalFare => acceptedOffer?.fare ?? fare;
}

enum TicketStatus { open, answered, closed }

extension TicketStatusLabel on TicketStatus {
  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.answered => 'Answered',
        TicketStatus.closed => 'Closed',
      };
}

const supportCategories = [
  'Problem with a ride',
  'Fare or payment',
  'Driver or passenger behaviour',
  'Lost item',
  'Account and login',
  'Safety issue',
  'Driver registration',
  'Other',
];

class TicketMessage {
  final bool fromSupport;
  final String text;
  final DateTime time;
  TicketMessage({required this.fromSupport, required this.text, DateTime? time})
      : time = time ?? DateTime.now();
}

class SupportTicket {
  final String id;
  final String userId;
  final AppMode role;
  final String category;
  final String? rideId;
  final DateTime createdAt;
  TicketStatus status = TicketStatus.open;
  final List<TicketMessage> messages = [];

  SupportTicket({
    required this.id,
    required this.userId,
    required this.role,
    required this.category,
    this.rideId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

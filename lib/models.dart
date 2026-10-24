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

enum VehicleType { moto, mini, ac, pickup, shehzore, truck }

extension VehicleTypeInfo on VehicleType {
  String get label => switch (this) {
        VehicleType.moto => 'Moto',
        VehicleType.mini => 'Ride Mini',
        VehicleType.ac => 'Ride AC',
        VehicleType.pickup => 'Pickup',
        VehicleType.shehzore => 'Shehzore',
        VehicleType.truck => 'Mazda truck',
      };

  String get description => switch (this) {
        VehicleType.moto => '1 passenger, fastest',
        VehicleType.mini => 'Small car, budget',
        VehicleType.ac => 'Comfortable car with AC',
        VehicleType.pickup => 'Up to 800 kg',
        VehicleType.shehzore => 'Up to 2 tons',
        VehicleType.truck => 'Up to 6 tons',
      };

  bool get isFreight =>
      this == VehicleType.pickup || this == VehicleType.shehzore || this == VehicleType.truck;

  int get maxKg => switch (this) {
        VehicleType.pickup => 800,
        VehicleType.shehzore => 2000,
        VehicleType.truck => 6000,
        _ => 20,
      };
}

/// inDrive jaisi services: sawari, parcel (courier) aur saman (freight).
enum ServiceType { ride, courier, freight, intercity }

extension ServiceTypeInfo on ServiceType {
  String get label => switch (this) {
        ServiceType.ride => 'Ride',
        ServiceType.courier => 'Courier',
        ServiceType.freight => 'Freight',
        ServiceType.intercity => 'Intercity',
      };

  List<VehicleType> get vehicles => switch (this) {
        ServiceType.ride => [VehicleType.moto, VehicleType.mini, VehicleType.ac],
        ServiceType.courier => [VehicleType.moto, VehicleType.mini],
        ServiceType.freight => [VehicleType.pickup, VehicleType.shehzore, VehicleType.truck],
        ServiceType.intercity => [VehicleType.mini, VehicleType.ac],
      };
}

enum ParcelSize { small, medium, large }

extension ParcelSizeInfo on ParcelSize {
  String get label => switch (this) {
        ParcelSize.small => 'Small',
        ParcelSize.medium => 'Medium',
        ParcelSize.large => 'Large',
      };

  String get description => switch (this) {
        ParcelSize.small => 'Documents, phone, keys',
        ParcelSize.medium => 'Shoe box, food order',
        ParcelSize.large => 'Up to 20 kg',
      };

  int get surcharge => switch (this) {
        ParcelSize.small => 0,
        ParcelSize.medium => 50,
        ParcelSize.large => 100,
      };
}

class ParcelDetails {
  final String receiverName;
  final String receiverPhone;
  final ParcelSize size;
  final String description;
  final bool fragile;
  const ParcelDetails({
    required this.receiverName,
    required this.receiverPhone,
    required this.size,
    required this.description,
    this.fragile = false,
  });
}

class FreightDetails {
  final String cargo;
  final int weightKg;
  final int helpers; // saman uthane wale mazdoor
  const FreightDetails({required this.cargo, required this.weightKg, required this.helpers});
}

const helperFee = 500;

enum PaymentMethod { cash, wallet }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.wallet => 'Wallet',
      };
}

enum TxType { topUp, commission, ridePayment, rideEarning, adjustment, promo, referral, bonus, withdrawal, refund }

extension TxTypeLabel on TxType {
  String get label => switch (this) {
        TxType.topUp => 'Top-up',
        TxType.commission => 'Commission',
        TxType.ridePayment => 'Ride payment',
        TxType.rideEarning => 'Ride earning',
        TxType.adjustment => 'Adjustment by support',
        TxType.promo => 'Promo discount paid by Go Ride',
        TxType.referral => 'Referral bonus',
        TxType.bonus => 'Driver bonus',
        TxType.withdrawal => 'Withdrawal',
        TxType.refund => 'Refund',
      };
}

enum TxStatus { pending, success, failed }

const topUpMethods = ['JazzCash', 'Easypaisa', 'Debit / credit card', 'Bank transfer'];

class WalletTransaction {
  final String id;
  final String userId;
  final TxType type;
  final int amount; // + jama, - kata
  final String? method;
  final String? rideId;
  final String note;
  final DateTime time;
  TxStatus status;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.method,
    this.rideId,
    this.note = '',
    this.status = TxStatus.success,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

/// Rating ke saath comment ke liye tayyar tags.
const driverReviewTags = ['Polite', 'Clean car', 'Safe driving', 'On time', 'Knows the route'];
const passengerReviewTags = ['Polite', 'On time', 'Clear pickup point', 'Respectful'];

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
        baseFare: {
          VehicleType.moto: 60, VehicleType.mini: 120, VehicleType.ac: 170,
          VehicleType.pickup: 600, VehicleType.shehzore: 1200, VehicleType.truck: 2500,
        },
        perKm: {
          VehicleType.moto: 22, VehicleType.mini: 40, VehicleType.ac: 52,
          VehicleType.pickup: 70, VehicleType.shehzore: 110, VehicleType.truck: 180,
        },
        minFare: {
          VehicleType.moto: 100, VehicleType.mini: 200, VehicleType.ac: 280,
          VehicleType.pickup: 1000, VehicleType.shehzore: 2000, VehicleType.truck: 4000,
        },
        commissionPercent: 10,
      );
}

class Place {
  final String name;
  final LatLng point;
  final bool isAirport;
  const Place(this.name, this.point, {this.isAirport = false});
}

/// Har sheher ki apni jaghein, kiraye aur services.
class City {
  final String name;
  final LatLng center;
  final List<Place> places;
  FareSettings settings;
  final Set<ServiceType> services;
  int airportFee;

  City({
    required this.name,
    required this.center,
    required this.places,
    required this.settings,
    Set<ServiceType>? services,
    this.airportFee = 150,
  }) : services = services ?? ServiceType.values.toSet();

  /// Intercity ke liye sheher khud ek jagah hai.
  Place get asPlace => Place(name, center);
}

// ------------------------------------------------------------ Control office

enum AdminRole { superAdmin, support, verification, finance }

extension AdminRoleInfo on AdminRole {
  String get label => switch (this) {
        AdminRole.superAdmin => 'Super admin',
        AdminRole.support => 'Support agent',
        AdminRole.verification => 'Verification team',
        AdminRole.finance => 'Finance',
      };
}

class StaffAccount {
  final String username;
  final String password;
  final String name;
  final AdminRole role;
  const StaffAccount(this.username, this.password, this.name, this.role);
}

class AuditEntry {
  final DateTime time;
  final String staff;
  final String action;
  final String target;
  AuditEntry(this.staff, this.action, this.target, {DateTime? time}) : time = time ?? DateTime.now();
}

class SafetyAlert {
  final String id;
  final String rideId;
  final String userId;
  final DateTime time;
  bool resolved = false;
  String note = '';
  SafetyAlert({required this.id, required this.rideId, required this.userId, DateTime? time})
      : time = time ?? DateTime.now();
}

class PromoCode {
  final String code;
  final int percent; // 0 ho to fixed
  final int fixed;
  final int maxDiscount;
  final int maxUses;
  final DateTime expires;
  int used = 0;
  bool active = true;
  PromoCode({
    required this.code,
    this.percent = 0,
    this.fixed = 0,
    this.maxDiscount = 300,
    required this.maxUses,
    required this.expires,
  });

  String get summary => percent > 0 ? '$percent% off (up to Rs $maxDiscount)' : 'Rs $fixed off';

  int discountFor(int fare) => percent > 0 ? (fare * percent / 100).round().clamp(0, maxDiscount) : fixed.clamp(0, fare);
}

/// Driver bonus: "aaj itni rides poori karo, itne paise pao".
class Incentive {
  final String id;
  final String title;
  final VehicleType? vehicleType; // null = sab
  final int targetRides;
  final int reward;
  final DateTime validUntil;
  final Set<String> paidTo = {};
  Incentive({
    required this.id,
    required this.title,
    this.vehicleType,
    required this.targetRides,
    required this.reward,
    required this.validUntil,
  });
}

enum Audience { everyone, passengers, drivers, user }

extension AudienceLabel on Audience {
  String get label => switch (this) {
        Audience.everyone => 'Everyone',
        Audience.passengers => 'Passengers',
        Audience.drivers => 'Drivers',
        Audience.user => 'One user',
      };
}

class AppNotification {
  final String id;
  final Audience audience;
  final String? userId;
  final String title;
  final String body;
  final DateTime time;
  final Set<String> readBy = {};
  AppNotification({
    required this.id,
    required this.audience,
    this.userId,
    required this.title,
    required this.body,
    DateTime? time,
  }) : time = time ?? DateTime.now();
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
  DateTime licenseExpiry;
  DateTime? lastSelfieAt; // roz ek dafa chehre ki tasdeeq
  Place? destination; // destination mode

  DriverProfile({
    required this.cnic,
    required this.licenseNo,
    required this.vehicle,
    required this.documents,
    this.status = DriverStatus.pending,
    DateTime? submittedAt,
    DateTime? licenseExpiry,
  })  : submittedAt = submittedAt ?? DateTime.now(),
        licenseExpiry = licenseExpiry ?? DateTime.now().add(const Duration(days: 700));

  bool get licenseExpired => licenseExpiry.isBefore(DateTime.now());
  bool get licenseExpiringSoon =>
      !licenseExpired && licenseExpiry.isBefore(DateTime.now().add(const Duration(days: 30)));
  bool get selfieValid =>
      lastSelfieAt != null && DateTime.now().difference(lastSelfieAt!) < const Duration(hours: 24);
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
  int walletBalance = 0;
  String referralCode = '';
  String? referredBy;
  int warnings = 0;
  DateTime? suspendedUntil;

  bool get suspended => suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());

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
  final bool isCall; // call ka record
  ChatMessage(this.senderId, this.text, {this.isCall = false}) : time = DateTime.now();
}

class RideRequest {
  final String id;
  final String passengerId;
  final ServiceType service;
  final VehicleType vehicleType;
  final PaymentMethod payment;
  final ParcelDetails? parcel;
  final FreightDetails? freight;
  final Place from;
  final Place to;
  int fare; // passenger ka bataya hua kiraya
  final String comment;
  final DateTime createdAt;
  final String city;
  final DateTime? scheduledAt; // baad ke waqt ki ride / intercity rawangi
  final int seats; // intercity
  final String? promoCode;
  final int discount; // promo se passenger ki bachat (Go Ride deta hai)

  RideStatus status = RideStatus.searching;
  bool refunded = false;
  final List<Offer> offers = [];
  final Set<String> declinedDriverIds = {};
  Offer? acceptedOffer;
  String? cancelReason;
  String? cancelledBy; // 'passenger', 'driver', 'admin'
  DateTime? completedAt;
  int? driverRatingGiven; // passenger ne driver ko di
  String driverReview = '';
  int? passengerRatingGiven; // driver ne passenger ko di
  String passengerReview = '';
  int commission = 0;
  final List<ChatMessage> chat = [];

  RideRequest({
    required this.id,
    required this.passengerId,
    this.service = ServiceType.ride,
    required this.vehicleType,
    this.payment = PaymentMethod.cash,
    this.parcel,
    this.freight,
    required this.from,
    required this.to,
    required this.fare,
    this.comment = '',
    DateTime? createdAt,
    this.city = 'Lahore',
    this.scheduledAt,
    this.seats = 1,
    this.promoCode,
    this.discount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String? get driverId => acceptedOffer?.driverId;

  /// Passenger asal mein kitna dega (promo ke baad).
  int get passengerPays => (finalFare - discount).clamp(0, finalFare);

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
  String? assignedTo; // staff ka naam

  /// 2 ghante se zyada jawab ke baghair khula ticket.
  bool get overdue =>
      status == TicketStatus.open && DateTime.now().difference(createdAt) > const Duration(hours: 2);
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

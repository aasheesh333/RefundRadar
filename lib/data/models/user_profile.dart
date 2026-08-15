import 'package:flutter/foundation.dart';

/// Complainant identity captured once at onboarding (editable in Settings)
/// and pre-filled into every escalation email via the
/// `USER_NAME / MOBILE_NO / EMAIL / ADDRESS / PLACE / ACCOUNT_NO`
/// template tokens, so the user can send a grievance email without typing
/// anything by hand.
@immutable
class UserProfile {
  final String name;
  final String mobile;
  final String email;
  final String address;
  final String place;
  final String accountNo;

  const UserProfile({
    this.name = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.place = '',
    this.accountNo = '',
  });

  static const empty = UserProfile();

  bool get isEmpty =>
      name.trim().isEmpty &&
      mobile.trim().isEmpty &&
      email.trim().isEmpty &&
      address.trim().isEmpty &&
      place.trim().isEmpty &&
      accountNo.trim().isEmpty;

  /// The email must come from a real account (the bank replies to it) and
  /// the name is the complainant signature — both are hard-required for a
  /// send-ready grievance email.
  bool get isSendReady => name.trim().isNotEmpty && email.trim().isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? mobile,
    String? email,
    String? address,
    String? place,
    String? accountNo,
  }) =>
      UserProfile(
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        address: address ?? this.address,
        place: place ?? this.place,
        accountNo: accountNo ?? this.accountNo,
      );

  Map<String, String> toJson() => {
        'name': name,
        'mobile': mobile,
        'email': email,
        'address': address,
        'place': place,
        'accountNo': accountNo,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        place: json['place'] as String? ?? '',
        accountNo: json['accountNo'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.mobile == mobile &&
      other.email == email &&
      other.address == address &&
      other.place == place &&
      other.accountNo == accountNo;

  @override
  int get hashCode => Object.hash(
      name, mobile, email, address, place, accountNo);
}

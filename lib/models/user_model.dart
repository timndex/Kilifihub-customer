/// User model representing the authenticated customer
///
/// Maps to the user data returned by auth endpoints
/// and `GET /kilifi/v1/customer/profile`.
class UserModel {
  final int id;
  final String displayName;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String avatar;
  final String token;

  UserModel({
    required this.id,
    this.displayName = '',
    this.email = '',
    this.phone = '',
    this.firstName = '',
    this.lastName = '',
    this.avatar = '',
    this.token = '',
  });

  /// Create from WordPress API JSON response
  ///
  /// Handles both login response format (flat) and profile response format.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] as int? ?? json['id'] as int? ?? 0,
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? json['avatar_url'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'avatar': avatar,
      'token': token,
    };
  }

  /// Full name (first + last)
  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : displayName;
  }

  /// Whether the user has an avatar
  bool get hasAvatar => avatar.isNotEmpty;

  /// Initials for avatar placeholder (e.g., "JD")
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (displayName.isNotEmpty) {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    return '?';
  }

  UserModel copyWith({
    int? id,
    String? displayName,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    String? avatar,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatar: avatar ?? this.avatar,
      token: token ?? this.token,
    );
  }
}

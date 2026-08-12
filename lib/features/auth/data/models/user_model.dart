import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatar;
  final String bio;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    this.bio = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      avatar: json['avatar'],
      bio: json['bio'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar': avatar,
        'bio': bio,
      };

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonStr) =>
      UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  UserModel copyWith({String? name, String? bio, String? avatar}) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
    );
  }
}

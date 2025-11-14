class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' | 'user'
  final String token; // JWT from backend

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json, {String token = ''}) {
    return AuthUser(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'user').toString(),
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'token': token,
      };
}

class UserModel {
  final String id;
  final String employeeCode;
  final String name;
  final String email;
  final String role;
  final String specialization;
  final List<String> skills;

  UserModel({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.role,
    required this.specialization,
    required this.skills,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      employeeCode: map['employeeCode'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      specialization: map['specialization'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeCode': employeeCode,
      'name': name,
      'email': email,
      'role': role,
      'specialization': specialization,
      'skills': skills,
    };
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isManager => role == 'MANAGER';
  bool get isAgent => role == 'AGENT';
}

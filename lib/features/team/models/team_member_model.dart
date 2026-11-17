import '../../auth/models/user_model.dart';

class TeamMemberModel {
  final String id;
  final String employeeCode;
  final String name;
  final String role;
  final String specialization;
  final List<String> skills;

  TeamMemberModel({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.role,
    required this.specialization,
    required this.skills,
  });

  factory TeamMemberModel.fromUser(UserModel user) {
    return TeamMemberModel(
      id: user.id,
      employeeCode: user.employeeCode,
      name: user.name,
      role: user.role,
      specialization: user.specialization,
      skills: user.skills,
    );
  }
}

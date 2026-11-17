class ProjectModel {
  final String id;
  final String name;
  final String clientName;
  final String description;
  final String managerId;
  final String managerName;
  final DateTime deadline;
  final List<String> agentIds;
  final int taskCount;
  final double totalEstimatedHours;

  ProjectModel({
    required this.id,
    required this.name,
    required this.clientName,
    required this.description,
    required this.managerId,
    required this.managerName,
    required this.deadline,
    required this.agentIds,
    required this.taskCount,
    required this.totalEstimatedHours,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    return ProjectModel(
      id: id,
      name: map['name'] ?? '',
      clientName: map['clientName'] ?? '',
      description: map['description'] ?? '',
      managerId: map['managerId'] ?? '',
      managerName: map['managerName'] ?? '',
      deadline: DateTime.parse(map['deadline']),
      agentIds: List<String>.from(map['agentIds'] ?? []),
      taskCount: map['taskCount'] ?? 0,
      totalEstimatedHours: (map['totalEstimatedHours'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'clientName': clientName,
      'description': description,
      'managerId': managerId,
      'managerName': managerName,
      'deadline': deadline.toIso8601String().split('T').first,
      'agentIds': agentIds,
      'taskCount': taskCount,
      'totalEstimatedHours': totalEstimatedHours,
    };
  }
}

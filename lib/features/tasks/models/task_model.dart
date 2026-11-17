class TaskModel {
  final String id;
  final String projectId;
  final String projectName;
  final String title;
  final String description;
  final String assigneeId;
  final String assigneeName;
  final String deadline;
  final double estimatedHours;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.assigneeName,
    required this.deadline,
    required this.estimatedHours,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      projectId: map['projectId'] ?? '',
      projectName: map['projectName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      assigneeId: map['assigneeId'] ?? '',
      assigneeName: map['assigneeName'] ?? '',
      deadline: map['deadline'] ?? '',
      estimatedHours: (map['estimatedHours'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'projectName': projectName,
      'title': title,
      'description': description,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'deadline': deadline,
      'estimatedHours': estimatedHours,
    };
  }
}

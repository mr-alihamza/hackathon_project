import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/models/user_model.dart';
import '../../features/projects/models/project_model.dart';
import '../../features/tasks/models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  Future<List<UserModel>> getTeamMembers() async {
    final snapshot = await _users.get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<UserModel>> getManagers() async {
    final snapshot = await _users.where('role', isEqualTo: 'MANAGER').get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<UserModel>> getAgents() async {
    final snapshot = await _users.where('role', isEqualTo: 'AGENT').get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<ProjectModel>> getProjects(UserModel user) async {
    Query<Map<String, dynamic>> query = _projects;

    if (user.isManager) {
      query = query.where('managerId', isEqualTo: user.id);
    } else if (user.isAgent) {
      query = query.where('agentIds', arrayContains: user.id);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<ProjectModel?> getProjectById(String id) async {
    final doc = await _projects.doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return ProjectModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<TaskModel>> getTasks({
    required UserModel user,
    String? projectId,
  }) async {
    Query<Map<String, dynamic>> query = _tasks;

    if (user.isAgent) {
      query = query.where('assigneeId', isEqualTo: user.id);
    }

    if (projectId != null) {
      query = query.where('projectId', isEqualTo: projectId);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> saveGeneratedProjects(
    List<Map<String, dynamic>> projects,
  ) async {
    if (projects.isEmpty) {
      throw Exception('No projects were generated.');
    }

    final batch = _db.batch();

    final projectReferences = <DocumentReference>[];

    for (final project in projects) {
      final projectRef = _projects.doc();
      projectReferences.add(projectRef);

      final tasks = List<Map<String, dynamic>>.from(project['tasks'] ?? []);

      final agentIds = tasks
          .map((task) => task['assigneeId'] as String)
          .toSet()
          .toList();

      final projectData = Map<String, dynamic>.from(project);
      projectData.remove('tasks');

      projectData['agentIds'] = agentIds;
      projectData['taskCount'] = tasks.length;
      projectData['totalEstimatedHours'] = tasks.fold<double>(
        0,
        (total, task) => total + (task['estimatedHours'] as num).toDouble(),
      );
      projectData['createdAt'] = FieldValue.serverTimestamp();

      batch.set(projectRef, projectData);

      for (final task in tasks) {
        final taskRef = _tasks.doc();

        batch.set(taskRef, {
          ...task,
          'projectId': projectRef.id,
          'projectName': project['name'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Firestore commits the entire batch or none of it.
    await batch.commit();
  }
}

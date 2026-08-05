import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/planner_task.dart';

/// Firestore-backed CRUD for a single user's tasks, stored at
/// users/{uid}/tasks/{taskId}.
class TaskService {
  TaskService({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('users').doc(uid).collection('tasks');

  Stream<List<PlannerTask>> watchTasks() {
    return _tasks.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => PlannerTask.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Generates a new document id without writing anything, so callers can
  /// build a [PlannerTask] with a real id before the first [updateTask] call.
  String createTaskId() => _tasks.doc().id;

  Future<void> updateTask(PlannerTask task) {
    return _tasks.doc(task.id).set(task.toMap());
  }

  Future<void> deleteTask(String taskId) {
    return _tasks.doc(taskId).delete();
  }

  /// Wipes every task plus the parent user document, for account deletion.
  ///
  /// Firestore has no client-side recursive delete, so this pages through the
  /// collection in batches. Must run *before* the auth account is deleted —
  /// the security rules match on `request.auth.uid`, so once the account is
  /// gone the data is unreachable and would be orphaned forever.
  Future<void> deleteAllData() async {
    const pageSize = 400;
    while (true) {
      final snapshot = await _tasks.limit(pageSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < pageSize) break;
    }
    await _db.collection('users').doc(uid).delete();
  }
}

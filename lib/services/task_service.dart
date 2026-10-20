import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/planner_task.dart';

/// Firestore-backed CRUD for a single user's tasks, stored at
/// users/{uid}/tasks/{taskId}.
class TaskService {
  TaskService({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _userDoc.collection('tasks');

  /// The user's category list. Emits null until they've customised it, so the
  /// caller can fall back to the presets.
  Stream<List<String>?> watchCategories() {
    return _userDoc.snapshots().map((snapshot) {
      final raw = snapshot.data()?['categories'] as List<dynamic>?;
      return raw?.map((value) => value as String).toList();
    });
  }

  /// Merged, so writing categories never clobbers anything else on the doc.
  Future<void> saveCategories(List<String> categories) {
    return _userDoc.set({'categories': categories}, SetOptions(merge: true));
  }

  Stream<Map<String, int>?> watchAppearance() {
    return _userDoc.snapshots().map((snapshot) {
      final raw = snapshot.data()?['appearance'] as Map<String, dynamic>?;
      return raw?.map((key, value) => MapEntry(key, (value as num).toInt()));
    });
  }

  Future<void> saveAppearance(Map<String, int> appearance) {
    return _userDoc.set({'appearance': appearance}, SetOptions(merge: true));
  }

  Stream<bool> watchCalendarSyncEnabled() {
    return _userDoc.snapshots().map(
      (snapshot) => snapshot.data()?['calendarSyncEnabled'] as bool? ?? false,
    );
  }

  Future<void> saveCalendarSyncEnabled(bool enabled) {
    return _userDoc.set({
      'calendarSyncEnabled': enabled,
    }, SetOptions(merge: true));
  }

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

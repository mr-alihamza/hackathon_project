import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../features/auth/models/user_model.dart';

class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rxn<UserModel> user = Rxn<UserModel>();

  UserModel? get currentUser => user.value;

  Future<void> initialize() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) return;

    try {
      await loadUser(firebaseUser.uid);
    } catch (_) {
      await _auth.signOut();
      user.value = null;
    }
  }

  Future<UserModel> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('Unable to authenticate user.');
    }

    try {
      return await loadUser(firebaseUser.uid);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<UserModel> loadUser(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Your account is not registered in NovaWorks.');
    }

    final model = UserModel.fromMap(snapshot.data()!, snapshot.id);

    if (!['ADMIN', 'MANAGER', 'AGENT'].contains(model.role)) {
      throw Exception('Invalid account role.');
    }

    user.value = model;

    return model;
  }

  Future<void> logout() async {
    await _auth.signOut();
    user.value = null;
  }
}

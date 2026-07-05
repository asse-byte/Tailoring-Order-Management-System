import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/mock_database.dart';
import '../../auth/domain/entities/app_user.dart';
import '../domain/entities/measurements.dart';

class CustomerFailure implements Exception {
  CustomerFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Repository for the user profile + body measurements.
/// (Used by both the customer and admin views.)
class CustomersRepository {
  CustomersRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(AppConstants.usersCollection);
  CollectionReference<Map<String, dynamic>> get _measurements =>
      firestore.collection(AppConstants.measurementsCollection);

  // -------- Profile --------

  Stream<AppUser?> watchUser(String uid) {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getCustomer(uid));
    }
    return _users
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? AppUser.fromMap(d.id, d.data()!) : null);
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    required String phone,
    String? profilePhotoUrl,
  }) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.updateProfile(
        uid: uid,
        name: name,
        phone: phone,
        profilePhotoUrl: profilePhotoUrl,
      );
      return;
    }
    final Map<String, dynamic> updates = <String, dynamic>{
      'name': name,
      'phone': phone,
    };
    if (profilePhotoUrl != null) {
      updates['profilePhotoUrl'] = profilePhotoUrl;
    }
    await _users.doc(uid).set(updates, SetOptions(merge: true));
  }

  Future<String> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    if (MockDatabase.useMock) {
      return 'https://via.placeholder.com/150';
    }
    final String ext = file.path.split('.').last;
    final Reference ref =
        storage.ref().child('${AppConstants.profilePhotosPath}/$uid.$ext');
    final TaskSnapshot snap = await ref.putFile(file);
    return snap.ref.getDownloadURL();
  }

  /// Admin: list all customer users.
  Stream<List<AppUser>> watchCustomers() {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getCustomers());
    }
    return _users
        .where('role', isEqualTo: AppConstants.roleCustomer)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  // -------- Measurements --------

  Stream<Measurements> watchMeasurements(String uid) {
    if (MockDatabase.useMock) {
      return Stream.value(MockDatabase.instance.getMeasurements(uid));
    }
    return _measurements.doc(uid).snapshots().map((d) => d.exists
        ? Measurements.fromMap(d.id, d.data()!)
        : Measurements.empty(uid));
  }

  Future<Measurements?> getMeasurements(String uid) async {
    if (MockDatabase.useMock) {
      return MockDatabase.instance.getMeasurements(uid);
    }
    final doc = await _measurements.doc(uid).get();
    if (!doc.exists) return null;
    return Measurements.fromMap(doc.id, doc.data()!);
  }

  Future<void> saveMeasurements(Measurements m) async {
    if (MockDatabase.useMock) {
      await MockDatabase.instance.saveMeasurements(m);
      return;
    }
    await _measurements.doc(m.userId).set(m.toMap(), SetOptions(merge: true));
  }
}

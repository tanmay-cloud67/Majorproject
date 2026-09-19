import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return UserProfile.fromDocument(snapshot);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }

    return UserProfile.fromDocument(snapshot);
  }

  Future<UserProfile> ensureUserProfile({
    required String uid,
    required String email,
  }) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists) {
      final profile = UserProfile.initial(uid: uid, email: email);
      await _usersCollection.doc(uid).set({
        ...profile.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return profile;
    }

    final profile = UserProfile.fromDocument(snapshot);
    if (email.isEmpty || profile.email == email) {
      return profile;
    }

    await _usersCollection.doc(uid).set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return profile.copyWith(email: email);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required int age,
    required double weight,
    required double height,
    required String goal,
  }) async {
    try {
      final email = _auth.currentUser?.email ?? '';

      await ensureUserProfile(uid: uid, email: email);
      await _usersCollection.doc(uid).set({
        'uid': uid,
        if (email.isNotEmpty) 'email': email,
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'goal': goal,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
  }) async {
    try {
      final trimmed = photoUrl.trim();
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (trimmed.isEmpty) {
        data['photoUrl'] = FieldValue.delete();
      } else {
        data['photoUrl'] = trimmed;
      }

      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile photo: $e');
    }
  }

  Future<void> updateStepsGoal({
    required String uid,
    required int stepsGoal,
  }) async {
    try {
      await _usersCollection.doc(uid).set({
        'stepsGoal': stepsGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update step goal: $e');
    }
  }

  Future<void> updateBio({
    required String uid,
    required String bio,
  }) async {
    try {
      final trimmed = bio.trim();
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (trimmed.isEmpty) {
        data['bio'] = FieldValue.delete();
      } else {
        data['bio'] = trimmed;
      }

      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update bio: $e');
    }
  }

  Future<void> updateProfileDetails({
    required String uid,
    String? profession,
    String? goal,
    int? age,
    double? height,
    double? weight,
    bool clearProfession = false,
    bool clearGoal = false,
    bool clearAge = false,
    bool clearHeight = false,
    bool clearWeight = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (profession != null) {
        final trimmed = profession.trim();
        data['profession'] =
            trimmed.isEmpty ? FieldValue.delete() : trimmed;
      } else if (clearProfession) {
        data['profession'] = FieldValue.delete();
      }

      if (goal != null) {
        final trimmed = goal.trim();
        data['goal'] = trimmed.isEmpty ? FieldValue.delete() : trimmed;
      } else if (clearGoal) {
        data['goal'] = FieldValue.delete();
      }

      if (age != null) {
        data['age'] = age;
      } else if (clearAge) {
        data['age'] = FieldValue.delete();
      }

      if (height != null) {
        data['height'] = height;
      } else if (clearHeight) {
        data['height'] = FieldValue.delete();
      }

      if (weight != null) {
        data['weight'] = weight;
      } else if (clearWeight) {
        data['weight'] = FieldValue.delete();
      }

      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null) {
        await ensureUserProfile(uid: user.uid, email: user.email ?? email);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.code);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.code);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.code);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.profileCompleted,
    this.name,
    this.age,
    this.weight,
    this.height,
    this.goal,
    this.stepsGoal,
    this.bio,
    this.profession,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String? name;
  final int? age;
  final double? weight;
  final double? height;
  final String? goal;
  final int? stepsGoal;
  final String? bio;
  final String? profession;
  final String? photoUrl;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.initial({required String uid, required String email}) {
    return UserProfile(uid: uid, email: email, profileCompleted: false);
  }

  factory UserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return UserProfile.fromMap(document.id, document.data() ?? {});
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: (data['uid'] as String?) ?? uid,
      email: (data['email'] as String?) ?? '',
      name: data['name'] as String?,
      age: _asInt(data['age']),
      weight: _asDouble(data['weight']),
      height: _asDouble(data['height']),
      goal: data['goal'] as String?,
      stepsGoal: _asInt(data['stepsGoal']),
      bio: data['bio'] as String?,
      profession: data['profession'] as String?,
      photoUrl: data['photoUrl'] as String?,
      profileCompleted: data['profileCompleted'] == true,
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      if (age != null) 'age': age,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (goal != null && goal!.trim().isNotEmpty) 'goal': goal!.trim(),
      if (stepsGoal != null) 'stepsGoal': stepsGoal,
      if (bio != null && bio!.trim().isNotEmpty) 'bio': bio!.trim(),
      if (profession != null && profession!.trim().isNotEmpty)
        'profession': profession!.trim(),
      if (photoUrl != null && photoUrl!.trim().isNotEmpty)
        'photoUrl': photoUrl!.trim(),
      'profileCompleted': profileCompleted,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    int? age,
    double? weight,
    double? height,
    String? goal,
    int? stepsGoal,
    String? bio,
    String? profession,
    String? photoUrl,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      goal: goal ?? this.goal,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      photoUrl: photoUrl ?? this.photoUrl,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int? _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}

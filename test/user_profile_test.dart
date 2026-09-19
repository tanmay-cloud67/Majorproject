import 'package:flutter_test/flutter_test.dart';
import 'package:health/models/user_profile.dart';

void main() {
  test('creates an initial profile with email only', () {
    final profile = UserProfile.initial(
      uid: 'user-123',
      email: 'person@example.com',
    );

    expect(profile.uid, 'user-123');
    expect(profile.email, 'person@example.com');
    expect(profile.profileCompleted, isFalse);
    expect(profile.toFirestore(), {
      'uid': 'user-123',
      'email': 'person@example.com',
      'profileCompleted': false,
    });
  });

  test('hydrates a profile from firestore-style data', () {
    final profile = UserProfile.fromMap('user-456', {
      'email': 'member@example.com',
      'name': 'Member',
      'age': 29,
      'weight': 68,
      'height': 172.5,
      'goal': 'Stay Active',
      'profileCompleted': true,
    });

    expect(profile.uid, 'user-456');
    expect(profile.email, 'member@example.com');
    expect(profile.name, 'Member');
    expect(profile.age, 29);
    expect(profile.weight, 68.0);
    expect(profile.height, 172.5);
    expect(profile.goal, 'Stay Active');
    expect(profile.profileCompleted, isTrue);
  });
}

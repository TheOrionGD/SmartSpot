import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/models/family_group.dart';

void main() {
  group('FamilyGroup Model Unit Tests', () {
    final now = DateTime(2026, 8, 23, 12, 0);

    test('serializes toJson and deserializes fromJson correctly', () {
      final group = FamilyGroup(
        id: 'grp-123',
        name: 'Household',
        memberNames: ['Alice', 'Bob'],
        inviteCode: 'AB12CD',
        createdAt: now,
      );

      final json = group.toJson();
      expect(json['id'], 'grp-123');
      expect(json['name'], 'Household');
      expect(json['memberNames'], ['Alice', 'Bob']);
      expect(json['inviteCode'], 'AB12CD');

      final reconstructed = FamilyGroup.fromJson(json);
      expect(reconstructed.id, group.id);
      expect(reconstructed.name, group.name);
      expect(reconstructed.memberNames, group.memberNames);
      expect(reconstructed.inviteCode, group.inviteCode);
    });

    test('copyWith updates member list properly', () {
      final original = FamilyGroup(
        id: 'grp-1',
        name: 'Study Circle',
        memberNames: ['Carol'],
        inviteCode: 'ST1234',
        createdAt: now,
      );

      final updated = original.copyWith(
        memberNames: ['Carol', 'Dave'],
      );

      expect(updated.id, 'grp-1');
      expect(updated.memberNames.length, 2);
      expect(updated.memberNames, contains('Dave'));
    });
  });
}

/// A lightweight, client-side-only group of "members" a user can share
/// location reminders with (e.g. a household or family).
///
/// NOTE: There is no backend yet. Membership here is a local list of names
/// the user has "invited" via a share code — nothing is actually synced to
/// other devices. This models the intended UX (and gives real UI to design
/// against) ahead of a proper multi-user backend (auth + sync) being built.
class FamilyGroup {
  final String id;
  final String name;
  final List<String> memberNames;
  final String inviteCode;
  final DateTime createdAt;

  FamilyGroup({
    required this.id,
    required this.name,
    required this.memberNames,
    required this.inviteCode,
    required this.createdAt,
  });

  FamilyGroup copyWith({
    String? name,
    List<String>? memberNames,
  }) {
    return FamilyGroup(
      id: id,
      name: name ?? this.name,
      memberNames: memberNames ?? this.memberNames,
      inviteCode: inviteCode,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberNames': memberNames,
        'inviteCode': inviteCode,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FamilyGroup.fromJson(Map<String, dynamic> json) {
    return FamilyGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      memberNames: List<String>.from(json['memberNames'] as List? ?? []),
      inviteCode: json['inviteCode'] as String? ?? '------',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

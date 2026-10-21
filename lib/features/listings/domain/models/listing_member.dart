import 'listing_role.dart';

/// One person on a project's team, as a row of `listing_members`.
class ListingMember {
  final String userId;

  /// Copied in when the row is written so the team can be listed without a
  /// lookup per person — ROBLE offers no join. Empty on rows written before the
  /// column existed.
  final String userName;
  final ListingRole role;

  const ListingMember({
    required this.userId,
    required this.userName,
    required this.role,
  });

  ListingMember copyWith({String? userName, ListingRole? role}) {
    return ListingMember(
      userId: userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
    );
  }
}

import '../../../auth/domain/entities/user_entity.dart';

/// Up to 2 uppercase initials from [user]'s name/lastname; [fallback] when
/// neither is available (or [user] is `null`). Same convention as
/// `EmergencyView`'s private `_initials` helper.
String userInitials(UserEntity? user, {String fallback = 'CS'}) {
  final first = user?.name.trim() ?? '';
  final last = user?.lastname.trim() ?? '';
  final initials =
      '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
          .toUpperCase();
  return initials.isNotEmpty ? initials : fallback;
}

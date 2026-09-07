/// Profile approval statuses (`UserProfileStatusEnum` on the API).
///
/// Distinct from account status (`active` / `paused` / `pending_deletion`).
abstract final class ProfileStatus {
  static const incomplete = 'incomplete';
  static const statusNew = 'new';
  static const disabled = 'disabled';
  static const deleted = 'deleted';
  static const unapproved = 'unapproved';
  static const approved = 'approved';
  static const fraud = 'fraud';
  static const pending = 'pending';
}

/// Pending-review reasons.
abstract final class PendingReason {
  /// Hide photo/name in chats (RN ActivityChatMessageItem).
  static const nudityRisk = 'nudity_risk';
}

/// Shared restriction rules for chat avatars / profile taps (RN ActivityChatMessageItem).
/// Fake user only for pending + nudity_risk (not pending + photo).
bool profileUserIsRestricted({
  String? status,
  String? pendingReason,
  String? accountStatus,
}) {
  if (status == ProfileStatus.deleted || status == ProfileStatus.disabled) {
    return true;
  }
  if (accountStatus == 'pending_deletion' || accountStatus == 'paused') {
    return true;
  }
  if (status == ProfileStatus.pending &&
      pendingReason == PendingReason.nudityRisk) {
    return true;
  }
  return false;
}

/// Meetups: only approved profiles may create posts.
bool canPostMeetups(String? status) => status == ProfileStatus.approved;

/// Client copy when [canPostMeetups] is false.
const meetupCannotPostMessage = 'Your account is too new to post meetups';

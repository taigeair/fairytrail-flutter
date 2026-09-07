abstract final class EndPoints {
  /// Flip to `false` for staging API + marketing share links.
  static const isProd = true;

  static const _prodBaseUrl = 'https://spring.fairytrail.app';
  static const _prodWebApiBaseUrl = 'https://web-api.fairytrail.app';
  static const _prodAtlasBaseUrl = 'https://atlas.fairytrail.app';

  static const _stagingBaseUrl = 'https://spring-staging.fairytrail.app';
  static const _stagingWebApiBaseUrl = 'https://web-api-staging.fairytrail.app';
  static const _stagingAtlasBaseUrl = 'https://atlas-staging.fairytrail.app';

  static const baseUrl = isProd ? _prodBaseUrl : _stagingBaseUrl;
  static const webApiBaseUrl = isProd
      ? _prodWebApiBaseUrl
      : _stagingWebApiBaseUrl;

  /// Atlas Go service (meetups).
  static const atlasBaseUrl = isProd ? _prodAtlasBaseUrl : _stagingAtlasBaseUrl;

  /// Base URL used by meetup HTTP calls.
  static String get atlasUrl => atlasBaseUrl;

  static const authCodeApprove = '/auth/code/approve';

  // Auth
  static const loginViaPassword = '/api/v1/login-via-password';
  static const loginApple = '/api/v1/login/apple';
  static const loginGoogleV2 = '/api/v2/login/google';
  static const logout = '/api/v1/logout';
  static const registration = '/api/v1/registration';
  static const passwordReset = '/api/v1/password-reset';
  static const passwordResetConfirmation =
      '/api/v1/password-reset-confirmation';
  static const me = '/api/v1/me';
  static const meTruthSerum = '/api/v1/me/truth-serum';
  static const init = '/api/v1/init';
  static const track = '/api/v1/track';
  static const attachments = '/api/v1/attachments';
  static const profilePhotos = '/api/v1/profile-photos';
  static const userData = '/api/v1/user-data';
  static const editProfileProps = '/api/v1/edit-profile-props';
  static const mePrefs = '/api/v1/me/prefs';
  static const meMatchWith = '/api/v1/me/match-with';
  static const profilesPrefetch = '/api/v1/profiles/prefetch';
  static const profilesConnect = '/api/v1/profiles/connect';
  static const profilesSkip = '/api/v1/profiles/skip';
  static const profilesUndoSkip = '/api/v1/profiles/undo-skip';
  static const profilesReport = '/api/v1/profiles/report';
  static const profilesStatus = '/api/v1/profiles/status';
  static const profilesIncoming = '/api/v1/profiles/incoming';
  static const profilesIncomingList = '/api/v1/profiles/incoming/list';
  static const location = '/api/v1/location';
  static const locationCountryId = '/api/v1/location/country-id';
  static const nearbyUsers = '/api/v1/nearby-users';
  static const restorePurchaseV2 = '/api/v1/billing/restore-purchase/v2';

  // Chat / matches (v2 delta sync — same as RN `/api/v2/matches?timestamp=`)
  static const matches = '/api/v2/matches';
  static const activityChats = '/api/v1/activity-chats';
  static const unread = '/api/v1/unread';
  static const profilesUnmatch = '/api/v1/profiles/unmatch';
  static const pushTokens = '/api/v1/push-tokens';
  static const timezone = '/api/v1/timezone';
  static const meConfig = '/api/v1/me/config';
  static const meAccountStatus = '/api/v1/me/account-status';
  static const meMarketingEmails = '/api/v1/me/marketing-emails';
  static const deleteAccount = '/api/v1/delete-account';

  /// Default full-sync watermark (RN `DEFAULT_MATCHES_SYNC_TIMESTAMP`).
  static const matchesSyncEpoch = '2018-01-01T00:00:00';

  static String matchesSince(String timestamp) =>
      '$matches?timestamp=${Uri.encodeQueryComponent(timestamp)}';

  static String matchMessages(int profileId) =>
      '/api/v1/matches/$profileId/messages';
  static String matchSeen(int profileId) => '/api/v1/matches/$profileId/seen';
  static String activityMessages(int activityId) =>
      '/api/v1/activities/$activityId/messages';
  static String activitySeen(int activityId) =>
      '/api/v1/activities/$activityId/seen';
  static String activityLeaveChat(int activityId) =>
      '/api/v1/activities/$activityId/leave-chat';
  static String profileView(int profileId) =>
      '/api/v1/profiles/view/$profileId';

  // Activities / bucket list
  static const activities = '/api/v1/activities';
  static const activitiesSearch = '/api/v1/search/activities';
  static const activitiesSave = '/api/v1/activities/save';
  static const activitiesUnsave = '/api/v1/activities/unsave';
  static const activitiesComplete = '/api/v1/activities/complete';
  static const activitiesEdit = '/api/v1/activities/edit';
  static const activitiesReport = '/api/v1/activities/report';
  static const addActivityProps = '/api/v1/add-activity-props';
  static const bucketLists = '/api/v1/bucket-lists';

  static String activityById(int id) => '/api/v1/activities/$id';
  static String activitySavedExplorers(int id) =>
      '/api/v1/activities/$id/saved-explorers';
  static String activityJoinChat(int id) => '/api/v1/activities/$id/join-chat';
  static String profileActivities(int profileId) =>
      '/api/v1/profiles/view/$profileId/activities';

  static String emailByEmail(String email) =>
      '/api/v1/email/${Uri.encodeComponent(email)}';

  // Travel / trail money (v2)
  static const travelAddMoney = '/api/v2/travel/add-money';
  static const travelUpdatePickupCountdown =
      '/api/v2/travel/update-pickup-countdown';
  static const stripeKeys = '/api/v2/stripe-keys';
  static const createPaymentIntent = '/api/v2/create-payment-intent';
  static const trailMoneyTopUp = '/api/v2/trail-money/top-up';

  // Trail Book / postcards (v2)
  static const sendCareNote = '/api/v2/send-care-note';
  static const updatePostcards = '/api/v2/update-postcards';
  static const trailBook = '/api/v2/trail-book';
  static const trailBookDelete = '/api/v2/trail-book/delete';
  static const trailBookReport = '/api/v2/trail-book/report';
  static const trailBookMarkRead = '/api/v2/trail-book/mark-read';
  static const trailBookMarkAllRead = '/api/v2/trail-book/list/mark-all-read';
  static const trailBookUnread = '/api/v2/trail-book/unread/items';
  static String trailBookById(int id) => '/api/v2/trail-book/$id';

  // Kindness rating (chat)
  static const rateUserKindness = '/api/v2/rate-user-kindness';
  static String checkKindnessRating(int matchId) =>
      '/api/v2/check-kindness-rating/$matchId';

  // Gift subscription
  static const giftSubscriptionPlans = '/api/v1/gift-subscription/plans';
  static const giftSubscriptionCreatePayment =
      '/api/v1/gift-subscription/create-payment';
  static const giftSubscriptionConfirm = '/api/v1/gift-subscription/confirm';
  static const giftSubscriptionPending = '/api/v1/gift-subscription/pending';
  static String giftSubscriptionById(String id) =>
      '/api/v1/gift-subscription/$id';
  static String giftSubscriptionAccept(String id) =>
      '/api/v1/gift-subscription/$id/accept';
  static String giftSubscriptionDecline(String id) =>
      '/api/v1/gift-subscription/$id/decline';

  // Meetups (Atlas)
  static const meetups = '/api/v1/meetups';
  static const meetupTerms = '/api/v1/meetups/terms';
  static const meetupTermsAccept = '/api/v1/meetups/terms/accept';
  static const meetupChats = '/api/v1/meetup-chats';
  static String meetupById(int id) => '/api/v1/meetups/$id';
  static String meetupJoin(int id) => '/api/v1/meetups/$id/join';
  static String meetupLeave(int id) => '/api/v1/meetups/$id/leave';
  static String meetupMembers(int id) => '/api/v1/meetups/$id/members';
  static String meetupReport(int id) => '/api/v1/meetups/$id/report';
  static String meetupMessages(int id) => '/api/v1/meetups/$id/messages';
  static String meetupSeen(int id) => '/api/v1/meetups/$id/seen';

  /// WebSocket origin derived from [baseUrl].
  static String get wsBaseUrl {
    final http = Uri.parse(baseUrl);
    final secure = http.scheme == 'https';
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: http.host,
      port: http.hasPort ? http.port : null,
    ).toString().replaceAll(RegExp(r'/$'), '');
  }
}

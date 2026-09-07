/// Result when a meetup chat closes: map/list callers remove the pin on `deleted` / `reported`.
typedef MeetupChatCloseResult = String;

class MeetupChatClose {
  MeetupChatClose._();

  static const deleted = 'deleted';
  static const reported = 'reported';
  static const left = 'left';
}

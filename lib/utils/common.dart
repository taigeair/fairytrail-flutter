import 'package:fairytrail/utils/api/https.dart';

const _genericErrorMessage =
    'Something went wrong. Please try again later';

const _messageSendForbiddenText =
    'Cannot send message right now, please try again';

/// Human-readable message from an [ApiException] (or any error).
///
/// API response errors keep their server message. Internal failures
/// (socket disconnect, timeouts, parse errors, etc.) use a generic copy.
String serverErrorText(Object error) {
  if (error is ApiException) {
    if (error.message.isNotEmpty) return error.message;
    return _genericErrorMessage;
  }
  return _genericErrorMessage;
}

/// True for HTTP 403 or an API message that includes "forbidden".
bool isForbiddenError(Object error) {
  if (error is! ApiException) return false;
  if (error.statusCode == 403) return true;
  return error.message.toLowerCase().contains('forbidden');
}

/// Toast copy when sending a chat message fails.
String messageSendFailedText(Object error) {
  if (isForbiddenError(error)) return _messageSendForbiddenText;
  return serverErrorText(error);
}

/// Error `code` from API payload when present.
String? serverErrorCode(Object error) {
  if (error is! ApiException) return null;
  final payload = error.payload;
  if (payload is Map && payload['code'] is String) {
    return payload['code'] as String;
  }
  return null;
}

/// Optional `reason` from API payload (e.g. unapproved profile).
String? serverErrorReason(Object error) {
  if (error is! ApiException) return null;
  final payload = error.payload;
  if (payload is Map && payload['reason'] is String) {
    final reason = payload['reason'] as String;
    return reason.isEmpty ? null : reason;
  }
  return null;
}

/// Returns [items] with selected entries first (stable within each group).
///
/// Prefer applying once when a picker opens — not on every select/deselect.
List<T> selectedFirst<T>(
  Iterable<T> items,
  bool Function(T item) isSelected,
) {
  final selected = <T>[];
  final rest = <T>[];
  for (final item in items) {
    if (isSelected(item)) {
      selected.add(item);
    } else {
      rest.add(item);
    }
  }
  return [...selected, ...rest];
}

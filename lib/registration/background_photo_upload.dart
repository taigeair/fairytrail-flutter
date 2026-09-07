import 'dart:async';
import 'dart:io';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/profile_photos.dart';
import 'package:fairytrail/track/track.dart';
import 'package:flutter/foundation.dart';

enum BackgroundPhotoUploadStatus {
  idle,
  uploading,
  uploaded,
  attaching,
  failed,
  done,
}

class PendingPhotoJob {
  PendingPhotoJob({
    required this.path,
    required this.filename,
    this.mimeType = 'image/jpeg',
  });

  final String path;
  final String filename;
  final String mimeType;

  String? attachmentId;
  String? uploadUrl;
  bool isUploaded = false;
  bool isCommitted = false;
  int? presignMs;
}

/// Uploads signup photo in the background (presign → S3 → attach on commit).
class BackgroundPhotoUpload extends ChangeNotifier {
  BackgroundPhotoUpload._();

  static final BackgroundPhotoUpload instance = BackgroundPhotoUpload._();

  static const _maxAttempts = 3;
  static const _retryDelayMs = 2000;

  PendingPhotoJob? _job;
  BackgroundPhotoUploadStatus _status = BackgroundPhotoUploadStatus.idle;
  VoidCallback? _onAttached;
  int _attempts = 0;
  Timer? _retryTimer;

  BackgroundPhotoUploadStatus get status => _status;
  String? get photoPath => _job?.path;

  bool get hasPendingUpload =>
      _status == BackgroundPhotoUploadStatus.uploading ||
      _status == BackgroundPhotoUploadStatus.uploaded ||
      _status == BackgroundPhotoUploadStatus.attaching;

  bool get hasFailedUpload => _status == BackgroundPhotoUploadStatus.failed;

  bool get hasJustCompletedUpload =>
      _status == BackgroundPhotoUploadStatus.done;

  void acknowledgeCompleted() {
    if (_status == BackgroundPhotoUploadStatus.done) {
      // Keep local photoPath until reset — preview UI may still need it.
      _setStatus(BackgroundPhotoUploadStatus.idle);
    }
  }

  void start({
    required String path,
    String filename = 'profile.jpg',
    String mimeType = 'image/jpeg',
  }) {
    _clearRetryTimer();
    _job = PendingPhotoJob(path: path, filename: filename, mimeType: mimeType);
    _onAttached = null;
    _attempts = 0;
    unawaited(_run(_job!));
  }

  /// User tapped Continue — attach when S3 upload is ready.
  void commit({VoidCallback? onAttached}) {
    final job = _job;
    if (job == null) return;

    _onAttached = onAttached;
    job.isCommitted = true;

    if (_status == BackgroundPhotoUploadStatus.uploaded) {
      unawaited(_run(job));
    } else if (_status == BackgroundPhotoUploadStatus.failed) {
      retry();
    }
    // If still uploading, _run continues after S3 and will attach.
  }

  void retry() {
    final job = _job;
    if (job == null || _status != BackgroundPhotoUploadStatus.failed) return;

    _attempts = 0;
    _prepareJobForRetry(job);
    unawaited(_run(job));
  }

  void reset() {
    _clearRetryTimer();
    _job = null;
    _onAttached = null;
    _attempts = 0;
    _setStatus(BackgroundPhotoUploadStatus.idle);
  }

  void _prepareJobForRetry(PendingPhotoJob job) {
    if (!job.isUploaded) {
      job.uploadUrl = null;
      job.attachmentId = null;
    }
  }

  void _clearRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _setStatus(BackgroundPhotoUploadStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> _run(PendingPhotoJob job) async {
    try {
      if (!job.isUploaded) {
        _setStatus(BackgroundPhotoUploadStatus.uploading);

        if (job.uploadUrl == null || job.attachmentId == null) {
          final presignStarted = DateTime.now();
          final signed = await createAttachment(filename: job.filename);
          if (!identical(_job, job)) return;
          job.presignMs = DateTime.now()
              .difference(presignStarted)
              .inMilliseconds;
          job.uploadUrl = signed.uploadUrl;
          job.attachmentId = signed.attachmentId;
        }

        final bytes = await File(job.path).readAsBytes();
        if (!identical(_job, job)) return;

        // final uploadStarted = DateTime.now();
        await uploadBytesToSignedUrl(
          uploadUrl: job.uploadUrl!,
          bytes: bytes,
          contentType: job.mimeType,
        );
        if (!identical(_job, job)) return;

        // unawaited(
        //   track('registration_photo_upload_timing', {
        //     'presignMs': job.presignMs ?? -1,
        //     'uploadMs':
        //         DateTime.now().difference(uploadStarted).inMilliseconds,
        //     'fileSizeKb': (bytes.length / 1024).round(),
        //   }),
        // );

        job.isUploaded = true;
      }

      if (!job.isCommitted) {
        _setStatus(BackgroundPhotoUploadStatus.uploaded);
        return;
      }

      final attachmentId = job.attachmentId;
      if (attachmentId == null || attachmentId.isEmpty) {
        throw StateError('Missing attachmentId after upload');
      }

      _setStatus(BackgroundPhotoUploadStatus.attaching);
      await attachProfilePhotos(attachmentIds: [attachmentId]);
      if (!identical(_job, job)) return;

      // Keep `_job` so [photoPath] remains available for signup preview while
      // auth/profile refresh rebuilds the tree.
      _setStatus(BackgroundPhotoUploadStatus.done);

      // Signup Mixpanel funnel is owned by [SignupFlowScreen]
      // (`completed_basic` / `completed_signup`). Firebase only here.
      unawaited(AnalyticsService.instance.logEvent('signup_basics_completed'));
      unawaited(AnalyticsService.instance.logEvent('fully_registered'));

      final onAttached = _onAttached;
      _onAttached = null;
      onAttached?.call();
    } catch (e, st) {
      if (!identical(_job, job)) return;
      debugPrint('[BackgroundPhotoUpload] attempt failed: $e\n$st');

      _attempts += 1;
      if (_attempts < _maxAttempts) {
        final delay = Duration(milliseconds: _retryDelayMs * _attempts);
        _clearRetryTimer();
        _retryTimer = Timer(delay, () {
          _retryTimer = null;
          if (!identical(_job, job)) return;
          _prepareJobForRetry(job);
          unawaited(_run(job));
        });
        return;
      }

      unawaited(
        track('registration_photo_bg_upload_failed', {
          'step': job.isUploaded ? 'attach' : 'upload',
          'attempts': _attempts,
          'error': e.toString(),
        }),
      );
      _setStatus(BackgroundPhotoUploadStatus.failed);
    }
  }
}
